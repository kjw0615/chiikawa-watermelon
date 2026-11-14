class_name AuthValidator
extends RefCounted
## 회원가입 입력 검증. 각 함수는 통과하면 "" 를, 아니면 사용자에게 보여줄 한국어 안내 문구를 돌려준다.

const NICK_MIN := 2
const NICK_MAX := 12
const PW_MIN := 8

static var _nick_re := _compile("^[가-힣a-zA-Z0-9-]+$")
static var _email_re := _compile(r"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$")
static var _letter_re := _compile("[A-Za-z]")
static var _digit_re := _compile("[0-9]")
static var _ascii_re := _compile("^[!-~]+$")   # 공백 없는 영문/숫자/특수문자(ASCII 인쇄 문자)만

static func _compile(p: String) -> RegEx:
	var r := RegEx.new()
	r.compile(p)
	return r

## 아이디(닉네임): 한글(완성형)/영문 대소문자/숫자/하이픈, 2~12자
static func nickname_error(s: String) -> String:
	if s.length() < NICK_MIN or s.length() > NICK_MAX:
		return "아이디는 %d~%d자로 입력해 주세요." % [NICK_MIN, NICK_MAX]
	if _nick_re.search(s) == null:
		return "아이디에는 한글, 영문, 숫자, 하이픈(-)만 쓸 수 있어요. (공백이나 다른 기호는 안 돼요)"
	return ""

## 비밀번호: 8자 이상, 영문과 숫자를 모두 포함
static func password_error(s: String) -> String:
	if s.length() < PW_MIN:
		return "비밀번호는 %d자 이상으로 입력해 주세요." % PW_MIN
	if _ascii_re.search(s) == null:
		return "비밀번호에는 영문, 숫자, 특수문자만 쓸 수 있어요. (한글과 공백은 안 돼요)"
	if _letter_re.search(s) == null or _digit_re.search(s) == null:
		return "비밀번호는 영문과 숫자를 모두 섞어서 만들어 주세요."
	return ""

static func email_error(s: String) -> String:
	if s.is_empty() or _email_re.search(s) == null:
		return "이메일 형식이 올바르지 않아요. (예: name@example.com)"
	return ""

## 회원가입 폼 전체 검사: 첫 번째로 걸린 안내 문구(모두 통과하면 "")
static func signup_error(nickname: String, email: String, password: String, password2 := "") -> String:
	var e := nickname_error(nickname)
	if e == "":
		e = email_error(email)
	if e == "":
		e = password_error(password)
	if e == "" and password2 != "" and password != password2:
		e = "비밀번호 확인이 서로 달라요."
	return e
