class_name SkillBar
extends Control
## 게이지 바 + 아이템 버튼 4개(아이콘 자리, 단축키 1~4, 비용 표기). 아이콘은 data/items.json 의 icon 경로에
## 파일이 생기면 자동으로 교체되고, 없으면 임시 글자 아이콘을 쓴다.

signal use_requested(id: String)

const GAUGE_H := 26.0
const BTN_H := 60.0
const GAP := 10.0

var _items: ItemSystem
var _fill := 0.0
var _gauge_label: Label
var _buttons := {}   # id -> Button
var _parts := {}     # id -> {name, cost, icon, glyph} 비활성 상태 표시용 자식들

func setup(items: ItemSystem) -> void:
	_items = items
	items.changed.connect(refresh)
	_gauge_label = Label.new()
	_gauge_label.position = Vector2(0, 2)
	_gauge_label.size = Vector2(size.x, GAUGE_H - 4)
	_gauge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gauge_label.add_theme_font_size_override("font_size", 13)
	_gauge_label.add_theme_color_override("font_color", UIPalette.TEXT)
	_gauge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gauge_label)

	var its := ItemDefs.items()
	for i in its.size():
		var it: Dictionary = its[i]
		var btn := _make_button(i, it)
		btn.position = Vector2((i % 2) * (_btn_w() + GAP), GAUGE_H + GAP + (i / 2) * (BTN_H + GAP))
		add_child(btn)
		_buttons[it["id"]] = btn
	refresh()

func _btn_w() -> float:
	return (size.x - GAP) / 2.0

func _make_button(i: int, it: Dictionary) -> Button:
	var btn := Button.new()
	btn.size = Vector2(_btn_w(), BTN_H)
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = "%s (%d%%)" % [it["full_name"], int(it["cost"])]
	var id: String = it["id"]
	_apply_styles(btn, id, false)
	btn.pressed.connect(func(): use_requested.emit(id))

	# 아이콘 자리(36x36): 아이콘 파일이 있으면 그것을, 없으면 임시 글자
	var slot := Panel.new()
	slot.position = Vector2(8, 10)
	slot.size = Vector2(40, 40)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", _box(UIPalette.PAPER, UIPalette.BORDER, 8))
	btn.add_child(slot)
	var icon_path: String = it.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # 크기 지정보다 먼저(원본 128px 최소 크기 방지)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = load(icon_path)
		tr.position = Vector2(2, 2)
		tr.size = slot.size - Vector2(4, 4)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tr)
		_parts[id] = {"icon": tr}
	else:
		var gl := _label(it.get("glyph", "?"), Vector2(0, 6), Vector2(40, 28), 20, UIPalette.TEXT, true)
		slot.add_child(gl)
		_parts[id] = {"glyph": gl}

	var nm := _label(it["name"], Vector2(52, 6), Vector2(_btn_w() - 56.0, 30), 12, UIPalette.TEXT, false)
	nm.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	btn.add_child(nm)
	var cost_label := _label("%d%%" % int(it["cost"]), Vector2(52, 36), Vector2(_btn_w() - 56.0, 18), 13, UIPalette.TEXT, false)
	btn.add_child(cost_label)
	_parts[id]["name"] = nm
	_parts[id]["cost"] = cost_label
	# 단축키 배지(좌상단)
	var badge := Panel.new()
	badge.position = Vector2(-2, -2)
	badge.size = Vector2(16, 16)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _box(UIPalette.TEXT, UIPalette.TEXT, 8))
	btn.add_child(badge)
	badge.add_child(_label(str(i + 1), Vector2(0, -1), Vector2(16, 16), 11, UIPalette.PAPER, true))
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

## 버튼 상태별 스타일: 아이템 고유 파스텔 배경 + 공통 테두리. 조준 중이면 클릭색 + 파란 3px 외곽선
func _apply_styles(btn: Button, id: String, aiming: bool) -> void:
	var c: Array = UIPalette.ITEM_BG.get(id, UIPalette.ITEM_BG["swap"])
	if aiming:
		var aim := _box(c[2], UIPalette.BLUE_INK, 10, 3)
		for st in ["normal", "hover", "pressed", "disabled"]:
			btn.add_theme_stylebox_override(st, aim)
		return
	btn.add_theme_stylebox_override("normal", _box(c[0], UIPalette.CONTROL_BORDER))
	btn.add_theme_stylebox_override("hover", _box(c[1], UIPalette.CONTROL_BORDER))
	btn.add_theme_stylebox_override("pressed", _box(c[2], UIPalette.CONTROL_BORDER))
	btn.add_theme_stylebox_override("disabled", _box(UIPalette.DISABLED_BG, UIPalette.DISABLED_BORDER))

func _box(fill: Color, border: Color, radius := 10, width := 2) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	return b

func refresh() -> void:
	_fill = _items.gauge / ItemDefs.gauge_max()
	_gauge_label.text = ("★ " if _items.gauge >= ItemDefs.gauge_max() else "") + "게이지 %d%%" % roundi(_items.gauge)
	for id in _buttons:
		var usable := _items.can_use(id)
		var btn: Button = _buttons[id]
		btn.disabled = not usable
		var aiming: bool = id == "sword" and _items.aiming
		_apply_styles(btn, id, aiming)
		var p: Dictionary = _parts[id]
		var txt := UIPalette.TEXT if (usable or aiming) else UIPalette.DISABLED_TEXT   # 글자는 읽히게, 아이콘만 흐리게
		p["name"].add_theme_color_override("font_color", txt)
		p["cost"].add_theme_color_override("font_color", txt)
		p["cost"].text = "조준 중" if aiming else "%d%%" % int(ItemDefs.item(id).get("cost", 0))
		if p.has("icon"):
			p["icon"].modulate = Color.WHITE if (usable or aiming) else Color(1, 1, 1, 0.45)
		if p.has("glyph"):
			p["glyph"].add_theme_color_override("font_color", txt)
	queue_redraw()

func _draw() -> void:
	var bar := Rect2(0, 0, size.x, GAUGE_H)
	draw_style_box(_box(UIPalette.DIVIDER, UIPalette.BORDER, 12), bar)
	if _fill > 0.0:
		var fw := maxf((size.x - 4.0) * _fill, 8.0)
		var full := _fill >= 1.0
		var fb := _box(UIPalette.CELL_FINAL_BG if full else UIPalette.GAUGE_FILL, UIPalette.GAUGE_FULL_BORDER if full else UIPalette.GAUGE_FILL, 10)
		draw_style_box(fb, Rect2(2, 2, fw, GAUGE_H - 4))
	# 비용 눈금선
	for it in ItemDefs.items():
		var x := size.x * float(it["cost"]) / ItemDefs.gauge_max()
		if x < size.x - 2.0:
			draw_line(Vector2(x, 3), Vector2(x, GAUGE_H - 3), Color(UIPalette.TEXT, 0.45), 1.5)
