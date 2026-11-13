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
const SEP_INTERVAL := 0.15     # 끼임 감지 주기(초)
const SEP_MIN_DEPTH := 3.0     # 이보다 깊게 겹쳐 있으면 분리(px)
const SEP_STRENGTH := 0.6      # 한 번에 겹침 깊이의 이 비율만큼 분리
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
var held_stage := 0   # 지금 마우스를 따라다니며 드롭 대기 중인 노드
var next_stage := 0   # 진짜 NEXT: 이번 드롭 다음에 나올 노드
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
var _sep_t := 0.0
var separations := 0
var _muted := false
var _mute_btn: Button
var _vol_slider: HSlider
var _vol_label: Label
var _volume := 1.0

func _ready() -> void:
	_auto = "--shot" in OS.get_cmdline_user_args()
	var verify := "--verify" in OS.get_cmdline_user_args()
	_auto = _auto or verify   # 자체 테스트 모드
	_build_walls()
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_label = Label.new()
	_label.position = Vector2(10, 8)
	_label.add_theme_color_override("font_color", Color("4b3f72"))
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
	_build_audio_ui()
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		best = cf.get_value("game", "best", 0)
		_muted = cf.get_value("audio", "muted", false)
		_volume = clampf(float(cf.get_value("audio", "volume", 1.0)), 0.0, 1.0)
	# 자체 테스트(--shot/--verify)는 항상 무음 + 설정 파일 미저장
	_set_volume(_volume, false)
	_set_muted(true if _auto else _muted, false)
	_new_game()
	if verify:
		_run_verify()
	elif _auto:
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
	held_stage = _rnd_stage()
	next_stage = _rnd_stage()
	_show_held()

func _rnd_stage() -> int:
	return randi() % (NodeDefs.drop_max_index() + 1)   # 드롭은 1~5단계만, 이후는 합체로만

## 드롭 대기 프리뷰: 실제 노드와 같은 조명 쉐이더를 적용해 드롭 전후 밝기를 통일
func _show_held() -> void:
	var d := HeadShapes.get_data(held_stage)
	_preview.texture = d["tex"]
	_preview.offset = d["size"] / 2.0 - d["centroid"]
	_preview.scale = Vector2.ONE * d["scale"]
	_preview.material = HeadShapes.make_material(held_stage)
	_preview.modulate = Color.WHITE
	_panel.set_next(next_stage)

func _build_walls() -> void:
	var wall := StaticBody2D.new()
	var pm := PhysicsMaterial.new()
	pm.friction = 0.3
	pm.bounce = 0.03
	wall.physics_material_override = pm
	for r in [Rect2(L - 80, -400, 80, 1600), Rect2(R, -400, 80, 1600), Rect2(L - 80, FLOOR_Y, R - L + 160, 80)]:
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
	if e is InputEventKey and e.pressed and e.keycode == KEY_M:
		_set_muted(not _muted)
	elif e is InputEventKey and e.pressed and e.keycode == KEY_R:
		_new_game()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if over:
			_new_game()
		elif cooldown <= 0.0:
			drop(e.position.x)

func drop(x: float) -> void:
	var r := NodeDefs.radius(held_stage)
	spawn(held_stage, Vector2(clampf(x, L + r, R - r), DROP_Y))
	cooldown = DROP_COOLDOWN
	held_stage = next_stage
	next_stage = _rnd_stage()
	_show_held()

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
		_save_cfg()
	_update_hud()

func _set_muted(m: bool, save := true) -> void:
	_muted = m
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), m)
	_mute_btn.set_pressed_no_signal(m)
	_mute_btn.text = "소리 꺼짐 (M)" if m else "소리 켜짐 (M)"
	_vol_slider.editable = not m
	if save and not _auto:
		_save_cfg()

func _set_volume(v: float, save := true) -> void:
	_volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(maxf(_volume, 0.0001)))
	_vol_slider.set_value_no_signal(_volume)
	_vol_label.text = "볼륨 %d%%" % roundi(_volume * 100.0)
	if save and not _auto:
		_save_cfg()

## 우측 하단 사운드 UI: 음소거 토글 + 볼륨 슬라이더
func _build_audio_ui() -> void:
	var box := Panel.new()
	box.position = Vector2(480, 728)
	box.size = Vector2(230, 64)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffaff")
	sb.border_color = Color("c9bfe8")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	box.add_theme_stylebox_override("panel", sb)
	add_child(box)

	_mute_btn = Button.new()
	_mute_btn.toggle_mode = true
	_mute_btn.focus_mode = Control.FOCUS_NONE   # 스페이스/엔터로 눌리지 않게
	_mute_btn.position = Vector2(8, 6)
	_mute_btn.size = Vector2(120, 26)
	_mute_btn.add_theme_font_size_override("font_size", 13)
	_mute_btn.toggled.connect(func(on: bool): _set_muted(on))
	box.add_child(_mute_btn)

	_vol_label = Label.new()
	_vol_label.position = Vector2(136, 8)
	_vol_label.size = Vector2(88, 22)
	_vol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_vol_label.add_theme_font_size_override("font_size", 13)
	_vol_label.add_theme_color_override("font_color", Color("4b3f72"))
	box.add_child(_vol_label)

	_vol_slider = HSlider.new()
	_vol_slider.min_value = 0.0
	_vol_slider.max_value = 1.0
	_vol_slider.step = 0.01
	_vol_slider.focus_mode = Control.FOCUS_NONE
	_vol_slider.position = Vector2(10, 40)
	_vol_slider.size = Vector2(210, 16)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("e3d9f5")
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("b79bf0")
	fill.set_corner_radius_all(4)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	_vol_slider.add_theme_stylebox_override("slider", track)
	_vol_slider.add_theme_stylebox_override("grabber_area", fill)
	_vol_slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	_vol_slider.value_changed.connect(func(v: float): _set_volume(v, false))   # 실시간 반영
	_vol_slider.drag_ended.connect(func(_changed: bool): _save_cfg())          # 놓을 때 저장
	box.add_child(_vol_slider)

func _save_cfg() -> void:
	if _auto:
		return   # 테스트 실행이 사용자 최고점/설정을 덮어쓰지 않게
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("game", "best", best)
	cf.set_value("audio", "muted", _muted)
	cf.set_value("audio", "volume", _volume)
	cf.save(SAVE_PATH)

## 끼임 안전장치: 서로 콜라이더가 깊게 겹친 쌍을 찾아 겹친 깊이만큼 중심 반대 방향으로 위치를 보정하고 살짝 밀어 분리
func _separate_overlaps() -> void:
	var hs := get_tree().get_nodes_in_group("heads")
	for i in hs.size():
		var a: Head = hs[i]
		if a.merging:
			continue
		for j in range(i + 1, hs.size()):
			var b: Head = hs[j]
			if b.merging or a.stage == b.stage:   # 같은 단계는 합체로 처리
				continue
			var d := b.position - a.position
			if d.length() > (NodeDefs.radius(a.stage) + NodeDefs.radius(b.stage)) * 1.4:
				continue
			var inter := Geometry2D.intersect_polygons(a.world_collider(), b.world_collider())
			if inter.is_empty():
				continue
			var n := d.normalized() if d.length() > 0.01 else Vector2.UP
			var lo := INF
			var hi := -INF
			for p in inter[0]:
				var k := p.dot(n)
				lo = minf(lo, k)
				hi = maxf(hi, k)
			var depth := hi - lo
			if depth < SEP_MIN_DEPTH:
				continue
			var wa := b.mass / (a.mass + b.mass)
			a.shift(-n * depth * SEP_STRENGTH * wa)
			b.shift(n * depth * SEP_STRENGTH * (1.0 - wa))
			a.apply_central_impulse(-n * 40.0 * a.mass)   # 살짝 흔들어 분리
			b.apply_central_impulse(n * 40.0 * b.mass)
			separations += 1

func _play(name: String, vol: float) -> void:
	var p := _players[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _players.size()
	p.stream = SFX[name]
	p.volume_db = linear_to_db(vol)
	p.play()

func _physics_process(dt: float) -> void:
	_sep_t += dt
	if _sep_t >= SEP_INTERVAL:
		_sep_t = 0.0
		_separate_overlaps()
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
	_label.text = "점수 %d   최고 %d" % [score, best]

## --shot: 자동 드롭 시뮬레이션 후 스크린샷/통계 출력
func _run_auto() -> void:
	for i in 60:
		if over:
			break
		drop(randf_range(L, R))
		_update_hud()
		await get_tree().create_timer(0.35).timeout
	await get_tree().create_timer(4.0).timeout
	var early := _settle_stats()
	await get_tree().create_timer(4.0).timeout
	print("settle@4s ", early, " merges=", merges)
	_update_hud()
	var path := ProjectSettings.globalize_path("res://").path_join("shot.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path, " score=", score, " merges=", merges, " seps=", separations, " over=", over, " states=", Head.state_counts, " heads=", get_tree().get_nodes_in_group("heads").size(), " ", _settle_stats())
	get_tree().quit()

## 정착 후 속도 통계(미끄러짐/끼임 지터 지표): 정지해야 할 시점에 움직이는 노드 수
func _settle_stats() -> String:
	var moving := 0
	var vmax := 0.0
	var vsum := 0.0
	var hs := get_tree().get_nodes_in_group("heads")
	for h: Head in hs:
		var v := h.linear_velocity.length() + absf(h.angular_velocity) * 10.0
		vmax = maxf(vmax, v)
		vsum += v
		if v > 15.0:
			moving += 1
	return "settle(moving=%d/%d vmax=%.1f vavg=%.2f)" % [moving, hs.size(), vmax, vsum / maxi(hs.size(), 1)]

## --verify: 11단계 전부의 알파 외곽선 콜라이더 점검 + 전 단계 동시 낙하 시뮬레이션
func _run_verify() -> void:
	var ok := true
	for st in NodeDefs.count():
		var d := HeadShapes.get_data(st)
		var outline: PackedVector2Array = d["outline"]
		var pieces := Geometry2D.decompose_polygon_in_convex(outline)
		var eq := sqrt(float(d["area"]) / PI)
		var good: bool = outline.size() >= 8 and pieces.size() >= 1 and absf(eq - NodeDefs.radius(st)) < 1.0
		ok = ok and good
		print("stage %2d %-10s pts=%3d convex=%2d eq_r=%.1f (target %.0f) %s" % [st + 1, NodeDefs.node_name(st), outline.size(), pieces.size(), eq, NodeDefs.radius(st), "OK" if good else "FAIL"])
	# 단독 회전 테스트: 각 단계를 약간 기울여 바닥에 떨어뜨리고 정착 후 회전/이동이 멈추는지 확인
	var spin_ok := await _spin_test()
	ok = ok and spin_ok
	for st in NodeDefs.count():
		var r := NodeDefs.radius(st)
		spawn(st, Vector2(randf_range(L + r, R - r), DROP_Y - st * 5.0)).age = 0.0
		await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(4.0).timeout
	var outside := 0
	for h: Head in get_tree().get_nodes_in_group("heads"):
		if h.position.x < L - 10 or h.position.x > R + 10 or h.position.y > FLOOR_Y + 10:
			outside += 1
			print("  outside: stage ", h.stage + 1, " pos=", h.position)
	var path := ProjectSettings.globalize_path("res://").path_join("shot.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("drop-all: heads=", get_tree().get_nodes_in_group("heads").size(), " merges=", merges, " outside_box=", outside, " over=", over, " ", _settle_stats())
	print("VERIFY ", "PASS" if ok and outside == 0 else "FAIL")
	get_tree().quit()

func _spin_test() -> bool:
	var all_ok := true
	for st in NodeDefs.count():
		var h := spawn(st, Vector2((L + R) / 2.0, 400.0))
		h.rotation = 0.6
		h.angular_velocity = 0.0
		await get_tree().create_timer(4.0).timeout
		var w := absf(h.angular_velocity)
		var v := h.linear_velocity.length()
		var good := w < 0.3 and v < 8.0
		all_ok = all_ok and good
		print("spin  stage %2d %-8s w=%.3f v=%.2f rot=%.2f %s" % [st + 1, NodeDefs.node_name(st), w, v, h.rotation, "OK" if good else "FAIL"])
		h.queue_free()
		await get_tree().process_frame
	return all_ok
