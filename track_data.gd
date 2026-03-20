extends Node
## Autoload singleton for track save/load and sharing data between scenes.

var current_track := ""
var current_server_id := 0  # server track ID (0 = local only)


func set_server_id(track_name: String, server_id: int) -> void:
	var cfg := ConfigFile.new()
	var path := "user://track_ids.cfg"
	if FileAccess.file_exists(path):
		cfg.load(path)
	cfg.set_value("ids", track_name, server_id)
	cfg.save(path)


func get_server_id(track_name: String) -> int:
	var cfg := ConfigFile.new()
	var path := "user://track_ids.cfg"
	if FileAccess.file_exists(path):
		cfg.load(path)
		return cfg.get_value("ids", track_name, 0)
	return 0


func save_track(track_name: String, pieces: Array[Dictionary]) -> void:
	DirAccess.make_dir_recursive_absolute("user://tracks")
	var file := FileAccess.open("user://tracks/%s.json" % track_name, FileAccess.WRITE)
	var data: Array = []
	for p in pieces:
		var entry := {
			"gx": p.grid.x,
			"gz": p.grid.y,
			"piece": p.piece,
			"rotation": p.rotation,
			"bh": p.get("base_height", 0),
		}
		if p.get("down", false):
			entry["down"] = 1
		data.append(entry)
	file.store_string(JSON.stringify(data))


func load_track(track_name: String) -> Array[Dictionary]:
	var path := "user://tracks/%s.json" % track_name
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	var result: Array[Dictionary] = []
	for entry in json.data:
		result.append({
			"grid": Vector2i(int(entry.gx), int(entry.gz)),
			"piece": int(entry.piece),
			"rotation": int(entry.rotation),
			"base_height": int(entry.get("bh", 0)),
			"down": bool(entry.get("down", 0)),
		})
	return result


func get_track_names() -> Array[String]:
	var names: Array[String] = []
	var dir := DirAccess.open("user://tracks")
	if dir:
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if file.ends_with(".json"):
				names.append(file.trim_suffix(".json"))
			file = dir.get_next()
	return names


func delete_track(track_name: String) -> void:
	DirAccess.remove_absolute("user://tracks/%s.json" % track_name)
