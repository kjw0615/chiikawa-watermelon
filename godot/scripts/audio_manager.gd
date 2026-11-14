class_name AudioManager
extends Node
## 오디오 매니저(autoload 이름: Audio): BGM 무한 루프 재생 + BGM/SFX 버스 볼륨·음소거 + 설정 저장.
## 버스는 default_bus_layout.tres 의 BGM, SFX(둘 다 Master 로 송출). 배경음악은 BGM, 모든 효과음은 SFX 버스로 보낸다.
## 일시정지(get_tree().paused) 중에도 BGM 이 이어지도록 PROCESS_MODE_ALWAYS.

signal changed

const BUS_BGM := "BGM"
const BUS_SFX := "SFX"
const SAVE_PATH := "user://settings.cfg"   # [audio] volume/muted = SFX, bgm_volume/bgm_muted = BGM (점수는 저장하지 않음)
const BGM_STREAM := "res://audio/bgm.mp3"
const TEST_FLAGS := ["--shot", "--verify", "--title-test", "--text-audit", "--net-test"]

var bgm_volume := 0.6
var bgm_muted := false
var sfx_volume := 1.0
var sfx_muted := false
var silent := false   # 자체 테스트/헤드리스: 항상 무음, BGM 미재생, 설정 파일 미저장
var bgm_on := false   # BGM 이 켜져 있어야 하는 상태(인게임)
var _bgm: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	silent = DisplayServer.get_name() == "headless"
	for f in TEST_FLAGS:
		if f in args:
			silent = true
	if not silent:
		var cf := ConfigFile.new()
		if cf.load(SAVE_PATH) == OK:
			sfx_volume = clampf(float(cf.get_value("audio", "volume", 1.0)), 0.0, 1.0)
			sfx_muted = bool(cf.get_value("audio", "muted", false))
			bgm_volume = clampf(float(cf.get_value("audio", "bgm_volume", bgm_volume)), 0.0, 1.0)
			bgm_muted = bool(cf.get_value("audio", "bgm_muted", false))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), silent)
	_apply()
	_bgm = AudioStreamPlayer.new()
	_bgm.bus = BUS_BGM
	var s := load(BGM_STREAM) as AudioStreamMP3
	if s != null:
		s.loop = true   # 끊김 없이 무한 반복
		_bgm.stream = s
	add_child(_bgm)
	# BGM 은 타이틀에서는 꺼 두고, 인게임이 시작될 때 main 이 play_bgm() 으로 켠다

## 인게임 시작: 처음부터 무한 루프 재생(자체 테스트는 무음이라 실제 재생은 안 하고 bgm_on 만 기록)
func play_bgm() -> void:
	bgm_on = true
	if not silent and _bgm != null and _bgm.stream != null:
		_bgm.play()

## 메인(타이틀) 복귀: BGM 끄기
func stop_bgm() -> void:
	bgm_on = false
	if _bgm != null:
		_bgm.stop()

func is_bgm_playing() -> bool:
	return _bgm != null and _bgm.playing

func set_bgm_volume(v: float, save := true) -> void:
	bgm_volume = clampf(v, 0.0, 1.0)
	_commit(save)

func set_bgm_muted(m: bool, save := true) -> void:
	bgm_muted = m
	_commit(save)

func set_sfx_volume(v: float, save := true) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_commit(save)

func set_sfx_muted(m: bool, save := true) -> void:
	sfx_muted = m
	_commit(save)

func _commit(save: bool) -> void:
	_apply()
	if save:
		save_settings()
	changed.emit()

func _apply() -> void:
	_set_bus(BUS_BGM, bgm_volume, bgm_muted)
	_set_bus(BUS_SFX, sfx_volume, sfx_muted)

func _set_bus(bus: String, vol: float, muted: bool) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(vol, 0.0001)))
	AudioServer.set_bus_mute(i, muted)

func save_settings() -> void:
	if silent:
		return   # 테스트 실행이 사용자 설정을 덮어쓰지 않게
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("audio", "volume", sfx_volume)
	cf.set_value("audio", "muted", sfx_muted)
	cf.set_value("audio", "bgm_volume", bgm_volume)
	cf.set_value("audio", "bgm_muted", bgm_muted)
	cf.save(SAVE_PATH)
