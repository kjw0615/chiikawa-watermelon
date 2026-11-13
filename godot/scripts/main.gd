extends Node2D
## 프로토타입: 원근 박스 + 클릭 드롭 + 같은 단계 합체/점수/게임오버/SFX.
## 합체 사다리: 11단계 노드(data/nodes.json), 마지막 단계끼리는 소멸 +100점. 드롭은 1~5단계만. 클릭 드롭, R 재시작.

const L := 40.0
const R := 440.0
const FLOOR_Y := 700.0
const TOP_Y := 120.0
const DROP_Y := 60.0
const DROP_COOLDOWN := 0.45
const OVER_TIME := 2.0
const MAX_COMBO := 5
const SAVE_PATH := "user://best.cfg"

const SFX := {
	"contact": preload("res://audio/contact_soft.wav"),
	"land": preload("res://audio/land_squash.wav"),
	"pop": preload("res://audio/merge_pop.wav"),
	"chain": preload("res://audio/merge_chain.wav"),
}

var score := 0
var best := 0
var over := false
var next_stage := 0
var cooldown := 0.0
var combo := 0
var combo_t := 0.0
var merges := 0
var pops: Array = []
var _label: Label
var _over_label: Label
var _panel: SidePanel
var _preview: Sprite2D
var _players: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _auto := false

func _ready() -> void:
	_auto = "--shot" in OS.get_cmdline_user_args()
	_build_walls()
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_label = Label.new()
	_label.position = Vector2(10, 8)
	add_child(_label)
	_over_label = Label.new()
	_over_label.position = Vector2(L, 300)
	_over_label.size = Vector2(400, 100)
	_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_label.add_theme_font_size_override("font_size", 30)
	_over_label.z_index = 50
	add_child(_over_label)
	_panel = SidePanel.new()
	_panel.position = Vector2(480, 20)
	_panel.size = Vector2(230, 700)
	add_child(_panel)
	_preview = Sprite2D.new()
	_preview.z_index = 20
	add_child(_preview)
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		best = cf.get_value("game", "best", 0)
	_new_game()
	if _auto:
		_run_auto()

func _new_game() -> void:
	for h in get_tree().get_nodes_in_group("heads"):
		h.queue_free()
	score = 0
	over = false
	cooldown = 0.0
	combo = 0
	merges = 0
	_over_label.text = ""
	_roll_next()
	_update_hud()

func _roll_next() -> void:
	next_stage = randi() % (NodeDefs.drop_max_index() + 1)   # 드롭은 1~5단계만, 이후는 합체로만
	_preview.texture = HeadShapes.get_data(next_stage)["tex"]
	var d := HeadShapes.get_data(next_stage)
	_preview.offset = d["size"] / 2.0 - d["centroid"]
	_preview.scale = Vector2.ONE * d["scale"]
	_preview.modulate = Color(1, 1, 1, 0.85)
	_panel.set_next(next_stage)

func _build_walls() -> void:
	var wall := StaticBody2D.new()
	var pm := PhysicsMaterial.new()
	pm.friction = 0.8
	pm.bounce = 0.1
	wall.physics_material_override = pm
	for r in [Rect2(L - 20, -400, 20, 1400), Rect2(R, -400, 20, 1400), Rect2(L - 40, FLOOR_Y, R - L + 80, 20)]:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = r.size
		cs.shape = rs
		cs.position = r.position + r.size / 2
		wall.add_child(cs)
	add_child(wall)

func _draw() -> void:
	var back := PackedVector2Array([Vector2(L, TOP_Y - 40), Vector2(R, TOP_Y - 40), Vector2(R, FLOOR_Y), Vector2(L, FLOOR_Y)])
	var f_tl := Vector2(L - 32, TOP_Y - 70)
	var f_tr := Vector2(R + 32, TOP_Y - 70)
	var f_br := Vector2(R + 32, FLOOR_Y + 44)
	var f_bl := Vector2(L - 32, FLOOR_Y + 44)
	draw_colored_polygon(back, Color("f7f1ff"))
	draw_colored_polygon(PackedVector2Array([f_tl, back[0], back[3], f_bl]), Color("d9cff2"))
	draw_colored_polygon(PackedVector2Array([back[1], f_tr, f_br, back[2]]), Color("cfc3ea"))
	draw_colored_polygon(PackedVector2Array([back[3], back[2], f_br, f_bl]), Color("e8d8c0"))
	var danger := 0.0
	for h in get_tree().get_nodes_in_group("heads"):
		danger = maxf(danger, h.danger)
	var a := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 80.0) * clampf(danger / OVER_TIME, 0.0, 1.0)
	var line_col := Color(1, 0.4, 0.5, a).lerp(Color(1, 0.1, 0.1, 1), clampf(danger / OVER_TIME, 0.0, 1.0))
	draw_line(Vector2(L, TOP_Y), Vector2(R, TOP_Y), line_col, 2.0 + 2.0 * danger)
	for p in [[back[0], f_tl], [back[1], f_tr], [back[2], f_br], [back[3], f_bl]]:
		draw_line(p[0], p[1], Color("b3a5d6"), 2.0)
	for p in pops:
		var k: float = p["t"] / 0.3
		draw_arc(p["pos"], p["r"] * (1.0 + k * 0.6), 0, TAU, 32, Color(1, 0.55, 0.7, 1.0 - k), 4.0)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_R:
		_new_game()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if over:
			_new_game()
		elif cooldown <= 0.0:
			drop(e.position.x)

func drop(x: float) -> void:
	spawn(next_stage, Vector2(clampf(x, L + NodeDefs.radius(next_stage), R - NodeDefs.radius(next_stage)), DROP_Y))
	cooldown = DROP_COOLDOWN
	_roll_next()

func spawn(stage: int, pos: Vector2, vel: Vector2 = Vector2.ZERO) -> Head:
	var h := Head.new()
	h.setup(stage)
	h.position = pos
	h.linear_velocity = vel
	h.angular_velocity = randf_range(-1.5, 1.5)
	h.add_to_group("heads")
	h.touched.connect(_on_touched)
	add_child(h)
	return h

func _on_touched(a: Head, b: Node, speed: float) -> void:
	if b is Head:
		if a.stage == b.stage and not a.merging and not b.merging and a.get_instance_id() < b.get_instance_id():
			_merge.call_deferred(a, b)
		elif speed > 120.0:
			_play("contact", clampf(speed / 600.0, 0.15, 1.0))
			if speed > 300.0:
				a.squash()
	elif speed > 220.0:
		_play("land", clampf(speed / 700.0, 0.3, 1.0))
		a.squash()

func _merge(a: Head, b: Head) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b) or a.merging or b.merging or over:
		return
	a.merging = true
	b.merging = true
	var pos := (a.position + b.position) / 2.0
	var vel := (a.linear_velocity + b.linear_velocity) / 2.0
	var st := a.stage
	a.queue_free()
	b.queue_free()
	merges += 1
	combo = combo + 1 if combo_t > 0.0 else 1
	combo_t = 0.8
	var gain := (st + 1) * 2
	if st + 1 < NodeDefs.count():
		spawn(st + 1, pos, vel).pop_in()
	else:
		gain += 100
	score += gain * mini(combo, MAX_COMBO)
	pops.append({"pos": pos, "r": NodeDefs.radius(mini(st + 1, NodeDefs.count() - 1)), "t": 0.0})
	_play("chain" if combo >= 2 else "pop", 1.0)
	if score > best:
		best = score
		var cf := ConfigFile.new()
		cf.set_value("game", "best", best)
		cf.save(SAVE_PATH)
	_update_hud()

func _play(name: String, vol: float) -> void:
	var p := _players[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _players.size()
	p.stream = SFX[name]
	p.volume_db = linear_to_db(vol)
	p.play()

func _physics_process(dt: float) -> void:
	cooldown = maxf(cooldown - dt, 0.0)
	combo_t = maxf(combo_t - dt, 0.0)
	if over:
		return
	for h: Head in get_tree().get_nodes_in_group("heads"):
		if h.merging:
			continue
		var above := h.position.y - h.top_extent < TOP_Y
		if above and h.age > 1.2 and h.linear_velocity.length() < 40.0:
			h.danger += dt
		else:
			h.danger = 0.0
		if h.danger > OVER_TIME:
			over = true
			_over_label.text = "GAME OVER\n점수 %d\n클릭/R: 다시 시작" % score
			break

func _process(dt: float) -> void:
	_preview.position = Vector2(clampf(get_global_mouse_position().x, L + 20, R - 20), DROP_Y)
	_preview.visible = not over and cooldown <= 0.0
	for p in pops:
		p["t"] += dt
	pops = pops.filter(func(p): return p["t"] < 0.3)
	queue_redraw()

func _update_hud() -> void:
	_label.text = "점수 %d   최고 %d   다음: %s" % [score, best, NodeDefs.node_name(next_stage)]

## --shot: 자동 드롭 시뮬레이션 후 스크린샷/통계 출력
func _run_auto() -> void:
	for i in 60:
		if over:
			break
		drop(randf_range(L, R))
		_update_hud()
		await get_tree().create_timer(0.35).timeout
	await get_tree().create_timer(2.5).timeout
	_update_hud()
	var path := ProjectSettings.globalize_path("res://").path_join("shot.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path, " score=", score, " merges=", merges, " over=", over, " states=", Head.state_counts, " heads=", get_tree().get_nodes_in_group("heads").size())
	get_tree().quit()
