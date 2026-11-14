class_name TitleScreen
extends Control
## 타이틀 화면: 제목 + 게임 시작 버튼 + 비영리 팬 메이드 면책 문구. 시작하면 start_pressed 를 낸다.

signal start_pressed
signal rank_pressed
signal login_pressed
signal logout_pressed

const TITLE_KO := "먼작귀 데굴데굴 섬"
const TITLE_EN := "Chiikawa Tumble Island"
const DISCLAIMER_KO := "본 게임은 공식이 아닌 비영리 팬 메이드 게임입니다."
const DISCLAIMER_EN := "This is a non-commercial fan-made game. All rights to Chiikawa belong to Nagano / Chiikawa Committee."

var start_button: Button
var rank_button: Button
var account_button: Button   # 로그인/회원가입 <-> 로그아웃
var _account_label: Label
var _mascots: Array[Sprite2D] = []
var blocked := false   # 모달이 열려 있으면 Enter/Space 로 시작하지 않는다
var _t := 0.0

func _ready() -> void:
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 배경: 상단 하늘색 -> 하단 크림의 완만한 그라데이션(동굴 그림이 12% 정도 비침)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(UIPalette.TITLE_BG_TOP, 0.88), Color(UIPalette.TITLE_BG_BOTTOM, 0.88)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	var bg := TextureRect.new()
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

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
	start_button.add_theme_font_override("font", UIPalette.button_font())
	start_button.add_theme_font_size_override("font_size", 32)
	start_button.add_theme_color_override("font_color", UIPalette.TEXT)
	start_button.add_theme_color_override("font_hover_color", UIPalette.TEXT)
	start_button.add_theme_color_override("font_pressed_color", UIPalette.TEXT)
	start_button.add_theme_stylebox_override("normal", _btn_box(UIPalette.PINK))
	start_button.add_theme_stylebox_override("hover", _btn_box(UIPalette.PINK_HOVER))
	start_button.add_theme_stylebox_override("pressed", _btn_box(UIPalette.PINK_PRESSED))
	start_button.pressed.connect(func(): start_pressed.emit())
	add_child(start_button)
	add_child(_text("Enter / Space 로도 시작할 수 있어요", Vector2(0, 520), Vector2(size.x, 24), 15, UIPalette.TEXT_MUTED, 0))

	# 랭킹 / 계정(로그인·로그아웃) 버튼 줄
	_account_label = _text("", Vector2(0, 552), Vector2(size.x, 24), 16, UIPalette.BLUE_INK, 0)
	add_child(_account_label)
	rank_button = _small_button("랭킹", Vector2(size.x / 2.0 - 160.0, 584), UIPalette.ITEM_BG["fountain"])
	rank_button.pressed.connect(func(): rank_pressed.emit())
	add_child(rank_button)
	account_button = _small_button("로그인 / 회원가입", Vector2(size.x / 2.0 + 10.0, 584), [UIPalette.PAPER, UIPalette.CREAM, UIPalette.DIVIDER])
	account_button.pressed.connect(func(): logout_pressed.emit() if Supabase.signed_in else login_pressed.emit())
	add_child(account_button)
	Supabase.auth_changed.connect(_refresh_account)
	_refresh_account()

	# 하단 면책 문구(공식 오인 방지)
	var bar := Panel.new()
	bar.position = Vector2(20, 668)
	bar.size = Vector2(size.x - 40.0, 112)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIPalette.PAPER
	sb.border_color = UIPalette.DIVIDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)
	add_child(_text(DISCLAIMER_KO, Vector2(30, 682), Vector2(size.x - 60.0, 28), 17, UIPalette.TEXT_MUTED, 0))
	var en := _text(DISCLAIMER_EN, Vector2(30, 716), Vector2(size.x - 60.0, 56), 14, UIPalette.TEXT_MUTED, 0)
	en.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(en)

## 큰 굵은 제목: 크림색 글자 + 치이카와 핑크 두꺼운 테두리 + 아래로 떨어지는 그림자, 영문 부제는 그 아래 핑크 리본
func _add_title() -> void:
	var bold := UIPalette.title_font()
	var t := _text(TITLE_KO, Vector2(0, 60), Vector2(size.x, 110), 80, UIPalette.TITLE_FILL, 6)
	t.add_theme_font_override("font", bold)
	t.add_theme_color_override("font_outline_color", UIPalette.TEXT)
	t.add_theme_color_override("font_shadow_color", UIPalette.TITLE_SHADOW)
	t.add_theme_constant_override("shadow_offset_x", 0)
	t.add_theme_constant_override("shadow_offset_y", 3)
	t.add_theme_constant_override("shadow_outline_size", 6)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(t)
	# 영문 부제 리본
	var ribbon := Panel.new()
	ribbon.position = Vector2((size.x - 420.0) / 2.0, 178)
	ribbon.size = Vector2(420, 46)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIPalette.RIBBON
	sb.border_color = UIPalette.BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(23)
	sb.shadow_color = UIPalette.SHADOW
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	ribbon.add_theme_stylebox_override("panel", sb)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ribbon)
	var sub := _text(TITLE_EN, Vector2(0, 182), Vector2(size.x, 38), 26, UIPalette.TEXT, 0)
	sub.add_theme_font_override("font", bold)
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(sub)

func _refresh_account() -> void:
	if Supabase.signed_in:
		_account_label.text = "%s님, 환영해요!" % Supabase.nickname
		account_button.text = "로그아웃"
	else:
		_account_label.text = ""
		account_button.text = "로그인 / 회원가입"

func _small_button(t: String, pos: Vector2, states: Array) -> Button:
	var b := Button.new()
	b.text = t
	b.position = pos
	b.size = Vector2(150, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UIPalette.button_font())
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", UIPalette.TEXT)
	b.add_theme_color_override("font_hover_color", UIPalette.TEXT)
	b.add_theme_color_override("font_pressed_color", UIPalette.TEXT)
	UIPalette.style_button(b, states)
	return b

func _process(dt: float) -> void:
	_t += dt
	for i in _mascots.size():
		var sp := _mascots[i]
		sp.position.y = 290.0 + sin(_t * 2.2 + i * 1.3) * 9.0
		sp.rotation = sin(_t * 1.6 + i) * 0.06

func _unhandled_input(e: InputEvent) -> void:
	if not visible or blocked:
		return
	if e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER or e.keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		start_pressed.emit()

func _text(t: String, pos: Vector2, sz: Vector2, font_size: int, col: Color, outline: int) -> Label:
	var l := Label.new()
	l.clip_text = true   # 글자가 많아도 칸이 늘어나지 않게(넘침은 --text-audit 로 점검)
	l.text = t
	l.position = pos
	l.size = sz
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", UIPalette.TEXT)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _btn_box(fill: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = UIPalette.CONTROL_BORDER
	b.set_border_width_all(3)
	b.set_corner_radius_all(38)
	b.shadow_color = UIPalette.SHADOW
	b.shadow_size = 8
	b.shadow_offset = Vector2(0, 4)
	return b
