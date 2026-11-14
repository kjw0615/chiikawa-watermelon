class_name FountainFx
extends Node2D
## 음식 분수의 물기둥 + 상단 물보라 거품 연출. 원점 = 분수 바닥 중앙.
## 코덱스 텍스처가 오면 TEX_COLUMN / TEX_SPRAY 경로에 같은 이름으로 파일만 넣으면 교체된다(없으면 임시 도형).
##  - 물기둥: 위아래로 늘어나는 한 장짜리 이미지(바닥이 아래, 폭 COLUMN_W 기준으로 맞춤)
##  - 물보라: 기둥 꼭대기에서 부채꼴로 퍼지는 거품 파티클 텍스처(정사각 한 장)

const TEX_COLUMN := "res://assets/effects/fountain/fountain_column.png"
const TEX_SPRAY := "res://assets/effects/fountain/fountain_spray.png"
const COLUMN_W := 150.0       # 기둥 폭(px) = 대형 노드 폭 정도
const RISE_TIME := 0.35       # 기둥이 솟는 시간
const FADE_TIME := 0.4        # 끝날 때 사라지는 시간
const WATER := Color("8fd8e0")   # 임시 도형용 하늘색/청록

var column_height := 300.0    # 기둥 최대 높이(바닥 -> 꼭대기)
var _column: Sprite2D
var _spray: CPUParticles2D
var _tween: Tween

func _ready() -> void:
	_column = Sprite2D.new()
	_column.texture = _load_or(TEX_COLUMN, _placeholder_column())
	_column.centered = false
	_column.modulate.a = 0.0
	add_child(_column)
	_spray = _make_spray()
	add_child(_spray)
	_apply_height(0.0)

## 기둥 높이 비율 t(0~1)를 반영: 바닥 고정, 위로 늘어남, 물보라는 꼭대기에 위치
func _apply_height(t: float) -> void:
	var h := maxf(column_height * t, 1.0)
	var tex := _column.texture
	_column.scale = Vector2(COLUMN_W / tex.get_width(), h / tex.get_height())
	_column.position = Vector2(-COLUMN_W / 2.0, -h)
	_spray.position = Vector2(0, -h)

func start() -> void:
	if _tween != null:
		_tween.kill()
	_spray.emitting = true
	_spray.restart()
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_apply_height, 0.0, 1.0, RISE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_column, "modulate:a", 0.85, RISE_TIME * 0.6)

func stop() -> void:
	if _tween != null:
		_tween.kill()
	_spray.emitting = false
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_column, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_method(_apply_height, 1.0, 0.6, FADE_TIME)

func is_active() -> bool:
	return _spray.emitting

func _make_spray() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _load_or(TEX_SPRAY, _placeholder_bubble())
	p.amount = 28
	p.lifetime = 0.9
	p.randomness = 0.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 30.0
	p.direction = Vector2(0, -1)
	p.spread = 55.0               # 부채꼴
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 220.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var col := Gradient.new()
	col.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	col.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	p.color_ramp = col
	p.emitting = false
	return p

static func _load_or(path: String, fallback: Texture2D) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return fallback

## 임시: 세로 방향은 위로 갈수록 옅어지고 좌우 가장자리가 부드러운 하늘색 기둥
static func _placeholder_column() -> Texture2D:
	var w := 64
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in w:
		var edge := 1.0 - absf((x + 0.5) / w * 2.0 - 1.0)
		for y in h:
			var a := clampf(edge * 2.0, 0.0, 1.0) * lerpf(0.35, 0.9, float(y) / h)
			img.set_pixel(x, y, Color(WATER, a))
	return ImageTexture.create_from_image(img)

## 임시: 가장자리가 진한 비눗방울 모양 거품
static func _placeholder_bubble() -> Texture2D:
	var d := 48
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d, d) / 2.0 - Vector2(0.5, 0.5)
	for x in d:
		for y in d:
			var r := Vector2(x, y).distance_to(c) / (d / 2.0)
			var a := 0.0
			if r < 1.0:
				a = 0.25 + 0.6 * smoothstep(0.55, 0.95, r)
			img.set_pixel(x, y, Color(0.9, 1.0, 1.0, a * clampf((1.0 - r) * 6.0, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
