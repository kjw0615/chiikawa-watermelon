class_name SkillBar
extends Control
## 게이지 바 + 아이템 버튼 4개(아이콘 자리, 단축키 1~4, 비용 표기). 아이콘은 data/items.json 의 icon 경로에
## 파일이 생기면 자동으로 교체되고, 없으면 임시 글자 아이콘을 쓴다.

signal use_requested(id: String)

const GAUGE_H := 24.0
const BTN_W := 111.0
const BTN_H := 52.0
const GAP := 8.0

var _items: ItemSystem
var _fill := 0.0
var _gauge_label: Label
var _buttons := {}   # id -> Button

func setup(items: ItemSystem) -> void:
	_items = items
	items.changed.connect(refresh)
	_gauge_label = Label.new()
	_gauge_label.position = Vector2(0, 2)
	_gauge_label.size = Vector2(size.x, GAUGE_H - 4)
	_gauge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gauge_label.add_theme_font_size_override("font_size", 13)
	_gauge_label.add_theme_color_override("font_color", Color("3b2f63"))
	_gauge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gauge_label)

	var its := ItemDefs.items()
	for i in its.size():
		var it: Dictionary = its[i]
		var btn := _make_button(i, it)
		btn.position = Vector2((i % 2) * (BTN_W + GAP), GAUGE_H + GAP + (i / 2) * (BTN_H + 6.0))
		add_child(btn)
		_buttons[it["id"]] = btn
	refresh()

func _make_button(i: int, it: Dictionary) -> Button:
	var btn := Button.new()
	btn.size = Vector2(BTN_W, BTN_H)
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = "%s (%d%%)" % [it["full_name"], int(it["cost"])]
	btn.add_theme_stylebox_override("normal", _box(Color("fff0f6"), Color("e9a9c6")))
	btn.add_theme_stylebox_override("hover", _box(Color("ffe3ee"), Color("e48ab3")))
	btn.add_theme_stylebox_override("pressed", _box(Color("ffd2e3"), Color("d4639a")))
	btn.add_theme_stylebox_override("disabled", _box(Color("ece8f3"), Color("cfc8de")))
	var id: String = it["id"]
	btn.pressed.connect(func(): use_requested.emit(id))

	# 아이콘 자리(36x36): 아이콘 파일이 있으면 그것을, 없으면 임시 글자
	var slot := Panel.new()
	slot.position = Vector2(6, 8)
	slot.size = Vector2(36, 36)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", _box(Color("fffaff"), Color("d9cbee"), 8))
	btn.add_child(slot)
	var icon_path: String = it.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var tr := TextureRect.new()
		tr.texture = load(icon_path)
		tr.size = slot.size - Vector2(4, 4)
		tr.position = Vector2(2, 2)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tr)
	else:
		slot.add_child(_label(it.get("glyph", "?"), Vector2(0, 5), Vector2(36, 26), 18, Color("a45a85"), true))

	var nm := _label(it["name"], Vector2(44, 4), Vector2(64, 30), 11, Color("4b3f72"), false)
	nm.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	btn.add_child(nm)
	btn.add_child(_label("%d%%" % int(it["cost"]), Vector2(44, 32), Vector2(64, 18), 12, Color("c2477f"), false))
	# 단축키 배지(좌상단)
	var badge := Panel.new()
	badge.position = Vector2(-2, -2)
	badge.size = Vector2(16, 16)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _box(Color("7f63c9"), Color("7f63c9"), 8))
	btn.add_child(badge)
	badge.add_child(_label(str(i + 1), Vector2(0, -1), Vector2(16, 16), 11, Color.WHITE, true))
	return btn

func _label(t: String, pos: Vector2, sz: Vector2, font_size: int, col: Color, center: bool) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _box(fill: Color, border: Color, radius := 10) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(2)
	b.set_corner_radius_all(radius)
	return b

func refresh() -> void:
	_fill = _items.gauge / ItemDefs.gauge_max()
	_gauge_label.text = "게이지 %d%%" % roundi(_items.gauge)
	for id in _buttons:
		var usable := _items.can_use(id)
		var btn: Button = _buttons[id]
		btn.disabled = not usable
		btn.modulate = Color.WHITE if usable else Color(1, 1, 1, 0.7)
	queue_redraw()

func _draw() -> void:
	var bar := Rect2(0, 0, size.x, GAUGE_H)
	draw_style_box(_box(Color("e3d9f5"), Color("c9bfe8"), 12), bar)
	if _fill > 0.0:
		var fw := maxf((size.x - 4.0) * _fill, 8.0)
		var fb := _box(Color("ff8fb8") if _fill < 1.0 else Color("ffb347"), Color("ff8fb8") if _fill < 1.0 else Color("ffb347"), 10)
		draw_style_box(fb, Rect2(2, 2, fw, GAUGE_H - 4))
	# 비용 눈금선
	for it in ItemDefs.items():
		var x := size.x * float(it["cost"]) / ItemDefs.gauge_max()
		if x < size.x - 2.0:
			draw_line(Vector2(x, 3), Vector2(x, GAUGE_H - 3), Color("7f63c9", 0.7), 1.5)
