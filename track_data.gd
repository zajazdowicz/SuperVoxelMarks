extends Node
## Autoload singleton for track save/load and sharing data between scenes.

var current_track := ""


func save_track(track_name: String, pieces: Array[Dictionary]) -> void:
	DirAccess.make_dir_recursive_absolute("user://tracks")
	var file := FileAccess.open("user://tracks/%s.json" % track_name, FileAccess.WRITE)
	var data: Array = []
	for p in pieces:
		data.append({
			"gx": p.grid.x,
			"gz": p.grid.y,
			"piece": p.piece,
			"rotation": p.rotation,
			"bh": p.get("base_height", 0),
		})
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
