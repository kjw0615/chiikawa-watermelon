class_name ResetModal
extends UiModal
## 비밀번호 재설정 모달: 가입 때 등록한 이메일을 입력하면 재설정 링크 메일을 보낸다(Supabase /auth/v1/recover).

var nick_edit: LineEdit
var email_edit: LineEdit
var send_button: Button
var _msg: Label
var _busy := false

func _init() -> void:
	title_text = "비밀번호 재설정"
	box_size = Vector2(460, 430)

func _build() -> void:
	var info := make_label("가입할 때 쓴 아이디와 이메일을 입력하면, 두 정보가 일치할 때 비밀번호를 다시 정할 수 있는 링크를 보내드려요.", Vector2(36, 78), Vector2(box_size.x - 72, 46), 15, UIPalette.TEXT_MUTED, true)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info)
	box.add_child(make_label("아이디", Vector2(40, 132), Vector2(box_size.x - 80, 20), 14, UIPalette.TEXT_MUTED))
	nick_edit = _edit(Vector2(40, 154), "")
	nick_edit.max_length = AuthValidator.NICK_MAX
	box.add_child(make_label("이메일", Vector2(40, 200), Vector2(box_size.x - 80, 20), 14, UIPalette.TEXT_MUTED))
	email_edit = _edit(Vector2(40, 222), "name@example.com")
	_msg = make_label("", Vector2(40, 270), Vector2(box_size.x - 80, 56), 14, AuthModal.ERROR_COL, true)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_msg)
	send_button = make_button("재설정 메일 보내기", Vector2(80, box_size.y - 82), Vector2(300, 52), UIPalette.PINK_STATES, 20)
	send_button.pressed.connect(_on_send)
	box.add_child(send_button)

func _edit(pos: Vector2, placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.position = pos
	e.size = Vector2(box_size.x - 80, 36)
	e.max_length = 64
	e.placeholder_text = placeholder
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
	e.text_submitted.connect(func(_t: String): _on_send())
	box.add_child(e)
	return e

func _on_open() -> void:
	_busy = false
	send_button.disabled = false
	nick_edit.text = ""
	email_edit.text = ""
	_msg.text = ""
	nick_edit.grab_focus()

func _on_send() -> void:
	if _busy:
		return
	var nick := nick_edit.text.strip_edges()
	var email := email_edit.text.strip_edges()
	var err := "아이디를 입력해 주세요." if nick == "" else AuthValidator.email_error(email)
	if err != "":
		_show(err, true)
		return
	_busy = true
	send_button.disabled = true
	_show("보내는 중...", false)
	var r: Dictionary = await Supabase.send_password_reset(nick, email)
	_busy = false
	send_button.disabled = false
	if not is_open():
		return
	_show(r.get("message", "") if r["ok"] else r.get("error", "메일을 보내지 못했어요."), not r["ok"])

func _show(text: String, is_error: bool) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", AuthModal.ERROR_COL if is_error else UIPalette.BLUE_INK)
