class_name TitleScreen
extends Control
## 타이틀 화면: 제목 + 게임 시작 버튼 + 비영리 팬 메이드 면책 문구. 시작하면 start_pressed 를 낸다.

signal start_pressed

const TITLE_KO := "먼작귀 데굴데굴 섬"
const TITLE_EN := "Chiikawa Tumble Island"
const DISCLAIMER_KO := "본 게임은 공식이 아닌 비영리 팬 메이드 게임입니다."
const DISCLAIMER_EN := "This is a non-commercial fan-made game. All rights to Chiikawa belong to Nagano / Chiikawa Committee."

var start_button: Button
var _mascots: Array[Sprite2D] = []
var _t := 0.0

func _ready() -> void:
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 동굴 아트가 비쳐 보이는 어두운 막
	var dim := ColorRect.new()
	dim.color = Color(0.09, 0.06, 0.2, 0.62)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# 제목
	_add_title()

	# 장식: 치이카와/하치와레/우사기가 둥실둥실
	for i in 3:
		var d := HeadShapes.get_data(i)
		var sp := Sprite2D.new()
		sp.texture = d["tex"]
		sp.offset = d["size"] / 2.0 - d["centroid"]
		sp.scale = Vector2.ONE * 0.2
		sp.position = Vector2(size.x / 2.0 + (i - 1) * 150.0, 290.0)
		add_child(sp)
		_mascots.append(sp)

	# 게임 시작 버튼
	start_button = Button.new()
	start_button.text = "게임 시작"
	start_button.size = Vector2(280, 76)
	start_button.position = Vector2((size.x - 280.0) / 2.0, 430.0)
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.add_theme_font_size_override("font_size", 32)
	start_button.add_theme_color_override("font_color", Color.WHITE)
	start_button.add_theme_color_override("font_hover_color", Color.WHITE)
	start_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	start_button.add_theme_color_override("font_outline_color", Color("c2477f"))
	start_button.add_theme_constant_override("outline_size", 4)
	start_button.add_theme_stylebox_override("normal", _btn_box(Color("ff8fb8")))
	start_button.add_theme_stylebox_override("hover", _btn_box(Color("ffa6c8")))
	start_button.add_theme_stylebox_override("pressed", _btn_box(Color("f0709f")))
	start_button.pressed.connect(func(): start_pressed.emit())
	add_child(start_button)
	add_child(_text("Enter / Space 로도 시작할 수 있어요", Vector2(0, 520), Vector2(size.x, 24), 15, Color("e9ddff"), 4))

	# 하단 면책 문구(공식 오인 방지)
	var bar := Panel.new()
	bar.position = Vector2(20, 668)
	bar.size = Vector2(size.x - 40.0, 112)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.12, 0.6)
	sb.border_color = Color("b79bf0")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)
	add_child(_text(DISCLAIMER_KO, Vector2(30, 682), Vector2(size.x - 60.0, 28), 17, Color.WHITE, 3))
	var en := _text(DISCLAIMER_EN, Vector2(30, 716), Vector2(size.x - 60.0, 56), 14, Color("e9ddff"), 3)
	en.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(en)

## 큰 굵은 제목: 크림색 글자 + 치이카와 핑크 두꺼운 테두리 + 아래로 떨어지는 그림자, 영문 부제는 그 아래 핑크 리본
func _add_title() -> void:
	var bold := FontVariation.new()
	bold.base_font = load("res://assets/fonts/NotoSansKR-subset.ttf")
	bold.variation_opentype = {0x77676874: 900}   # "wght" 축 최대 굵기
	bold.variation_embolden = 0.25
	var t := _text(TITLE_KO, Vector2(0, 60), Vector2(size.x, 110), 80, Color("fff6e0"), 16)
	t.add_theme_font_override("font", bold)
	t.add_theme_color_override("font_outline_color", Color("ff7fae"))
	t.add_theme_color_override("font_shadow_color", Color("b83a73"))
	t.add_theme_constant_override("shadow_offset_x", 0)
	t.add_theme_constant_override("shadow_offset_y", 8)
	t.add_theme_constant_override("shadow_outline_size", 16)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(t)
	# 영문 부제 리본
	var ribbon := Panel.new()
	ribbon.position = Vector2((size.x - 420.0) / 2.0, 178)
	ribbon.size = Vector2(420, 46)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("ff9cc2")
	sb.border_color = Color("fff6e0")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(23)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	ribbon.add_theme_stylebox_override("panel", sb)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ribbon)
	var sub := _text(TITLE_EN, Vector2(0, 182), Vector2(size.x, 38), 26, Color("fffaf0"), 5)
	sub.add_theme_font_override("font", bold)
	sub.add_theme_color_override("font_outline_color", Color("d9558a"))
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(sub)

func _process(dt: float) -> void:
	_t += dt
	for i in _mascots.size():
		var sp := _mascots[i]
		sp.position.y = 290.0 + sin(_t * 2.2 + i * 1.3) * 9.0
		sp.rotation = sin(_t * 1.6 + i) * 0.06

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER or e.keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		start_pressed.emit()

func _text(t: String, pos: Vector2, sz: Vector2, font_size: int, col: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.size = sz
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("2d2552"))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _btn_box(fill: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = Color.WHITE
	b.set_border_width_all(4)
	b.set_corner_radius_all(38)
	b.shadow_color = Color(0, 0, 0, 0.35)
	b.shadow_size = 8
	b.shadow_offset = Vector2(0, 4)
	return b
