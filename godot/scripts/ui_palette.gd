class_name UIPalette
## UI 색상 팔레트(단일 출처). 모든 UI 스크립트는 여기 토큰만 쓴다.
## 코덱스의 치이카와 파스텔 팔레트가 오면 아래 값만 바꾸면 타이틀/사이드바/버튼/게이지/메뉴가 일괄 리스타일된다.
## 현재 값은 리스타일 전 기존 색 그대로(시각 변화 없음).

const PANEL := Color("fffaff")   # 패널/카드 배경
const PANEL_BORDER := Color("c9bfe8")   # 패널 테두리
const DIVIDER := Color("e3d9f5")   # 구분선/게이지 바 바탕
const SLOT_BG := Color("f0e9ff")   # NEXT 슬롯 배경
const SLOT_BORDER := Color("b3a5d6")   # NEXT 슬롯 테두리
const LOCKED_BG := Color("ece4fb")   # 합체로만 생성되는 단계 칸 배경
const ICON_SLOT_BORDER := Color("d9cbee")   # 아이템 아이콘 슬롯 테두리
const TEXT := Color("4b3f72")   # 기본 글자
const TEXT_STRONG := Color("3b2f63")   # 강조 글자
const TEXT_MUTED := Color("7a6da3")   # 보조 글자
const TEXT_DISABLED := Color("a89cc8")   # 비활성 아이콘
const OUTLINE := Color("2d2552")   # 글자 외곽선(어두운 색)
const ACCENT_TEXT := Color("c2477f")   # 강조 핑크 글자/외곽선(점수 등)
const ACCENT := Color("ff8fb8")   # 주 버튼/게이지 채움 핑크
const ACCENT_HOVER := Color("ffa6c8")   # 주 버튼 hover
const ACCENT_PRESSED := Color("f0709f")   # 주 버튼 pressed
const ACCENT_DEEP := Color("d9558a")   # 부제 외곽선
const TITLE_SHADOW := Color("b83a73")   # 타이틀 그림자
const TITLE_OUTLINE := Color("ff7fae")   # 타이틀 테두리
const RIBBON := Color("ff9cc2")   # 부제 리본
const CREAM := Color("fff6e0")   # 타이틀 글자(크림)
const CREAM_LIGHT := Color("fffaf0")   # 부제 글자
const TEXT_ON_DARK := Color("e9ddff")   # 어두운 막 위 보조 글자
const PINK_SOFT := Color("ffe3ee")   # 연분홍(드롭 단계 칸/버튼 hover)
const BTN_BG := Color("fff0f6")   # 아이템 버튼 배경
const BTN_BORDER := Color("e9a9c6")   # 아이템 버튼 테두리
const BTN_BORDER_HOVER := Color("e48ab3")   # 아이템 버튼 hover 테두리
const BTN_BORDER_PRESSED := Color("d4639a")   # 아이템 버튼 pressed 테두리
const BTN_BG_PRESSED := Color("ffd2e3")   # 아이템 버튼 pressed 배경
const BTN_DISABLED_BG := Color("ece8f3")   # 아이템 버튼 비활성 배경
const BTN_DISABLED_BORDER := Color("cfc8de")   # 아이템 버튼 비활성 테두리
const GLYPH := Color("a45a85")   # 임시 글자 아이콘
const CELL_BORDER_DROP := Color("f08fb5")   # 드롭 단계 칸 테두리
const SECONDARY := Color("b79bf0")   # 보조 색(현재 라벤더, 종료/합체전용 칸)
const SECONDARY_DEEP := Color("7f63c9")   # 보조 진한 색(배지/스피커)
const SECONDARY_DARK := Color("6a4fb5")   # 보조 가장 진한 색
const GAUGE_FULL := Color("ffb347")   # 게이지 가득 참
const MUTE_X := Color("e0457b")   # 음소거 X 표시
