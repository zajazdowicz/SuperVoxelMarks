extends Control

@onready var track_list: ItemList = $VBox/TrackList
@onready var play_button: Button = $VBox/Buttons/PlayButton
@onready var editor_button: Button = $VBox/Buttons/EditorButton

var tracks: Array[String] = []


func _ready() -> void:
	play_button.pressed.connect(_on_play)
	editor_button.pressed.connect(_on_editor)
	_load_track_list()


func _load_track_list() -> void:
	tracks.clear()
	track_list.clear()
	var dir := DirAccess.open("user://tracks")
	if dir:
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if file.ends_with(".json"):
				var name := file.trim_suffix(".json")
				tracks.append(name)
				track_list.add_item(name)
			file = dir.get_next()

	if tracks.is_empty():
		play_button.disabled = true
		play_button.text = "GRAJ (brak tras)"
	else:
		track_list.select(0)


func _on_play() -> void:
	if track_list.get_selected_items().is_empty():
		return
	var idx := track_list.get_selected_items()[0]
	TrackData.current_track = tracks[idx]
	get_tree().change_scene_to_file("res://race.tscn")


func _on_editor() -> void:
	get_tree().change_scene_to_file("res://editor.tscn")
