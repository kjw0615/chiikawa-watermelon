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
const DROP_L := 54.0            # 드롭 x 범위(동굴 벽 굴곡 안쪽)
const DROP_R := 426.0
const WALL_THICK := 80.0
const SAVE_PATH := "user://best.cfg"

# 세이렌 동굴: 왼쪽 벽 윤곽(위->아래). 오른쪽은 x 기준 좌우 대칭. 모서리 데드존을 없애도록 하단을 둥글게 깎음.
const CAVE_LEFT := [
	Vector2(36, -300), Vector2(36, 100), Vector2(30, 200), Vector2(40, 320), Vector2(34, 440),
	Vector2(44, 560), Vector2(58, 640), Vector2(100, 690), Vector2(135, 700),
]

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
var items: ItemSystem
var _skill_bar: SkillBar
var last_play_x := 240.0   # 마우스가 마지막으로 있던 플레이 영역 x(명검 낙하 위치)
var _cave: PackedVector2Array   # 동굴 윤곽 폴리라인(왼쪽 위 -> 바닥 -> 오른쪽 위)

func _ready() -> void:
	_auto = "--shot" in OS.get_cmdline_user_args()
	var verify := "--verify" in OS.get_cmdline_user_args()
	_auto = _auto or verify   # 자체 테스트 모드
	_build_cave()
	_build_walls()
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_label = Label.new()
	_label.position = Vector2(10, 8)
	_label.add_theme_color_override("font_color", Color("f3eefc"))
	add_child(_label)
	_over_label = Label.new()
	_over_label.position = Vector2(L, 300)
	_over_label.size = Vector2(400, 100)
	_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_label.add_theme_font_size_override("font_size", 30)
	_over_label.add_theme_color_override("font_color", Color("f3eefc"))
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
	items = ItemSystem.new()
	items.main = self
	add_child(items)
	_skill_bar = SkillBar.new()
	_skill_bar.position = Vector2(480, 566)
	_skill_bar.size = Vector2(230, 150)
	add_child(_skill_bar)
	_skill_bar.setup(items)
	_skill_bar.use_requested.connect(func(id: String): items.use(id))
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
	items.reset()
	_over_label.text = ""
	_roll_next()
	_update_hud()

func _roll_next() -> void:
	held_stage = _rnd_stage()
	next_stage = _rnd_stage()
	_show_held()

## 교환권: NEXT 노드를 다른 1~5단계 노드로 바꿈
func reroll_next() -> void:
	var s := next_stage
	var tries := 0
	while s == next_stage and tries < 16:
		s = _rnd_stage()
		tries += 1
	next_stage = s
	_panel.set_next(next_stage)

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

## 동굴 윤곽(왼쪽 위 -> 왼쪽 바닥 -> 오른쪽 바닥 -> 오른쪽 위)
func _build_cave() -> void:
	var pts := PackedVector2Array()
	for p in CAVE_LEFT:
		pts.append(p)
	for i in range(CAVE_LEFT.size() - 1, -1, -1):
		pts.append(Vector2(L + R - CAVE_LEFT[i].x, CAVE_LEFT[i].y))
	_cave = pts

## 각 윤곽 선분을 바깥쪽으로 WALL_THICK 만큼 압출한 볼록 사각형 콜라이더(CCD 없이도 터널링 방지)
func _build_walls() -> void:
	var wall := StaticBody2D.new()
	var pm := PhysicsMaterial.new()
	pm.friction = 0.3
	pm.bounce = 0.03
	wall.physics_material_override = pm
	var center := Vector2((L + R) / 2.0, 300.0)
	for i in _cave.size() - 1:
		var p0 := _cave[i]
		var p1 := _cave[i + 1]
		var n := (p1 - p0).orthogonal().normalized()
		if n.dot((p0 + p1) / 2.0 - center) < 0.0:
			n = -n
		var cp := CollisionPolygon2D.new()
		cp.polygon = PackedVector2Array([p0, p1, p1 + n * WALL_THICK, p0 + n * WALL_THICK])
		wall.add_child(cp)
	add_child(wall)

func _draw() -> void:
	# 하늘색 테두리 없는 깨끗한 세이렌 동굴: 어두운 보랏빛 내부 + 바위 벽
	var top_y := 0.0
	var interior := PackedVector2Array()
	var cols := PackedColorArray()
	for p in _cave:
		if p.y < top_y:
			continue
		interior.append(p)
	interior.insert(0, Vector2(_cave[0].x, top_y))
	interior.append(Vector2(L + R - _cave[0].x, top_y))
	for p in interior:
		var k := clampf(p.y / FLOOR_Y, 0.0, 1.0)
		cols.append(Color("3a2f66").lerp(Color("211a42"), k))
	draw_polygon(interior, cols)
	var rock := Color("120e26")
	var left_rock := PackedVector2Array([Vector2(0, top_y), Vector2(_cave[0].x, top_y)])
	var right_rock := PackedVector2Array([Vector2(L + R, top_y)])
	for i in _cave.size():
		var p := _cave[i]
		if p.y < top_y:
			continue
		if i < CAVE_LEFT.size():
			left_rock.append(p)
		else:
			right_rock.append(p)
	left_rock.append(Vector2(0, FLOOR_Y + 100))
	right_rock = _reverse_tail(right_rock)
	right_rock.insert(1, Vector2(L + R - _cave[0].x, top_y))
	right_rock.append(Vector2(L + R, FLOOR_Y + 100))
	draw_colored_polygon(left_rock, rock)
	draw_colored_polygon(right_rock, rock)
	draw_rect(Rect2(0, FLOOR_Y, L + R, 120), rock)
	# 바위 윤곽의 은은한 하이라이트(하늘색 아님)
	draw_polyline(_cave, Color("5d4a9a"), 3.0)
	draw_polyline(_cave, Color("8a74d1", 0.35), 1.0)

	var danger := 0.0
	for h in get_tree().get_nodes_in_group("heads"):
		danger = maxf(danger, h.danger)
	var a := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 80.0) * clampf(danger / OVER_TIME, 0.0, 1.0)
	var line_col := Color(1, 0.4, 0.5, a).lerp(Color(1, 0.1, 0.1, 1), clampf(danger / OVER_TIME, 0.0, 1.0))
	draw_line(Vector2(L, TOP_Y), Vector2(R, TOP_Y), line_col, 2.0 + 2.0 * danger)
	for p in pops:
		var k: float = p["t"] / 0.3
		draw_arc(p["pos"], p["r"] * (1.0 + k * 0.6), 0, TAU, 32, Color(1, 0.55, 0.7, 1.0 - k), 4.0)

## right_rock 은 [첫점, 오른쪽 윤곽(바닥->위)...] 순서로 쌓였으므로 윤곽 부분만 위->아래 순으로 뒤집어 다각형 방향을 맞춤
func _reverse_tail(arr: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([arr[0]])
	for i in range(arr.size() - 1, 0, -1):
		out.append(arr[i])
	return out

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_M:
		_set_muted(not _muted)
	elif e is InputEventKey and e.pressed and e.keycode == KEY_R:
		_new_game()
	elif e is InputEventKey and e.pressed and e.keycode >= KEY_1 and e.keycode <= KEY_4:
		items.use_by_index(e.keycode - KEY_1)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if over:
			_new_game()
		elif cooldown <= 0.0:
			drop(e.position.x)

func drop(x: float) -> void:
	var r := NodeDefs.radius(held_stage)
	spawn(held_stage, Vector2(clampf(x, DROP_L + r, DROP_R - r), DROP_Y))
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
	items.add_gauge_for_stage(st + 1)
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
		if above and h.age > 1.2 and h.linear_velocity.length() < 40.0 and not items.suppress_over:
			h.danger += dt
		else:
			h.danger = 0.0
		if h.danger > OVER_TIME:
			over = true
			_over_label.text = "GAME OVER\n점수 %d\n클릭/R: 다시 시작" % score
			break

func _process(dt: float) -> void:
	var mx := get_global_mouse_position().x
	if mx > DROP_L and mx < DROP_R:
		last_play_x = mx
	_preview.position = Vector2(clampf(mx, DROP_L + 20, DROP_R - 20), DROP_Y)
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
		drop(randf_range(DROP_L, DROP_R))
		if "--items" in OS.get_cmdline_user_args() and i % 7 == 6:
			items.gauge = 100.0   # 아이템 스트레스: 더미가 쌓인 상태에서 아이템을 연속 사용
			items.use(["shake", "fountain", "swap", "sword"][(i / 7) % 4])
		_update_hud()
		await get_tree().create_timer(0.35).timeout
	await get_tree().create_timer(4.0).timeout
	var early := _settle_stats()
	await get_tree().create_timer(4.0).timeout
	print("settle@4s ", early, " merges=", merges)
	_update_hud()
	var path := ProjectSettings.globalize_path("res://").path_join("shot.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path, " score=", score, " merges=", merges, " seps=", separations, " over=", over, " states=", Head.state_counts, " heads=", get_tree().get_nodes_in_group("heads").size(), " outside=", _count_outside(), " ", _settle_stats())
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
	var item_ok := await _item_test()
	ok = ok and item_ok
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

func _count_outside() -> int:
	var n := 0
	for h: Head in get_tree().get_nodes_in_group("heads"):
		if h.position.x < L - 10 or h.position.x > R + 10 or h.position.y > FLOOR_Y + 10 or h.position.y < -150:
			n += 1
	return n

func _count_moving() -> int:
	var n := 0
	for h: Head in get_tree().get_nodes_in_group("heads"):
		if h.linear_velocity.length() + absf(h.angular_velocity) * 10.0 > 15.0:
			n += 1
	return n

## 아이템 4종 검증: 필드를 채운 뒤 각 아이템을 1회씩 사용하고 상자 이탈/정착을 확인
func _item_test() -> bool:
	_new_game()
	for i in 16:
		cooldown = 0.0
		drop(randf_range(DROP_L + 40.0, DROP_R - 40.0))
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(3.0).timeout
	var all_ok := true
	# 게이지 충전/차감 규칙
	items.reset()
	items.add_gauge_for_stage(2)
	items.add_gauge_for_stage(5)
	items.add_gauge_for_stage(9)
	var gauge_ok := is_equal_approx(items.gauge, 53.0)
	print("item gauge charge 8+15+30 = %.0f %s" % [items.gauge, "OK" if gauge_ok else "FAIL"])
	all_ok = all_ok and gauge_ok
	for id in ["swap", "shake", "fountain", "sword"]:
		items.gauge = 100.0
		var before := get_tree().get_nodes_in_group("heads").size()
		var prev_next := next_stage
		var heads := get_tree().get_nodes_in_group("heads")
		if id == "sword" and heads.size() > 0:
			last_play_x = (heads[randi() % heads.size()] as Head).position.x
		var used := items.use(id)
		var t := 0.0
		while items.busy and t < 8.0:
			await get_tree().create_timer(0.1).timeout
			t += 0.1
		await get_tree().create_timer(4.0).timeout
		var outside := _count_outside()
		var after := get_tree().get_nodes_in_group("heads").size()
		var moving := _count_moving()
		var extra := ""
		var good := used and outside == 0 and moving <= maxi(2, after / 6)
		if id == "swap":
			good = good and next_stage != prev_next and next_stage <= NodeDefs.drop_max_index() and is_equal_approx(items.gauge, 70.0)
			extra = " next %d->%d gauge=%.0f" % [prev_next + 1, next_stage + 1, items.gauge]
		elif id == "sword":
			var left := 0
			if items.last_sword_stage >= 0:
				for h: Head in get_tree().get_nodes_in_group("heads"):
					if h.stage == items.last_sword_stage:
						left += 1
				good = good and left == 0
			extra = " target_stage=%d heads %d->%d left_same=%d gauge=%.0f" % [items.last_sword_stage + 1, before, after, left, items.gauge]
		print("item %-8s used=%s outside=%d moving=%d/%d%s %s" % [id, used, outside, moving, after, extra, "OK" if good else "FAIL"])
		all_ok = all_ok and good
	# 게이지 부족 시 사용 불가 / 비용 차감
	items.gauge = 20.0
	var denied := not items.use("swap")
	print("item low-gauge deny=%s %s" % [denied, "OK" if denied else "FAIL"])
	all_ok = all_ok and denied
	return all_ok
