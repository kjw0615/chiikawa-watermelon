class_name UIPalette
## UI 색상 팔레트(단일 출처) - 코덱스 치이카와 파스텔 가이드 v1 (art/guides/ui_palette_v1.md, 공식 지정색 아님).
## 모든 UI 스크립트는 여기 토큰만 쓴다. 색을 바꾸려면 이 파일만 고치면 된다.

# 공통
const CREAM := Color("FFF8EB")          # 화면·패널 기본 바탕
const PAPER := Color("FFFDF7")          # 작은 카드·아이콘 슬롯
const TEXT := Color("59443B")           # 본문·버튼 글자
const TEXT_MUTED := Color("80665A")     # 보조 글자·면책·음소거
const BORDER := Color("C9AA95")         # 패널 장식 테두리
const CONTROL_BORDER := Color("8C6557") # 누르는 버튼 외곽선
const DIVIDER := Color("E8DCCD")        # 구분선·게이지/슬라이더 바탕
const BLUE_INK := Color("4D7180")       # 볼륨 활성·포커스
const SHADOW := Color(0.349, 0.267, 0.231, 0.14)   # #59443B 14%

# 타이틀
const TITLE_BG_TOP := Color("EAF4F7")
const TITLE_BG_BOTTOM := Color("FFF8EB")
const TITLE_FILL := Color("FFF4CC")
const TITLE_SHADOW := Color("C9AA95")
const RIBBON := Color("F8CCD5")
const PINK := Color("F8CCD5")
const PINK_HOVER := Color("FFE0E6")
const PINK_PRESSED := Color("E9A5B5")

# 사이드바
const SCORE := Color("76513C")
const NEXT_BG := Color("EAF4F7")
const NEXT_BORDER := Color("94BBC8")
const CELL_DROP_BG := Color("FBE3E8")
const CELL_DROP_BORDER := Color("D5A1AD")
const CELL_MERGE_BG := Color("EAF4F7")
const CELL_MERGE_BORDER := Color("94BBC8")
const CELL_FINAL_BG := Color("FFF0BE")
const CELL_FINAL_BORDER := Color("BE9B63")

# 아이템 버튼(기본/호버/클릭), 순서 = items.json
const ITEM_BG := {
	"shake": [Color("FFF0BE"), Color("FFF6D9"), Color("EEDB9D")],
	"swap": [Color("F8CCD5"), Color("FFE0E6"), Color("E9A5B5")],
	"sword": [Color("DCEEF5"), Color("EEF7FA"), Color("BED9E5")],
	"fountain": [Color("DFF1EA"), Color("EFF8F3"), Color("BFDDCF")],
}
const DISABLED_BG := Color("ECE6DD")
const DISABLED_BORDER := Color("C5B8A8")
const DISABLED_TEXT := Color("85786E")
const GAUGE_FILL := Color("BCDCCB")
const GAUGE_FULL_BORDER := Color("BE9B63")

# 볼륨
const SLIDER_FILL := Color("4D7180")
const SLIDER_GRABBER_HOVER := Color("59443B")

# 종료 버튼(기본/호버/클릭)
const QUIT_BG := [Color("FFFDF7"), Color("FBE3E8"), Color("F8CCD5")]

## 둥근 버튼 공통 스타일: states = [기본, 호버, 클릭] 배경색. 테두리 #8C6557, 글자 #59443B(외곽선 없음), 그림자 #59443B 14%
static func style_button(b: Button, states: Array, radius := 27) -> void:
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, TEXT)
	b.add_theme_constant_override("outline_size", 0)
	var names := ["normal", "hover", "pressed"]
	for i in 3:
		var bx := StyleBoxFlat.new()
		bx.bg_color = states[i]
		bx.border_color = CONTROL_BORDER
		bx.set_border_width_all(3)
		bx.set_corner_radius_all(radius)
		bx.shadow_color = SHADOW
		bx.shadow_size = 6
		bx.shadow_offset = Vector2(0, 3)
		b.add_theme_stylebox_override(names[i], bx)

## 제목용 폰트(Jua). Jua에 없는 기호는 본문 폰트(Gowun Dodum)로 대체된다.
static func title_font() -> Font:
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/Jua-subset.ttf")
	f.fallbacks = [load("res://assets/fonts/GowunDodum-subset.ttf")]
	return f

static func circle_texture(col: Color, d := 20) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d, d) / 2.0 - Vector2(0.5, 0.5)
	for x in d:
		for y in d:
			var dist := Vector2(x, y).distance_to(c)
			img.set_pixel(x, y, Color(col, clampf(d / 2.0 - dist, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
