class_name VolumeRow
extends Control
## 볼륨 한 줄: 스피커(음소거 토글) + 이름 + 슬라이더 + 퍼센트. kind 가 "bgm" 이면 BGM 버스, "sfx" 이면 효과음 버스를 조절한다.
## 값은 Audio(autoload)가 들고 있어서 설정 모달/일시정지 메뉴/인게임 어디서 바꿔도 서로 동기화된다.

const WIDTH := 400.0

var kind := "bgm"
var caption := "BGM"
var _mute_btn: Button
var _speaker: Control
var _slider: HSlider
var _pct: Label

func _init(k := "bgm", cap := "BGM") -> void:
	kind = k
	caption = cap
	size = Vector2(WIDTH, 40)

func _ready() -> void:
	_mute_btn = Button.new()
	_mute_btn.toggle_mode = true
	_mute_btn.flat = true
	_mute_btn.focus_mode = Control.FOCUS_NONE
	_mute_btn.size = Vector2(36, 36)
	_mute_btn.position = Vector2(0, 2)
	_mute_btn.tooltip_text = "%s 음소거" % caption
	_speaker = Control.new()
	_speaker.size = _mute_btn.size
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker.draw.connect(_draw_speaker)
	_mute_btn.add_child(_speaker)
	_mute_btn.toggled.connect(func(on: bool): _set_muted(on))
	add_child(_mute_btn)
	var cap_l := UiModal.make_label(caption, Vector2(44, 8), Vector2(74, 26), 16, UIPalette.TEXT)
	cap_l.add_theme_font_override("font", UIPalette.button_font())
	add_child(cap_l)
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.01
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.position = Vector2(124, 12)
	_slider.size = Vector2(WIDTH - 124.0 - 56.0, 16)
	var track := StyleBoxFlat.new()
	track.bg_color = UIPalette.DIVIDER
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIPalette.SLIDER_FILL
	fill.set_corner_radius_all(4)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	_slider.add_theme_icon_override("grabber", UIPalette.circle_texture(UIPalette.BLUE_INK))
	_slider.add_theme_icon_override("grabber_highlight", UIPalette.circle_texture(UIPalette.SLIDER_GRABBER_HOVER))
	_slider.add_theme_icon_override("grabber_disabled", UIPalette.circle_texture(UIPalette.TEXT_MUTED))
	_slider.add_theme_stylebox_override("slider", track)
	_slider.add_theme_stylebox_override("grabber_area", fill)
	_slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	_slider.value_changed.connect(func(v: float): _set_volume(v, false))   # 실시간 반영
	_slider.drag_ended.connect(func(_c: bool): Audio.save_settings())      # 놓을 때 저장
	add_child(_slider)
	_pct = UiModal.make_label("", Vector2(WIDTH - 52.0, 8), Vector2(52, 26), 15, UIPalette.TEXT)
	_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_pct)
	Audio.changed.connect(_refresh)
	_refresh()

func _volume() -> float:
	return Audio.bgm_volume if kind == "bgm" else Audio.sfx_volume

func _muted() -> bool:
	return Audio.bgm_muted if kind == "bgm" else Audio.sfx_muted

func _set_volume(v: float, save: bool) -> void:
	if kind == "bgm":
		Audio.set_bgm_volume(v, save)
	else:
		Audio.set_sfx_volume(v, save)

func _set_muted(m: bool) -> void:
	if kind == "bgm":
		Audio.set_bgm_muted(m)
	else:
		Audio.set_sfx_muted(m)

func _refresh() -> void:
	_slider.set_value_no_signal(_volume())
	_slider.editable = not _muted()
	_mute_btn.set_pressed_no_signal(_muted())
	_pct.text = "%d%%" % roundi(_volume() * 100.0)
	_speaker.queue_redraw()

func _draw_speaker() -> void:
	var col := UIPalette.TEXT_MUTED if _muted() else UIPalette.BLUE_INK
	_speaker.draw_colored_polygon(PackedVector2Array([Vector2(8, 14), Vector2(14, 14), Vector2(21, 8), Vector2(21, 28), Vector2(14, 22), Vector2(8, 22)]), col)
	if _muted():
		_speaker.draw_line(Vector2(25, 12), Vector2(34, 24), UIPalette.TEXT_MUTED, 3.0)
		_speaker.draw_line(Vector2(34, 12), Vector2(25, 24), UIPalette.TEXT_MUTED, 3.0)
	else:
		_speaker.draw_arc(Vector2(21, 18), 7.0, -0.9, 0.9, 10, col, 2.5)
		_speaker.draw_arc(Vector2(21, 18), 12.0, -0.9, 0.9, 12, col, 2.5)
