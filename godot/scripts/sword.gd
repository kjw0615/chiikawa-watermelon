class_name Sword
extends Node2D
## 랏코의 명검: 물리 바디가 아닌 스크립트로 떨어지는 특수 오브젝트. 첫 접촉 노드를 알리고 사라진다.

signal hit(head: Head)
signal fizzled

const SPEED := 1100.0
const BLADE := 70.0     # 칼날 길이(아래 방향이 끝)
const FLOOR_Y := 700.0

var _done := false

func _physics_process(dt: float) -> void:
	if _done:
		return
	position.y += SPEED * dt
	var tip := global_position + Vector2(0, BLADE)
	for n in get_tree().get_nodes_in_group("heads"):
		var h := n as Head
		if h == null or h.merging:
			continue
		if h.position.distance_to(tip) > NodeDefs.radius(h.stage) * 2.2 + BLADE:
			continue
		var poly := h.world_collider()
		for k in [0.0, 25.0, 50.0]:
			if Geometry2D.is_point_in_polygon(tip - Vector2(0, k), poly):
				_done = true
				hit.emit(h)
				queue_free()
				return
	if tip.y > FLOOR_Y:
		_done = true
		fizzled.emit()
		queue_free()

func _draw() -> void:
	# 손잡이(위) - 날밑 - 칼날(아래로 향함)
	draw_rect(Rect2(-4, -34, 8, 22), Color("7a4b2a"))
	draw_rect(Rect2(-16, -12, 32, 7), Color("e0b84a"))
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -5), Vector2(8, -5), Vector2(8, BLADE - 14), Vector2(0, BLADE), Vector2(-8, BLADE - 14)]), Color("dfe8f2"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -5), Vector2(8, -5), Vector2(8, BLADE - 14), Vector2(0, BLADE)]), Color("b4c3d6"))
	draw_line(Vector2(0, -5), Vector2(0, BLADE - 4), Color("ffffff"), 1.5)
	draw_circle(Vector2(0, -36), 5.0, Color("e0b84a"))
