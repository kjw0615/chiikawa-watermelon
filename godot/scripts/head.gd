class_name Head
extends RigidBody2D
## 비정형 머리 1개. 2D 물리(알파 외곽선 -> 볼록 분해 콜라이더) + 2.5D 연출(광원 쉐이더(납작한 원본 스프라이트)).

signal touched(head: Head, other: Node, speed: float)

const MAX_SPEED := 1200.0
const FRESH_MAX_SPEED := 340.0   # 합체 직후 겹침 해소 중에는 천천히 밀려나게
const FRESH_TIME := 0.5
const PUSH_RANGE := 1.35    # 합체로 커진 노드가 이웃을 밀어낼 범위(두 반지름 합 기준 배율)
const PUSH_SPEED := 800.0   # 합체 순간 충격파 최대 속도(px/s)
const PUSH_UP := 0.12       # 충격파 방향에 섞는 위쪽 성분(좌우가 막혀도 솟구쳐 빠지게)
const SELF_POP := 50.0      # 합체로 생긴 노드 본인이 위로 튀어오르는 속도(px/s)
const MAX_SPIN := 12.0
const ANGULAR_DAMP := 4.0
const LINEAR_DAMP := 0.15

static var state_counts := {}   # 검증용: 표정 전환 횟수

var stage := 0
var top_extent := 0.0
var age := 0.0
var danger := 0.0
var merging := false
var _sprite: Sprite2D
var _mat: ShaderMaterial
var _base_scale := 1.0
var _last_vel := Vector2.ZERO
var _texs := {}
var _state := "neutral"
var _happy_t := 0.0
var _squash_t := 0.0
var _fresh_t := 0.0
var _collider := PackedVector2Array()
var _pending_shift := Vector2.ZERO

func setup(st: int) -> void:
	stage = st
	var data := HeadShapes.get_data(stage)
	var outline: PackedVector2Array = data["outline"]
	top_extent = data["top"]

	mass = pow(maxf(data["area"] / 2500.0, 0.2), 0.7)   # 대형 노드가 소형을 튕겨내지 않도록 질량비 압축
	var pm := PhysicsMaterial.new()
	pm.friction = 0.3   # 낮은 마찰: 서로 끼거나 달라붙지 않고 미끄러져 빠지게
	pm.bounce = 0.03
	physics_material_override = pm
	# 무게중심/관성을 콜라이더 폴리곤에서 직접 계산해 고정(자동 계산 시 조각 배치에 따라 비정상 회전)
	center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = data["com"]
	inertia = mass * float(data["inertia_k"])
	angular_damp = ANGULAR_DAMP
	linear_damp = LINEAR_DAMP
	continuous_cd = RigidBody2D.CCD_MODE_DISABLED   # 레이캐스트 CCD가 다조각 오목 콜라이더 더미에서 폭주를 유발해 끔(속도 상한+두꺼운 벽으로 터널링 방지)
	contact_monitor = true
	max_contacts_reported = 48   # 접촉점 수 기준: 다조각 노드(카니 등)도 포화되지 않게
	body_entered.connect(func(b: Node): touched.emit(self, b, _last_vel.length()))

	# 콜라이더: 오목 외곽선 -> 볼록 조각들
	var collider: PackedVector2Array = data["collider"]
	_collider = collider
	var pieces := Geometry2D.decompose_polygon_in_convex(collider)
	if pieces.is_empty():
		pieces = [Geometry2D.convex_hull(collider)]
	for piece in pieces:
		var cs := CollisionPolygon2D.new()
		cs.polygon = piece
		add_child(cs)


	_base_scale = data["scale"]
	_texs = data["texs"]
	_sprite = Sprite2D.new()
	_sprite.texture = data["tex"]
	_sprite.offset = data["size"] / 2.0 - data["centroid"]   # 무게중심 = 바디 원점
	_sprite.scale = Vector2.ONE * _base_scale
	_mat = HeadShapes.make_material(stage)
	_sprite.material = _mat
	add_child(_sprite)

## 생성/합체 직후 커지며 등장
func pop_in() -> void:
	_sprite.scale = Vector2.ONE * _base_scale * 0.6
	var t := create_tween()
	t.tween_property(_sprite, "scale", Vector2.ONE * _base_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_happy_t = 0.7
	_fresh_t = FRESH_TIME
	apply_central_impulse(Vector2(0, -SELF_POP) * mass)   # 바닥/이웃에 파묻히지 않게 위로 살짝 튀어오름
	_push_neighbors(1.0)   # 합체 충격파: 확장된 콜라이더 영역 안의 노드를 바깥으로 밀어냄
	_mat.set_shader_parameter("flash", 0.15)
	t.parallel().tween_method(func(v: float): _mat.set_shader_parameter("flash", v), 0.15, 0.0, 0.25)

## 아이템 등으로 필드에서 제거: 충돌/그룹에서 빠지고 작아지며 사라짐
func vanish() -> void:
	merging = true
	remove_from_group("heads")
	for c in get_children():
		if c is CollisionPolygon2D:
			c.set_deferred("disabled", true)
	set_deferred("freeze", true)
	var t := create_tween()
	t.tween_property(_sprite, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)

## 착지 시 찌그러짐
func squash() -> void:
	_squash_t = 0.25
	_sprite.scale = _base_scale * Vector2(1.12, 0.88)
	create_tween().tween_property(_sprite, "scale", Vector2.ONE * _base_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 가까운 노드를 중심에서 바깥쪽으로 밀어내는 충격(겹침이 클수록 강하게)
func _push_neighbors(strength: float) -> void:
	var my_r := NodeDefs.radius(stage)
	for n in get_tree().get_nodes_in_group("heads"):
		var h := n as Head
		if h == self or h.merging:
			continue
		var d := h.position - position
		var reach := (my_r + NodeDefs.radius(h.stage)) * PUSH_RANGE
		var dist := maxf(d.length(), 0.01)
		if dist >= reach:
			continue
		var k := 1.0 - dist / reach
		var dir := (d / dist + Vector2(0, -PUSH_UP)).normalized()
		h.apply_central_impulse(dir * PUSH_SPEED * k * strength * h.mass)

## 월드 좌표의 콜라이더 외곽선(겹침 검사용)
func world_collider() -> PackedVector2Array:
	return global_transform * _collider

## 겹침 해소용 위치 보정을 다음 물리 스텝에 적용
func shift(v: Vector2) -> void:
	_pending_shift += v

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _pending_shift != Vector2.ZERO:
		var t := state.transform
		t.origin += _pending_shift
		state.transform = t
		_pending_shift = Vector2.ZERO
	# 합체 직후 겹침 등으로 인한 폭주(튕겨나감) 방지
	var cap := FRESH_MAX_SPEED if _fresh_t > 0.0 else MAX_SPEED
	state.linear_velocity = state.linear_velocity.limit_length(cap)
	state.angular_velocity = clampf(state.angular_velocity, -MAX_SPIN, MAX_SPIN)

func _physics_process(dt: float) -> void:
	age += dt
	if _fresh_t > 0.0:
		_push_neighbors(0.35)   # 스케일업 동안 겹침이 남아 있으면 계속 밀어냄
	_fresh_t = maxf(_fresh_t - dt, 0.0)
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
