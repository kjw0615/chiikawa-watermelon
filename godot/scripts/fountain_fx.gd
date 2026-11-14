class_name FountainFx
extends Node2D
## 음식 분수의 물기둥 + 상단 물보라 거품 연출. 원점 = 분수 바닥 중앙. 음식 파티클은 이 위 레이어에서 따로 뿜는다.
## 배치 수치는 assets/effects/fountain/layout.json(부모 캔버스 256x384, 발생점 (128,292))을 원점 기준으로 옮긴 값이다.

const TEX_COLUMN := "res://assets/effects/fountain/water_column.png"   # 512x1024
const TEX_CAP := "res://assets/effects/fountain/splash_cap.png"         # 1024x512
const RISE_TIME := 0.4        # 솟아오르는 시간
const FADE_TIME := 0.5        # 끝날 때 서서히 사라지는 시간
const COL_SIZE := Vector2(80, 240)    # layout.json 표시 크기
const COL_TOP := -220.0               # 기둥 꼭대기 y(원점 기준, 100% 높이일 때)
const COL_BOTTOM := 20.0              # 기둥 아래 끝(바닥 패딩 포함)
const CAP_SIZE := Vector2(240, 120)
const CAP_CENTER_Y := -200.0          # 물보라 중심 y(100% 높이일 때)

var fx_scale := 1.15          # 전체 배율(발생점~물보라 꼭대기가 바닥~화면 중간 높이에 닿도록)
var _column: Sprite2D
var _cap: Sprite2D
var _grow := 0.0              # 0~1 솟은 정도
var _fade := 1.0              # 0~1 불투명도
var _on := false
var _time := 0.0
var _tween: Tween

func _ready() -> void:
	_column = Sprite2D.new()
	_column.texture = load(TEX_COLUMN)
	_column.centered = false
	add_child(_column)
	_cap = Sprite2D.new()
	_cap.texture = load(TEX_CAP)
	add_child(_cap)
	_layout()

func _process(dt: float) -> void:
	if _grow <= 0.0 and not _on:
		return
	_time += dt
	_layout()

## 솟은 정도/흔들림을 반영해 두 레이어를 배치(기둥은 바닥 고정, 위로 늘어남, 물보라는 꼭대기에서 커지며 따라 올라감)
func _layout() -> void:
	var k := fx_scale
	var g := clampf(_grow, 0.0, 1.0)
	var top := COL_TOP * g
	var wob_w := 1.0 + 0.02 * sin(_time * 9.0)
	var col_h := (COL_BOTTOM - top) * k
	var col_w := COL_SIZE.x * k * wob_w
	_column.scale = Vector2(col_w / _column.texture.get_width(), col_h / _column.texture.get_height())
	_column.position = Vector2(-col_w / 2.0, top * k)
	var cap_sx := CAP_SIZE.x * k * (1.0 + 0.04 * sin(_time * 6.0)) * lerpf(0.4, 1.0, g)
	var cap_sy := CAP_SIZE.y * k * (1.0 + 0.03 * sin(_time * 7.3 + 1.0)) * lerpf(0.4, 1.0, g)
	_cap.scale = Vector2(cap_sx / _cap.texture.get_width(), cap_sy / _cap.texture.get_height())
	_cap.position = Vector2(0, CAP_CENTER_Y * g * k)
	_column.modulate.a = _fade * 0.92
	_cap.modulate.a = _fade

func start() -> void:
	if _tween != null:
		_tween.kill()
	_on = true
	_fade = 1.0
	_tween = create_tween()
	_tween.tween_method(func(v: float): _grow = v, _grow, 1.0, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func stop() -> void:
	if _tween != null:
		_tween.kill()
	_on = false
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(func(v: float): _fade = v; _layout(), _fade, 0.0, FADE_TIME)
	_tween.tween_method(func(v: float): _grow = v, _grow, 0.7, FADE_TIME)
	_tween.chain().tween_callback(func(): _grow = 0.0; _layout())

func is_active() -> bool:
	return _on
