class_name AuthModal
extends UiModal
## 로그인 / 회원가입 모달. 입력 규칙은 AuthValidator, 서버 호출은 Supabase(autoload)가 맡는다.

const ERROR_COL := Color("B5524E")

var signup := false
var _tab_login: Button
var _tab_signup: Button
var _fields: Dictionary = {}   # key -> {cap: Label, edit: LineEdit}
var _msg: Label
var _submit: Button
var _busy := false
var _forgot: Button

signal forgot_requested   # 비밀번호 재설정 모달 열기

func _init() -> void:
	title_text = "로그인 / 회원가입"
	box_size = Vector2(480, 540)

func _build() -> void:
	_tab_login = make_button("로그인", Vector2(40, 76), Vector2(190, 40), UIPalette.PINK_STATES, 20)
	_tab_login.pressed.connect(func(): _set_mode(false))
	box.add_child(_tab_login)
	_tab_signup = make_button("회원가입", Vector2(250, 76), Vector2(190, 40), UIPalette.PINK_STATES, 20)
	_tab_signup.pressed.connect(func(): _set_mode(true))
	box.add_child(_tab_signup)
	_add_field("nick", "아이디", false)
	_add_field("email", "이메일 (비밀번호 재설정용)", false)
	_add_field("pw", "비밀번호 (8자 이상, 영문+숫자)", true)
	_add_field("pw2", "비밀번호 확인", true)
	_msg = make_label("", Vector2(40, 0), Vector2(box_size.x - 80, 40), 14, ERROR_COL, true)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_msg)
	_forgot = Button.new()
	_forgot.text = "비밀번호를 잊으셨나요?"
	_forgot.flat = true
	_forgot.focus_mode = Control.FOCUS_NONE
	_forgot.size = Vector2(220, 30)
	_forgot.add_theme_font_override("font", UIPalette.button_font())
	_forgot.add_theme_font_size_override("font_size", 15)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		_forgot.add_theme_color_override(c, UIPalette.BLUE_INK)
	_forgot.pressed.connect(func(): forgot_requested.emit())
	box.add_child(_forgot)
	_submit = make_button("로그인", Vector2(110, box_size.y - 72), Vector2(260, 52), UIPalette.PINK_STATES, 22)
	_submit.pressed.connect(_on_submit)
	box.add_child(_submit)
	_set_mode(false)

func _add_field(key: String, caption: String, secret: bool) -> void:
	var cap := make_label(caption, Vector2(40, 0), Vector2(box_size.x - 80, 20), 14, UIPalette.TEXT_MUTED)
	box.add_child(cap)
	var e := LineEdit.new()
	e.size = Vector2(box_size.x - 80, 36)
	e.secret = secret
	e.secret_character = "*"   # 웹에서 기본 점(•)이 이모지로 보이는 문제 방지
	e.max_length = 64 if key != "nick" else AuthValidator.NICK_MAX
	e.add_theme_font_size_override("font_size", 16)
	e.add_theme_color_override("font_color", UIPalette.TEXT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIPalette.PAPER
	sb.border_color = UIPalette.BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	e.add_theme_stylebox_override("normal", sb)
	var sf := sb.duplicate() as StyleBoxFlat
	sf.border_color = UIPalette.BLUE_INK
	e.add_theme_stylebox_override("focus", sf)
	e.text_submitted.connect(func(_t: String): _on_submit())
	box.add_child(e)
	_fields[key] = {"cap": cap, "edit": e}

## 로그인 / 회원가입 전환: 보이는 입력칸을 다시 배치
func _set_mode(is_signup: bool) -> void:
	signup = is_signup
	var tab_on := [UIPalette.PINK, UIPalette.PINK_HOVER, UIPalette.PINK_PRESSED]
	var tab_off := [UIPalette.PAPER, UIPalette.CREAM, UIPalette.DIVIDER]
	UIPalette.style_button(_tab_login, tab_off if is_signup else tab_on)
	UIPalette.style_button(_tab_signup, tab_on if is_signup else tab_off)
	var keys := ["nick", "email", "pw", "pw2"] if is_signup else ["nick", "pw"]
	(_fields["nick"]["cap"] as Label).text = "아이디 (한글·영문·숫자·-, 2~12자)" if is_signup else "아이디"
	var y := 132.0
	for k in ["nick", "email", "pw", "pw2"]:
		var f: Dictionary = _fields[k]
		var on: bool = k in keys
		(f["cap"] as Label).visible = on
		(f["edit"] as LineEdit).visible = on
		if on:
			(f["cap"] as Label).position.y = y
			(f["edit"] as LineEdit).position = Vector2(40, y + 22.0)
			y += 68.0
	_msg.position.y = y + 2.0
	_forgot.visible = not is_signup
	_forgot.position = Vector2((box_size.x - 220.0) / 2.0, y + 46.0)
	_msg.text = ""
	_submit.text = "가입하기" if is_signup else "로그인"

func _on_open() -> void:
	_busy = false
	_submit.disabled = false
	for k in _fields:
		(_fields[k]["edit"] as LineEdit).text = ""
	_set_mode(false)
	(_fields["nick"]["edit"] as LineEdit).grab_focus()

func _text(k: String) -> String:
	return (_fields[k]["edit"] as LineEdit).text.strip_edges() if k != "pw" and k != "pw2" else (_fields[k]["edit"] as LineEdit).text

func _on_submit() -> void:
	if _busy:
		return
	var err := ""
	if signup:
		err = AuthValidator.signup_error(_text("nick"), _text("email"), _text("pw"), _text("pw2"))
	else:
		if _text("nick") == "":
			err = "아이디를 입력해 주세요."
		elif _text("pw") == "":
			err = "비밀번호를 입력해 주세요."
	if err != "":
		_show(err, true)
		return
	_busy = true
	_submit.disabled = true
	_show("잠시만요...", false)
	var r: Dictionary
	if signup:
		r = await Supabase.sign_up(_text("nick"), _text("email"), _text("pw"))
	else:
		r = await Supabase.sign_in(_text("nick"), _text("pw"))
	_busy = false
	_submit.disabled = false
	if not is_open():
		return
	if not r["ok"]:
		_show(r.get("error", "문제가 생겼어요. 다시 시도해 주세요."), true)
		return
	if Supabase.signed_in:
		close()
	else:
		_set_mode(false)   # 이메일 인증이 필요한 가입: 안내 후 로그인 탭으로
		_show(r.get("message", ""), false)

func _show(text: String, is_error: bool) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", ERROR_COL if is_error else UIPalette.BLUE_INK)
