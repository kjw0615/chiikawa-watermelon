class_name SidePanel
extends Control
## 오른쪽 UI: 점수/BEST + NEXT(다음 노드) + 합쳐지는 노드 순서(1~11단계 진화표, 2줄 미니 원형 아이콘).

signal help_pressed

const COLS := 6
const CELL := 40.0
const SCORE_FS := 36   # SCORE 와 BEST 가 같은 글꼴/크기

var _next_icon: TextureRect
var _next_name: Label
var _next_stage_label: Label
var _score_label: Label
var _best_label: Label

func _ready() -> void:
	var bg := Panel.new()
	bg.size = size
	bg.add_theme_stylebox_override("panel", _box(UIPalette.CREAM, UIPalette.BORDER, 14))
	add_child(bg)

	# 상단: 게임 설명 버튼 / 점수(왼쪽) + BEST(오른쪽, 같은 글꼴·크기)
	var help := Button.new()
	help.text = "게임 설명"
	help.position = Vector2(size.x - 100.0, 8.0)
	help.size = Vector2(88, 26)
	help.focus_mode = Control.FOCUS_NONE
	help.add_theme_font_override("font", UIPalette.button_font())
	help.add_theme_font_size_override("font_size", 13)
	UIPalette.style_button(help, [UIPalette.NEXT_BG, UIPalette.PAPER, UIPalette.DIVIDER], 13)
	help.pressed.connect(func(): help_pressed.emit())
	add_child(help)
	var col_w := size.x / 2.0
	for k in 2:
		var t := _add_title("SCORE" if k == 0 else "BEST", Vector2(col_w * k, 48), 14)
		t.size.x = col_w
		t.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
		var v := _label(Vector2(col_w * k, 64), SCORE_FS)
		v.size = Vector2(col_w, 46)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_theme_color_override("font_color", UIPalette.SCORE)
		add_child(v)
		if k == 0:
			_score_label = v
		else:
			_best_label = v
	_divider(124.0)

	_add_title("NEXT", Vector2(0, 134), 16).add_theme_color_override("font_color", UIPalette.BLUE_INK)
	var next_box := Panel.new()
	next_box.position = Vector2((size.x - 84.0) / 2.0, 160)
	next_box.size = Vector2(84, 84)
	next_box.add_theme_stylebox_override("panel", _box(UIPalette.NEXT_BG, UIPalette.NEXT_BORDER, 12))
	add_child(next_box)
	_next_icon = _icon_rect(Vector2(6, 6), Vector2(72, 72))
	next_box.add_child(_next_icon)
	_next_stage_label = _label(Vector2(0, 248), 14)
	_next_stage_label.size = Vector2(size.x, 20)
	_next_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_next_stage_label)
	_next_name = _label(Vector2(0, 268), 13)
	_next_name.size = Vector2(size.x, 20)
	_next_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_next_name)
	_divider(300.0)

	var card := Panel.new()   # 진화표 카드
	card.position = Vector2(10, 304)
	card.size = Vector2(size.x - 20.0, 158)
	card.add_theme_stylebox_override("panel", _box(UIPalette.PAPER, UIPalette.BORDER, 12))
	add_child(card)
	_add_title("합쳐지는 순서", Vector2(0, 310), 16)
	var x0 := (size.x - COLS * CELL) / 2.0
	for i in NodeDefs.count():
		var droppable := i <= NodeDefs.drop_max_index()
		var cell := Panel.new()
		cell.position = Vector2(x0 + (i % COLS) * CELL + 1, 340 + (i / COLS) * 60.0)
		cell.size = Vector2(CELL - 2.0, CELL - 2.0)
		cell.tooltip_text = "%d. %s" % [i + 1, NodeDefs.node_name(i)]
		var final := i == NodeDefs.count() - 1
		var sb := _box(UIPalette.CELL_FINAL_BG if final else (UIPalette.CELL_DROP_BG if droppable else UIPalette.CELL_MERGE_BG),
			UIPalette.CELL_FINAL_BORDER if final else (UIPalette.CELL_DROP_BORDER if droppable else UIPalette.CELL_MERGE_BORDER), 19)
		cell.add_theme_stylebox_override("panel", sb)   # 둥근 미니 원형 뱃지
		add_child(cell)
		var icon := _icon_rect(Vector2(4, 4), cell.size - Vector2(8, 8))
		icon.texture = HeadShapes.get_data(i)["tex"]
		cell.add_child(icon)
		var num := _label(Vector2(x0 + (i % COLS) * CELL, 340 + (i / COLS) * 60.0 + CELL - 3.0), 11)
		num.size = Vector2(CELL, 16)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.text = str(i + 1)   # 별/이모지 글리프 없이 숫자만
		add_child(num)
	var note := _label(Vector2(14, 470), 12)
	note.size = Vector2(size.x - 28, 56)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	note.text = "분홍 1~%d단계: 랜덤 드롭 / 하늘색: 합체로만 생성
%d단계끼리 합체 시 소멸 +100점" % [NodeDefs.drop_max_index() + 1, NodeDefs.count()]
	add_child(note)

func set_score(v: int) -> void:
	_fit(_score_label, str(v))

func set_best(v: int) -> void:
	_fit(_best_label, str(v))

## 점수/BEST 는 같은 글꼴·크기(SCORE_FS). 자릿수가 많아 칸을 넘으면 둘이 똑같이 함께 줄인다
func _fit(l: Label, text: String) -> void:
	l.text = text
	_fit_both()

func _fit_both() -> void:
	var fs := SCORE_FS
	var font := _score_label.get_theme_font("font")
	var widest := maxf(font.get_string_size(_score_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, SCORE_FS).x, font.get_string_size(_best_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, SCORE_FS).x)
	var avail := size.x / 2.0 - 12.0
	if widest > avail:
		fs = maxi(int(floor(SCORE_FS * avail / widest)), 12)
	_score_label.add_theme_font_size_override("font_size", fs)
	_best_label.add_theme_font_size_override("font_size", fs)

func set_next(stage: int) -> void:
	_next_icon.texture = HeadShapes.get_data(stage)["tex"]
	_next_stage_label.text = "%d단계" % (stage + 1)
	_next_name.text = NodeDefs.node_name(stage)

func _divider(y: float) -> void:
	var d := ColorRect.new()
	d.color = UIPalette.DIVIDER
	d.position = Vector2(16, y)
	d.size = Vector2(size.x - 32, 2)
	add_child(d)

func _add_title(t: String, pos: Vector2, font_size := 16) -> Label:
	var l := _label(pos, font_size)
	l.size = Vector2(size.x, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text = t
	add_child(l)
	return l

func _label(pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.clip_text = true   # 글자가 많아도 칸이 늘어나지 않게(넘침은 --text-audit 로 점검)
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", UIPalette.TEXT)
	return l

func _icon_rect(pos: Vector2, sz: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.position = pos
	t.size = sz
	return t

func _box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(2)
	b.set_corner_radius_all(radius)
	return b
