extends Node
## Autoload singleton storing player nick and flag. Persists to user://player.json.

var player_name := "PLAYER"
var player_flag := ""  # Country code e.g. "PL", "DE", "" for none

const SAVE_PATH := "user://player.json"


func _ready() -> void:
	_load()


func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"name": player_name,
		"flag": player_flag,
	}))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	if json.data:
		player_name = str(json.data.get("name", "PLAYER"))
		player_flag = str(json.data.get("flag", ""))
