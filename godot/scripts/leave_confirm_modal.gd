class_name LeaveConfirmModal
extends UiModal
## 로그인 상태에서 일시정지 메뉴의 '메인으로'를 누르면 뜨는 확인 팝업: 이번 기록은 저장되지 않는다는 안내 + 확인/취소

signal confirmed

var confirm_button: Button
var cancel_button: Button

const MESSAGE := "지금 메인으로 돌아가면 이번 기록은 저장되지 않아요. 돌아갈까요?"

func _init() -> void:
	title_text = "잠깐만요!"
	box_size = Vector2(460, 290)

func _build() -> void:
	var m := make_label(MESSAGE, Vector2(36, 84), Vector2(box_size.x - 72, 80), 18, UIPalette.TEXT, true)
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(m)
	cancel_button = make_button("취소", Vector2(36, box_size.y - 90), Vector2(180, 56), UIPalette.PINK_STATES, 22)
	cancel_button.pressed.connect(close)
	box.add_child(cancel_button)
	confirm_button = make_button("확인", Vector2(box_size.x - 216, box_size.y - 90), Vector2(180, 56), UIPalette.QUIT_BG, 22)
	confirm_button.pressed.connect(func():
		close()
		confirmed.emit())
	box.add_child(confirm_button)
