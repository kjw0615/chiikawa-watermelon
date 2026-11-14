extends Node2D
## 프로토타입: 원근 박스 + 클릭 드롭 + 같은 단계 합체/점수/게임오버/SFX.
## 합체 사다리: 11단계 노드(data/nodes.json), 마지막 단계끼리는 소멸 +100점. 드롭은 1~5단계만. 클릭 드롭, R 재시작.

const L := 24.0
const R := 460.0
const FLOOR_Y := 702.0   # 동굴 바닥 돌판 윗면(아트 기준)
const TOP_Y := 120.0
const DROP_Y := 60.0
const DROP_COOLDOWN := 0.45
const OVER_TIME := 2.0
const MAX_COMBO := 5
const SEP_INTERVAL := 0.15     # 끼임 감지 주기(초)
const SEP_MIN_DEPTH := 3.0     # 이보다 깊게 겹쳐 있으면 분리(px)
const SEP_STRENGTH := 0.6      # 한 번에 겹침 깊이의 이 비율만큼 분리
# 동굴 아트(cave_v1) 배치: 배경/전경 PNG(1024x1536)를 같은 스케일/위치로 겹침. 벽 콜라이더는 전경 알파에서 추출한 윤곽.
const ART_SCALE := 0.52
const ART_POS := Vector2(-18, 0)
const BG_ART := preload("res://assets/maps/cave_v1/background.png")
const FG_ART := preload("res://assets/maps/cave_v1/foreground.png")
const WALL_THICK := 80.0

# 세이렌 동굴 벽 윤곽(전경 알파에서 추출, 위->아래). 왼쪽/오른쪽은 비대칭.
const CAVE_LEFT := [
	Vector2(69.1, -300.0), Vector2(69.1, 0.0), Vector2(61.1, 25.0), Vector2(58.2, 49.9),
	Vector2(63.4, 74.9), Vector2(71.5, 99.8), Vector2(68.9, 124.8), Vector2(62.4, 149.8),
	Vector2(55.8, 174.7), Vector2(48.8, 199.7), Vector2(41.6, 224.6), Vector2(35.8, 249.6),
	Vector2(33.2, 274.6), Vector2(33.2, 299.5), Vector2(32.2, 324.5), Vector2(28.7, 349.4),
	Vector2(25.4, 374.4), Vector2(25.4, 399.4), Vector2(29.1, 424.3), Vector2(31.7, 449.3),
	Vector2(30.5, 474.2), Vector2(26.5, 499.2), Vector2(26.1, 524.2), Vector2(28.6, 549.1),
	Vector2(30.3, 574.1), Vector2(28.7, 599.0), Vector2(29.6, 624.0), Vector2(33.2, 649.0),
	Vector2(36.6, 655.2), Vector2(46.2, 681.2), Vector2(60.8, 702.0)
]
const CAVE_RIGHT := [
	Vector2(420.6, -300.0), Vector2(420.6, 0.0), Vector2(416.8, 25.0), Vector2(409.9, 49.9),
	Vector2(407.9, 74.9), Vector2(412.8, 99.8), Vector2(421.6, 124.8), Vector2(429.1, 149.8),
	Vector2(432.6, 174.7), Vector2(435.5, 199.7), Vector2(439.5, 224.6), Vector2(444.2, 249.6),
	Vector2(446.4, 274.6), Vector2(448.3, 299.5), Vector2(451.1, 324.5), Vector2(453.7, 349.4),
	Vector2(454.6, 374.4), Vector2(453.5, 399.4), Vector2(453.5, 424.3), Vector2(454.6, 449.3),
	Vector2(454.1, 474.2), Vector2(453.9, 499.2), Vector2(453.4, 524.2), Vector2(456.3, 549.1),
	Vector2(458.4, 574.1), Vector2(457.9, 599.0), Vector2(454.7, 624.0), Vector2(451.5, 649.0),
	Vector2(450.8, 655.2), Vector2(447.1, 681.2), Vector2(435.7, 702.0)
]

const SFX := {
	"contact": preload("res://audio/contact_soft.wav"),
	"land": preload("res://audio/land_squash.wav"),
	"pop": preload("res://audio/merge_pop.wav"),
	"chain": preload("res://audio/merge_chain.wav"),
	"item_shake": preload("res://audio/item_1.mp3"),   # 1번 우사기 엉덩이 흔들기
	"item_swap": preload("res://audio/item_2.mp3"),    # 2번 캐릭터 교체권
	"item_sword": preload("res://audio/item_3.mp3"),   # 3번 랏코 명검 투하
}

var score := 0
var over := false
var held_stage := 0   # 지금 마우스를 따라다니며 드롭 대기 중인 노드
var next_stage := 0   # 진짜 NEXT: 이번 드롭 다음에 나올 노드
var cooldown := 0.0
var combo := 0
var combo_t := 0.0
var merges := 0
var pops: Array = []
var _over_modal: Panel
var _over_score: Label
var _over_note: Label   # 게임오버 모달의 랭킹/신기록 안내 한 줄
var _dragging := false
var _drag_x := 0.0
var _pause_menu: PauseMenu
var _auth_modal: AuthModal
var _rank_modal: RankModal
var _help_modal: HelpModal
var _settings_modal: SettingsModal
var _confirm_modal: StartConfirmModal
var _reset_modal: ResetModal
var _record_note := ""   # 게임오버 모달에 붙는 신기록/제출 결과 문구
var _over_restart: Button
var _over_quit: Button
var _panel: SidePanel
var _preview: Sprite2D
var _players: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _synth := {}   # 코드로 합성한 효과음(음식 분수)
var _auto := false
var _sep_t := 0.0
var separations := 0
var items: ItemSystem
var _skill_bar: SkillBar
var last_play_x := 240.0   # 마우스가 마지막으로 있던 플레이 영역 x(명검 낙하 위치)
var drop_l := 60.0    # 드롭선(y=DROP_Y) 높이에서의 벽 안쪽 x 범위(윤곽에서 계산)
var drop_r := 410.0
enum State { TITLE, PLAYING }
var state := State.TITLE
var _title: TitleScreen
var _credit: Label   # 게임 화면 구석의 면책 문구
var _art_bg: Sprite2D
var _art_fg: Sprite2D
var _cave: PackedVector2Array   # 동굴 윤곽 폴리라인(왼쪽 위 -> 바닥 -> 오른쪽 위)

func _ready() -> void:
	_auto = "--shot" in OS.get_cmdline_user_args()
	var verify := "--verify" in OS.get_cmdline_user_args()
	var title_test := "--title-test" in OS.get_cmdline_user_args()
	var text_audit := "--text-audit" in OS.get_cmdline_user_args()
	var net_test := "--net-test" in OS.get_cmdline_user_args()
	_auto = _auto or verify or title_test or text_audit or net_test   # 자체 테스트 모드
	_build_cave()
	_build_walls()
	_art_bg = _make_art(BG_ART, -100)
	_art_fg = _make_art(FG_ART, -50)   # 노드가 돌판/바위에 가려지지 않도록 노드(z=0) 뒤, 배경(-100) 앞
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = Audio.BUS_SFX   # 모든 효과음은 SFX 버스
		add_child(p)
		_players.append(p)
	_build_over_modal()
	_panel = SidePanel.new()
	_panel.position = Vector2(520, 16)
	_panel.size = Vector2(264, 768)
	_panel.z_index = 40
	add_child(_panel)
	_preview = Sprite2D.new()
	_preview.z_index = 20
	add_child(_preview)
	items = ItemSystem.new()
	items.main = self
	add_child(items)
	_skill_bar = SkillBar.new()
	_skill_bar.position = Vector2(532, 568)
	_skill_bar.size = Vector2(240, 190)
	_skill_bar.z_index = 41
	add_child(_skill_bar)
	_skill_bar.setup(items)
	_skill_bar.use_requested.connect(func(id: String): items.use(id))
	_synth["fountain"] = SfxSynth.fountain()
	_build_credit()
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_pause_menu.home_requested.connect(_go_title)
	_settings_modal = SettingsModal.new()
	_auth_modal = AuthModal.new()
	_reset_modal = ResetModal.new()   # 로그인 팝업 위에 열린다
	_rank_modal = RankModal.new()
	_confirm_modal = StartConfirmModal.new()
	_help_modal = HelpModal.new()   # 마지막에 만들어 다른 모달 위에 겹쳐 열린다
	for m: UiModal in [_settings_modal, _auth_modal, _reset_modal, _rank_modal, _confirm_modal, _help_modal]:
		add_child(m)
		m.closed.connect(_sync_title_block)
	_auth_modal.forgot_requested.connect(func(): _reset_modal.open(); _sync_title_block())
	_settings_modal.help_requested.connect(func(): _help_modal.open())
	_confirm_modal.start_chosen.connect(_start_game)
	_confirm_modal.login_chosen.connect(func(): _auth_modal.open(); _sync_title_block())
	_panel.help_pressed.connect(_open_help)
	Supabase.auth_changed.connect(_update_hud)
	_new_game()
	if _auto and not title_test and not text_audit and not net_test:
		_set_state(State.PLAYING)   # 자체 테스트는 타이틀을 건너뜀
	else:
		_make_title()
		_set_state(State.TITLE)
		Supabase.auto_login()   # 저장된 토큰이 있으면 조용히 자동 로그인(실패해도 게임은 그대로)
	if net_test:
		_run_net_test()
	elif text_audit:
		_run_text_audit()
	elif title_test:
		_run_title_test()
	elif verify:
		_run_verify()
	elif _auto:
		_run_auto()

func _build_credit() -> void:
	_credit = Label.new()
	_credit.clip_text = true   # 글자가 많아도 칸이 늘어나지 않게(넘침은 --text-audit 로 점검)
	_credit.text = TitleScreen.DISCLAIMER_KO + "\n" + TitleScreen.DISCLAIMER_EN
	_credit.position = Vector2(6, 764)
	_credit.size = Vector2(468, 34)
	_credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_credit.add_theme_font_size_override("font_size", 9)
	_credit.add_theme_color_override("font_color", UIPalette.CREAM)
	_credit.add_theme_color_override("font_outline_color", UIPalette.TEXT)
	_credit.add_theme_constant_override("outline_size", 3)
	_credit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_credit.z_index = 45
	add_child(_credit)

## 상태 머신: TITLE(타이틀 화면) -> PLAYING(게임)
func _set_state(st: State) -> void:
	state = st
	var playing := st == State.PLAYING
	for n in [_panel, _skill_bar, _credit]:
		n.visible = playing
	if not playing:
		_over_modal.visible = false
	_preview.visible = false

func _make_title() -> void:
	_title = TitleScreen.new()
	_title.size = Vector2(800, 800)
	add_child(_title)
	_title.start_pressed.connect(_on_start_pressed)
	_title.rank_pressed.connect(func(): _rank_modal.open(); _sync_title_block())
	_title.login_pressed.connect(func(): _auth_modal.open(); _sync_title_block())
	_title.settings_pressed.connect(func(): _settings_modal.open(); _sync_title_block())

func _sync_title_block() -> void:
	if _title != null:
		_title.blocked = _auth_modal.is_open() or _rank_modal.is_open() or _settings_modal.is_open() or _confirm_modal.is_open() or _help_modal.is_open() or _reset_modal.is_open()

## 게임 중/게임오버/일시정지에서 메인(타이틀) 화면으로 복귀
func _go_title() -> void:
	if _pause_menu.is_open():
		_pause_menu.resume()
	get_tree().paused = false
	_dragging = false
	items.cancel_aim(false)
	Audio.stop_bgm()
	_set_state(State.TITLE)
	_new_game()
	if _title == null:
		_make_title()

## '게임 시작': 로그인 상태면 바로 시작, 비로그인이면 확인 팝업(시작하기 / 로그인하기)
func _on_start_pressed() -> void:
	if state != State.TITLE or _title == null or _title.blocked:
		return
	if Supabase.signed_in:
		_start_game()   # 로그인 상태: 경고 없이 바로 시작
	else:
		_confirm_modal.open()   # 비로그인: 기록이 저장되지 않는다는 안내 팝업
		_sync_title_block()

func _open_help() -> void:
	if state == State.PLAYING and not over and not items.aiming and not _pause_menu.is_open():
		_help_modal.open()

func _start_game() -> void:
	if state != State.TITLE:
		return
	if _title != null:
		_title.queue_free()
		_title = null
	_set_state(State.PLAYING)
	_new_game()
	Audio.play_bgm()

func _new_game() -> void:
	_dragging = false
	for h in get_tree().get_nodes_in_group("heads"):
		h.queue_free()
	score = 0
	over = false
	cooldown = 0.0
	combo = 0
	merges = 0
	items.reset()
	_over_modal.visible = false
	_over_note.text = ""
	_roll_next()
	_update_hud()

func _roll_next() -> void:
	held_stage = _rnd_stage()
	next_stage = _rnd_stage()
	_show_held()

## 캐릭터 교체권: 지금 손에 쥔(드롭 대기 중인) 노드를 다른 1~5단계 노드로 바꿈
func reroll_held() -> void:
	var s := held_stage
	var tries := 0
	while s == held_stage and tries < 16:
		s = _rnd_stage()
		tries += 1
	held_stage = s
	_show_held()
	_preview.scale = Vector2.ONE * HeadShapes.get_data(held_stage)["scale"] * 1.25   # 뿅 하고 바뀌는 팝
	create_tween().tween_property(_preview, "scale", Vector2.ONE * HeadShapes.get_data(held_stage)["scale"], 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
func _make_art(tex: Texture2D, z: int) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.position = ART_POS
	sp.scale = Vector2.ONE * ART_SCALE
	sp.z_index = z
	add_child(sp)
	return sp

func _build_cave() -> void:
	var pts := PackedVector2Array()
	for p in CAVE_LEFT:
		pts.append(p)
	for i in range(CAVE_RIGHT.size() - 1, -1, -1):
		pts.append(CAVE_RIGHT[i])
	_cave = pts
	# 드롭 높이(노드가 떨어지는 구간)에서 가장 좁은 안쪽 폭 기준으로 드롭 x 범위 결정
	drop_l = 0.0
	drop_r = 1.0e6
	for y in range(int(DROP_Y) - 30, int(DROP_Y) + 90, 10):
		drop_l = maxf(drop_l, _wall_x(CAVE_LEFT, float(y)))
		drop_r = minf(drop_r, _wall_x(CAVE_RIGHT, float(y)))
	drop_l += 4.0
	drop_r -= 4.0

## 윤곽 폴리라인(위->아래)에서 높이 y 의 벽 x 를 선형 보간
func _wall_x(line: Array, y: float) -> float:
	for i in line.size() - 1:
		var a: Vector2 = line[i]
		var b: Vector2 = line[i + 1]
		if y >= a.y and y <= b.y and b.y > a.y:
			return lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
	return line[line.size() - 1].x

## 각 윤곽 선분을 바깥쪽으로 WALL_THICK 만큼 압출한 볼록 사각형 콜라이더(CCD 없이도 터널링 방지)
func _build_walls() -> void:
	var wall := StaticBody2D.new()
	var pm := PhysicsMaterial.new()
	pm.friction = 0.3
	pm.bounce = 0.03
	wall.physics_material_override = pm
	var center := Vector2((L + R) / 2.0, 400.0)
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
	# 배경/전경 아트는 Sprite2D(_art_bg/_art_fg)로 그리고, 여기서는 게임오버 선과 합체 이펙트만 그린다.
	var danger := 0.0
	for h in get_tree().get_nodes_in_group("heads"):
		danger = maxf(danger, h.danger)
	var a := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 80.0) * clampf(danger / OVER_TIME, 0.0, 1.0)
	var line_col := Color(1, 0.45, 0.6, a).lerp(Color(1, 0.1, 0.1, 1), clampf(danger / OVER_TIME, 0.0, 1.0))
	draw_line(Vector2(_wall_x(CAVE_LEFT, TOP_Y), TOP_Y), Vector2(_wall_x(CAVE_RIGHT, TOP_Y), TOP_Y), line_col, 2.0 + 2.0 * danger)
	for p in pops:
		var k: float = p["t"] / 0.3
		draw_arc(p["pos"], p["r"] * (1.0 + k * 0.6), 0, TAU, 32, Color(1, 0.55, 0.7, 1.0 - k), 4.0)

## 드래그 조준 & 릴리즈 드롭: 눌렀을 때(UI가 소비하지 않은 입력)만 시작, 이동/뗌은 UI 위에서도 받도록 _input 에서 처리
func _input(e: InputEvent) -> void:
	if not _dragging:
		return
	if e is InputEventMouseMotion:
		_drag_x = e.position.x
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		_dragging = false
		_drag_x = e.position.x
		if state == State.PLAYING and not over and not items.aiming and cooldown <= 0.0:
			drop(_drag_x)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		if items.aiming:
			items.cancel_aim()   # 조준 중 ESC 는 취소(환불)
		elif state == State.PLAYING and not over:
			_pause_menu.open()   # 인게임 ESC: 일시정지 메뉴
		else:
			get_tree().quit()    # 타이틀/게임오버에서는 ESC 로 종료
		return
	if state != State.PLAYING:
		return
	elif e is InputEventKey and e.pressed and e.keycode == KEY_R:
		_new_game()
	elif e is InputEventKey and e.pressed and e.keycode >= KEY_1 and e.keycode <= KEY_4:
		items.use_by_index(e.keycode - KEY_1)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
		items.cancel_aim()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if items.aiming:
			items.confirm_aim(e.position.x)
		elif over:
			pass   # 게임오버 팝업의 버튼으로만 진행
		elif cooldown <= 0.0:
			_dragging = true   # 드래그 조준: 누르고 있는 동안 노드가 따라다니고, 떼는 순간 낙하
			_drag_x = e.position.x

func drop(x: float) -> void:
	var r := NodeDefs.radius(held_stage)
	spawn(held_stage, Vector2(clampf(x, drop_l + r, drop_r - r), DROP_Y))
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
		if a.stage == b.stage and not a.merging and not b.merging:
			# 어느 쪽 이벤트가 먼저 와도 합체(접촉 슬롯이 찬 노드는 한쪽 이벤트만 올 수 있음). (작은 id, 큰 id)로 정규화하고 _merge 의 merging 가드로 1회만 처리
			if a.get_instance_id() < b.get_instance_id():
				_merge.call_deferred(a, b)
			else:
				_merge.call_deferred(b, a)
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
	_update_hud()

## 게임오버 팝업: 다시하기 / 종료하기
func _build_over_modal() -> void:
	_over_modal = Panel.new()
	_over_modal.size = Vector2(300, 220)
	_over_modal.position = Vector2((drop_l + drop_r) / 2.0 - 150.0, 250)
	_over_modal.z_index = 60
	_over_modal.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIPalette.CREAM
	sb.border_color = UIPalette.BORDER
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(22)
	sb.shadow_color = UIPalette.SHADOW
	sb.shadow_size = 16
	_over_modal.add_theme_stylebox_override("panel", sb)
	add_child(_over_modal)
	var t := Label.new()
	t.clip_text = true   # 글자가 많아도 칸이 늘어나지 않게(넘침은 --text-audit 로 점검)
	t.text = "GAME OVER"
	t.position = Vector2(0, 20)
	t.size = Vector2(300, 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", UIPalette.title_font())
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", UIPalette.TEXT)
	_over_modal.add_child(t)
	_over_score = Label.new()
	_over_score.clip_text = true   # 글자가 많아도 칸이 늘어나지 않게(넘침은 --text-audit 로 점검)
	_over_score.position = Vector2(0, 70)
	_over_score.size = Vector2(300, 32)
	_over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_score.add_theme_font_size_override("font_size", 24)
	_over_score.add_theme_color_override("font_color", UIPalette.TEXT)
	_over_modal.add_child(_over_score)
	_over_note = UiModal.make_label("", Vector2(8, 102), Vector2(284, 22), 13, UIPalette.BLUE_INK, true)
	_over_modal.add_child(_over_note)
	_over_restart = _modal_button("다시하기", Vector2(24, 130), [UIPalette.PINK, UIPalette.PINK_HOVER, UIPalette.PINK_PRESSED])
	_over_restart.pressed.connect(_new_game)
	_over_modal.add_child(_over_restart)
	_over_quit = _modal_button("메인으로", Vector2(158, 130), UIPalette.QUIT_BG)
	_over_quit.pressed.connect(_go_title)
	_over_modal.add_child(_over_quit)

func _modal_button(text: String, pos: Vector2, states: Array) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(118, 54)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UIPalette.button_font())
	b.add_theme_font_size_override("font_size", 22)
	UIPalette.style_button(b, states)
	return b

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

## 아이템 효과음: 모두 SFX 버스(_players)로 재생
func play_item_sound(id: String) -> void:
	_play("item_" + id if SFX.has("item_" + id) else id, 1.0)

func _play(name: String, vol: float) -> void:
	var p := _players[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _players.size()
	p.stream = SFX[name] if SFX.has(name) else _synth[name]
	p.volume_db = linear_to_db(vol)
	p.play()

func _physics_process(dt: float) -> void:
	if state != State.PLAYING:
		return
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
			_over_score.text = "점수 %d" % score
			_over_modal.visible = true
			_on_game_over()
			break

func _process(dt: float) -> void:
	var mx := _drag_x if _dragging else get_global_mouse_position().x
	if mx > drop_l and mx < drop_r:
		last_play_x = mx
	_preview.position = Vector2(clampf(mx, drop_l + 20, drop_r - 20), DROP_Y)
	items.aim_move(mx)
	_preview.visible = state == State.PLAYING and not over and cooldown <= 0.0 and not items.aiming
	for p in pops:
		p["t"] += dt
	pops = pops.filter(func(p): return p["t"] < 0.3)
	queue_redraw()

func _update_hud() -> void:
	_panel.set_score(score)
	# BEST: 로그인하면 서버 최고점(현재 점수가 넘으면 실시간으로 현재 점수), 비로그인이면 곧 현재 점수(로컬 저장 없음)
	_panel.set_best(maxi(Supabase.server_best, score) if Supabase.signed_in else score)

## 게임오버: 로그인 상태면 서버에 제출(서버가 신기록일 때만 반영). 로컬 최고점 저장은 하지 않는다
func _on_game_over() -> void:
	_over_note.text = ""
	if not Supabase.signed_in:
		_over_note.text = "로그인하면 랭킹에 올라가요" if Supabase.enabled else ""
		return
	var final := score
	var r: Dictionary = await Supabase.record_score(final)
	if not over or score != final:
		return   # 그 사이에 다시 시작했으면 문구를 덮어쓰지 않음
	if r["ok"]:
		_over_note.text = "신기록! 랭킹에 반영됐어요" if final >= Supabase.server_best else "내 최고 기록 %d" % Supabase.server_best
	else:
		_over_note.text = "랭킹 전송에 실패했어요"
	_update_hud()

## --shot: 자동 드롭 시뮬레이션 후 스크린샷/통계 출력
func _run_auto() -> void:
	for i in 60:
		if over:
			break
		drop(randf_range(drop_l, drop_r))
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
	_save_shot(path)
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
	_save_shot(path)
	print("drop-all: heads=", get_tree().get_nodes_in_group("heads").size(), " merges=", merges, " outside_box=", outside, " over=", over, " ", _settle_stats())
	var val_ok := _auth_validator_test()
	print("VERIFY ", "PASS" if ok and outside == 0 and val_ok else "FAIL")
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
		drop(randf_range(drop_l + 40.0, drop_r - 40.0))
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(3.0).timeout
	var all_ok := true
	# 게이지 충전/차감 규칙
	items.reset()
	items.add_gauge_for_stage(2)
	items.add_gauge_for_stage(5)
	items.add_gauge_for_stage(9)
	var gauge_ok := is_equal_approx(items.gauge, 25.0)
	print("item gauge charge 5+5+15 = %.0f %s" % [items.gauge, "OK" if gauge_ok else "FAIL"])
	all_ok = all_ok and gauge_ok
	for id in ["swap", "shake", "fountain", "sword"]:
		items.gauge = 100.0
		var before := get_tree().get_nodes_in_group("heads").size()
		var prev_next := next_stage
		var prev_held := held_stage
		var heads := get_tree().get_nodes_in_group("heads")
		if id == "sword" and heads.size() > 0:
			last_play_x = (heads[randi() % heads.size()] as Head).position.x
		var used := items.use(id)
		if id == "sword":
			var aim_ok := items.aiming
			items.confirm_aim(last_play_x)
			print("sword aim mode entered/confirmed %s" % ["OK" if aim_ok else "FAIL"])
			all_ok = all_ok and aim_ok
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
			good = good and held_stage != prev_held and held_stage <= NodeDefs.drop_max_index() and next_stage == prev_next and is_equal_approx(items.gauge, 70.0)
			extra = " held %d->%d (next %d->%d) gauge=%.0f" % [prev_held + 1, held_stage + 1, prev_next + 1, next_stage + 1, items.gauge]
		elif id == "fountain":
			good = good and items.fountain_peak_y < 420.0 and items.fountain_peak_y > 120.0
			extra = " peak_y=%.0f (target ~350-400)" % items.fountain_peak_y
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
	# 대형 노드(8~11단계) 분수 테스트
	for h in get_tree().get_nodes_in_group("heads"):
		h.queue_free()
	await get_tree().process_frame
	for sp in [[7, 200.0], [9, 330.0], [8, 265.0]]:
		spawn(sp[0], Vector2(sp[1], 640.0))
	await get_tree().create_timer(2.5).timeout
	items.gauge = 100.0
	items.use("fountain")
	while items.busy:
		await get_tree().create_timer(0.1).timeout
	var big_ok := items.fountain_big_rise >= 100.0 and _count_outside() == 0
	print("fountain big nodes (stage 8,9,10) max rise=%.0f outside=%d %s" % [items.fountain_big_rise, _count_outside(), "OK" if big_ok else "FAIL"])
	all_ok = all_ok and big_ok
	await get_tree().create_timer(2.0).timeout
	# 명검 조준 취소 시 환불
	items.gauge = 100.0
	items.use("sword")
	items.cancel_aim()
	var cancel_ok := not items.aiming and not items.busy and is_equal_approx(items.gauge, 100.0)
	print("sword aim cancel refund gauge=%.0f %s" % [items.gauge, "OK" if cancel_ok else "FAIL"])
	all_ok = all_ok and cancel_ok
	# 게이지 부족 시 사용 불가 / 비용 차감
	items.gauge = 20.0
	var denied := not items.use("swap")
	print("item low-gauge deny=%s %s" % [denied, "OK" if denied else "FAIL"])
	all_ok = all_ok and denied
	return all_ok

## 스크린샷 저장(--headless 에서는 렌더링이 없어 건너뜀). 자체 테스트는 창을 띄우지 않도록 항상 --headless 로 실행한다.
func _save_shot(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png(path)

## --title-test: 타이틀 -> 게임 시작 상태 전환 검증(창 없이 --headless 로 실행)
func _run_title_test() -> void:
	await get_tree().create_timer(0.4).timeout
	var ok := true
	var title_ok := state == State.TITLE and _title != null and not _panel.visible
	title_ok = title_ok and _title.start_button.text == "게임 시작" and TitleScreen.TITLE_KO == "먼작귀 데굴데굴 섬"
	print("title shown: state=TITLE ui_hidden=%s %s" % [not _panel.visible, "OK" if title_ok else "FAIL"])
	ok = ok and title_ok
	_unhandled_input_blocked_check()
	var art_right := ART_POS.x + BG_ART.get_width() * ART_SCALE
	var lay_ok := _panel.position.x >= art_right + 4.0 and _skill_bar.position.x >= _panel.position.x and _panel.position.x + _panel.size.x <= 800.0
	print("sidebar x=%.0f art_right=%.0f no_overlap %s" % [_panel.position.x, art_right, "OK" if lay_ok else "FAIL"])
	ok = ok and lay_ok
	var bgm_title_off := not Audio.bgm_on   # 타이틀에서는 BGM 꺼짐
	_test_press_start()
	await get_tree().create_timer(0.3).timeout
	var play_ok := state == State.PLAYING and _title == null and _panel.visible and _credit.visible and _credit.text.contains("비영리 팬 메이드") and _credit.text.contains("Nagano / Chiikawa Committee")
	print("start pressed: state=PLAYING ui_visible=%s credit=%s %s" % [_panel.visible, _credit.visible, "OK" if play_ok else "FAIL"])
	play_ok = play_ok and Audio.bgm_on and bgm_title_off   # 게임 시작하면 BGM 켜짐
	print("bgm: title off=%s, in-game on=%s" % [bgm_title_off, Audio.bgm_on])
	ok = ok and play_ok
	# ESC 일시정지 메뉴: 열면 트리 정지 + 드롭 차단, 닫으면 재개
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	_unhandled_input(esc)
	var pause_ok := _pause_menu.is_open() and get_tree().paused
	_pause_menu._unhandled_input(esc)   # 다시 ESC -> 계속하기
	pause_ok = pause_ok and not _pause_menu.is_open() and not get_tree().paused
	print("pause menu open/ESC-close %s" % ["OK" if pause_ok else "FAIL"])
	ok = ok and pause_ok
	# 드래그 조준: 누르는 동안은 낙하하지 않고, 떼는 순간 그 x에서 낙하
	cooldown = 0.0
	var pr := InputEventMouseButton.new()
	pr.button_index = MOUSE_BUTTON_LEFT
	pr.pressed = true
	pr.position = Vector2(200, 300)
	_unhandled_input(pr)
	var mv := InputEventMouseMotion.new()
	mv.position = Vector2(260, 310)
	_input(mv)
	await get_tree().create_timer(0.1).timeout
	var held_ok := get_tree().get_nodes_in_group("heads").size() == 0 and _dragging and is_equal_approx(_preview.position.x, 260.0)
	var rl := InputEventMouseButton.new()
	rl.button_index = MOUSE_BUTTON_LEFT
	rl.pressed = false
	rl.position = Vector2(270, 310)
	_input(rl)
	await get_tree().create_timer(0.3).timeout
	var hs := get_tree().get_nodes_in_group("heads")
	var rel_ok: bool = held_ok and hs.size() == 1 and not _dragging and absf((hs[0] as Head).position.x - 270.0) < 20.0
	print("drag aim: no drop while pressed + follows, drops on release at x=270 (heads=%d) %s" % [hs.size(), "OK" if rel_ok else "FAIL"])
	ok = ok and rel_ok
	var drop_ok := get_tree().get_nodes_in_group("heads").size() == 1
	print("drop after start: heads=%d %s" % [get_tree().get_nodes_in_group("heads").size(), "OK" if drop_ok else "FAIL"])
	ok = ok and drop_ok
	# 메인 복귀: 게임오버 모달의 '메인으로' / 일시정지의 '메인으로' -> 타이틀 상태, 다시 시작 가능
	_over_modal.visible = true
	_over_quit.pressed.emit()
	await get_tree().create_timer(0.2).timeout
	var home_ok := state == State.TITLE and _title != null and not _panel.visible and not _over_modal.visible and not get_tree().paused and not Audio.bgm_on
	_test_press_start()
	await get_tree().create_timer(0.2).timeout
	_pause_menu.open()
	_pause_menu.quit_button.pressed.emit()
	await get_tree().create_timer(0.2).timeout
	home_ok = home_ok and state == State.TITLE and _title != null and not _pause_menu.is_open() and not get_tree().paused
	print("back to title (over modal, pause menu): %s" % ["OK" if home_ok else "FAIL"])
	ok = ok and home_ok
	# 시작 버튼: 비로그인이면 확인 팝업(시작하기/로그인하기), 로그인이면 즉시 시작
	_title.start_button.pressed.emit()
	var c1 := _confirm_modal.is_open() and state == State.TITLE and _title.blocked
	_confirm_modal.login_button.pressed.emit()
	var c2 := not _confirm_modal.is_open() and _auth_modal.is_open() and state == State.TITLE
	_auth_modal.close()
	_title.start_button.pressed.emit()
	_confirm_modal.start_button.pressed.emit()
	await get_tree().create_timer(0.1).timeout
	var c3 := state == State.PLAYING
	_go_title()
	Supabase.signed_in = true
	_title.start_button.pressed.emit()
	var c4 := state == State.PLAYING and not _confirm_modal.is_open()
	Supabase.signed_in = false
	_go_title()
	var confirm_ok := c1 and c2 and c3 and c4
	print("start confirm (guest popup %s, login btn %s, guest start %s, signed-in direct %s) %s" % [c1, c2, c3, c4, "OK" if confirm_ok else "FAIL"])
	ok = ok and confirm_ok
	# 오디오: BGM/SFX 버스 분리, BGM 루프 스트림, 설정 모달
	var bgm_i := AudioServer.get_bus_index("BGM")
	var sfx_i := AudioServer.get_bus_index("SFX")
	Audio.set_bgm_volume(0.25, false)
	Audio.set_sfx_volume(0.5, false)
	Audio.set_sfx_volume(0.8, false)
	var audio_ok := bgm_i > 0 and sfx_i > 0 and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bgm_i)), 0.25) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(sfx_i)), 0.8)
	Audio.set_bgm_muted(true, false)
	audio_ok = audio_ok and AudioServer.is_bus_mute(bgm_i) and not AudioServer.is_bus_mute(sfx_i)
	Audio.set_bgm_muted(false, false)
	var stream := Audio._bgm.stream as AudioStreamMP3
	audio_ok = audio_ok and stream != null and stream.loop and Audio._bgm.bus == "BGM" and _players[0].bus == "SFX" and Audio.silent
	_settings_modal.open()
	audio_ok = audio_ok and _settings_modal.is_open()
	_settings_modal.close()
	print("audio buses (BGM/SFX split, bgm loop stream, test silent) %s" % ["OK" if audio_ok else "FAIL"])
	ok = ok and audio_ok
	# 아이템 효과음(1~3번 mp3 + 4번 합성), BEST 규칙, 사이드바 별 글리프 제거, 비밀번호 칸 필터/눈 토글
	var snd_ok := SFX.has("item_shake") and SFX.has("item_swap") and SFX.has("item_sword") and _synth.has("fountain")
	snd_ok = snd_ok and (_synth["fountain"] as AudioStreamWAV).get_length() > 2.8 and (_synth["fountain"] as AudioStreamWAV).data.size() > 100000
	for id in ["shake", "swap", "sword", "fountain"]:
		play_item_sound(id)
		snd_ok = snd_ok and _players[(_sfx_i + _players.size() - 1) % _players.size()].stream != null and _players[(_sfx_i + _players.size() - 1) % _players.size()].bus == "SFX"
	score = 500
	_update_hud()
	var guest_best: String = _panel._best_label.text
	Supabase.signed_in = true
	Supabase.server_best = 900
	_update_hud()
	var login_best: String = _panel._best_label.text
	score = 1200
	_update_hud()
	var live_best: String = _panel._best_label.text
	Supabase.signed_in = false
	Supabase.server_best = 0
	score = 0
	_update_hud()
	var best_ok := guest_best == "500" and login_best == "900" and live_best == "1200" and _panel._best_label.get_theme_font_size("font_size") == _panel._score_label.get_theme_font_size("font_size") and _panel._score_label.get_theme_font_size("font_size") == 36
	var star := false
	for root in [_panel, _skill_bar]:
		var st: Array = [root]
		while not st.is_empty():
			var c: Node = st.pop_back()
			st.append_array(c.get_children())
			if (c is Label or c is Button) and (c.text.contains("★") or c.text.contains("?") and c is Button):
				star = true
	_skill_bar._items.gauge = 100.0
	_skill_bar.refresh()
	star = star or _skill_bar._gauge_label.text.contains("★")
	var pw_edit := _auth_modal._fields["pw"]["edit"] as LineEdit
	pw_edit.text = "ab한글12 !"
	_auth_modal._filter_password(pw_edit, pw_edit.text)
	var eye := _auth_modal._fields["pw"]["eye"] as Button
	var was_secret := pw_edit.secret
	eye.pressed.emit()
	var shown := not pw_edit.secret
	eye.pressed.emit()
	var pw_ok := pw_edit.text == "ab12!" and was_secret and shown and pw_edit.secret and pw_edit.secret_character == "*" and AuthValidator.password_error("abc한글1234") != ""
	var ui_ok := snd_ok and best_ok and not star and pw_ok
	print("item sounds %s ; BEST rules (guest %s, login %s, live %s) %s ; no star/? glyphs %s ; password filter+eye %s" % [snd_ok, guest_best, login_best, live_best, best_ok, not star, pw_ok])
	ok = ok and ui_ok
	# 로그인/회원가입 모달: 잘못된 입력은 서버 호출 없이 한국어 안내, 랭킹은 오프라인 안내
	_auth_modal.open()
	_auth_modal._set_mode(true)
	(_auth_modal._fields["nick"]["edit"] as LineEdit).text = "a"
	await _auth_modal._on_submit()
	var msg1: String = _auth_modal._msg.text
	(_auth_modal._fields["nick"]["edit"] as LineEdit).text = "치이카와"
	(_auth_modal._fields["email"]["edit"] as LineEdit).text = "bad"
	await _auth_modal._on_submit()
	var msg2: String = _auth_modal._msg.text
	var auth_ok := msg1.contains("2~12자") and msg2.contains("이메일 형식")
	_auth_modal.close()
	# 로그인(아이디+비밀번호) 폼 검증 + 비밀번호 재설정 폼 검증(서버 호출 없이 안내문만)
	_auth_modal.open()
	_auth_modal._set_mode(false)
	await _auth_modal._on_submit()
	var msg3: String = _auth_modal._msg.text
	(_auth_modal._fields["nick"]["edit"] as LineEdit).text = "치이카와"
	await _auth_modal._on_submit()
	var msg4: String = _auth_modal._msg.text
	var login_form_ok := msg3.contains("아이디를 입력") and msg4.contains("비밀번호를 입력") and not (_auth_modal._fields["email"]["edit"] as LineEdit).visible and _auth_modal._forgot.visible
	_auth_modal._forgot.pressed.emit()
	var reset_open := _reset_modal.is_open()
	await _reset_modal._on_send()
	var msg5a: String = _reset_modal._msg.text   # 아이디 비움
	_reset_modal.nick_edit.text = "치이카와"
	_reset_modal.email_edit.text = "bad"
	await _reset_modal._on_send()
	var msg5: String = _reset_modal._msg.text
	var reset_ok := reset_open and msg5a.contains("아이디를 입력") and msg5.contains("이메일 형식")
	_reset_modal.close()
	_auth_modal.close()
	print("login form (nickname+password, forgot btn): '%s' / '%s' %s ; reset modal: '%s' %s" % [msg3, msg4, "OK" if login_form_ok else "FAIL", msg5, "OK" if reset_ok else "FAIL"])
	ok = ok and login_form_ok and reset_ok
	_rank_modal.open()
	await get_tree().create_timer(0.2).timeout
	var rank_ok := _rank_modal.is_open() and _rank_modal._status.text.contains("온라인")
	_rank_modal.close()
	print("auth modal validation msgs: '%s' / '%s' %s ; rank offline msg '%s' %s" % [msg1, msg2, "OK" if auth_ok else "FAIL", _rank_modal._status.text, "OK" if rank_ok else "FAIL"])
	ok = ok and auth_ok and rank_ok
	print("TITLE TEST ", "PASS" if ok else "FAIL")
	get_tree().quit()

## 타이틀 상태에서는 드롭/아이템 입력이 막히는지 확인
## 테스트용: 시작 버튼 -> 비로그인 확인 팝업이 뜨면 '시작하기'까지 누른다
func _test_press_start() -> void:
	_title.start_button.pressed.emit()
	if _confirm_modal.is_open():
		_confirm_modal.start_button.pressed.emit()

func _unhandled_input_blocked_check() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(240, 300)
	_unhandled_input(ev)
	var blocked := get_tree().get_nodes_in_group("heads").size() == 0
	print("title blocks drop: %s %s" % [blocked, "OK" if blocked else "FAIL"])

## --text-audit: 모든 Label/Button 글자가 자기 칸(크기) 안에 들어가는지 폰트 실측으로 점검(--headless)
func _run_text_audit() -> void:
	await get_tree().create_timer(0.3).timeout
	var bad := 0
	var n := 0
	# 1) 타이틀 화면
	_title = TitleScreen.new()
	_title.size = Vector2(730, 800)
	add_child(_title)
	await get_tree().process_frame
	var r := _audit_tree(_title)
	n += r[0]; bad += r[1]
	_title.queue_free()
	_title = null
	# 2) 게임 화면(사이드바/스킬바/볼륨/저작권) + 게임오버 모달 + 일시정지 메뉴
	_set_state(State.PLAYING)
	_over_modal.visible = true
	_over_score.text = "점수 1234567"
	for id in _skill_bar._parts:
		_skill_bar._parts[id]["cost"].text = "조준 중"   # 가장 긴 비용 칸 문구(조준 모드)
	_over_note.text = "로그인하면 랭킹에 올라가요"
	_panel.set_score(9999999)
	_panel.set_best(9999999)
	var sample: Array = []
	for i in 10:
		sample.append({"rank": i + 1, "nickname": "열두글자열두글자열두글자", "best_score": 99999999})
	_rank_modal._show_rows(sample)
	_rank_modal._mine.text = "열두글자열두글자열두글자님의 최고점: 99999999"
	_auth_modal._set_mode(true)
	for item in [_panel, _skill_bar, _credit, _over_modal, _pause_menu, _rank_modal.box, _auth_modal.box, _help_modal.box, _settings_modal.box, _confirm_modal.box, _reset_modal.box]:
		r = _audit_tree(item)
		n += r[0]; bad += r[1]
	_auth_modal._set_mode(false)   # 로그인 탭(아이디 + 비밀번호 + 비밀번호 찾기)도 점검
	r = _audit_tree(_auth_modal.box)
	n += r[0]; bad += r[1]
	print("TEXT AUDIT checked=%d overflow=%d %s" % [n, bad, "PASS" if bad == 0 else "FAIL"])
	get_tree().quit()

func _audit_tree(root: Node) -> Array:
	var checked := 0
	var bad := 0
	var stack: Array = [root]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		stack.append_array(c.get_children())
		if not (c is Label or c is Button):
			continue
		var text: String = c.text
		if text.strip_edges() == "":
			continue
		checked += 1
		var font: Font = c.get_theme_font("font")
		var fs: int = c.get_theme_font_size("font_size")
		var line_h := font.get_height(fs)
		var avail: Vector2 = c.size
		if c is Button:
			avail -= Vector2(12, 4)   # 버튼 안쪽 여백
		var need: Vector2
		if c is Label and c.autowrap_mode != TextServer.AUTOWRAP_OFF:
			need = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, avail.x, fs, -1, TextServer.BREAK_WORD_BOUND | TextServer.BREAK_MANDATORY | TextServer.BREAK_ADAPTIVE)
		else:
			need = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var too_wide := need.x > avail.x + 0.5
		var too_tall := need.y > avail.y + 1.0 and avail.y > 0.0
		# Label 은 글자가 넓으면 스스로 커지므로(최소 크기), 부모 칸을 벗어났는지도 함께 본다
		var par := c.get_parent() as Control
		var out_of_parent := false
		if par != null and c is Label:
			var rc := Rect2(c.position, c.size)
			out_of_parent = rc.position.x < -0.5 or rc.end.x > par.size.x + 0.5
			out_of_parent = out_of_parent or c.position.y < -4.0 or c.position.y + minf(need.y, c.size.y) > par.size.y + 1.0   # 세로는 실제 글자 높이 기준
		if too_wide or too_tall or out_of_parent:
			bad += 1
			print("  OVERFLOW %s '%s' font=%d need=%s avail=%s rect=%s parent=%s" % [c.get_path(), text.replace("
", "/"), fs, need.snapped(Vector2(0.1, 0.1)), avail, Rect2(c.position, c.size), par.size if par != null else Vector2.ZERO])
	return [checked, bad]

## 회원가입 검증 규칙 단위 점검(통과/실패 기대 케이스)
func _auth_validator_test() -> bool:
	var cases := [
		["nick", "치이카와", true], ["nick", "Chii-123", true], ["nick", "가나", true], ["nick", "열두글자열두글자열두글자", true],
		["nick", "a", false], ["nick", "열세글자열세글자열세글자열", false], ["nick", "치이 카와", false], ["nick", "ㅋㅋㅋ", false],
		["nick", "chii_kawa", false], ["nick", "치이카와!", false], ["nick", "", false],
		["pw", "abcd1234", true], ["pw", "Abcdefg1", true], ["pw", "1234abcD", true],
		["pw", "abc123", false], ["pw", "abcdefgh", false], ["pw", "12345678", false], ["pw", "가나다라마바사1", false],
		["email", "a@b.co", true], ["email", "chii.kawa+1@example.com", true],
		["email", "abc", false], ["email", "a@b", false], ["email", "a@@b.com", false], ["email", "a b@c.com", false], ["email", "", false],
	]
	var ok := true
	for c in cases:
		var err: String = AuthValidator.nickname_error(c[1]) if c[0] == "nick" else (AuthValidator.password_error(c[1]) if c[0] == "pw" else AuthValidator.email_error(c[1]))
		var pass_ := err == ""
		if pass_ != c[2] or (not pass_ and err.length() < 8):
			ok = false
			print("  validator FAIL: %s '%s' expected=%s msg='%s'" % [c[0], c[1], c[2], err])
	var mm := AuthValidator.signup_error("치이카와", "a@b.co", "abcd1234", "abcd12345") != ""
	var good := AuthValidator.signup_error("치이카와", "a@b.co", "abcd1234", "abcd1234") == ""
	ok = ok and mm and good
	print("signup validation: %d cases %s" % [cases.size() + 2, "OK" if ok else "FAIL"])
	return ok

## --net-test <이메일> <닉네임> <비밀번호>: 실서버 가입 -> 로그인 -> 점수 제출 -> 랭킹 조회 -> 자동로그인 -> 로그아웃 점검
func _run_net_test() -> void:
	var a := OS.get_cmdline_user_args()
	var i := a.find("--net-test")
	var email := a[i + 1]
	var nick := a[i + 2]
	var pw := a[i + 3]
	var ok := true
	print("net enabled=", Supabase.enabled)
	var r: Dictionary = await Supabase.sign_up(nick, email, pw)
	print("sign_up: ", r)
	ok = ok and r["ok"] and Supabase.signed_in and Supabase.nickname == nick
	var dup: Dictionary = await Supabase.sign_up(nick, "other-" + email, pw)
	print("sign_up duplicate nickname rejected: ", dup)
	ok = ok and not dup["ok"]
	var r1: Dictionary = await Supabase.record_score(1234)
	var r2: Dictionary = await Supabase.record_score(500)    # 낮은 점수는 갱신되면 안 됨
	var r3: Dictionary = await Supabase.record_score(2222)
	print("submit 1234 -> ", r1.get("data"), " | 500 -> ", r2.get("data"), " | 2222 -> ", r3.get("data"))
	ok = ok and int(r1.get("data", -1)) == 1234 and int(r2.get("data", -1)) == 1234 and int(r3.get("data", -1)) == 2222
	var top: Dictionary = await Supabase.fetch_top(10)
	print("top10: ", top.get("data", top))
	var found := false
	if top["ok"]:
		for row in top["data"]:
			if row["nickname"] == nick and int(row["best_score"]) == 2222:
				found = true
	ok = ok and found
	await Supabase.sign_out()
	ok = ok and not Supabase.signed_in
	var bad: Dictionary = await Supabase.sign_in(nick, pw + "x")
	print("wrong password: ", bad.get("error"))
	ok = ok and not bad["ok"]
	var li: Dictionary = await Supabase.sign_in(nick, pw)
	print("sign_in: ", li, " nickname=", Supabase.nickname, " best=", Supabase.server_best)
	ok = ok and li["ok"] and Supabase.server_best == 2222
	# 자동 로그인: 메모리 상태를 지우고 저장된 refresh_token 으로 복구되는지
	Supabase.signed_in = false
	Supabase._access = ""
	await Supabase.auto_login()
	print("auto_login: signed_in=", Supabase.signed_in, " nickname=", Supabase.nickname)
	ok = ok and Supabase.signed_in and Supabase.nickname == nick
	await Supabase.sign_out()   # 저장된 토큰 파일도 지움
	ok = ok and not FileAccess.file_exists(Supabase.AUTH_PATH)
	print("NET TEST ", "PASS" if ok else "FAIL")
	get_tree().quit()
