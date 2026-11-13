class_name EffectSprite
extends Sprite2D
## 아이템 연출용 스프라이트시트 재생기(3열x2행, 6프레임, 기준점 = 셀 (128, 240)).
## duration < 0 이면 1회 재생 후 사라지고, 아니면 duration 초 동안 루프한 뒤 사라진다.

signal finished

const SHEET_DIR := "res://assets/effects/spritesheets/"
const FRAMES := 6
const FADE := 0.15

var _fps := 10.0
var _t := 0.0
var _duration := -1.0
var _end := 0.0

static func spawn(parent: Node, sheet: String, pos: Vector2, sc: float, fps: float, duration := -1.0) -> EffectSprite:
	var e := EffectSprite.new()
	e.texture = load(SHEET_DIR + sheet)
	e.hframes = 3
	e.vframes = 2
	e.offset = Vector2(0, 128.0 - 240.0)   # 원점을 발끝 기준점으로
	e.position = pos
	e.scale = Vector2.ONE * sc * 0.6
	e.z_index = 35
	e._fps = fps
	e._duration = duration
	e._end = duration if duration >= 0.0 else FRAMES / fps + 0.1
	parent.add_child(e)
	e.create_tween().tween_property(e, "scale", Vector2.ONE * sc, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return e

func _process(dt: float) -> void:
	_t += dt
	var f := int(_t * _fps)
	frame = (f % FRAMES) if _duration >= 0.0 else mini(f, FRAMES - 1)
	if _t > _end - FADE:
		modulate.a = clampf((_end - _t) / FADE, 0.0, 1.0)
	if _t >= _end:
		set_process(false)
		finished.emit()
		queue_free()
