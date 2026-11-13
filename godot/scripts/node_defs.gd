class_name NodeDefs
## 노드(캐릭터 단계) 데이터 테이블 로더. 데이터는 res://data/nodes.json 에서 관리한다.

const PATH := "res://data/nodes.json"

static var _defs: Array = []
static var _drop_max := 5

static func _ensure() -> void:
	if not _defs.is_empty():
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	var j: Dictionary = JSON.parse_string(f.get_as_text())
	_defs = j["nodes"]
	_drop_max = int(j["drop_max_stage"])

static func count() -> int:
	_ensure()
	return _defs.size()

static func radius(stage: int) -> float:
	_ensure()
	return float(_defs[stage]["radius"])

static func node_name(stage: int) -> String:
	_ensure()
	return _defs[stage]["name"]

static func is_placeholder(stage: int) -> bool:
	_ensure()
	return _defs[stage]["placeholder"]

## 드롭으로 나올 수 있는 마지막 단계의 인덱스(0부터). 이후 단계는 합체로만 생성.
static func drop_max_index() -> int:
	_ensure()
	return _drop_max - 1

static func art_path(stage: int, state: String) -> String:
	_ensure()
	return String(_defs[stage]["art"]).replace("{state}", state)
