class_name StartConfirmModal
extends UiModal
## 비로그인으로 '게임 시작'을 눌렀을 때 뜨는 확인 팝업: 시작하기(비로그인으로 바로 시작) / 로그인하기(로그인 팝업 열기)

signal start_chosen
signal login_chosen

var start_button: Button
var login_button: Button

const MESSAGE := "비로그인 상태에서는 점수가 서버에 저장되지 않고 랭킹에 등록되지 않아요. 그래도 시작할까요?"

func _init() -> void:
	title_text = "잠깐만요!"
	box_size = Vector2(460, 290)

func _build() -> void:
	var m := make_label(MESSAGE, Vector2(36, 84), Vector2(box_size.x - 72, 80), 18, UIPalette.TEXT, true)
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(m)
	start_button = make_button("시작하기", Vector2(36, box_size.y - 90), Vector2(180, 56), UIPalette.QUIT_BG, 22)
	start_button.pressed.connect(func():
		close()
		start_chosen.emit())
	box.add_child(start_button)
	login_button = make_button("로그인하기", Vector2(box_size.x - 216, box_size.y - 90), Vector2(180, 56), UIPalette.PINK_STATES, 22)
	login_button.pressed.connect(func():
		close()
		login_chosen.emit())
	box.add_child(login_button)
