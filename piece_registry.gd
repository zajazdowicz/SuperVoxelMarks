extends Node

## Loads piece metadata from pieces.json — single source of truth
## for names, ports, height deltas, categories, and flags.

var _data: Dictionary = {}
var _pieces: Dictionary = {}

func _ready() -> void:
	var file := FileAccess.open("res://pieces.json", FileAccess.READ)
	if not file:
		push_error("PieceRegistry: cannot open pieces.json")
		return
	_data = JSON.parse_string(file.get_as_text())
	if _data == null:
		push_error("PieceRegistry: failed to parse pieces.json")
		_data = {}
		return
	_pieces = _data.get("pieces", {})


# --- Names ---

func get_piece_name(id: int) -> String:
	var p: Dictionary = _pieces.get(str(id), {})
	return p.get("name", "???")


# --- Ports ---

func get_ports(id: int) -> Array[Dictionary]:
	var p: Dictionary = _pieces.get(str(id), {})
	var raw_ports: Array = p.get("ports", [])
	var result: Array[Dictionary] = []
	for rp in raw_ports:
		var d: Array = rp.get("dir", [0, 0])
		result.append({"side": rp.get("side", "S"), "dir": Vector2i(int(d[0]), int(d[1]))})
	return result


func rotate_ports(ports: Array[Dictionary], rotations: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var sides := ["S", "W", "N", "E"]
	var dirs := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]
	for port in ports:
		var side_idx := sides.find(port.side)
		var new_idx := (side_idx + rotations) % 4
		result.append({"side": sides[new_idx], "dir": dirs[new_idx]})
	return result


# --- Height Deltas ---

func get_height_delta(id: int, is_down: bool = false) -> int:
	var p: Dictionary = _pieces.get(str(id), {})
	var delta: int = int(p.get("height_delta", 0))
	if is_down and p.get("flags", {}).get("has_down_variant", false):
		return -absi(delta)
	return delta


# --- Categories ---

func get_categories() -> Array:
	return _data.get("categories", [])


# --- Flags ---

func get_flags(id: int) -> Dictionary:
	var p: Dictionary = _pieces.get(str(id), {})
	return p.get("flags", {})


func get_preview_type(id: int) -> String:
	var p: Dictionary = _pieces.get(str(id), {})
	return p.get("preview_type", "voxel")


func is_disabled(id: int) -> bool:
	return get_flags(id).get("disabled", false)


func get_spans_cells(id: int) -> int:
	return int(get_flags(id).get("spans_cells", 1))


# --- Constants ---

func get_constant(key: String, default_val: int = 0) -> int:
	return int(_data.get("constants", {}).get(key, default_val))


# --- Piece count ---

func get_piece_count() -> int:
	return _pieces.size()
