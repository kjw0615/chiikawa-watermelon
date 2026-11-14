class_name ResetModal
extends UiModal
## 비밀번호 재설정 모달: 가입 때 등록한 이메일을 입력하면 재설정 링크 메일을 보낸다(Supabase /auth/v1/recover).

var email_edit: LineEdit
var send_button: Button
var _msg: Label
var _busy := false

func _init() -> void:
	title_text = "비밀번호 재설정"
	box_size = Vector2(460, 360)

func _build() -> void:
	var info := make_label("가입할 때 등록한 이메일을 입력하면 비밀번호를 다시 정할 수 있는 링크를 보내드려요.", Vector2(36, 78), Vector2(box_size.x - 72, 46), 15, UIPalette.TEXT_MUTED, true)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info)
	box.add_child(make_label("이메일", Vector2(40, 136), Vector2(box_size.x - 80, 20), 14, UIPalette.TEXT_MUTED))
	email_edit = LineEdit.new()
	email_edit.position = Vector2(40, 158)
	email_edit.size = Vector2(box_size.x - 80, 36)
	email_edit.max_length = 64
	email_edit.placeholder_text = "name@example.com"
	email_edit.add_theme_font_size_override("font_size", 16)
	email_edit.add_theme_color_override("font_color", UIPalette.TEXT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIPalette.PAPER
	sb.border_color = UIPalette.BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	email_edit.add_theme_stylebox_override("normal", sb)
	var sf := sb.duplicate() as StyleBoxFlat
	sf.border_color = UIPalette.BLUE_INK
	email_edit.add_theme_stylebox_override("focus", sf)
	email_edit.text_submitted.connect(func(_t: String): _on_send())
	box.add_child(email_edit)
	_msg = make_label("", Vector2(40, 204), Vector2(box_size.x - 80, 56), 14, AuthModal.ERROR_COL, true)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_msg)
	send_button = make_button("재설정 메일 보내기", Vector2(80, box_size.y - 82), Vector2(300, 52), UIPalette.PINK_STATES, 20)
	send_button.pressed.connect(_on_send)
	box.add_child(send_button)

func _on_open() -> void:
	_busy = false
	send_button.disabled = false
	email_edit.text = ""
	_msg.text = ""
	email_edit.grab_focus()

func _on_send() -> void:
	if _busy:
		return
	var email := email_edit.text.strip_edges()
	var err := AuthValidator.email_error(email)
	if err != "":
		_show(err, true)
		return
	_busy = true
	send_button.disabled = true
	_show("보내는 중...", false)
	var r: Dictionary = await Supabase.send_password_reset(email)
	_busy = false
	send_button.disabled = false
	if not is_open():
		return
	_show(r.get("message", "") if r["ok"] else r.get("error", "메일을 보내지 못했어요."), not r["ok"])

func _show(text: String, is_error: bool) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", AuthModal.ERROR_COL if is_error else UIPalette.BLUE_INK)
