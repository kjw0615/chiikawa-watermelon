class_name HelpModal
extends UiModal
## 게임 설명 모달: 규칙 + 아이템 4종. 인게임에서 열면 게임이 멈춘다.

const RULES := [
	"같은 노드 두 개를 부딪혀 합치면 다음 단계로 진화해요. 마우스(터치)를 누른 채 위치를 정하고 놓으면 떨어져요.",
	"노드가 위쪽 선을 넘은 채로 쌓이면 게임 오버! 11단계끼리 합치면 사라지고 +100점이에요.",
	"합체할 때마다 게이지가 차요(1~5단계 합체 5%, 6단계 이상 15%). 게이지를 써서 아이템을 쓸 수 있어요.",
]
const ITEM_TEXT := {
	"shake": "우사기가 엉덩이를 흔들어 쌓인 노드들을 좌우로 흔들어요.",
	"swap": "지금 들고 있는 노드를 다른 노드로 바꿔요.",
	"sword": "누르면 조준 모드! 클릭한 곳에 명검이 떨어져 닿은 노드를 없애요. (우클릭/ESC로 취소)",
	"fountain": "3초 동안 음식 분수가 솟아 노드들을 위로 밀어 올려요.",
}

func _init() -> void:
	title_text = "게임 설명"
	box_size = Vector2(600, 660)
	pause_game = true

func _build() -> void:
	var y := 78.0
	for t in RULES:
		var l := make_label("• " + t, Vector2(30, y), Vector2(box_size.x - 60, 58), 15, UIPalette.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
		y += 62.0
	var head := make_label("아이템 (숫자키 1~4 로도 사용)", Vector2(30, y + 4), Vector2(box_size.x - 60, 24), 17, UIPalette.BLUE_INK)
	head.add_theme_font_override("font", UIPalette.title_font())
	box.add_child(head)
	y += 36.0
	for it in ItemDefs.items():
		var card := Panel.new()
		card.position = Vector2(24, y)
		card.size = Vector2(box_size.x - 48, 76)
		var sb := StyleBoxFlat.new()
		sb.bg_color = UIPalette.PAPER
		sb.border_color = UIPalette.DIVIDER
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(12)
		card.add_theme_stylebox_override("panel", sb)
		box.add_child(card)
		var icon_path: String = it.get("icon", "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			var tr := TextureRect.new()
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture = load(icon_path)
			tr.position = Vector2(10, 10)
			tr.size = Vector2(56, 56)
			card.add_child(tr)
		var nm := make_label("%s  (게이지 %d%%)" % [it["full_name"], int(it["cost"])], Vector2(78, 6), Vector2(card.size.x - 90, 26), 16, UIPalette.TEXT)
		nm.add_theme_font_override("font", UIPalette.button_font())
		card.add_child(nm)
		var ds := make_label(ITEM_TEXT.get(it["id"], ""), Vector2(78, 32), Vector2(card.size.x - 90, 40), 14, UIPalette.TEXT_MUTED)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(ds)
		y += 84.0
