class_name SidePanel
extends Control
## 오른쪽 UI: 점수 + NEXT(다음 노드) + 합쳐지는 노드 순서(1~11단계 진화표, 2줄 미니 원형 아이콘).

const COLS := 6
const CELL := 40.0

var _next_icon: TextureRect
var _next_name: Label
var _next_stage_label: Label
var _score_label: Label

func _ready() -> void:
	var bg := Panel.new()
	bg.size = size
	bg.add_theme_stylebox_override("panel", _box(UIPalette.PANEL, UIPalette.PANEL_BORDER, 14))
	add_child(bg)

	# 점수(최고점수는 표기하지 않음)
	_add_title("SCORE", Vector2(0, 10), 14)
	_score_label = _label(Vector2(0, 28), 36)
	_score_label.size = Vector2(size.x, 46)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_color_override("font_color", UIPalette.ACCENT_TEXT)
	add_child(_score_label)
	_divider(86.0)

	_add_title("NEXT", Vector2(0, 96), 16)
	var next_box := Panel.new()
	next_box.position = Vector2((size.x - 84.0) / 2.0, 122)
	next_box.size = Vector2(84, 84)
	next_box.add_theme_stylebox_override("panel", _box(UIPalette.SLOT_BG, UIPalette.SLOT_BORDER, 12))
	add_child(next_box)
	_next_icon = _icon_rect(Vector2(6, 6), Vector2(72, 72))
	next_box.add_child(_next_icon)
	_next_stage_label = _label(Vector2(0, 210), 14)
	_next_stage_label.size = Vector2(size.x, 20)
	_next_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_next_stage_label)
	_next_name = _label(Vector2(0, 230), 13)
	_next_name.size = Vector2(size.x, 20)
	_next_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_next_name)
	_divider(262.0)

	_add_title("합쳐지는 순서", Vector2(0, 272), 16)
	var x0 := (size.x - COLS * CELL) / 2.0
	for i in NodeDefs.count():
		var droppable := i <= NodeDefs.drop_max_index()
		var cell := Panel.new()
		cell.position = Vector2(x0 + (i % COLS) * CELL + 1, 302 + (i / COLS) * 60.0)
		cell.size = Vector2(CELL - 2.0, CELL - 2.0)
		cell.tooltip_text = "%d. %s" % [i + 1, NodeDefs.node_name(i)]
		var sb := _box(UIPalette.PINK_SOFT if droppable else UIPalette.LOCKED_BG, UIPalette.CELL_BORDER_DROP if droppable else UIPalette.SECONDARY, 19)
		cell.add_theme_stylebox_override("panel", sb)   # 둥근 미니 원형 뱃지
		add_child(cell)
		var icon := _icon_rect(Vector2(4, 4), cell.size - Vector2(8, 8))
		icon.texture = HeadShapes.get_data(i)["tex"]
		cell.add_child(icon)
		var num := _label(Vector2(x0 + (i % COLS) * CELL, 302 + (i / COLS) * 60.0 + CELL - 3.0), 11)
		num.size = Vector2(CELL, 16)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.text = "%d%s" % [i + 1, "★" if i == NodeDefs.count() - 1 else ""]
		add_child(num)
	var note := _label(Vector2(14, 424), 12)
	note.size = Vector2(size.x - 28, 56)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	note.text = "분홍 1~%d단계: 랜덤 드롭 / 보라: 합체로만 생성\n%d단계끼리 합체 시 소멸 +100점" % [NodeDefs.drop_max_index() + 1, NodeDefs.count()]
	add_child(note)

func set_score(v: int) -> void:
	_score_label.text = str(v)

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

func _add_title(t: String, pos: Vector2, font_size := 16) -> void:
	var l := _label(pos, font_size)
	l.size = Vector2(size.x, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text = t
	add_child(l)

func _label(pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
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
