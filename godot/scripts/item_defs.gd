class_name ItemDefs
## 아이템/게이지 데이터 테이블 로더(res://data/items.json).

const PATH := "res://data/items.json"

static var _data: Dictionary = {}

static func _ensure() -> void:
	if not _data.is_empty():
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	_data = JSON.parse_string(f.get_as_text())

static func gauge_max() -> float:
	_ensure()
	return float(_data["gauge_max"])

static func items() -> Array:
	_ensure()
	return _data["items"]

static func item(id: String) -> Dictionary:
	for it in items():
		if it["id"] == id:
			return it
	return {}

## 합체한 노드 단계(1~11)에 따른 게이지 충전량(%)
static func gain_for_stage(stage_no: int) -> float:
	_ensure()
	for g in _data["gain"]:
		if stage_no >= int(g["from"]) and stage_no <= int(g["to"]):
			return float(g["pct"])
	return 0.0
