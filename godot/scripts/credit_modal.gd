class_name CreditModal
extends UiModal
## 크레딧 모달(설정의 '크레딧' 버튼): 제작진 / BGM / 폰트 / 원작 저작권 안내.

## [제목, 내용, 내용 높이]
const ENTRIES := [
	["디렉터 / 총괄기획", "쑤운", 22],
	["팀장 / 총괄조율", "안티 (Antigravity)", 22],
	["프로그래밍 / 물리 / UI / 빌드", "클로드 (Claude Code)", 22],
	["아트디렉팅 / 스프라이트 / 컬러", "코덱스 (Codex)", 22],
	["BGM", "하치와레의 혼잣말 피아노 편곡 버전\n편곡·연주·녹음·믹싱: Joo&Kii (주키플리)\n원작 TV 애니메이션 먼작귀 엔딩곡", 66],
	["폰트", "학교안심 둥근미소 B, 망고보드별별, 뚝딱감자체", 22],
	["원작 저작권", "비영리 팬메이드 게임입니다. Chiikawa의 모든 권리는 Nagano 및 치이카와 제작위원회에 귀속됩니다.", 44],
]

func _init() -> void:
	title_text = "크레딧"
	box_size = Vector2(520, 660)

func _build() -> void:
	var y := 78.0
	for e in ENTRIES:
		var h := make_label(e[0], Vector2(36, y), Vector2(box_size.x - 72, 22), 15, UIPalette.BLUE_INK)
		h.add_theme_font_override("font", UIPalette.title_font())
		box.add_child(h)
		var b := make_label(e[1], Vector2(36, y + 24), Vector2(box_size.x - 72, e[2]), 16, UIPalette.TEXT)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(b)
		y += 24 + e[2] + 14
	var ok := make_button("닫기", Vector2(box_size.x / 2 - 90, box_size.y - 74), Vector2(180, 52), UIPalette.PINK_STATES, 20)
	ok.pressed.connect(close)
	box.add_child(ok)
