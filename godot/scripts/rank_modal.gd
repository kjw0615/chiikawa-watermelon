class_name RankModal
extends UiModal
## 랭킹 TOP 10 모달: 열 때마다 서버에서 한 번 조회(Stateless)해서 보여준다.

const ROWS := 10
const ROW_H := 38.0

var _rows: Array = []   # [{bg, rank, nick, score}]
var _status: Label
var _mine: Label

func _init() -> void:
	title_text = "랭킹 TOP 10"
	box_size = Vector2(480, 560)

func _build() -> void:
	for i in ROWS:
		var y := 84.0 + i * ROW_H
		var bg := Panel.new()
		bg.position = Vector2(20, y)
		bg.size = Vector2(box_size.x - 40, ROW_H - 4)
		bg.add_theme_stylebox_override("panel", _row_box(UIPalette.PAPER if i % 2 == 0 else UIPalette.CREAM))
		box.add_child(bg)
		var rk := make_label("", Vector2(8, 4), Vector2(44, 26), 18, UIPalette.TEXT, true)
		var nk := make_label("", Vector2(60, 4), Vector2(210, 26), 18, UIPalette.TEXT)
		var sc := make_label("", Vector2(280, 4), Vector2(132, 26), 18, UIPalette.SCORE)
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bg.add_child(rk)
		bg.add_child(nk)
		bg.add_child(sc)
		_rows.append({"bg": bg, "rank": rk, "nick": nk, "score": sc})
	_status = make_label("", Vector2(20, 250), Vector2(box_size.x - 40, 60), 18, UIPalette.TEXT_MUTED, true)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	_mine = make_label("", Vector2(20, box_size.y - 56), Vector2(box_size.x - 40, 30), 16, UIPalette.BLUE_INK, true)
	box.add_child(_mine)

func _row_box(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.border_color = UIPalette.DIVIDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(10)
	return s

func _on_open() -> void:
	_show_rows([])
	_status.text = "불러오는 중..."
	_mine.text = ""
	var r: Dictionary = await Supabase.fetch_top(ROWS)
	if not is_open():
		return
	if not r["ok"]:
		_status.text = r.get("error", "랭킹을 불러오지 못했어요.")
		return
	var list: Array = r["data"]
	_status.text = "" if not list.is_empty() else "아직 기록이 없어요. 첫 번째 주인공이 되어 보세요!"
	_show_rows(list)
	if Supabase.signed_in:
		_mine.text = "%s님의 최고점: %d" % [Supabase.nickname, Supabase.server_best]

func _show_rows(list: Array) -> void:
	for i in ROWS:
		var row: Dictionary = _rows[i]
		var has := i < list.size()
		(row["bg"] as Panel).visible = has
		if not has:
			continue
		var d: Dictionary = list[i]
		var rank := int(d.get("rank", i + 1))
		(row["rank"] as Label).text = str(rank)
		(row["nick"] as Label).text = str(d.get("nickname", ""))
		(row["score"] as Label).text = str(int(d.get("best_score", 0)))
		var me: bool = Supabase.signed_in and str(d.get("nickname", "")) == Supabase.nickname
		(row["bg"] as Panel).add_theme_stylebox_override("panel", _row_box(UIPalette.PINK_HOVER if me else (UIPalette.PAPER if i % 2 == 0 else UIPalette.CREAM)))
