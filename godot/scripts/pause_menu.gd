class_name PauseMenu
extends CanvasLayer
## ESC 일시정지 메뉴: 트리를 멈추고(get_tree().paused) 중앙에 계속하기/종료하기 팝업을 띄운다.
## 이 노드만 PROCESS_MODE_ALWAYS 라서 멈춘 동안에도 ESC/버튼 입력을 받는다.

var _root: Control
var resume_button: Button
var quit_button: Button

signal home_requested   # 메인(타이틀) 화면으로 돌아가기

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.size = Vector2(800, 800)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP   # 뒤쪽 클릭(노드 드롭) 차단
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.349, 0.267, 0.231, 0.35)
	dim.size = _root.size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var box := Panel.new()
	box.size = Vector2(440, 400)
	box.position = Vector2(180, 200)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIPalette.CREAM
	sb.border_color = UIPalette.BORDER
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(22)
	sb.shadow_color = UIPalette.SHADOW
	sb.shadow_size = 16
	box.add_theme_stylebox_override("panel", sb)
	_root.add_child(box)
	var t := Label.new()
	t.clip_text = true   # 글자가 많아도 칸이 늘어나지 않게(넘침은 --text-audit 로 점검)
	t.text = "일시정지 (PAUSE)"
	t.position = Vector2(0, 26)
	t.size = Vector2(440, 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", UIPalette.title_font())
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", UIPalette.TEXT)
	box.add_child(t)
	# 게임 중 언제든 두 볼륨을 조절: BGM / SFX(효과음)
	var bgm_row := VolumeRow.new("bgm", "BGM")
	bgm_row.position = Vector2(20, 88)
	box.add_child(bgm_row)
	var sfx_row := VolumeRow.new("sfx", "효과음")
	sfx_row.position = Vector2(20, 138)
	box.add_child(sfx_row)
	var div := ColorRect.new()
	div.color = UIPalette.DIVIDER
	div.position = Vector2(30, 196)
	div.size = Vector2(380, 2)
	box.add_child(div)
	resume_button = _button("계속하기", Vector2(120, 216), [UIPalette.PINK, UIPalette.PINK_HOVER, UIPalette.PINK_PRESSED])
	resume_button.pressed.connect(resume)
	box.add_child(resume_button)
	quit_button = _button("메인으로", Vector2(120, 290), UIPalette.QUIT_BG)
	quit_button.pressed.connect(func(): home_requested.emit())
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

func _button(text: String, pos: Vector2, states: Array) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(200, 54)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UIPalette.button_font())
	b.add_theme_font_size_override("font_size", 22)
	UIPalette.style_button(b, states)
	return b
