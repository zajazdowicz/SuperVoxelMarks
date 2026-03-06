extends Control

@onready var track_list: ItemList = $VBox/TrackList
@onready var play_button: Button = $VBox/Buttons/PlayButton
@onready var editor_button: Button = $VBox/Buttons/EditorButton

var tracks: Array[String] = []
var name_input: LineEdit
var flag_button: Button
var flag_modal: Control


func _ready() -> void:
	play_button.pressed.connect(_on_play)
	editor_button.pressed.connect(_on_editor)
	_load_track_list()
	_create_player_ui()
	_create_generate_button()
	_create_delete_button()


func _load_track_list() -> void:
	tracks.clear()
	track_list.clear()
	var dir := DirAccess.open("user://tracks")
	if dir:
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if file.ends_with(".json"):
				var tname := file.trim_suffix(".json")
				tracks.append(tname)
				track_list.add_item(tname)
			file = dir.get_next()

	if tracks.is_empty():
		play_button.disabled = true
		play_button.text = "GRAJ (brak tras)"
	else:
		track_list.select(0)


func _create_player_ui() -> void:
	var vbox: VBoxContainer = $VBox

	# Player row: NAME: [input] [FLAG]
	var player_row := HBoxContainer.new()
	player_row.alignment = BoxContainer.ALIGNMENT_CENTER
	player_row.add_theme_constant_override("separation", 10)
	# Insert before track list (index 2 = after Title and Subtitle)
	vbox.add_child(player_row)
	vbox.move_child(player_row, 2)

	var name_label := Label.new()
	name_label.text = "NICK:"
	var name_settings := LabelSettings.new()
	name_settings.font_size = 22
	name_settings.font_color = Color.WHITE
	name_label.label_settings = name_settings
	player_row.add_child(name_label)

	name_input = LineEdit.new()
	name_input.text = PlayerData.player_name
	name_input.placeholder_text = "Wpisz nick"
	name_input.max_length = 15
	name_input.custom_minimum_size = Vector2(200, 40)
	name_input.add_theme_font_size_override("font_size", 20)
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.12, 0.12, 0.18)
	input_style.border_color = Color(0.3, 0.7, 1.0)
	input_style.set_border_width_all(2)
	input_style.set_corner_radius_all(4)
	name_input.add_theme_stylebox_override("normal", input_style)
	name_input.text_changed.connect(_on_name_changed)
	player_row.add_child(name_input)

	# Flag button
	flag_button = Button.new()
	flag_button.custom_minimum_size = Vector2(60, 40)
	flag_button.add_theme_font_size_override("font_size", 20)
	var flag_style := StyleBoxFlat.new()
	flag_style.bg_color = Color(0.12, 0.12, 0.18)
	flag_style.border_color = Color(0.3, 0.7, 1.0)
	flag_style.set_border_width_all(2)
	flag_style.set_corner_radius_all(4)
	flag_button.add_theme_stylebox_override("normal", flag_style)
	flag_button.pressed.connect(_on_flag_pressed)
	player_row.add_child(flag_button)
	_update_flag_button()


func _update_flag_button() -> void:
	# Remove old flag texture if any
	for child in flag_button.get_children():
		child.queue_free()

	if PlayerData.player_flag.is_empty():
		flag_button.text = "FLAGA"
		return

	flag_button.text = ""
	flag_button.clip_contents = true
	var tex := FlagData.get_flag_texture(PlayerData.player_flag)
	if tex:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(36, 22)
		rect.size = Vector2(36, 22)
		rect.position = Vector2(12, 9)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flag_button.add_child(rect)
	else:
		flag_button.text = PlayerData.player_flag


func _on_name_changed(new_text: String) -> void:
	PlayerData.player_name = new_text
	PlayerData.save()


func _on_flag_pressed() -> void:
	if flag_modal:
		return
	_create_flag_modal()


func _create_flag_modal() -> void:
	flag_modal = Panel.new()
	flag_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.92)
	flag_modal.add_theme_stylebox_override("panel", bg_style)
	add_child(flag_modal)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flag_modal.add_child(center)

	var content := PanelContainer.new()
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.06, 0.06, 0.1)
	box_style.border_color = Color(0.3, 0.7, 1.0)
	box_style.set_border_width_all(2)
	box_style.set_corner_radius_all(8)
	box_style.content_margin_left = 20
	box_style.content_margin_right = 20
	box_style.content_margin_top = 15
	box_style.content_margin_bottom = 15
	content.add_theme_stylebox_override("panel", box_style)
	content.custom_minimum_size = Vector2(500, 550)
	center.add_child(content)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	content.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "WYBIERZ FLAGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	vbox.add_child(title)

	# Search
	var search := LineEdit.new()
	search.placeholder_text = "Szukaj kraju..."
	search.add_theme_font_size_override("font_size", 18)
	var search_style := StyleBoxFlat.new()
	search_style.bg_color = Color(0.1, 0.1, 0.15)
	search_style.border_color = Color(0.3, 0.7, 1.0)
	search_style.set_border_width_all(2)
	search.add_theme_stylebox_override("normal", search_style)
	vbox.add_child(search)

	# "None" button
	var none_btn := Button.new()
	none_btn.text = "BEZ FLAGI"
	none_btn.custom_minimum_size = Vector2(0, 35)
	none_btn.add_theme_font_size_override("font_size", 16)
	none_btn.pressed.connect(_on_flag_selected.bind(""))
	vbox.add_child(none_btn)

	# Scroll + grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	_populate_flag_grid(grid, FlagData.COUNTRIES)

	search.text_changed.connect(func(text: String):
		_populate_flag_grid(grid, FlagData.search_countries(text))
	)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "ZAMKNIJ"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.add_theme_font_size_override("font_size", 18)
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.25, 0.05, 0.05)
	close_style.border_color = Color(1.0, 0.3, 0.3)
	close_style.set_border_width_all(2)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.pressed.connect(func(): flag_modal.queue_free(); flag_modal = null)
	vbox.add_child(close_btn)


func _populate_flag_grid(grid: GridContainer, countries: Array) -> void:
	for child in grid.get_children():
		child.queue_free()

	for country in countries:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(80, 55)
		btn.tooltip_text = country["name"]

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.08, 0.08, 0.12)
		btn_style.border_color = Color(0.2, 0.2, 0.3)
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", btn_style)

		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(0.15, 0.2, 0.3)
		hover.border_color = Color(0.3, 0.7, 1.0)
		hover.set_border_width_all(2)
		hover.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("hover", hover)

		var bvbox := VBoxContainer.new()
		bvbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bvbox.alignment = BoxContainer.ALIGNMENT_CENTER
		bvbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bvbox)

		var flag_tex := FlagData.get_flag_texture(country["code"])
		if flag_tex:
			var flag_rect := TextureRect.new()
			flag_rect.texture = flag_tex
			flag_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			flag_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			flag_rect.custom_minimum_size = Vector2(40, 26)
			flag_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			flag_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bvbox.add_child(flag_rect)

		var code_label := Label.new()
		code_label.text = country["code"]
		code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		code_label.add_theme_font_size_override("font_size", 11)
		code_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		code_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bvbox.add_child(code_label)

		btn.pressed.connect(_on_flag_selected.bind(country["code"]))
		grid.add_child(btn)


func _on_flag_selected(code: String) -> void:
	PlayerData.player_flag = code
	PlayerData.save()
	_update_flag_button()
	if flag_modal:
		flag_modal.queue_free()
		flag_modal = null


func _create_generate_button() -> void:
	var buttons: HBoxContainer = $VBox/Buttons
	var gen_btn := Button.new()
	gen_btn.text = "GENERUJ"
	gen_btn.custom_minimum_size = Vector2(130, 50)
	var gen_style := StyleBoxFlat.new()
	gen_style.bg_color = Color(0.05, 0.2, 0.05)
	gen_style.border_color = Color(0.2, 0.8, 0.3)
	gen_style.set_border_width_all(2)
	gen_btn.add_theme_stylebox_override("normal", gen_style)
	gen_btn.pressed.connect(_on_generate)
	buttons.add_child(gen_btn)


func _on_generate() -> void:
	var length: int = randi_range(15, 30)
	var gen_name := "gen_%d" % (randi() % 9999)
	TrackGenerator.generate(length, gen_name)
	_load_track_list()
	# Select and play the generated track
	for i in range(tracks.size()):
		if tracks[i] == gen_name:
			track_list.select(i)
			break


func _create_delete_button() -> void:
	var buttons: HBoxContainer = $VBox/Buttons
	var del_btn := Button.new()
	del_btn.text = "USUN"
	del_btn.custom_minimum_size = Vector2(100, 50)
	var del_style := StyleBoxFlat.new()
	del_style.bg_color = Color(0.3, 0.05, 0.05)
	del_style.border_color = Color(0.8, 0.2, 0.2)
	del_style.set_border_width_all(2)
	del_btn.add_theme_stylebox_override("normal", del_style)
	del_btn.pressed.connect(_on_delete)
	buttons.add_child(del_btn)


func _on_delete() -> void:
	if track_list.get_selected_items().is_empty():
		return
	var idx := track_list.get_selected_items()[0]
	var tname := tracks[idx]
	TrackData.delete_track(tname)
	# Also delete best time
	if FileAccess.file_exists("user://times/%s.json" % tname):
		DirAccess.remove_absolute("user://times/%s.json" % tname)
	_load_track_list()


func _on_play() -> void:
	if track_list.get_selected_items().is_empty():
		return
	var idx := track_list.get_selected_items()[0]
	TrackData.current_track = tracks[idx]
	get_tree().change_scene_to_file("res://race.tscn")


func _on_editor() -> void:
	# If a track is selected, edit it. Otherwise create new.
	if not track_list.get_selected_items().is_empty():
		var idx := track_list.get_selected_items()[0]
		TrackData.current_track = tracks[idx]
	else:
		TrackData.current_track = "_new_"
	get_tree().change_scene_to_file("res://editor.tscn")
