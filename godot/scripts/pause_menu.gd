class_name PauseMenu
extends CanvasLayer
## ESC 일시정지 메뉴: 트리를 멈추고(get_tree().paused) 중앙에 계속하기/종료하기 팝업을 띄운다.
## 이 노드만 PROCESS_MODE_ALWAYS 라서 멈춘 동안에도 ESC/버튼 입력을 받는다.

var _root: Control
var resume_button: Button
var quit_button: Button

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.size = Vector2(800, 800)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP   # 뒤쪽 클릭(노드 드롭) 차단
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.12, 0.55)
	dim.size = _root.size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var box := Panel.new()
	box.size = Vector2(320, 240)
	box.position = Vector2(240, 280)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffaff")
	sb.border_color = Color("c9bfe8")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 16
	box.add_theme_stylebox_override("panel", sb)
	_root.add_child(box)
	var t := Label.new()
	t.text = "일시정지 (PAUSE)"
	t.position = Vector2(0, 26)
	t.size = Vector2(320, 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color("7f63c9"))
	box.add_child(t)
	resume_button = _button("계속하기", Vector2(60, 92), Color("ff8fb8"))
	resume_button.pressed.connect(resume)
	box.add_child(resume_button)
	quit_button = _button("종료하기", Vector2(60, 160), Color("b79bf0"))
	quit_button.pressed.connect(func(): get_tree().quit())
	box.add_child(quit_button)

func is_open() -> bool:
	return _root.visible

func open() -> void:
	_root.visible = true
	get_tree().paused = true

func resume() -> void:
	_root.visible = false
	get_tree().paused = false

func _unhandled_input(e: InputEvent) -> void:
	if _root.visible and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		resume()

func _button(text: String, pos: Vector2, fill: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(200, 54)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	for st in ["normal", "hover", "pressed"]:
		var bx := StyleBoxFlat.new()
		bx.bg_color = fill.lightened(0.12) if st == "hover" else (fill.darkened(0.1) if st == "pressed" else fill)
		bx.border_color = Color.WHITE
		bx.set_border_width_all(3)
		bx.set_corner_radius_all(27)
		b.add_theme_stylebox_override(st, bx)
	return b
