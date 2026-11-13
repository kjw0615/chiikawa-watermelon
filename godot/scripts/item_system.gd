class_name ItemSystem
extends Node
## 단일 게이지 + 아이템 4종(엉덩이 흔들기/교환권/명검 투하/음식 분수)의 기본 로직.
## 모든 효과는 임펄스/힘 기반이며 Head의 속도 상한(MAX_SPEED)과 겹침 분리 안전장치를 그대로 통과한다.

signal changed

const SHAKE_PULSES := 3
const SHAKE_INTERVAL := 0.18
const SHAKE_SPEED := 260.0      # 좌우 반발 펄스 속도(px/s)
const SHAKE_UP := 140.0
const FOUNTAIN_TIME := 1.6
const FOUNTAIN_HALF_W := 130.0  # 분수 영향 반폭(px)
const FOUNTAIN_UP_ACC := 2100.0 # 중력(1400)을 이겨 둥실 솟게 하는 상향 가속(px/s^2)
const FOUNTAIN_SIDE_ACC := 520.0

var main: Node2D
var gauge := 0.0
var busy := false
var suppress_over := false     # 분수 동안 게임오버 카운트다운 일시정지
var last_sword_stage := -1
var _fountain_t := 0.0
var _particles: CPUParticles2D

func add_gauge_for_stage(stage_no: int) -> void:
	gauge = minf(gauge + ItemDefs.gain_for_stage(stage_no), ItemDefs.gauge_max())
	changed.emit()

func reset() -> void:
	gauge = 0.0
	busy = false
	suppress_over = false
	_fountain_t = 0.0
	changed.emit()

func cost(id: String) -> float:
	return float(ItemDefs.item(id).get("cost", 100))

func can_use(id: String) -> bool:
	return not busy and not main.over and gauge >= cost(id)

## 게이지가 충분할 때만 사용(비용 차감). 성공 여부를 반환.
func use(id: String) -> bool:
	if not can_use(id):
		return false
	gauge -= cost(id)
	changed.emit()
	_run(id)
	return true

func use_by_index(i: int) -> bool:
	var its := ItemDefs.items()
	return i >= 0 and i < its.size() and use(its[i]["id"])

func _run(id: String) -> void:
	match id:
		"swap": main.reroll_next()
		"shake": _shake()
		"sword": _sword()
		"fountain": _fountain()

func _heads() -> Array:
	return main.get_tree().get_nodes_in_group("heads")

# ① 엉덩이 흔들기: x 순서로 이웃끼리 반대 방향 펄스를 줘서 서로 부딪히고 튕기며 섞이게 한다
func _shake() -> void:
	busy = true
	changed.emit()
	var heads := _heads()
	heads.sort_custom(func(a, b): return a.position.x < b.position.x)
	for pulse in SHAKE_PULSES:
		for i in heads.size():
			var h = heads[i]
			if not is_instance_valid(h) or h.merging:
				continue
			var dir := 1.0 if (i + pulse) % 2 == 0 else -1.0
			h.sleeping = false
			h.apply_central_impulse(Vector2(dir * SHAKE_SPEED, -SHAKE_UP) * h.mass)
			h.angular_velocity += dir * randf_range(1.0, 3.0)
			h.squash()
		await get_tree().create_timer(SHAKE_INTERVAL).timeout
	busy = false
	changed.emit()

# ③ 명검 투하: 마지막으로 마우스가 있던 x에서 검이 낙하, 닿은 노드와 같은 단계 전원 삭제
func _sword() -> void:
	busy = true
	changed.emit()
	var sw := Sword.new()
	sw.position = Vector2(clampf(main.last_play_x, main.L + 20.0, main.R - 20.0), main.DROP_Y - 40.0)
	sw.z_index = 30
	sw.hit.connect(_on_sword_hit)
	sw.fizzled.connect(_on_sword_fizzled)
	main.add_child(sw)

func _on_sword_hit(target: Head) -> void:
	last_sword_stage = target.stage
	var victims: Array = []
	for h in _heads():
		if h.stage == target.stage and not h.merging:
			victims.append(h)
	for v in victims:
		main.pops.append({"pos": v.position, "r": NodeDefs.radius(v.stage), "t": 0.0})
		v.vanish()
	for h in _heads():    # 쌓임을 깨워 빈 자리로 무너지게
		if is_instance_valid(h) and not h.merging:
			h.sleeping = false
			h.apply_central_impulse(Vector2(0, -1) * h.mass)
	busy = false
	changed.emit()

func _on_sword_fizzled() -> void:
	last_sword_stage = -1
	gauge = minf(gauge + cost("sword"), ItemDefs.gauge_max())   # 아무 노드에도 안 닿았으면 비용 환불
	busy = false
	changed.emit()

# ⑤ 음식 분수: 하단 중앙에서 위/좌우로 수압처럼 밀어올림(질량 무관 가속도, 부드럽게 켜지고 꺼짐)
func _fountain() -> void:
	busy = true
	suppress_over = true
	_fountain_t = FOUNTAIN_TIME
	if _particles == null:
		_particles = _make_particles()
		main.add_child(_particles)
	_particles.position = Vector2((main.L + main.R) / 2.0, main.FLOOR_Y - 8.0)
	_particles.restart()
	_particles.emitting = true
	changed.emit()

func _make_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 70
	p.lifetime = 1.0
	p.one_shot = false
	p.explosiveness = 0.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(50, 4)
	p.direction = Vector2(0, -1)
	p.spread = 28.0
	p.initial_velocity_min = 520.0
	p.initial_velocity_max = 820.0
	p.gravity = Vector2(0, 1400)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color("ffe9a8"), Color("ffb3c7"), Color("a8dcff")])
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	p.color_ramp = grad
	p.z_index = 25
	p.emitting = false
	return p

func _physics_process(dt: float) -> void:
	if _fountain_t <= 0.0:
		return
	_fountain_t -= dt
	var t := 1.0 - clampf(_fountain_t / FOUNTAIN_TIME, 0.0, 1.0)
	var ramp := sin(PI * t)
	var cx: float = (main.L + main.R) / 2.0
	for h in _heads():
		if h.merging:
			continue
		var dx: float = h.position.x - cx
		var w := 1.0 - absf(dx) / FOUNTAIN_HALF_W
		if w <= 0.0:
			continue
		h.sleeping = false
		var acc := Vector2(signf(dx) * FOUNTAIN_SIDE_ACC * w, -FOUNTAIN_UP_ACC * w)
		h.apply_central_force(acc * h.mass * ramp)
	if _fountain_t <= 0.0:
		_particles.emitting = false
		suppress_over = false
		busy = false
		changed.emit()
