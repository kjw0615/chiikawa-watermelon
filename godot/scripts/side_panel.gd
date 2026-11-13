class_name SidePanel
extends Control
## 오른쪽 UI: NEXT(다음 노드) 박스 + 합쳐지는 노드 순서(1~11단계 진화표).

const COLS := 4
const ICON := 44.0

var _next_icon: TextureRect
var _next_name: Label
var _next_stage_label: Label

func _ready() -> void:
	var bg := Panel.new()
	bg.size = size
	bg.add_theme_stylebox_override("panel", _box(Color("fffaff"), Color("c9bfe8"), 14))
	add_child(bg)

	_add_title("NEXT", Vector2(0, 10))
	var next_box := Panel.new()
	next_box.position = Vector2(60, 40)
	next_box.size = Vector2(100, 100)
	next_box.add_theme_stylebox_override("panel", _box(Color("f0e9ff"), Color("b3a5d6"), 12))
	add_child(next_box)
	_next_icon = _icon_rect(Vector2(8, 8), Vector2(84, 84))
	next_box.add_child(_next_icon)
	_next_stage_label = _label(Vector2(0, 144), 15)
	_next_stage_label.size = Vector2(size.x, 20)
	_next_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_next_stage_label)
	_next_name = _label(Vector2(0, 164), 14)
	_next_name.size = Vector2(size.x, 20)
	_next_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_next_name)

	_add_title("합쳐지는 노드 순서", Vector2(0, 202))
	var cell_w := (size.x - 20.0) / COLS
	for i in NodeDefs.count():
		var cell := Panel.new()
		cell.position = Vector2(10 + (i % COLS) * cell_w, 234 + (i / COLS) * 78)
		cell.size = Vector2(cell_w - 4, 72)
		var droppable := i <= NodeDefs.drop_max_index()
		cell.add_theme_stylebox_override("panel", _box(Color("ffe9f1") if droppable else Color("f0e9ff"), Color("e3d9f5"), 8))
		cell.tooltip_text = NodeDefs.node_name(i)
		add_child(cell)
		var icon := _icon_rect(Vector2(4, 3), Vector2(cell.size.x - 8, ICON))
		icon.texture = HeadShapes.get_data(i)["tex"]
		cell.add_child(icon)
		var num := _label(Vector2(0, 50), 14)
		num.size = Vector2(cell.size.x, 20)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.text = "%d%s" % [i + 1, "★" if i == NodeDefs.count() - 1 else ""]
		cell.add_child(num)
	var rows := ceili(NodeDefs.count() / float(COLS))
	var note := _label(Vector2(10, 234 + rows * 78 + 6), 12)
	note.size = Vector2(size.x - 20, 60)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "분홍: 1~%d단계 랜덤 드롭\n보라: %d~%d단계는 합체로만 생성\n%d단계끼리 합체 시 소멸 +100점" % [
		NodeDefs.drop_max_index() + 1, NodeDefs.drop_max_index() + 2, NodeDefs.count(), NodeDefs.count()]
	add_child(note)

func set_next(stage: int) -> void:
	_next_icon.texture = HeadShapes.get_data(stage)["tex"]
	_next_stage_label.text = "%d단계" % (stage + 1)
	_next_name.text = NodeDefs.node_name(stage)

func _add_title(t: String, pos: Vector2) -> void:
	var l := _label(pos, 18)
	l.size = Vector2(size.x, 28)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text = t
	add_child(l)

func _label(pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color("4b3f72"))
	return l

func _icon_rect(pos: Vector2, sz: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.position = pos
	t.size = sz
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t

func _box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(2)
	b.set_corner_radius_all(radius)
	return b
