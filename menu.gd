extends Control
## Main menu — tile-based layout for mobile.

var tracks: Array[String] = []
var name_input: LineEdit
var flag_button: Button
var flag_modal: Control
var _selected_track := -1
var _track_buttons: Array[Button] = []
var _online_modal: Control
var _track_modal: Control
var _status_label: Label  # bottom info bar


func _ready() -> void:
	_build_ui()
	_load_tracks()
	_auto_register_player()


func _load_tracks() -> void:
	tracks.clear()
	var dir := DirAccess.open("user://tracks")
	if dir:
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if file.ends_with(".json"):
				tracks.append(file.trim_suffix(".json"))
			file = dir.get_next()
	_selected_track = 0 if not tracks.is_empty() else -1


# =============================================================================
# MAIN UI BUILD
# =============================================================================

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.07, 1.0)
	add_child(bg)

	# Main vertical layout
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# --- HEADER (title + player) ---
	var header := _build_header()
	root.add_child(header)

	# --- TILE GRID (main content) ---
	var tile_scroll := ScrollContainer.new()
	tile_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(tile_scroll)

	var tile_container := _build_tiles()
	tile_scroll.add_child(tile_container)

	# --- FOOTER (status bar) ---
	var footer := _build_footer()
	root.add_child(footer)


func _build_header() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 1.0)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "RC TRICK MANIA X"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_s := LabelSettings.new()
	title_s.font_size = 52
	title_s.font_color = Color(1.0, 0.9, 0.2)
	title_s.outline_size = 4
	title_s.outline_color = Color(0.15, 0.1, 0.0)
	title.label_settings = title_s
	vbox.add_child(title)

	# Player row
	var player_row := HBoxContainer.new()
	player_row.alignment = BoxContainer.ALIGNMENT_CENTER
	player_row.add_theme_constant_override("separation", 8)
	vbox.add_child(player_row)

	var nick_label := Label.new()
	nick_label.text = "NICK:"
	nick_label.add_theme_font_size_override("font_size", 28)
	nick_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	player_row.add_child(nick_label)

	name_input = LineEdit.new()
	name_input.text = PlayerData.player_name
	name_input.placeholder_text = "Wpisz nick"
	name_input.max_length = 15
	name_input.custom_minimum_size = Vector2(280, 50)
	name_input.add_theme_font_size_override("font_size", 28)
	var input_sb := StyleBoxFlat.new()
	input_sb.bg_color = Color(0.1, 0.1, 0.15)
	input_sb.border_color = Color(0.3, 0.5, 0.8)
	input_sb.set_border_width_all(1)
	input_sb.set_corner_radius_all(6)
	input_sb.content_margin_left = 8.0
	input_sb.content_margin_right = 8.0
	name_input.add_theme_stylebox_override("normal", input_sb)
	name_input.text_changed.connect(func(t: String): PlayerData.player_name = t; PlayerData.save())
	player_row.add_child(name_input)

	var nick_ok := Button.new()
	nick_ok.text = "OK"
	nick_ok.custom_minimum_size = Vector2(60, 50)
	nick_ok.add_theme_font_size_override("font_size", 26)
	var ok_sb := StyleBoxFlat.new()
	ok_sb.bg_color = Color(0.15, 0.4, 0.15)
	ok_sb.set_corner_radius_all(6)
	nick_ok.add_theme_stylebox_override("normal", ok_sb)
	nick_ok.pressed.connect(func(): _on_nick_submitted(name_input.text))
	player_row.add_child(nick_ok)

	flag_button = Button.new()
	flag_button.custom_minimum_size = Vector2(70, 50)
	flag_button.add_theme_font_size_override("font_size", 28)
	var flag_sb := StyleBoxFlat.new()
	flag_sb.bg_color = Color(0.1, 0.1, 0.15)
	flag_sb.border_color = Color(0.3, 0.5, 0.8)
	flag_sb.set_border_width_all(1)
	flag_sb.set_corner_radius_all(6)
	flag_button.add_theme_stylebox_override("normal", flag_sb)
	flag_button.focus_mode = Control.FOCUS_NONE
	flag_button.pressed.connect(_on_flag_pressed)
	player_row.add_child(flag_button)
	_update_flag_button()

	return panel


func _build_tiles() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	margin.add_child(grid)

	# Row 1: TRASA DNIA | GRAJ
	grid.add_child(_make_tile(
		"TRASA\nDNIA", "Codzienne wyzwanie",
		Color(0.4, 0.3, 0.05), Color(1.0, 0.85, 0.2),
		_on_daily
	))
	grid.add_child(_make_tile(
		"GRAJ", "Wybierz trase",
		Color(0.1, 0.35, 0.15), Color(0.3, 0.9, 0.4),
		_on_track_picker
	))

	# Row 2: ONLINE | EDYTOR
	grid.add_child(_make_tile(
		"TRASY\nONLINE", "Pobierz i rywalizuj",
		Color(0.1, 0.15, 0.35), Color(0.4, 0.6, 1.0),
		_on_online_pressed
	))
	grid.add_child(_make_tile(
		"EDYTOR", "Buduj wlasne trasy",
		Color(0.25, 0.15, 0.3), Color(0.7, 0.5, 1.0),
		_on_editor
	))

	# Row 3: GENERUJ | USTAWIENIA (placeholder)
	grid.add_child(_make_tile(
		"LOSOWA\nTRASA", "Generuj i jedz",
		Color(0.05, 0.2, 0.1), Color(0.2, 0.8, 0.4),
		_on_generate_and_play
	))
	grid.add_child(_make_tile(
		"POLACZ\nZ WEB", "Edytor w przegladarce",
		Color(0.15, 0.1, 0.3), Color(0.6, 0.4, 1.0),
		_on_link_web
	))

	return margin


func _make_tile(title: String, subtitle: String, bg_color: Color, accent: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 130)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.border_color = accent.darkened(0.4)
	sb.border_width_left = 4
	sb.content_margin_left = 18.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	btn.add_theme_stylebox_override("normal", sb)

	var sb_pressed := sb.duplicate()
	sb_pressed.bg_color = bg_color.lightened(0.15)
	sb_pressed.border_color = accent
	sb_pressed.border_width_left = 4
	btn.add_theme_stylebox_override("pressed", sb_pressed)

	var sb_hover := sb.duplicate()
	sb_hover.bg_color = bg_color.lightened(0.08)
	btn.add_theme_stylebox_override("hover", sb_hover)

	# Content: title + subtitle stacked
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_s := LabelSettings.new()
	title_s.font_size = 32
	title_s.font_color = accent
	title_s.outline_size = 2
	title_s.outline_color = Color(0, 0, 0, 0.5)
	title_lbl.label_settings = title_s
	vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = subtitle
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sub_s := LabelSettings.new()
	sub_s.font_size = 18
	sub_s.font_color = Color(0.6, 0.6, 0.65)
	sub_lbl.label_settings = sub_s
	vbox.add_child(sub_lbl)

	btn.pressed.connect(callback)
	return btn


func _build_footer() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 22)
	_status_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	_update_status()
	panel.add_child(_status_label)

	return panel


func _update_status() -> void:
	if not _status_label:
		return
	var track_count := tracks.size()
	var nick := PlayerData.player_name if not PlayerData.player_name.is_empty() else "???"
	_status_label.text = "%s  |  %d tras  |  v0.8" % [nick, track_count]


# =============================================================================
# TRACK PICKER MODAL
# =============================================================================

func _on_track_picker() -> void:
	if _track_modal:
		return
	_load_tracks()
	_create_track_modal()


func _create_track_modal() -> void:
	_track_modal = Panel.new()
	_track_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.92)
	_track_modal.add_theme_stylebox_override("panel", bg)
	add_child(_track_modal)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_track_modal.add_child(center)

	var content := PanelContainer.new()
	var box_sb := StyleBoxFlat.new()
	box_sb.bg_color = Color(0.05, 0.05, 0.08)
	box_sb.border_color = Color(0.2, 0.5, 0.3)
	box_sb.set_border_width_all(2)
	box_sb.set_corner_radius_all(12)
	box_sb.content_margin_left = 16
	box_sb.content_margin_right = 16
	box_sb.content_margin_top = 12
	box_sb.content_margin_bottom = 12
	content.add_theme_stylebox_override("panel", box_sb)
	content.custom_minimum_size = Vector2(680, 850)
	center.add_child(content)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	content.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "WYBIERZ TRASE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	vbox.add_child(title)

	# Track list scroll
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	_track_buttons.clear()
	var colors := [
		Color(0.12, 0.2, 0.32),
		Color(0.18, 0.12, 0.28),
		Color(0.08, 0.22, 0.15),
		Color(0.22, 0.12, 0.12),
		Color(0.2, 0.16, 0.08),
	]

	if tracks.is_empty():
		var empty := Label.new()
		empty.text = "Brak tras.\nUzyj GENERUJ lub EDYTOR."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 28)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		list.add_child(empty)
	else:
		for i in range(tracks.size()):
			var tname := tracks[i]
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(0, 72)
			btn.add_theme_font_size_override("font_size", 28)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.focus_mode = Control.FOCUS_NONE

			# Track info
			var sid: int = TrackData.get_server_id(tname)
			var online_tag := "  [ONLINE]" if sid > 0 else ""
			var time_tag := ""
			var best_path := "user://times/%s.json" % tname
			if FileAccess.file_exists(best_path):
				var f := FileAccess.open(best_path, FileAccess.READ)
				var j := JSON.new()
				j.parse(f.get_as_text())
				if j.data:
					var t: float = float(j.data.get("time", 0))
					if t > 0:
						time_tag = "  %.2fs" % t

			btn.text = "  %s%s%s" % [tname, time_tag, online_tag]

			var sb := StyleBoxFlat.new()
			sb.bg_color = colors[i % colors.size()]
			sb.set_corner_radius_all(8)
			sb.content_margin_left = 12
			sb.content_margin_right = 12
			btn.add_theme_stylebox_override("normal", sb)

			var idx := i
			btn.pressed.connect(func(): _pick_and_play(idx))
			list.add_child(btn)
			_track_buttons.append(btn)

	# Bottom buttons row
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	vbox.add_child(bottom)

	# DELETE button
	var del_btn := Button.new()
	del_btn.text = "USUN"
	del_btn.custom_minimum_size = Vector2(0, 50)
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.add_theme_font_size_override("font_size", 24)
	del_btn.focus_mode = Control.FOCUS_NONE
	var del_sb := StyleBoxFlat.new()
	del_sb.bg_color = Color(0.3, 0.08, 0.08)
	del_sb.set_corner_radius_all(6)
	del_btn.add_theme_stylebox_override("normal", del_sb)
	del_btn.pressed.connect(func():
		if _selected_track >= 0 and _selected_track < tracks.size():
			var tname := tracks[_selected_track]
			TrackData.delete_track(tname)
			if FileAccess.file_exists("user://times/%s.json" % tname):
				DirAccess.remove_absolute("user://times/%s.json" % tname)
			_load_tracks()
			_track_modal.queue_free()
			_track_modal = null
			_update_status()
			_on_track_picker()  # reopen
	)
	bottom.add_child(del_btn)

	# CLOSE button
	var close_btn := Button.new()
	close_btn.text = "ZAMKNIJ"
	close_btn.custom_minimum_size = Vector2(0, 50)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.focus_mode = Control.FOCUS_NONE
	var close_sb := StyleBoxFlat.new()
	close_sb.bg_color = Color(0.15, 0.15, 0.2)
	close_sb.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("normal", close_sb)
	close_btn.pressed.connect(func(): _track_modal.queue_free(); _track_modal = null)
	bottom.add_child(close_btn)


func _pick_and_play(idx: int) -> void:
	_selected_track = idx
	if _selected_track < 0 or _selected_track >= tracks.size():
		return
	var tname := tracks[_selected_track]
	TrackData.current_track = tname
	var sid := TrackData.get_server_id(tname)
	if sid > 0:
		TrackData.current_server_id = sid
		RaceManager.set_track_id(sid)
	if _track_modal:
		_track_modal.queue_free()
		_track_modal = null
	get_tree().change_scene_to_file("res://race.tscn")


# =============================================================================
# ACTIONS
# =============================================================================

func _on_editor() -> void:
	TrackData.current_track = "_new_"
	get_tree().change_scene_to_file("res://editor.tscn")


func _on_generate_and_play() -> void:
	var length: int = randi_range(15, 30)
	var gen_name := "gen_%d" % (randi() % 9999)
	TrackGenerator.generate(length, gen_name, randi())
	get_tree().change_scene_to_file("res://race.tscn")


func _on_link_web() -> void:
	if not ApiClient.is_registered():
		_set_status("Najpierw wpisz nick!")
		return

	# Ensure we have auth token, then generate link code
	_set_status("Laczenie...")
	ApiClient.ensure_auth(func(success: bool):
		if not success:
			_set_status("Blad autoryzacji")
			return
		ApiClient.generate_link_code(func(ok: bool, code: String):
			if ok:
				_show_link_code_modal(code)
				_set_status("")
			else:
				_set_status("Blad generowania kodu")
		)
	)


# =============================================================================
# DAILY TRACK
# =============================================================================

func _on_daily() -> void:
	var today := Time.get_date_string_from_system()
	var daily_name := "daily_%s" % today.replace("-", "")

	if daily_name in tracks:
		TrackData.current_track = daily_name
		var sid := TrackData.get_server_id(daily_name)
		if sid > 0:
			TrackData.current_server_id = sid
			RaceManager.set_track_id(sid)
		get_tree().change_scene_to_file("res://race.tscn")
		return

	_fetch_daily_from_server(today, daily_name)


func _fetch_daily_from_server(date_str: String, daily_name: String) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray):
		if code == 200:
			var json: Variant = JSON.parse_string(body.get_string_from_utf8())
			if json and json.has("track_json"):
				var track_json: Array = json["track_json"]
				var track_id: int = int(json.get("id", 0))
				var pieces: Array[Dictionary] = []
				for entry in track_json:
					pieces.append({
						"grid": Vector2i(int(entry.get("gx", 0)), int(entry.get("gz", 0))),
						"piece": int(entry.get("piece", 0)),
						"rotation": int(entry.get("rotation", 0)),
						"base_height": int(entry.get("bh", 0)),
						"down": bool(entry.get("down", false)),
					})
				TrackData.save_track(daily_name, pieces)
				if track_id > 0:
					TrackData.set_server_id(daily_name, track_id)
					TrackData.current_server_id = track_id
					RaceManager.set_track_id(track_id)
				TrackData.current_track = daily_name
				get_tree().change_scene_to_file("res://race.tscn")
				req.queue_free()
				return

		TrackGenerator.generate_daily(date_str, daily_name)
		get_tree().change_scene_to_file("res://race.tscn")
		req.queue_free()
	)
	req.request(ApiClient.API_BASE + "/daily-track")


# =============================================================================
# ONLINE TRACKS
# =============================================================================

func _on_online_pressed() -> void:
	if _online_modal:
		return
	_create_online_modal()


func _create_online_modal() -> void:
	_online_modal = Panel.new()
	_online_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.92)
	_online_modal.add_theme_stylebox_override("panel", bg)
	add_child(_online_modal)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_online_modal.add_child(center)

	var content := PanelContainer.new()
	var box_sb := StyleBoxFlat.new()
	box_sb.bg_color = Color(0.05, 0.05, 0.08)
	box_sb.border_color = Color(0.3, 0.5, 1.0)
	box_sb.set_border_width_all(2)
	box_sb.set_corner_radius_all(12)
	box_sb.content_margin_left = 16
	box_sb.content_margin_right = 16
	box_sb.content_margin_top = 12
	box_sb.content_margin_bottom = 12
	content.add_theme_stylebox_override("panel", box_sb)
	content.custom_minimum_size = Vector2(700, 850)
	center.add_child(content)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	content.add_child(vbox)

	var title := Label.new()
	title.text = "TRASY ONLINE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	vbox.add_child(title)

	var status := Label.new()
	status.name = "StatusLabel"
	status.text = "Ladowanie..."
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 26)
	status.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.name = "TrackListOnline"
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(list_vbox)

	var close_btn := Button.new()
	close_btn.text = "ZAMKNIJ"
	close_btn.custom_minimum_size = Vector2(0, 50)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.focus_mode = Control.FOCUS_NONE
	var close_sb := StyleBoxFlat.new()
	close_sb.bg_color = Color(0.2, 0.05, 0.05)
	close_sb.border_color = Color(0.8, 0.2, 0.2)
	close_sb.set_border_width_all(1)
	close_sb.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("normal", close_sb)
	close_btn.pressed.connect(func(): _online_modal.queue_free(); _online_modal = null)
	vbox.add_child(close_btn)

	ApiClient.get_track_list(func(server_tracks: Array):
		status.text = "%d tras online" % server_tracks.size()
		_populate_online_tracks(list_vbox, server_tracks)
	)


func _populate_online_tracks(container: VBoxContainer, server_tracks: Array) -> void:
	for child in container.get_children():
		child.queue_free()

	for t in server_tracks:
		var track_id: int = int(t.get("id", 0))
		var track_name: String = str(t.get("name", "???"))
		var author: String = str(t.get("author", ""))
		var author_nat: String = str(t.get("author_nationality", ""))
		var pieces_count: int = int(t.get("piece_count", 0))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 60)

		var info := Label.new()
		info.text = "%s  (%d kl.)\n%s [%s]" % [track_name, pieces_count, author, author_nat]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override("font_size", 24)
		info.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(info)

		var is_local: bool = track_name in tracks
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 56)
		btn.add_theme_font_size_override("font_size", 26)
		btn.focus_mode = Control.FOCUS_NONE

		btn.text = "GRAJ" if is_local else "POBIERZ"
		var btn_sb := StyleBoxFlat.new()
		btn_sb.bg_color = Color(0.1, 0.35, 0.1) if is_local else Color(0.1, 0.15, 0.35)
		btn_sb.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", btn_sb)
		# Always download fresh version before playing (track may have been updated via web editor)
		btn.pressed.connect(_download_and_play.bind(track_id, track_name, btn))

		row.add_child(btn)
		container.add_child(row)


func _download_track(track_id: int, track_name: String, btn: Button) -> void:
	btn.text = "..."
	btn.disabled = true

	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray):
		if code != 200:
			btn.text = "BLAD"
			btn.disabled = false
			req.queue_free()
			return

		var json: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not json or not json.has("track_json"):
			btn.text = "BLAD"
			btn.disabled = false
			req.queue_free()
			return

		var track_json: Array = json["track_json"]
		var pieces: Array[Dictionary] = []
		for entry in track_json:
			pieces.append({
				"grid": Vector2i(int(entry.get("gx", 0)), int(entry.get("gz", 0))),
				"piece": int(entry.get("piece", 0)),
				"rotation": int(entry.get("rotation", 0)),
				"base_height": int(entry.get("bh", 0)),
				"down": bool(entry.get("down", 0)),
			})
		TrackData.save_track(track_name, pieces)
		TrackData.set_server_id(track_name, track_id)

		btn.text = "GRAJ"
		btn.disabled = false
		var play_sb := StyleBoxFlat.new()
		play_sb.bg_color = Color(0.1, 0.35, 0.1)
		play_sb.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", play_sb)

		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn.callable)
		btn.pressed.connect(_download_and_play.bind(track_id, track_name, btn))

		tracks.append(track_name)
		_update_status()

		req.queue_free()
	)
	req.request(ApiClient.API_BASE + "/tracks/%d" % track_id)


func _download_and_play(track_id: int, track_name: String, btn: Button) -> void:
	btn.text = "..."
	btn.disabled = true

	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray):
		req.queue_free()
		if code != 200:
			btn.text = "BLAD"
			btn.disabled = false
			return

		var json: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not json or not json.has("track_json"):
			btn.text = "BLAD"
			btn.disabled = false
			return

		var track_json: Array = json["track_json"]
		var pieces: Array[Dictionary] = []
		for entry in track_json:
			pieces.append({
				"grid": Vector2i(int(entry.get("gx", 0)), int(entry.get("gz", 0))),
				"piece": int(entry.get("piece", 0)),
				"rotation": int(entry.get("rotation", 0)),
				"base_height": int(entry.get("bh", 0)),
				"down": bool(entry.get("down", 0)),
			})
		TrackData.save_track(track_name, pieces)
		TrackData.set_server_id(track_name, track_id)

		TrackData.current_track = track_name
		TrackData.current_server_id = track_id
		RaceManager.set_track_id(track_id)
		if _online_modal:
			_online_modal.queue_free()
			_online_modal = null
		get_tree().change_scene_to_file("res://race.tscn")
	)
	req.request(ApiClient.API_BASE + "/tracks/%d" % track_id)


# =============================================================================
# FLAG PICKER
# =============================================================================

func _update_flag_button() -> void:
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
	var box_sb := StyleBoxFlat.new()
	box_sb.bg_color = Color(0.05, 0.05, 0.08)
	box_sb.border_color = Color(0.3, 0.6, 0.9)
	box_sb.set_border_width_all(2)
	box_sb.set_corner_radius_all(12)
	box_sb.content_margin_left = 16
	box_sb.content_margin_right = 16
	box_sb.content_margin_top = 12
	box_sb.content_margin_bottom = 12
	content.add_theme_stylebox_override("panel", box_sb)
	content.custom_minimum_size = Vector2(500, 600)
	center.add_child(content)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	content.add_child(vbox)

	var title := Label.new()
	title.text = "WYBIERZ FLAGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	vbox.add_child(title)

	var search := LineEdit.new()
	search.placeholder_text = "Szukaj kraju..."
	search.add_theme_font_size_override("font_size", 24)
	var search_sb := StyleBoxFlat.new()
	search_sb.bg_color = Color(0.08, 0.08, 0.12)
	search_sb.border_color = Color(0.3, 0.5, 0.8)
	search_sb.set_border_width_all(1)
	search_sb.set_corner_radius_all(6)
	search.add_theme_stylebox_override("normal", search_sb)
	vbox.add_child(search)

	var none_btn := Button.new()
	none_btn.text = "BEZ FLAGI"
	none_btn.custom_minimum_size = Vector2(0, 44)
	none_btn.add_theme_font_size_override("font_size", 22)
	none_btn.focus_mode = Control.FOCUS_NONE
	none_btn.pressed.connect(_on_flag_selected.bind(""))
	vbox.add_child(none_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	_populate_flag_grid(grid, FlagData.COUNTRIES)

	search.text_changed.connect(func(text: String):
		_populate_flag_grid(grid, FlagData.search_countries(text))
	)

	var close_btn := Button.new()
	close_btn.text = "ZAMKNIJ"
	close_btn.custom_minimum_size = Vector2(0, 44)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.focus_mode = Control.FOCUS_NONE
	var close_sb := StyleBoxFlat.new()
	close_sb.bg_color = Color(0.2, 0.05, 0.05)
	close_sb.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("normal", close_sb)
	close_btn.pressed.connect(func(): flag_modal.queue_free(); flag_modal = null)
	vbox.add_child(close_btn)


func _populate_flag_grid(grid: GridContainer, countries: Array) -> void:
	for child in grid.get_children():
		child.queue_free()

	for country in countries:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(80, 50)
		btn.tooltip_text = country["name"]
		btn.focus_mode = Control.FOCUS_NONE

		var btn_sb := StyleBoxFlat.new()
		btn_sb.bg_color = Color(0.08, 0.08, 0.12)
		btn_sb.border_color = Color(0.15, 0.15, 0.2)
		btn_sb.set_border_width_all(1)
		btn_sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", btn_sb)

		var hover_sb := StyleBoxFlat.new()
		hover_sb.bg_color = Color(0.12, 0.18, 0.28)
		hover_sb.border_color = Color(0.3, 0.6, 0.9)
		hover_sb.set_border_width_all(1)
		hover_sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("hover", hover_sb)

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
			flag_rect.custom_minimum_size = Vector2(36, 22)
			flag_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			flag_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bvbox.add_child(flag_rect)

		var code_lbl := Label.new()
		code_lbl.text = country["code"]
		code_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		code_lbl.add_theme_font_size_override("font_size", 11)
		code_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		code_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bvbox.add_child(code_lbl)

		btn.pressed.connect(_on_flag_selected.bind(country["code"]))
		grid.add_child(btn)


func _on_flag_selected(code: String) -> void:
	PlayerData.player_flag = code
	PlayerData.save()
	_update_flag_button()
	if flag_modal:
		flag_modal.queue_free()
		flag_modal = null


# =============================================================================
# PLAYER REGISTRATION
# =============================================================================

func _on_nick_submitted(new_name: String) -> void:
	new_name = new_name.strip_edges()
	if new_name.is_empty() or new_name == PlayerData.player_name:
		return
	PlayerData.player_name = new_name
	PlayerData.save()
	# Re-register with new name on server
	ApiClient.register(new_name, PlayerData.player_flag, func(success, reason = ""):
		if success:
			_set_status("Nick: %s" % new_name)
			_update_status()
		elif reason == "reserved":
			_prompt_admin_password()
		else:
			_set_status("Nie mozna zmienic nicku")
	)


func _auto_register_player() -> void:
	if PlayerData.player_name.is_empty():
		return
	# Always register — updates name on server if changed
	ApiClient.register(PlayerData.player_name, PlayerData.player_flag, func(success, reason = ""):
		if success:
			print("Player registered/updated: %s (id: %s)" % [ApiClient.player_name, ApiClient.player_id])
		elif str(reason) == "reserved":
			print("Name reserved — prompting for password")
			call_deferred("_prompt_admin_password")
		else:
			print("Registration result: success=%s reason=%s" % [success, reason])
	)

func _prompt_admin_password() -> void:
	# Show password dialog for reserved name login
	var dialog := AcceptDialog.new()
	dialog.title = "Zarezerwowany nick"
	dialog.dialog_text = "Nick '%s' jest zarezerwowany.\nPodaj haslo admina:" % PlayerData.player_name
	var line := LineEdit.new()
	line.placeholder_text = "haslo"
	line.secret = true
	line.custom_minimum_size = Vector2(300, 50)
	line.add_theme_font_size_override("font_size", 28)
	dialog.add_child(line)
	dialog.confirmed.connect(func():
		var pw: String = line.text.strip_edges()
		if pw.is_empty():
			dialog.queue_free()
			return
		ApiClient.register(PlayerData.player_name, PlayerData.player_flag, func(success, reason = ""):
			if success:
				print("Admin login OK: %s (%s)" % [ApiClient.player_name, ApiClient.player_id])
				PlayerData.player_name = ApiClient.player_name
				PlayerData.save_data()
				_set_status("Zalogowano jako admin!")
			else:
				_set_status("Bledne haslo!")
			dialog.queue_free()
		, pw)
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _set_status(text: String) -> void:
	if _status_label:
		if text.is_empty():
			_update_status()
		else:
			_status_label.text = text


# =============================================================================
# LINK TO WEB
# =============================================================================

var _link_modal: Control

func _show_link_code_modal(code: String) -> void:
	if _link_modal:
		_link_modal.queue_free()

	_link_modal = Panel.new()
	_link_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.92)
	_link_modal.add_theme_stylebox_override("panel", bg)
	add_child(_link_modal)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_link_modal.add_child(center)

	var content := PanelContainer.new()
	var box_sb := StyleBoxFlat.new()
	box_sb.bg_color = Color(0.05, 0.05, 0.08)
	box_sb.border_color = Color(0.6, 0.4, 1.0)
	box_sb.set_border_width_all(2)
	box_sb.set_corner_radius_all(12)
	box_sb.content_margin_left = 32
	box_sb.content_margin_right = 32
	box_sb.content_margin_top = 24
	box_sb.content_margin_bottom = 24
	content.add_theme_stylebox_override("panel", box_sb)
	content.custom_minimum_size = Vector2(500, 400)
	center.add_child(content)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(vbox)

	var title := Label.new()
	title.text = "POLACZ Z WEB"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.6, 0.4, 1.0))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Wpisz ten kod w edytorze\nw przegladarce:"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 26)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vbox.add_child(desc)

	var code_label := Label.new()
	code_label.text = code
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var code_s := LabelSettings.new()
	code_s.font_size = 72
	code_s.font_color = Color(1.0, 0.9, 0.2)
	code_s.outline_size = 4
	code_s.outline_color = Color(0.2, 0.15, 0.0)
	code_label.label_settings = code_s
	vbox.add_child(code_label)

	var timer_label := Label.new()
	timer_label.text = "Wazny 5 minut"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	vbox.add_child(timer_label)

	var close_btn := Button.new()
	close_btn.text = "ZAMKNIJ"
	close_btn.custom_minimum_size = Vector2(0, 56)
	close_btn.add_theme_font_size_override("font_size", 26)
	close_btn.focus_mode = Control.FOCUS_NONE
	var close_sb := StyleBoxFlat.new()
	close_sb.bg_color = Color(0.2, 0.05, 0.05)
	close_sb.border_color = Color(0.8, 0.2, 0.2)
	close_sb.set_border_width_all(1)
	close_sb.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("normal", close_sb)
	close_btn.pressed.connect(func(): _link_modal.queue_free(); _link_modal = null)
	vbox.add_child(close_btn)
