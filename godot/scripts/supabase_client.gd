class_name SupabaseClient
extends Node
## Supabase 연동(autoload 이름: Supabase). DB 에 항상 붙어 있지 않고, 필요할 때만 HTTPS 요청 한 번(Stateless)으로 조회/저장한다.
##  - 인증: GoTrue(/auth/v1) 이메일+비밀번호. refresh_token 만 user://auth.cfg 에 저장해 자동 로그인
##  - 데이터: PostgREST(/rest/v1) RPC(submit_score, get_leaderboard, nickname_available)
## 모든 요청 함수는 await 로 쓰며 {"ok": bool, "error": 한국어 안내, ...} 를 돌려준다. 실패해도 게임은 계속 진행된다.

signal auth_changed

const CONFIG_PATH := "res://data/supabase.cfg"
const AUTH_PATH := "user://auth.cfg"
const TIMEOUT := 10.0

var enabled := true            # 자체 테스트(--headless)에서는 false: 네트워크/사용자 파일을 건드리지 않는다
var signed_in := false
var user_id := ""
var nickname := ""
var server_best := 0
var _url := ""
var _key := ""
var _access := ""
var _refresh := ""
var _expires_at := 0.0         # access_token 만료(유닉스 초)

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		_url = str(cfg.get_value("supabase", "url", "")).trim_suffix("/")
		_key = str(cfg.get_value("supabase", "key", ""))
	var net_test := "--net-test" in OS.get_cmdline_user_args()   # 실서버 통신 점검용(헤드리스에서도 네트워크 허용)
	enabled = (DisplayServer.get_name() != "headless" or net_test) and _url != "" and _key != ""

## 저장된 refresh_token 으로 자동 로그인 시도(타이틀 진입 시 한 번)
func auto_login() -> void:
	if not enabled or signed_in:
		return
	var cfg := ConfigFile.new()
	if cfg.load(AUTH_PATH) != OK:
		return
	_refresh = str(cfg.get_value("auth", "refresh_token", ""))
	if _refresh == "":
		return
	var r := await _auth_request("/auth/v1/token?grant_type=refresh_token", {"refresh_token": _refresh})
	if r["ok"]:
		await _on_session(r["data"])
	elif r.get("status", 0) >= 400 and r.get("status", 0) < 500:
		_clear_saved()   # 만료/폐기된 토큰이면 지운다(네트워크 오류일 땐 유지)

func sign_up(nick: String, email: String, password: String) -> Dictionary:
	var v := AuthValidator.signup_error(nick, email, password)
	if v != "":
		return {"ok": false, "error": v}
	var av := await _rpc("nickname_available", {"p_nick": nick}, false)
	if av["ok"] and av["data"] == false:
		return {"ok": false, "error": "이미 사용 중인 아이디예요. 다른 아이디를 써 주세요."}
	var r := await _auth_request("/auth/v1/signup", {"email": email, "password": password, "data": {"nickname": nick}})
	if not r["ok"]:
		return r
	var d = r["data"]
	if d is Dictionary and d.has("access_token"):
		await _on_session(d)
		return {"ok": true, "message": "가입 완료! 환영해요, %s님." % nickname}
	return {"ok": true, "message": "가입 완료! 인증 메일을 확인한 뒤 로그인해 주세요."}

## 아이디(닉네임) + 비밀번호로 로그인. 서버 RPC login_email 이 비밀번호까지 맞을 때만 이메일을 돌려주고, 그 이메일로 Supabase Auth 로그인한다
func sign_in(nick: String, password: String) -> Dictionary:
	if nick == "":
		return {"ok": false, "error": "아이디를 입력해 주세요."}
	if password == "":
		return {"ok": false, "error": "비밀번호를 입력해 주세요."}
	var lr := await _rpc("login_email", {"p_nick": nick, "p_password": password}, false)
	if not lr["ok"]:
		return lr
	if not (lr["data"] is String) or lr["data"] == "":
		return {"ok": false, "error": "아이디 또는 비밀번호가 맞지 않아요. (여러 번 틀렸다면 잠시 후 다시 시도해 주세요)"}
	var r := await _auth_request("/auth/v1/token?grant_type=password", {"email": lr["data"], "password": password})
	if not r["ok"]:
		return r
	await _on_session(r["data"])
	return {"ok": true, "message": "%s님, 어서 와요!" % nickname}

## 비밀번호 재설정 메일 발송(/auth/v1/recover). 서버는 가입 여부와 관계없이 성공으로 답하므로 이메일 존재 여부는 알려주지 않는다
func send_password_reset(email: String) -> Dictionary:
	var e := AuthValidator.email_error(email)
	if e != "":
		return {"ok": false, "error": e}
	var r := await _auth_request("/auth/v1/recover", {"email": email})
	if not r["ok"]:
		if r.get("status", 0) == 429:
			r["error"] = "메일을 너무 자주 보냈어요. 잠시 후 다시 시도해 주세요."
		return r
	return {"ok": true, "message": "등록된 이메일로 비밀번호 재설정 링크를 보냈어요! 메일이 안 보이면 스팸함도 확인해 주세요."}

func sign_out() -> void:
	if enabled and _access != "":
		await _auth_request("/auth/v1/logout", {}, true)   # 실패해도 로컬 로그아웃은 진행
	signed_in = false
	user_id = ""
	nickname = ""
	server_best = 0
	_access = ""
	_refresh = ""
	_clear_saved()
	auth_changed.emit()

## 게임오버 시 호출: 로그인 상태면 서버에 제출(서버는 신기록일 때만 반영). 로컬 최고점은 main 이 따로 저장한다
func record_score(score: int) -> Dictionary:
	if not (enabled and signed_in):
		return {"ok": true, "submitted": false}
	var r := await _rpc("submit_score", {"p_score": score}, true)
	if r["ok"]:
		server_best = int(r["data"])
		r["submitted"] = true
	return r

func fetch_top(limit := 10) -> Dictionary:
	if not enabled:
		return {"ok": false, "error": "랭킹은 온라인에서만 볼 수 있어요."}
	var r := await _rpc("get_leaderboard", {"p_limit": limit}, false)
	if r["ok"] and not (r["data"] is Array):
		return {"ok": false, "error": "랭킹 정보를 읽지 못했어요."}
	return r

# ---- 내부 ----

func _on_session(d: Dictionary) -> void:
	_access = str(d.get("access_token", ""))
	_refresh = str(d.get("refresh_token", ""))
	_expires_at = Time.get_unix_time_from_system() + float(d.get("expires_in", 3600))
	var u = d.get("user", {})
	user_id = str(u.get("id", "")) if u is Dictionary else ""
	signed_in = _access != "" and user_id != ""
	if not signed_in:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("auth", "refresh_token", _refresh)
	cfg.save(AUTH_PATH)
	nickname = ""
	var p := await _rest_get("/rest/v1/profiles?select=nickname&id=eq.%s" % user_id)
	if p["ok"] and p["data"] is Array and not p["data"].is_empty():
		nickname = str(p["data"][0].get("nickname", ""))
	if nickname == "" and u is Dictionary:
		nickname = str(u.get("user_metadata", {}).get("nickname", "플레이어"))
	var s := await _rest_get("/rest/v1/scores?select=best_score&user_id=eq.%s" % user_id)
	server_best = int(s["data"][0].get("best_score", 0)) if s["ok"] and s["data"] is Array and not s["data"].is_empty() else 0
	auth_changed.emit()

func _clear_saved() -> void:
	if FileAccess.file_exists(AUTH_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTH_PATH))

## access_token 이 곧 만료되면 refresh_token 으로 갱신
func _ensure_token() -> bool:
	if _access != "" and Time.get_unix_time_from_system() < _expires_at - 30.0:
		return true
	if _refresh == "":
		return false
	var r := await _auth_request("/auth/v1/token?grant_type=refresh_token", {"refresh_token": _refresh})
	if not r["ok"]:
		return false
	_access = str(r["data"].get("access_token", ""))
	_refresh = str(r["data"].get("refresh_token", _refresh))
	_expires_at = Time.get_unix_time_from_system() + float(r["data"].get("expires_in", 3600))
	var cfg := ConfigFile.new()
	cfg.set_value("auth", "refresh_token", _refresh)
	cfg.save(AUTH_PATH)
	return true

func _auth_request(path: String, body: Dictionary, with_token := false) -> Dictionary:
	return await _http(HTTPClient.METHOD_POST, path, body, _access if with_token else "")

func _rpc(fn: String, args: Dictionary, need_login: bool) -> Dictionary:
	if need_login:
		if not await _ensure_token():
			return {"ok": false, "error": "로그인이 필요해요."}
	return await _http(HTTPClient.METHOD_POST, "/rest/v1/rpc/" + fn, args, _access if need_login else "")

func _rest_get(path: String) -> Dictionary:
	return await _http(HTTPClient.METHOD_GET, path, {}, _access)

## 요청 1회: 새 HTTPRequest 를 만들어 보내고 응답을 받으면 바로 정리한다(연결을 유지하지 않음)
func _http(method: int, path: String, body: Dictionary, token: String) -> Dictionary:
	if not enabled:
		return {"ok": false, "error": "서버에 연결할 수 없어요."}
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT
	add_child(req)
	var headers := PackedStringArray(["apikey: " + _key, "Content-Type: application/json"])
	headers.append("Authorization: Bearer " + (token if token != "" else _key))
	var payload := "" if method == HTTPClient.METHOD_GET else JSON.stringify(body)
	var err := req.request(_url + path, headers, method, payload)
	if err != OK:
		req.queue_free()
		return {"ok": false, "error": "서버에 연결할 수 없어요. 잠시 후 다시 시도해 주세요."}
	var res: Array = await req.request_completed
	req.queue_free()
	var result: int = res[0]
	var status: int = res[1]
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "error": "서버에 연결할 수 없어요. 인터넷 연결을 확인해 주세요."}
	var data = JSON.parse_string(text) if text != "" else {}
	if status >= 200 and status < 300:
		return {"ok": true, "status": status, "data": data}
	return {"ok": false, "status": status, "error": error_message(status, data)}

## 서버 오류 응답을 한국어 안내로 바꾼다
static func error_message(status: int, data) -> String:
	var raw := ""
	if data is Dictionary:
		for k in ["msg", "error_description", "message", "error"]:
			if data.has(k):
				raw = str(data[k])
				break
	var low := raw.to_lower()
	if low.contains("invalid login credentials"):
		return "이메일 또는 비밀번호가 맞지 않아요."
	if low.contains("already registered") or low.contains("already been registered"):
		return "이미 가입된 이메일이에요. 로그인해 주세요."
	if low.contains("email not confirmed"):
		return "이메일 인증이 아직 안 됐어요. 메일함을 확인해 주세요."
	if low.contains("password") and (low.contains("weak") or low.contains("least")):
		return "비밀번호가 너무 약해요. 8자 이상, 영문과 숫자를 섞어 주세요."
	if low.contains("rate limit") or status == 429:
		return "요청이 너무 많아요. 잠시 후 다시 시도해 주세요."
	if low.contains("database error saving new user") or low.contains("duplicate key") or low.contains("nickname"):
		return "이미 사용 중인 아이디이거나 사용할 수 없는 아이디예요."
	if status >= 500:
		return "서버에 문제가 생겼어요. 잠시 후 다시 시도해 주세요."
	return "요청을 처리하지 못했어요. (%s)" % (raw if raw != "" else str(status))
