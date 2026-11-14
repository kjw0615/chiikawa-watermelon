class_name UiModal
extends CanvasLayer
## 공용 모달 뼈대: 어둡게 덮는 배경 + 크림색 상자 + 제목 + 닫기(X). ESC 로도 닫힌다.
## 하위 클래스는 title_text / box_size 를 정한 뒤 add_child 하고, _build() 에서 상자(box) 안을 채운다.
## 이 노드는 PROCESS_MODE_ALWAYS 라서 게임이 멈춘 동안(pause_game)에도 입력을 받는다.

signal closed

var title_text := ""
var box_size := Vector2(480, 520)
var pause_game := false   # true 면 열려 있는 동안 게임(트리)을 멈춘다
var box: Panel
var _root: Control

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.size = Vector2(800, 800)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP   # 뒤쪽 클릭 차단
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(UIPalette.TEXT, 0.35)
	dim.size = _root.size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	box = Panel.new()
	box.size = box_size
	box.position = (Vector2(800, 800) - box_size) / 2.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIPalette.CREAM
	sb.border_color = UIPalette.BORDER
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(22)
	sb.shadow_color = UIPalette.SHADOW
	sb.shadow_size = 16
	box.add_theme_stylebox_override("panel", sb)
	_root.add_child(box)
	var t := make_label(title_text, Vector2(0, 18), Vector2(box_size.x, 44), 28, UIPalette.TEXT, true)
	t.add_theme_font_override("font", UIPalette.title_font())
	box.add_child(t)
	var x := make_button("X", Vector2(box_size.x - 52, 14), Vector2(36, 36), UIPalette.QUIT_BG, 18)
	x.pressed.connect(close)
	box.add_child(x)
	_build()

## 하위 클래스가 상자(box) 안을 채운다
func _build() -> void:
	pass

func _on_open() -> void:
	pass

func is_open() -> bool:
	return _root != null and _root.visible

func open() -> void:
	_root.visible = true
	if pause_game:
		get_tree().paused = true
	_on_open()

func close() -> void:
	if not is_open():
		return
	_root.visible = false
	if pause_game:
		get_tree().paused = false
	closed.emit()

func _unhandled_input(e: InputEvent) -> void:
	if is_open() and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

static func make_label(text: String, pos: Vector2, sz: Vector2, font_size: int, col: Color, center := false) -> Label:
	var l := Label.new()
	l.clip_text = true   # 글자가 많아도 칸이 늘어나지 않게(넘침은 --text-audit 로 점검)
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.size = sz   # 글꼴 크기를 정한 뒤에 크기를 줘야 기본(16px) 높이로 커지지 않는다
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func make_button(text: String, pos: Vector2, sz: Vector2, states: Array, font_size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UIPalette.button_font())
	b.add_theme_font_size_override("font_size", font_size)
	UIPalette.style_button(b, states)
	return b
