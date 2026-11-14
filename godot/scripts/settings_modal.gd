class_name SettingsModal
extends UiModal
## 설정 모달(타이틀 화면의 톱니바퀴): BGM/SFX 볼륨 + 음소거, 게임 설명, 크레딧(자리만), 로그아웃.

signal help_requested

var _logout: Button
var _account: Label

func _init() -> void:
	title_text = "설정"
	box_size = Vector2(460, 560)

func _build() -> void:
	var sec := make_label("소리", Vector2(30, 76), Vector2(200, 24), 17, UIPalette.BLUE_INK)
	sec.add_theme_font_override("font", UIPalette.title_font())
	box.add_child(sec)
	var bgm := VolumeRow.new("bgm", "BGM")
	bgm.position = Vector2(30, 108)
	box.add_child(bgm)
	var sfx := VolumeRow.new("sfx", "효과음")
	sfx.position = Vector2(30, 158)
	box.add_child(sfx)
	var div := ColorRect.new()
	div.color = UIPalette.DIVIDER
	div.position = Vector2(30, 216)
	div.size = Vector2(box_size.x - 60, 2)
	box.add_child(div)
	var sec2 := make_label("더보기", Vector2(30, 228), Vector2(200, 24), 17, UIPalette.BLUE_INK)
	sec2.add_theme_font_override("font", UIPalette.title_font())
	box.add_child(sec2)
	var help := make_button("게임 설명", Vector2(80, 262), Vector2(300, 50), UIPalette.PINK_STATES, 20)
	help.pressed.connect(func(): help_requested.emit())
	box.add_child(help)
	var credit := make_button("크레딧 (준비 중)", Vector2(80, 322), Vector2(300, 50), [UIPalette.PAPER, UIPalette.CREAM, UIPalette.DIVIDER], 20)
	credit.disabled = true   # 나중에 크레딧 팝업을 연결할 자리(출처 문서: 전달사항/크레딧_출처_정보.md)
	box.add_child(credit)
	_account = make_label("", Vector2(30, 388), Vector2(box_size.x - 60, 22), 15, UIPalette.TEXT_MUTED, true)
	box.add_child(_account)
	_logout = make_button("로그아웃", Vector2(80, 414), Vector2(300, 50), UIPalette.QUIT_BG, 20)
	_logout.pressed.connect(func():
		await Supabase.sign_out()
		_refresh())
	box.add_child(_logout)
	Supabase.auth_changed.connect(_refresh)
	_refresh()

func _on_open() -> void:
	_refresh()

func _refresh() -> void:
	if _logout == null:
		return
	_logout.disabled = not Supabase.signed_in
	_account.text = "%s님으로 로그인 중" % Supabase.nickname if Supabase.signed_in else "로그인하지 않았어요"
