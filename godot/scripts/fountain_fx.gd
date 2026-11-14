class_name FountainFx
extends Node2D
## 음식 분수의 물기둥 + 상단 물보라 거품 연출. 원점 = 분수 바닥 중앙. 음식 파티클은 이 위 레이어에서 따로 뿜는다.
## 물기둥은 아래가 좁고 위로 갈수록 좌우로 넓어지는 깔때기 메쉬(Polygon2D)이고, 그 꼭대기(왕관 모양)가
## 물보라 거품 안쪽에 겹쳐 들어가 한 줄기로 이어진다. 물보라는 기둥보다 뒤 레이어이고 아래쪽 목(neck)은 잘라 쓴다.

const TEX_COLUMN := "res://assets/effects/fountain/water_column.png"   # 512x1024 (실제 그림은 y 130~940)
const TEX_CAP := "res://assets/effects/fountain/splash_cap.png"         # 1024x512
const RISE_TIME := 0.4        # 솟아오르는 시간
const FADE_TIME := 0.5        # 끝날 때 서서히 사라지는 시간
const CAP_W := 330.0          # 물보라 폭(px)
const CAP_REGION := Rect2(0, 0, 1024, 440)   # 아래 목(neck) 부분은 잘라서 기둥에 덮이게 함
const CAP_OVERLAP := 95.0     # 물보라 맨 위에서 기둥 꼭대기까지의 거리(물보라 안쪽으로 겹쳐 들어감)
const COL_BOTTOM := 10.0      # 기둥 아래 끝(바닥 패딩 포함)
const COL_UV_Y := Vector2(130.0, 940.0)   # 기둥 그림의 실제 사용 구간(위, 아래)
const COL_S_BOTTOM := 0.20    # 아래쪽 가로 배율(좁게)
const COL_S_TOP := 0.44       # 위쪽 가로 배율(넓게): 아래 20% -> 위 44% 로 갈수록 벌어지는 V자 깔때기
const ROWS := 18

var reach := 294.0            # 바닥~물보라 꼭대기 높이(px)
var _column: Polygon2D
var _cap: Sprite2D
var _grow := 0.0              # 0~1 솟은 정도
var _fade := 1.0              # 0~1 불투명도
var _on := false
var _time := 0.0
var _tween: Tween

func _ready() -> void:
	_cap = Sprite2D.new()
	_cap.texture = load(TEX_CAP)
	_cap.centered = false
	_cap.region_enabled = true
	_cap.region_rect = CAP_REGION
	add_child(_cap)
	_column = Polygon2D.new()   # 물보라보다 나중에 그려져 기둥 꼭대기가 물보라 위에 얹힌다
	_column.texture = load(TEX_COLUMN)
	add_child(_column)
	_layout()

func _process(dt: float) -> void:
	if _grow <= 0.0 and not _on:
		return
	_time += dt
	_layout()

func _layout() -> void:
	var g := clampf(_grow, 0.0, 1.0)
	var gs := lerpf(0.4, 1.0, g)
	# 물보라: 꼭대기가 reach*g 높이, 살짝 출렁임
	var sx := CAP_W / 1024.0 * gs * (1.0 + 0.04 * sin(_time * 6.0))
	var sy := CAP_W / 1024.0 * gs * (1.0 + 0.03 * sin(_time * 7.3 + 1.0))
	var cap_top := -reach * g
	_cap.scale = Vector2(sx, sy)
	_cap.position = Vector2(-CAP_REGION.size.x * sx / 2.0, cap_top)
	# 기둥: 바닥 고정, 꼭대기는 물보라 안쪽(CAP_OVERLAP)까지
	var top := cap_top + CAP_OVERLAP * gs
	var wob := 1.0 + 0.02 * sin(_time * 9.0)
	var poly := PackedVector2Array()
	var uv := PackedVector2Array()
	var quads: Array = []
	for i in ROWS + 1:
		var t := float(i) / ROWS   # 0 = 아래, 1 = 위
		var y := lerpf(COL_BOTTOM, top, t)
		var uy := lerpf(COL_UV_Y.y, COL_UV_Y.x, t)
		var s := lerpf(COL_S_BOTTOM, COL_S_TOP, pow(t, 1.6)) * wob * gs
		poly.append(Vector2(-256.0 * s, y))
		poly.append(Vector2(256.0 * s, y))
		uv.append(Vector2(0.0, uy))
		uv.append(Vector2(512.0, uy))
		if i > 0:
			var b := (i - 1) * 2
			quads.append(PackedInt32Array([b, b + 1, b + 3, b + 2]))
	_column.polygon = poly
	_column.uv = uv
	_column.polygons = quads
	_column.modulate.a = _fade * 0.95
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
