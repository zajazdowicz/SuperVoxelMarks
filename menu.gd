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
	# Force full screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	# No separate bg — SubViewport fills entire background

	# Scrollable root
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	scroll.add_child(root)

	# --- SPINNING CAR BACKGROUND ---
	_setup_spinning_car()

	# --- TOP SPACER ---
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.custom_minimum_size = Vector2(0, 20)
	root.add_child(top_spacer)

	# --- LOGO ---
	var logo_section := _build_logo()
	root.add_child(logo_section)

	# --- PLAYER ROW ---
	var player_section := _build_player_row()
	root.add_child(player_section)

	# --- MID SPACER ---
	var mid_spacer := Control.new()
	mid_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_spacer.custom_minimum_size = Vector2(0, 10)
	root.add_child(mid_spacer)

	# --- MAIN BUTTONS ---
	var buttons := _build_main_buttons()
	root.add_child(buttons)

	# --- SECONDARY BUTTONS ---
	var secondary := _build_secondary_buttons()
	root.add_child(secondary)

	# --- BOTTOM SPACER ---
	var bot_spacer := Control.new()
	bot_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bot_spacer.custom_minimum_size = Vector2(0, 10)
	root.add_child(bot_spacer)

	# --- FOOTER ---
	var footer := _build_footer()
	root.add_child(footer)


func _build_logo() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 10)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title — big voxel style
	var title := Label.new()
	title.text = "RC TRICK MANIA X"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_s := LabelSettings.new()
	title_s.font_size = 58
	title_s.font_color = Color(1.0, 0.9, 0.52)
	title_s.outline_size = 6
	title_s.outline_color = Color(0.7, 0.37, 0.1)
	title.label_settings = title_s
	vbox.add_child(title)

	# Subtitle pill
	var sub_row := HBoxContainer.new()
	sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(sub_row)

	var sub_btn := Button.new()
	sub_btn.text = "  VOXEL RACING  "
	sub_btn.disabled = true
	sub_btn.custom_minimum_size = Vector2(0, 36)
	sub_btn.add_theme_font_size_override("font_size", 16)
	sub_btn.add_theme_color_override("font_disabled_color", Color(0.53, 0.8, 1.0))
	var sub_sb := StyleBoxFlat.new()
	sub_sb.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	sub_sb.set_corner_radius_all(20)
	sub_sb.content_margin_left = 16.0
	sub_sb.content_margin_right = 16.0
	sub_btn.add_theme_stylebox_override("disabled", sub_sb)
	sub_row.add_child(sub_btn)

	return margin


func _build_player_row() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)

	var player_row := HBoxContainer.new()
	player_row.alignment = BoxContainer.ALIGNMENT_CENTER
	player_row.add_theme_constant_override("separation", 8)
	margin.add_child(player_row)

	name_input = LineEdit.new()
	name_input.text = PlayerData.player_name
	name_input.placeholder_text = "Enter nickname"
	name_input.max_length = 15
	name_input.custom_minimum_size = Vector2(320, 56)
	name_input.add_theme_font_size_override("font_size", 28)
	var input_sb := StyleBoxFlat.new()
	input_sb.bg_color = Color(0.08, 0.08, 0.12)
	input_sb.border_color = Color(0.3, 0.5, 0.8)
	input_sb.set_border_width_all(1)
	input_sb.set_corner_radius_all(12)
	input_sb.content_margin_left = 14.0
	input_sb.content_margin_right = 14.0
	name_input.add_theme_stylebox_override("normal", input_sb)
	name_input.text_changed.connect(func(t: String): PlayerData.player_name = t; PlayerData.save())
	player_row.add_child(name_input)

	var nick_ok := Button.new()
	nick_ok.text = "OK"
	nick_ok.custom_minimum_size = Vector2(70, 56)
	nick_ok.add_theme_font_size_override("font_size", 26)
	var ok_sb := StyleBoxFlat.new()
	ok_sb.bg_color = Color(0.12, 0.35, 0.12)
	ok_sb.set_corner_radius_all(12)
	nick_ok.add_theme_stylebox_override("normal", ok_sb)
	nick_ok.pressed.connect(func(): _on_nick_submitted(name_input.text))
	player_row.add_child(nick_ok)

	flag_button = Button.new()
	flag_button.custom_minimum_size = Vector2(80, 56)
	flag_button.add_theme_font_size_override("font_size", 28)
	var flag_sb := StyleBoxFlat.new()
	flag_sb.bg_color = Color(0.08, 0.08, 0.12)
	flag_sb.border_color = Color(0.3, 0.5, 0.8)
	flag_sb.set_border_width_all(1)
	flag_sb.set_corner_radius_all(12)
	flag_button.add_theme_stylebox_override("normal", flag_sb)
	flag_button.focus_mode = Control.FOCUS_NONE
	flag_button.pressed.connect(_on_flag_pressed)
	player_row.add_child(flag_button)
	_update_flag_button()

	return margin


func _build_main_buttons() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 10)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	# PLAY — primary CTA, oversized
	var play_btn := UIStyle.primary_button("PLAY", UIStyle.ORANGE)
	play_btn.custom_minimum_size = Vector2(0, 130)
	play_btn.add_theme_font_size_override("font_size", 48)
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_btn.focus_mode = Control.FOCUS_NONE
	play_btn.pressed.connect(_on_track_picker)
	vbox.add_child(play_btn)

	# ONLINE TRACKS + EDITOR — row of two
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	vbox.add_child(row)

	var online_btn := UIStyle.primary_button("ONLINE TRACKS", UIStyle.PURPLE)
	online_btn.custom_minimum_size = Vector2(0, 100)
	online_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	online_btn.focus_mode = Control.FOCUS_NONE
	online_btn.add_theme_font_size_override("font_size", 28)
	online_btn.pressed.connect(_on_online_pressed)
	row.add_child(online_btn)

	var editor_btn := UIStyle.primary_button("EDITOR", UIStyle.CYAN)
	editor_btn.custom_minimum_size = Vector2(0, 100)
	editor_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_btn.focus_mode = Control.FOCUS_NONE
	editor_btn.add_theme_font_size_override("font_size", 32)
	editor_btn.pressed.connect(_on_editor)
	row.add_child(editor_btn)

	return margin


func _build_secondary_buttons() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 20)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var rnd := UIStyle.ghost_button("RANDOM TRACK", UIStyle.GOLD)
	rnd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rnd.focus_mode = Control.FOCUS_NONE
	rnd.pressed.connect(_on_generate_and_play)
	row.add_child(rnd)

	var lnk := UIStyle.ghost_button("WEB LINK", UIStyle.CYAN)
	lnk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lnk.focus_mode = Control.FOCUS_NONE
	lnk.pressed.connect(_on_link_web)
	row.add_child(lnk)

	return margin


func _make_big_btn(title: String, color_top: Color, color_bot: Color, accent: Color, border_w: int, callback: Callable, is_main: bool = false) -> Button:
	var btn := Button.new()
	var h: int = 130 if is_main else 100
	btn.custom_minimum_size = Vector2(0, h)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE

	var sb := StyleBoxFlat.new()
	sb.bg_color = color_top
	sb.set_corner_radius_all(20)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.3)
	sb.border_width_left = border_w
	sb.set_border_width_all(1)
	sb.border_width_left = border_w
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	sb.shadow_color = Color(0.04, 0.06, 0.1, 1.0)
	sb.shadow_size = 12
	btn.add_theme_stylebox_override("normal", sb)

	var sb_p := sb.duplicate()
	sb_p.bg_color = color_top.lightened(0.15)
	sb_p.shadow_size = 4
	btn.add_theme_stylebox_override("pressed", sb_p)

	# Label centered
	var lbl := Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font_size = 34 if is_main else 28
	ls.font_color = accent
	ls.outline_size = 3
	ls.outline_color = Color(0, 0, 0, 0.5)
	lbl.label_settings = ls
	btn.add_child(lbl)

	btn.pressed.connect(callback)
	return btn


func _make_pill_btn(title: String, accent: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 56)
	btn.focus_mode = Control.FOCUS_NONE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.12, 0.22, 0.85)
	sb.set_corner_radius_all(30)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.6)
	sb.set_border_width_all(1)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.shadow_color = Color(0.01, 0.02, 0.05, 1.0)
	sb.shadow_size = 5
	btn.add_theme_stylebox_override("normal", sb)

	var sb_p := sb.duplicate()
	sb_p.bg_color = Color(0.12, 0.16, 0.28)
	sb_p.shadow_size = 1
	btn.add_theme_stylebox_override("pressed", sb_p)

	btn.text = title
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", accent)

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
	content.custom_minimum_size = Vector2(1020, 900)
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
		empty.text = "No tracks.\nUse RANDOM TRACK or EDITOR."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 28)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		list.add_child(empty)
	else:
		for i in range(tracks.size()):
			var tname := tracks[i]
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(0, 76)
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

			# Medal badge prefix
			var medal: String = TrackData.get_medal(tname)
			var badge: String = ""
			match medal:
				"author": badge = "[A]"
				"gold":   badge = "[G]"
				"silver": badge = "[S]"
				"bronze": badge = "[B]"
				_:        badge = "[ ]"

			btn.text = "  %s  %s%s%s" % [badge, tname, time_tag, online_tag]
			var medal_c: Color = TrackData.medal_color(medal)

			var sb := StyleBoxFlat.new()
			sb.bg_color = colors[i % colors.size()]
			sb.set_corner_radius_all(8)
			sb.content_margin_left = 12
			sb.content_margin_right = 12
			sb.border_width_left = 8
			sb.border_color = medal_c
			btn.add_theme_stylebox_override("normal", sb)

			var sb_press := sb.duplicate()
			sb_press.bg_color = sb.bg_color.lightened(0.15)
			btn.add_theme_stylebox_override("pressed", sb_press)

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
	del_btn.text = "DELETE"
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


func _on_generate_and_edit() -> void:
	var length: int = randi_range(18, 30)
	var gen_name := "gen_%d" % (randi() % 9999)
	TrackGenerator.generate(length, gen_name, randi())
	get_tree().change_scene_to_file("res://editor.tscn")


func _on_link_web() -> void:
	if not ApiClient.is_registered():
		_set_status("Najpierw wpisz nick!")
		return

	# Ensure we have auth token, then generate link code
	_set_status("Laczenie...")
	ApiClient.ensure_auth(func(success: bool):
		if not success:
			_set_status("Auth error")
			return
		ApiClient.generate_link_code(func(ok: bool, code: String):
			if ok:
				_show_link_code_modal(code)
				_set_status("")
			else:
				_set_status("Code generation error")
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
				var at_ms := int(json.get("author_time_ms", 0))
				if at_ms > 0:
					TrackData.set_author_time(daily_name, float(at_ms) / 1000.0)
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
	content.custom_minimum_size = Vector2(1020, 900)
	center.add_child(content)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	content.add_child(vbox)

	var title := Label.new()
	title.text = "ONLINE TRACKS"
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

		btn.text = "PLAY" if is_local else "DOWNLOAD"
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
		var at_ms1 := int(json.get("author_time_ms", 0))
		if at_ms1 > 0:
			TrackData.set_author_time(track_name, float(at_ms1) / 1000.0)

		btn.text = "PLAY"
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
		var at_ms2 := int(json.get("author_time_ms", 0))
		if at_ms2 > 0:
			TrackData.set_author_time(track_name, float(at_ms2) / 1000.0)

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
		rect.custom_minimum_size = Vector2(48, 30)
		rect.size = Vector2(48, 30)
		rect.position = Vector2(10, 8)
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
	content.custom_minimum_size = Vector2(700, 750)
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
	grid.columns = 4
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
		btn.custom_minimum_size = Vector2(100, 64)
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
			flag_rect.custom_minimum_size = Vector2(48, 30)
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
	var overlay := Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.9)
	overlay.add_theme_stylebox_override("panel", bg)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(600, 400)
	var box_sb := StyleBoxFlat.new()
	box_sb.bg_color = Color(0.06, 0.06, 0.1)
	box_sb.border_color = Color(0.6, 0.4, 1.0)
	box_sb.set_border_width_all(2)
	box_sb.set_corner_radius_all(12)
	box_sb.content_margin_left = 32.0
	box_sb.content_margin_right = 32.0
	box_sb.content_margin_top = 24.0
	box_sb.content_margin_bottom = 24.0
	box.add_theme_stylebox_override("panel", box_sb)
	center.add_child(box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(vbox)

	var title := Label.new()
	title.text = "ZAREZERWOWANY NICK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.6, 0.4, 1.0))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Nick '%s' jest zarezerwowany.\nPodaj haslo:" % PlayerData.player_name
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 24)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vbox.add_child(desc)

	var line := LineEdit.new()
	line.placeholder_text = "haslo"
	line.secret = true
	line.custom_minimum_size = Vector2(400, 60)
	line.add_theme_font_size_override("font_size", 32)
	var input_sb := StyleBoxFlat.new()
	input_sb.bg_color = Color(0.1, 0.1, 0.15)
	input_sb.border_color = Color(0.3, 0.5, 0.8)
	input_sb.set_border_width_all(1)
	input_sb.set_corner_radius_all(8)
	input_sb.content_margin_left = 12.0
	input_sb.content_margin_right = 12.0
	line.add_theme_stylebox_override("normal", input_sb)
	vbox.add_child(line)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var ok_btn := Button.new()
	ok_btn.text = "ZALOGUJ"
	ok_btn.custom_minimum_size = Vector2(200, 56)
	ok_btn.add_theme_font_size_override("font_size", 26)
	var ok_sb := StyleBoxFlat.new()
	ok_sb.bg_color = Color(0.15, 0.5, 0.2)
	ok_sb.set_corner_radius_all(8)
	ok_btn.add_theme_stylebox_override("normal", ok_sb)
	btn_row.add_child(ok_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "ANULUJ"
	cancel_btn.custom_minimum_size = Vector2(200, 56)
	cancel_btn.add_theme_font_size_override("font_size", 26)
	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color(0.3, 0.1, 0.1)
	c_sb.set_corner_radius_all(8)
	cancel_btn.add_theme_stylebox_override("normal", c_sb)
	btn_row.add_child(cancel_btn)

	cancel_btn.pressed.connect(func(): overlay.queue_free())

	ok_btn.pressed.connect(func():
		var pw: String = line.text.strip_edges()
		if pw.is_empty():
			return
		ok_btn.text = "..."
		ok_btn.disabled = true
		ApiClient.register(PlayerData.player_name, PlayerData.player_flag, func(success, reason = ""):
			if success:
				print("Admin login OK: %s (%s)" % [ApiClient.player_name, ApiClient.player_id])
				PlayerData.player_name = ApiClient.player_name
				PlayerData.save()
				_set_status("Zalogowano jako admin!")
			else:
				_set_status("Bledne haslo!")
				ok_btn.text = "ZALOGUJ"
				ok_btn.disabled = false
				return
			overlay.queue_free()
		, pw)
	)


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
	desc.text = "Enter this code in the web editor:"
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


# =============================================================================
# SPINNING CAR IN BACKGROUND
# =============================================================================

var _bg_scene: Node3D
var _bg_cars: Array[Dictionary] = []  # {node, speed, yaw, drift_timer, wheels}
var _bg_spawn_timer := 0.0
var _f1_scene: PackedScene
const BG_AREA := 35.0  # spawn radius — beyond camera view
const BG_DESPAWN := 42.0  # despawn only well beyond view
const BG_MAX_CARS := 12
const BG_SPAWN_INTERVAL := 0.5

func _setup_spinning_car() -> void:
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	move_child(svc, 0)  # background layer, UI on top

	var svp := SubViewport.new()
	svp.size = Vector2i(540, 960)
	svp.transparent_bg = false
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(svp)

	_bg_scene = Node3D.new()
	svp.add_child(_bg_scene)

	# World environment: retrowave sunset gradient sky + bloom
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	var sky_shader := Shader.new()
	sky_shader.code = """
shader_type sky;
void sky() {
	vec3 dir = EYEDIR;
	float y = dir.y * 0.5 + 0.5;
	vec3 top = vec3(0.02, 0.01, 0.08);
	vec3 mid = vec3(0.35, 0.05, 0.45);
	vec3 horizon = vec3(1.0, 0.35, 0.45);
	vec3 col;
	if (y > 0.6) {
		float t = smoothstep(0.6, 1.0, y);
		col = mix(mid, top, t);
	} else {
		float t = smoothstep(0.35, 0.6, y);
		col = mix(horizon, mid, t);
	}
	// Sun disk
	float sun = smoothstep(0.985, 0.999, max(0.0, dot(dir, normalize(vec3(0.0, 0.15, -1.0)))));
	col = mix(col, vec3(1.0, 0.8, 0.4), sun);
	COLOR = col;
}
"""
	sky_mat.shader = sky_shader
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.4
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.0
	env.glow_bloom = 0.3
	world_env.environment = env
	_bg_scene.add_child(world_env)

	# Camera — lower angle for retrowave dramatic look
	var cam := Camera3D.new()
	cam.position = Vector3(0, 6, 12)
	cam.rotation_degrees = Vector3(-18, 0, 0)
	cam.fov = 55
	cam.current = true
	_bg_scene.add_child(cam)

	# Lights with shadows
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	light.shadow_blur = 1.5
	light.directional_shadow_max_distance = 30.0
	_bg_scene.add_child(light)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, -150, 0)
	fill.light_energy = 0.4
	_bg_scene.add_child(fill)

	var ambient := OmniLight3D.new()
	ambient.position = Vector3(0, 10, 0)
	ambient.light_energy = 0.2
	ambient.omni_range = 40.0
	_bg_scene.add_child(ambient)

	# Neon retrowave grid ground — scrolls toward camera
	var ground := MeshInstance3D.new()
	var gplane := PlaneMesh.new()
	gplane.size = Vector2(200, 200)
	gplane.subdivide_width = 1
	gplane.subdivide_depth = 1
	ground.mesh = gplane
	var gshader := Shader.new()
	gshader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Grid in world space, 2 units per cell
	vec2 g_uv = world_pos.xz * 0.5;
	// Scroll toward camera along Z
	g_uv.y += TIME * 2.0;
	// Anti-aliased grid lines using screen-space derivatives
	vec2 g = abs(fract(g_uv - 0.5) - 0.5);
	vec2 fw = fwidth(g_uv);
	float line_x = 1.0 - smoothstep(0.0, fw.x * 1.2, g.x);
	float line_y = 1.0 - smoothstep(0.0, fw.y * 1.2, g.y);
	float grid = max(line_x, line_y);
	// Distance-based fade from camera
	float dist = length(world_pos.xz - (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz);
	float fade = 1.0 - smoothstep(25.0, 90.0, dist);
	float near_fade = smoothstep(0.5, 6.0, dist);  // dim near camera
	fade *= near_fade;
	// Colors — magenta near, violet far
	vec3 base = vec3(0.04, 0.01, 0.08);
	vec3 grid_col = mix(vec3(1.0, 0.2, 0.6), vec3(0.4, 0.3, 1.0), clamp(dist / 60.0, 0.0, 1.0));
	vec3 col = base + grid * grid_col * fade * 2.5;
	ALBEDO = col;
	EMISSION = grid * grid_col * fade * 1.3;
}
"""
	var gmat := ShaderMaterial.new()
	gmat.shader = gshader
	ground.material_override = gmat
	ground.position.y = -0.01
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bg_scene.add_child(ground)

	# Distant silhouette mountains (voxel block cutouts) for horizon depth
	for i in range(8):
		var mtn := MeshInstance3D.new()
		var mbox := BoxMesh.new()
		var mw := randf_range(6.0, 12.0)
		var mh := randf_range(3.0, 7.0)
		mbox.size = Vector3(mw, mh, 2.0)
		mtn.mesh = mbox
		var mmat := StandardMaterial3D.new()
		mmat.albedo_color = Color(0.06, 0.02, 0.12)
		mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mmat.emission_enabled = true
		mmat.emission = Color(0.15, 0.05, 0.3)
		mmat.emission_energy_multiplier = 0.5
		mtn.material_override = mmat
		mtn.position = Vector3(randf_range(-60, 60), mh * 0.5, -randf_range(35, 50))
		_bg_scene.add_child(mtn)

	_f1_scene = load("res://assets/models/f1_car_new.glb")


func _spawn_bg_car() -> void:
	if not _f1_scene or not _bg_scene:
		return

	var car_root := Node3D.new()
	var model := _f1_scene.instantiate()
	model.scale = Vector3(1.0, 1.0, 1.0)
	car_root.add_child(model)
	_bg_scene.add_child(car_root)

	# Random color — tint the body mesh
	var colors := [
		Color(0.9, 0.15, 0.1),   # red
		Color(0.1, 0.4, 0.9),    # blue
		Color(0.1, 0.8, 0.2),    # green
		Color(1.0, 0.6, 0.0),    # orange
		Color(0.9, 0.9, 0.1),    # yellow
		Color(0.7, 0.1, 0.9),    # purple
		Color(0.1, 0.8, 0.8),    # cyan
		Color(0.95, 0.95, 0.95), # white
	]
	var car_color: Color = colors[randi() % colors.size()]
	_tint_model(model, car_color)

	# Find wheels
	var wheels: Array[Node3D] = []
	_find_bg_nodes(model, ["WheelFront.000", "WheelFront.001", "WheelFront.002", "WheelFront.003"], wheels)

	# Drift smoke — GPU particles behind car (matches in-game style)
	var smoke_emitters: Array[GPUParticles3D] = []
	for offset in [Vector3(0.6, 0.15, 1.0), Vector3(-0.6, 0.15, 1.0)]:
		var em := GPUParticles3D.new()
		em.amount = 24
		em.lifetime = 0.7
		em.emitting = false
		em.position = offset
		em.explosiveness = 0.0
		em.speed_scale = 1.5
		em.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 3, 6))
		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 1, 0)
		mat.spread = 25.0
		mat.initial_velocity_min = 0.8
		mat.initial_velocity_max = 2.0
		mat.gravity = Vector3(0, 0.3, 0)
		mat.scale_min = 0.3
		mat.scale_max = 0.7
		mat.color = Color(0.85, 0.85, 0.95, 0.55)
		em.process_material = mat
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.8, 0.8)
		em.draw_pass_1 = mesh
		car_root.add_child(em)
		smoke_emitters.append(em)

	# Random spawn from edge
	var side := randi() % 4  # 0=left, 1=right, 2=top, 3=bottom
	var pos := Vector3.ZERO
	var yaw := 0.0
	match side:
		0:  # from left
			pos = Vector3(-BG_AREA, 0.3, randf_range(-BG_AREA, BG_AREA))
			yaw = randf_range(-0.3, 0.3)
		1:  # from right
			pos = Vector3(BG_AREA, 0.3, randf_range(-BG_AREA, BG_AREA))
			yaw = PI + randf_range(-0.3, 0.3)
		2:  # from top (far)
			pos = Vector3(randf_range(-BG_AREA, BG_AREA), 0.3, -BG_AREA)
			yaw = PI / 2.0 + randf_range(-0.3, 0.3)
		3:  # from bottom (near)
			pos = Vector3(randf_range(-BG_AREA, BG_AREA), 0.3, BG_AREA)
			yaw = -PI / 2.0 + randf_range(-0.3, 0.3)

	car_root.position = pos
	car_root.rotation.y = yaw + PI

	var speed := randf_range(10.0, 18.0)
	var drift_time := randf_range(2.0, 5.0)  # when to start drifting

	# Skidmark mesh — bright cyan glow trails (retrowave style)
	var skid_mesh := ImmediateMesh.new()
	var skid_inst := MeshInstance3D.new()
	skid_inst.mesh = skid_mesh
	var skid_mat := StandardMaterial3D.new()
	skid_mat.albedo_color = Color(0.9, 0.3, 1.0, 0.9)
	skid_mat.emission_enabled = true
	skid_mat.emission = Color(0.9, 0.3, 1.0)
	skid_mat.emission_energy_multiplier = 2.0
	skid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	skid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	skid_mat.no_depth_test = false
	skid_inst.material_override = skid_mat
	skid_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bg_scene.add_child(skid_inst)

	_bg_cars.append({
		"node": car_root,
		"speed": speed,
		"yaw": yaw,
		"drift_timer": drift_time,
		"drift_active": false,
		"drift_dir": 1.0 if randf() > 0.5 else -1.0,
		"drift_angle": 0.0,
		"drift_target": TAU,
		"wheels": wheels,
		"wheel_spin": 0.0,
		"lifetime": 0.0,
		"skid_mesh": skid_mesh,
		"skid_inst": skid_inst,
		"skid_points": [],
		"last_pos": pos,
		"smoke_emitters": smoke_emitters,
	})


func _tint_model(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		# Only tint body parts (orange/glossy), not wheels (black)
		if "black" not in String(mi.name) and "Glass" not in String(mi.name):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			mat.roughness = 0.4
			mat.metallic = 0.2
			mi.material_override = mat
	for child in node.get_children():
		_tint_model(child, color)


func _find_bg_nodes(root: Node, names: Array, result: Array[Node3D]) -> void:
	if root is Node3D and String(root.name) in names:
		result.append(root)
	for child in root.get_children():
		_find_bg_nodes(child, names, result)


func _process(delta: float) -> void:
	if not _bg_scene:
		return

	# Spawn new cars
	_bg_spawn_timer -= delta
	if _bg_spawn_timer <= 0 and _bg_cars.size() < BG_MAX_CARS:
		_spawn_bg_car()
		_bg_spawn_timer = BG_SPAWN_INTERVAL + randf_range(-0.5, 0.5)

	# Update cars
	var to_remove: Array[int] = []
	for i in range(_bg_cars.size()):
		var c: Dictionary = _bg_cars[i]
		var node: Node3D = c.node
		c.lifetime += delta

		# Movement
		var move_dir := Vector3(sin(c.yaw), 0, cos(c.yaw))
		var spd: float = c.speed

		# Drift/donut after timer
		c.drift_timer -= delta
		if c.drift_timer <= 0 and not c.drift_active:
			c.drift_active = true
			c.drift_angle = 0.0  # track total rotation
			# 50% chance: full donut (360°), 50%: sharp turn (~90°)
			c.drift_target = TAU if randf() > 0.5 else (PI * 0.5)

		if c.drift_active:
			var turn_speed := 4.0 if c.drift_target >= TAU else 2.5
			c.yaw += c.drift_dir * turn_speed * delta
			c.drift_angle += turn_speed * delta
			spd *= 0.5
			move_dir = Vector3(sin(c.yaw), 0, cos(c.yaw))
			# Body sideways during drift
			node.rotation.y = c.yaw + PI + c.drift_dir * 0.6
			# Done spinning?
			if c.drift_angle >= c.drift_target:
				c.drift_active = false
				c.drift_timer = randf_range(1.5, 4.0)
				c.drift_dir = [-1.0, 1.0][randi() % 2]
		else:
			node.rotation.y = c.yaw + PI

		node.position += move_dir * spd * delta

		# Wheel spin
		c.wheel_spin += spd * 2.0 * delta
		for w in c.wheels:
			w.rotation.x = c.wheel_spin

		# Smoke emitters — active during drift
		if c.has("smoke_emitters"):
			for em in c.smoke_emitters:
				em.emitting = c.drift_active

		# Skidmarks during drift
		if c.drift_active:
			var cur_pos: Vector3 = node.position
			if cur_pos.distance_to(c.last_pos) > 0.3:
				# Add skid point pair (two tire tracks)
				var right := Vector3(sin(c.yaw + PI / 2.0), 0, cos(c.yaw + PI / 2.0)) * 0.35
				c.skid_points.append(cur_pos + right)
				c.skid_points.append(cur_pos - right)
				c.last_pos = cur_pos
				# Rebuild skid mesh
				if c.skid_points.size() >= 4:
					_rebuild_skidmarks(c.skid_mesh, c.skid_points)
		else:
			c.last_pos = node.position

		# Despawn if far beyond view bounds
		if absf(node.position.x) > BG_DESPAWN or absf(node.position.z) > BG_DESPAWN:
			to_remove.append(i)

	# Remove despawned
	for i in range(to_remove.size() - 1, -1, -1):
		var idx: int = to_remove[i]
		_bg_cars[idx].node.queue_free()
		_bg_cars[idx].skid_inst.queue_free()
		_bg_cars.remove_at(idx)


func _rebuild_skidmarks(imesh: ImmediateMesh, points: Array) -> void:
	imesh.clear_surfaces()
	if points.size() < 4:
		return
	imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(0, points.size(), 2):
		var p1: Vector3 = points[i]
		var p2: Vector3 = points[i + 1] if i + 1 < points.size() else p1
		p1.y = 0.02
		p2.y = 0.02
		imesh.surface_add_vertex(p1)
		imesh.surface_add_vertex(p2)
	imesh.surface_end()
