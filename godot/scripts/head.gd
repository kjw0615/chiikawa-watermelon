class_name Head
extends RigidBody2D
## 비정형 머리 1개. 2D 물리(알파 외곽선 -> 볼록 분해 콜라이더) + 2.5D 연출(압출 레이어, 드롭 섀도, 광원 쉐이더).

signal touched(head: Head, other: Node, speed: float)

const DEPTH_LAYERS := 6
const DEPTH_STEP := 2.5
const SHADOW_OFFSET := Vector2(12, 16)
const LIGHT_DIR := Vector2(-0.5, -0.7)
const SHADER := preload("res://shaders/head_lit.gdshader")

static var state_counts := {}   # 검증용: 표정 전환 횟수

var stage := 0
var top_extent := 0.0
var age := 0.0
var danger := 0.0
var merging := false
var _layers: Array[Polygon2D] = []
var _shadow: Polygon2D
var _sprite: Sprite2D
var _mat: ShaderMaterial
var _base_scale := 1.0
var _last_vel := Vector2.ZERO
var _texs := {}
var _state := "neutral"
var _happy_t := 0.0
var _squash_t := 0.0

func setup(st: int) -> void:
	stage = st
	var data := HeadShapes.get_data(stage)
	var outline: PackedVector2Array = data["outline"]
	var col: Color = data["color"]
	top_extent = data["top"]

	mass = maxf(data["area"] / 2500.0, 0.2)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.12
	physics_material_override = pm
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(func(b: Node): touched.emit(self, b, _last_vel.length()))

	# 콜라이더: 오목 외곽선 -> 볼록 조각들
	var pieces := Geometry2D.decompose_polygon_in_convex(outline)
	if pieces.is_empty():
		pieces = [Geometry2D.convex_hull(outline)]
	for piece in pieces:
		var cs := CollisionPolygon2D.new()
		cs.polygon = piece
		add_child(cs)

	_shadow = _poly(outline, Color(0, 0, 0, 0.22), -10)
	for i in DEPTH_LAYERS:
		var shade := 0.4 + 0.25 * float(i) / DEPTH_LAYERS
		_layers.append(_poly(outline, Color(col.r * shade, col.g * shade, col.b * shade), 0))

	_base_scale = data["scale"]
	_texs = data["texs"]
	_sprite = Sprite2D.new()
	_sprite.texture = data["tex"]
	_sprite.offset = data["size"] / 2.0 - data["centroid"]   # 무게중심 = 바디 원점
	_sprite.scale = Vector2.ONE * _base_scale
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("light_dir", LIGHT_DIR)
	_mat.set_shader_parameter("center_uv", data["centroid_uv"])
	_mat.set_shader_parameter("extent_uv", data["extent_uv"])
	_sprite.material = _mat
	_sprite.z_index = 1   # top_level 레이어보다 위에 그리기
	add_child(_sprite)

func _poly(pts: PackedVector2Array, col: Color, z: int) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = col
	p.top_level = true   # 회전은 따라가되 오프셋은 월드 기준으로 직접 갱신
	p.z_index = z
	add_child(p)
	return p

## 생성/합체 직후 커지며 등장
func pop_in() -> void:
	_sprite.scale = Vector2.ONE * _base_scale * 0.6
	var t := create_tween()
	t.tween_property(_sprite, "scale", Vector2.ONE * _base_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_happy_t = 0.7
	_mat.set_shader_parameter("flash", 0.15)
	t.parallel().tween_method(func(v: float): _mat.set_shader_parameter("flash", v), 0.15, 0.0, 0.25)

## 착지 시 찌그러짐
func squash() -> void:
	_squash_t = 0.25
	_sprite.scale = _base_scale * Vector2(1.12, 0.88)
	create_tween().tween_property(_sprite, "scale", Vector2.ONE * _base_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _physics_process(dt: float) -> void:
	age += dt
	_last_vel = linear_velocity
	_happy_t = maxf(_happy_t - dt, 0.0)
	_squash_t = maxf(_squash_t - dt, 0.0)
	# 표정: 합체=happy > 착지=squash > 낙하=surprised > 평상=neutral
	var want := "neutral"
	if _happy_t > 0.0:
		want = "happy"
	elif _squash_t > 0.0:
		want = "squash"
	elif linear_velocity.y > 300.0:
		want = "surprised"
	if want != _state:
		_state = want
		state_counts[want] = state_counts.get(want, 0) + 1
		_sprite.texture = _texs[want]

func _process(_dt: float) -> void:
	_mat.set_shader_parameter("body_rot", global_rotation)
	_shadow.global_position = global_position + SHADOW_OFFSET
	_shadow.global_rotation = global_rotation
	for i in _layers.size():
		var l := _layers[i]
		l.global_position = global_position + Vector2(0, (_layers.size() - i) * DEPTH_STEP)
		l.global_rotation = global_rotation
