extends CanvasLayer
## Race HUD: countdown, lap timer, remaining time, speed, best time, lap list.

var timer_label: Label
var best_label: Label
var remaining_label: Label
var speed_label: Label
var info_label: Label
var countdown_label: Label
var laps_label: Label
var delta_label: Label
var car: CharacterBody3D
var drift_bar: ProgressBar
var drift_label: Label
var _cp_label: Label
var _cp_timer := 0.0
var _finish_overlay: PanelContainer
var _finish_vbox: VBoxContainer
var _finish_shown := false
var _lb_panel: PanelContainer
var _lb_vbox: VBoxContainer
var _lb_loaded := false

var _last_lap_count := 0
var _last_countdown := -1


func _ready() -> void:
	for child in get_parent().get_children():
		if child is CharacterBody3D:
			car = child
			break

	_create_ui()
	RaceManager.reset()
	RaceManager.load_best(TrackData.current_track)


func _create_ui() -> void:
	# Lap timer (top center)
	timer_label = Label.new()
	timer_label.anchor_left = 0.5
	timer_label.anchor_right = 0.5
	timer_label.offset_left = -150.0
	timer_label.offset_right = 150.0
	timer_label.offset_top = 10.0
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var timer_s := LabelSettings.new()
	timer_s.font_size = 68
	timer_s.font_color = Color.WHITE
	timer_s.outline_size = 4
	timer_s.outline_color = Color.BLACK
	timer_label.label_settings = timer_s
	add_child(timer_label)

	# Best time (below timer)
	best_label = Label.new()
	best_label.anchor_left = 0.5
	best_label.anchor_right = 0.5
	best_label.offset_left = -150.0
	best_label.offset_right = 150.0
	best_label.offset_top = 52.0
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var best_s := LabelSettings.new()
	best_s.font_size = 40
	best_s.font_color = Color(0.4, 0.8, 1.0)
	best_s.outline_size = 3
	best_s.outline_color = Color.BLACK
	best_label.label_settings = best_s
	add_child(best_label)

	# Delta vs best (below best time)
	delta_label = Label.new()
	delta_label.anchor_left = 0.5
	delta_label.anchor_right = 0.5
	delta_label.offset_left = -100.0
	delta_label.offset_right = 100.0
	delta_label.offset_top = 76.0
	delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var delta_s := LabelSettings.new()
	delta_s.font_size = 42
	delta_s.font_color = Color(0.3, 1.0, 0.3)
	delta_s.outline_size = 3
	delta_s.outline_color = Color.BLACK
	delta_label.label_settings = delta_s
	add_child(delta_label)

	# Remaining time (top left)
	remaining_label = Label.new()
	remaining_label.offset_left = 10.0
	remaining_label.offset_top = 10.0
	remaining_label.offset_right = 200.0
	var rem_s := LabelSettings.new()
	rem_s.font_size = 44
	rem_s.font_color = Color(0.8, 0.8, 0.8)
	rem_s.outline_size = 3
	rem_s.outline_color = Color.BLACK
	remaining_label.label_settings = rem_s
	add_child(remaining_label)

	# Speed (top right)
	speed_label = Label.new()
	speed_label.anchor_left = 1.0
	speed_label.anchor_right = 1.0
	speed_label.offset_left = -200.0
	speed_label.offset_top = 10.0
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var speed_s := LabelSettings.new()
	speed_s.font_size = 44
	speed_s.font_color = Color(0.8, 0.8, 0.8)
	speed_s.outline_size = 3
	speed_s.outline_color = Color.BLACK
	speed_label.label_settings = speed_s
	add_child(speed_label)

	# Countdown (big center)
	countdown_label = Label.new()
	countdown_label.anchor_left = 0.5
	countdown_label.anchor_right = 0.5
	countdown_label.anchor_top = 0.35
	countdown_label.offset_left = -200.0
	countdown_label.offset_right = 200.0
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cd_s := LabelSettings.new()
	cd_s.font_size = 130
	cd_s.font_color = Color(1.0, 1.0, 1.0)
	cd_s.outline_size = 6
	cd_s.outline_color = Color.BLACK
	countdown_label.label_settings = cd_s
	add_child(countdown_label)

	# Info (center, below countdown)
	info_label = Label.new()
	info_label.anchor_left = 0.5
	info_label.anchor_right = 0.5
	info_label.anchor_top = 0.3
	info_label.offset_left = -200.0
	info_label.offset_right = 200.0
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var info_s := LabelSettings.new()
	info_s.font_size = 52
	info_s.font_color = Color(1.0, 0.9, 0.2)
	info_s.outline_size = 4
	info_s.outline_color = Color.BLACK
	info_label.label_settings = info_s
	add_child(info_label)

	# Laps list (right side)
	laps_label = Label.new()
	laps_label.anchor_left = 1.0
	laps_label.anchor_right = 1.0
	laps_label.offset_left = -250.0
	laps_label.offset_top = 50.0
	laps_label.offset_right = -10.0
	laps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var laps_s := LabelSettings.new()
	laps_s.font_size = 28
	laps_s.font_color = Color(0.7, 0.9, 0.7)
	laps_s.outline_size = 3
	laps_s.outline_color = Color.BLACK
	laps_label.label_settings = laps_s
	add_child(laps_label)

	# --- Checkpoint popup ---
	_cp_label = Label.new()
	_cp_label.anchor_left = 0.5
	_cp_label.anchor_right = 0.5
	_cp_label.offset_left = -200.0
	_cp_label.offset_right = 200.0
	_cp_label.offset_top = 110.0
	_cp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cp_s := LabelSettings.new()
	cp_s.font_size = 38
	cp_s.font_color = Color(0.3, 1.0, 0.3)
	cp_s.outline_size = 3
	cp_s.outline_color = Color.BLACK
	_cp_label.label_settings = cp_s
	_cp_label.visible = false
	add_child(_cp_label)

	# --- Finish overlay ---
	_finish_overlay = PanelContainer.new()
	_finish_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fo_sb := StyleBoxFlat.new()
	fo_sb.bg_color = Color(0.02, 0.02, 0.05, 0.88)
	_finish_overlay.add_theme_stylebox_override("panel", fo_sb)
	_finish_overlay.visible = false
	add_child(_finish_overlay)

	var fo_center := CenterContainer.new()
	fo_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_finish_overlay.add_child(fo_center)

	_finish_vbox = VBoxContainer.new()
	_finish_vbox.add_theme_constant_override("separation", 8)
	_finish_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	fo_center.add_child(_finish_vbox)

	# Connect checkpoint signal
	if not RaceManager.checkpoint_passed.is_connected(_on_checkpoint):
		RaceManager.checkpoint_passed.connect(_on_checkpoint)

	# --- Leaderboard panel (left side) ---
	_create_leaderboard_panel()
	_load_leaderboard()

	# --- Drift progress bar (bottom center) ---
	_create_drift_bar()

	# --- Touch buttons ---
	_create_touch_buttons()

	# --- Touch zone indicators (left/right) ---
	_create_touch_zones()


func _process(_delta: float) -> void:
	countdown_label.text = ""

	match RaceManager.state:
		RaceManager.State.IDLE:
			timer_label.text = "0:00.000"
			remaining_label.text = "2:00"
			info_label.text = ""
		RaceManager.State.COUNTDOWN:
			timer_label.text = "0:00.000"
			remaining_label.text = "2:00"
			info_label.text = ""
			var cd := ceili(RaceManager.countdown_timer)
			if cd > 0:
				countdown_label.text = str(cd)
				if cd >= 3:
					countdown_label.label_settings.font_color = Color(1.0, 0.2, 0.2)
				elif cd == 2:
					countdown_label.label_settings.font_color = Color(1.0, 0.85, 0.2)
				else:
					countdown_label.label_settings.font_color = Color(0.2, 1.0, 0.2)
			else:
				countdown_label.text = "GO!"
				countdown_label.label_settings.font_color = Color(0.2, 1.0, 0.2)
		RaceManager.State.RACING:
			timer_label.text = RaceManager.get_time_string()
			remaining_label.text = RaceManager.get_remaining_string()
			# Hide GO after 1 second
			if RaceManager.race_time < 1.0:
				countdown_label.text = "GO!"
				countdown_label.label_settings.font_color = Color(0.2, 1.0, 0.2)
			# Flash remaining when low
			if RaceManager.race_time > RaceManager.TIME_LIMIT - 30.0:
				remaining_label.label_settings.font_color = Color(1.0, 0.3, 0.3)
			else:
				remaining_label.label_settings.font_color = Color(0.8, 0.8, 0.8)
			# Show new lap info briefly
			if RaceManager.lap_count > _last_lap_count:
				_last_lap_count = RaceManager.lap_count
				_show_lap_complete()
			elif RaceManager.lap_count == 0 and RaceManager.race_time > 1.0:
				info_label.text = ""
		RaceManager.State.TIME_UP:
			timer_label.text = RaceManager.get_time_string()
			remaining_label.text = "0:00"
			info_label.text = "TIME UP!\nLaps: %d" % RaceManager.lap_count
			if RaceManager.best_time < INF:
				info_label.text += "\nBest: %s" % RaceManager.get_time_string(RaceManager.best_time)
			info_label.text += "\nR = restart | ESC = menu"
			info_label.text += "\nTap to continue"
		RaceManager.State.FINISHED:
			var finish_time := RaceManager.get_last_lap_time()
			timer_label.text = RaceManager.get_time_string(finish_time)
			remaining_label.text = ""
			info_label.text = ""
			_show_finish_overlay()

	# Best time (always visible when available)
	if RaceManager.best_time < INF:
		best_label.text = "Best: %s" % RaceManager.get_time_string(RaceManager.best_time)
	else:
		best_label.text = ""

	# Delta vs best (during racing)
	if RaceManager.state == RaceManager.State.RACING and RaceManager.best_time < INF:
		var d: float = RaceManager.lap_time - RaceManager.best_time
		if d >= 0.0:
			delta_label.text = "+%s" % RaceManager.get_time_string(d)
			delta_label.label_settings.font_color = Color(1.0, 0.3, 0.3)
		else:
			delta_label.text = "-%s" % RaceManager.get_time_string(absf(d))
			delta_label.label_settings.font_color = Color(0.3, 1.0, 0.3)
	else:
		delta_label.text = ""

	# Speed + drift indicator
	if car:
		var spd: int = int(abs(car.speed) * 3.6)
		var drift_text := ""
		if car.get("_drifting") and car._drifting:
			var dt: float = car._drift_timer
			if dt >= car.DRIFT_BOOST_TIME:
				drift_text = " BOOST!"
			else:
				drift_text = " DRIFT"
		speed_label.text = "%d km/h%s" % [spd, drift_text]

	# Laps list
	_update_laps_list()

	# Drift bar
	_update_drift_bar()

	# Touch zone visual feedback
	_update_touch_indicators()

	# Checkpoint popup fade
	if _cp_timer > 0:
		_cp_timer -= _delta
		if _cp_timer <= 0:
			_cp_label.visible = false
		elif _cp_timer < 0.5:
			_cp_label.modulate.a = _cp_timer / 0.5
		else:
			_cp_label.modulate.a = 1.0

	# Hide finish overlay on reset
	if RaceManager.state != RaceManager.State.FINISHED and _finish_shown:
		_finish_overlay.visible = false
		_finish_shown = false


func _update_laps_list() -> void:
	if RaceManager.laps.is_empty():
		laps_label.text = ""
		return
	var text := ""
	for i in range(RaceManager.laps.size()):
		var t: float = RaceManager.laps[i]
		var prefix := ""
		if t == RaceManager.best_time:
			prefix = ">> "
		text += "%sLap %d: %s\n" % [prefix, i + 1, RaceManager.get_time_string(t)]
	laps_label.text = text


func _show_lap_complete() -> void:
	var last_time := RaceManager.get_last_lap_time()
	if last_time < 0:
		return
	var msg := "LAP %d: %s" % [RaceManager.lap_count, RaceManager.get_time_string(last_time)]
	if last_time == RaceManager.best_time:
		msg += "\nNEW RECORD!"
	elif RaceManager.best_time < INF:
		var d: float = last_time - RaceManager.best_time
		msg += "\n+%s" % RaceManager.get_time_string(d)
	info_label.text = msg

	# Auto-hide after 3 seconds
	var timer := get_tree().create_timer(3.0)
	var current_lap := RaceManager.lap_count
	timer.timeout.connect(func():
		if RaceManager.lap_count == current_lap:
			info_label.text = ""
	)


# --- Touch controls ---

var _touch_left_indicator: ColorRect
var _touch_right_indicator: ColorRect


func _create_drift_bar() -> void:
	# Container at bottom center
	var container := Control.new()
	container.anchor_left = 0.5
	container.anchor_right = 0.5
	container.anchor_top = 1.0
	container.anchor_bottom = 1.0
	container.offset_left = -80.0
	container.offset_right = 80.0
	container.offset_top = -60.0
	container.offset_bottom = -35.0
	add_child(container)

	# Progress bar
	drift_bar = ProgressBar.new()
	drift_bar.min_value = 0.0
	drift_bar.max_value = 1.0
	drift_bar.value = 0.0
	drift_bar.show_percentage = false
	drift_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.15, 0.15, 0.6)
	bar_bg.corner_radius_top_left = 4
	bar_bg.corner_radius_top_right = 4
	bar_bg.corner_radius_bottom_left = 4
	bar_bg.corner_radius_bottom_right = 4
	drift_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(1.0, 0.5, 0.0, 0.9)
	bar_fill.corner_radius_top_left = 4
	bar_fill.corner_radius_top_right = 4
	bar_fill.corner_radius_bottom_left = 4
	bar_fill.corner_radius_bottom_right = 4
	drift_bar.add_theme_stylebox_override("fill", bar_fill)
	container.add_child(drift_bar)

	# Label above bar
	drift_label = Label.new()
	drift_label.anchor_left = 0.5
	drift_label.anchor_right = 0.5
	drift_label.anchor_top = 1.0
	drift_label.anchor_bottom = 1.0
	drift_label.offset_left = -50.0
	drift_label.offset_right = 50.0
	drift_label.offset_top = -80.0
	drift_label.offset_bottom = -60.0
	drift_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var dl_s := LabelSettings.new()
	dl_s.font_size = 20
	dl_s.font_color = Color(1.0, 0.5, 0.0)
	dl_s.outline_size = 2
	dl_s.outline_color = Color.BLACK
	drift_label.label_settings = dl_s
	add_child(drift_label)

	drift_bar.visible = false
	drift_label.visible = false


func _update_drift_bar() -> void:
	if not car or not car.get("_drifting"):
		drift_bar.visible = false
		drift_label.visible = false
		return

	if car._drifting:
		drift_bar.visible = true
		drift_label.visible = true
		var progress: float = clampf(car._drift_timer / car.DRIFT_BOOST_TIME, 0.0, 1.0)
		drift_bar.value = progress
		if progress >= 1.0:
			drift_label.text = "BOOST!"
			drift_label.label_settings.font_color = Color(0.2, 1.0, 0.2)
			# Change bar color to green
			var fill := drift_bar.get_theme_stylebox("fill") as StyleBoxFlat
			if fill:
				fill.bg_color = Color(0.2, 1.0, 0.2, 0.9)
		else:
			drift_label.text = "DRIFT"
			drift_label.label_settings.font_color = Color(1.0, 0.5, 0.0)
			var fill := drift_bar.get_theme_stylebox("fill") as StyleBoxFlat
			if fill:
				fill.bg_color = Color(1.0, 0.5, 0.0, 0.9)
	else:
		drift_bar.visible = false
		drift_label.visible = false


func _create_touch_buttons() -> void:
	# RESET button (top right corner, below speed)
	var reset_btn := Button.new()
	reset_btn.text = "RESET"
	reset_btn.anchor_left = 1.0
	reset_btn.anchor_right = 1.0
	reset_btn.offset_left = -160.0
	reset_btn.offset_right = -10.0
	reset_btn.anchor_top = 0.0
	reset_btn.offset_top = 50.0
	reset_btn.offset_bottom = 110.0
	reset_btn.add_theme_font_size_override("font_size", 32)
	var reset_sb := StyleBoxFlat.new()
	reset_sb.bg_color = Color(0.8, 0.2, 0.2, 0.7)
	reset_sb.corner_radius_top_left = 8
	reset_sb.corner_radius_top_right = 8
	reset_sb.corner_radius_bottom_left = 8
	reset_sb.corner_radius_bottom_right = 8
	reset_btn.add_theme_stylebox_override("normal", reset_sb)
	var reset_sb_pressed := reset_sb.duplicate()
	reset_sb_pressed.bg_color = Color(1.0, 0.3, 0.3, 0.9)
	reset_btn.add_theme_stylebox_override("pressed", reset_sb_pressed)
	reset_btn.pressed.connect(_on_reset_pressed)
	add_child(reset_btn)

	# PAUSE / MENU button (top left corner, below remaining)
	var pause_btn := Button.new()
	pause_btn.text = "MENU"
	pause_btn.offset_left = 10.0
	pause_btn.offset_top = 50.0
	pause_btn.offset_right = 160.0
	pause_btn.offset_bottom = 110.0
	pause_btn.add_theme_font_size_override("font_size", 32)
	var pause_sb := StyleBoxFlat.new()
	pause_sb.bg_color = Color(0.3, 0.3, 0.3, 0.7)
	pause_sb.corner_radius_top_left = 8
	pause_sb.corner_radius_top_right = 8
	pause_sb.corner_radius_bottom_left = 8
	pause_sb.corner_radius_bottom_right = 8
	pause_btn.add_theme_stylebox_override("normal", pause_sb)
	pause_btn.pressed.connect(_on_pause_pressed)
	add_child(pause_btn)


var _touch_brake_indicator: ColorRect
var _left_label: Label
var _right_label: Label
var _brake_label: Label

func _create_touch_zones() -> void:
	# Left steer zone (top 80%, left half)
	_touch_left_indicator = ColorRect.new()
	_touch_left_indicator.anchor_left = 0.0
	_touch_left_indicator.anchor_right = 0.5
	_touch_left_indicator.anchor_top = 0.0
	_touch_left_indicator.anchor_bottom = 0.8
	_touch_left_indicator.color = Color(0.2, 0.5, 1.0, 0.04)
	_touch_left_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_touch_left_indicator)

	# Right steer zone (top 80%, right half)
	_touch_right_indicator = ColorRect.new()
	_touch_right_indicator.anchor_left = 0.5
	_touch_right_indicator.anchor_right = 1.0
	_touch_right_indicator.anchor_top = 0.0
	_touch_right_indicator.anchor_bottom = 0.8
	_touch_right_indicator.color = Color(1.0, 0.3, 0.3, 0.04)
	_touch_right_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_touch_right_indicator)

	# Brake zone (bottom 20%)
	_touch_brake_indicator = ColorRect.new()
	_touch_brake_indicator.anchor_left = 0.0
	_touch_brake_indicator.anchor_right = 1.0
	_touch_brake_indicator.anchor_top = 0.8
	_touch_brake_indicator.anchor_bottom = 1.0
	_touch_brake_indicator.color = Color(1.0, 0.6, 0.0, 0.04)
	_touch_brake_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_touch_brake_indicator)

	# Divider line between left/right (center vertical)
	var divider := ColorRect.new()
	divider.anchor_left = 0.5
	divider.anchor_right = 0.5
	divider.anchor_top = 0.3
	divider.anchor_bottom = 0.75
	divider.offset_left = -1.0
	divider.offset_right = 1.0
	divider.color = Color(1.0, 1.0, 1.0, 0.08)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(divider)

	# Divider line between steer/brake (horizontal)
	var brake_line := ColorRect.new()
	brake_line.anchor_left = 0.0
	brake_line.anchor_right = 1.0
	brake_line.anchor_top = 0.8
	brake_line.anchor_bottom = 0.8
	brake_line.offset_top = -1.0
	brake_line.offset_bottom = 1.0
	brake_line.color = Color(1.0, 0.6, 0.0, 0.12)
	brake_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(brake_line)

	# Zone labels (persistent, subtle)
	var label_settings := LabelSettings.new()
	label_settings.font_size = 28
	label_settings.font_color = Color(1.0, 1.0, 1.0, 0.12)
	label_settings.outline_size = 0

	_left_label = Label.new()
	_left_label.text = "< LEWO"
	_left_label.label_settings = label_settings
	_left_label.anchor_left = 0.0
	_left_label.anchor_top = 0.5
	_left_label.offset_left = 20.0
	_left_label.offset_top = -14.0
	_left_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_left_label)

	_right_label = Label.new()
	_right_label.text = "PRAWO >"
	_right_label.label_settings = label_settings
	_right_label.anchor_left = 1.0
	_right_label.anchor_top = 0.5
	_right_label.offset_left = -140.0
	_right_label.offset_top = -14.0
	_right_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_right_label)

	_brake_label = Label.new()
	_brake_label.text = "HAMULEC"
	_brake_label.label_settings = label_settings
	_brake_label.anchor_left = 0.5
	_brake_label.anchor_top = 0.8
	_brake_label.offset_left = -50.0
	_brake_label.offset_top = 8.0
	_brake_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_brake_label)


func _update_touch_indicators() -> void:
	if not car:
		return
	var left_active: bool = car.get("_touch_left") and car._touch_left
	var right_active: bool = car.get("_touch_right") and car._touch_right
	var brake_active: bool = car.get("_touch_brake") and car._touch_brake

	# Zones light up when active, subtle when idle
	_touch_left_indicator.color.a = 0.15 if left_active else 0.04
	_touch_right_indicator.color.a = 0.15 if right_active else 0.04
	_touch_brake_indicator.color.a = 0.15 if brake_active else 0.04

	# Labels become more visible when active
	_left_label.label_settings.font_color.a = 0.5 if left_active else 0.12
	_right_label.label_settings.font_color.a = 0.5 if right_active else 0.12
	_brake_label.label_settings.font_color.a = 0.5 if brake_active else 0.12


func _on_reset_pressed() -> void:
	# Soft restart — find car and call _soft_restart
	for child in get_parent().get_children():
		if child is CharacterBody3D and child.has_method("_soft_restart"):
			child._soft_restart()
			return
	# Fallback: hard restart
	RaceManager.reset()
	get_tree().reload_current_scene()


func _on_pause_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")


# === CHECKPOINT POPUP ===

func _on_checkpoint(index: int, time: float, delta: float) -> void:
	var time_str := RaceManager.get_time_string(time)
	var delta_str := ""
	if absf(delta) > 0.001 and RaceManager.best_checkpoint_times.size() > index:
		if delta > 0:
			delta_str = "  +%s" % RaceManager.get_time_string(delta)
			_cp_label.label_settings.font_color = Color(1.0, 0.3, 0.3)  # red = slower
		else:
			delta_str = "  -%s" % RaceManager.get_time_string(absf(delta))
			_cp_label.label_settings.font_color = Color(0.3, 1.0, 0.3)  # green = faster
	else:
		_cp_label.label_settings.font_color = Color(1.0, 1.0, 1.0)

	_cp_label.text = "CP%d: %s%s" % [index + 1, time_str, delta_str]
	_cp_label.visible = true
	_cp_timer = 2.5


# === FINISH OVERLAY ===

func _show_finish_overlay() -> void:
	if _finish_shown:
		return
	_finish_shown = true

	# Clear previous content
	for child in _finish_vbox.get_children():
		child.queue_free()

	_finish_vbox.add_theme_constant_override("separation", 24)

	var lap := RaceManager.get_last_lap_time()
	var author_time: float = TrackData.current_author_time
	var medal: String = RaceManager.get_medal(lap, author_time) if author_time > 0.0 else "none"

	# --- Hero row: medal cell + time cell ---
	var hero := HBoxContainer.new()
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_theme_constant_override("separation", 32)
	_finish_vbox.add_child(hero)

	# Medal cell
	var medal_panel := PanelContainer.new()
	var mp_sb := StyleBoxFlat.new()
	mp_sb.bg_color = Color(0.06, 0.08, 0.13, 0.95)
	mp_sb.set_corner_radius_all(16)
	mp_sb.set_border_width_all(4)
	mp_sb.border_color = TrackData.medal_color(medal)
	mp_sb.content_margin_left = 32
	mp_sb.content_margin_right = 32
	mp_sb.content_margin_top = 24
	mp_sb.content_margin_bottom = 24
	medal_panel.add_theme_stylebox_override("panel", mp_sb)
	hero.add_child(medal_panel)

	var medal_text: String
	match medal:
		"author": medal_text = "AUTHOR"
		"gold":   medal_text = "GOLD"
		"silver": medal_text = "SILVER"
		"bronze": medal_text = "BRONZE"
		_:        medal_text = "NO MEDAL"
	var medal_label := Label.new()
	medal_label.text = medal_text
	medal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	medal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ml_s := LabelSettings.new()
	ml_s.font_size = 72
	ml_s.font_color = TrackData.medal_color(medal)
	ml_s.outline_size = 5
	ml_s.outline_color = Color.BLACK
	medal_label.label_settings = ml_s
	medal_panel.add_child(medal_label)

	# Time cell
	var time_box := VBoxContainer.new()
	time_box.alignment = BoxContainer.ALIGNMENT_CENTER
	time_box.add_theme_constant_override("separation", 4)
	hero.add_child(time_box)

	var time_label := Label.new()
	time_label.text = RaceManager.get_time_string(lap)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tl_s := LabelSettings.new()
	tl_s.font_size = 140
	tl_s.font_color = Color.WHITE
	tl_s.outline_size = 6
	tl_s.outline_color = Color.BLACK
	time_label.label_settings = tl_s
	time_box.add_child(time_label)

	# Delta vs PB / NEW RECORD
	var is_new_record: bool = lap == RaceManager.best_time and RaceManager.best_time < INF
	if is_new_record:
		var rec := Label.new()
		rec.text = "NEW RECORD!"
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var rec_s := LabelSettings.new()
		rec_s.font_size = 48
		rec_s.font_color = Color(0.2, 1.0, 0.3)
		rec_s.outline_size = 3
		rec_s.outline_color = Color.BLACK
		rec.label_settings = rec_s
		time_box.add_child(rec)
	elif RaceManager.best_time < INF:
		var d := lap - RaceManager.best_time
		var delta := Label.new()
		var sign_str := "+" if d > 0 else "-"
		delta.text = "%s%s vs PB" % [sign_str, RaceManager.get_time_string(absf(d))]
		delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var d_s := LabelSettings.new()
		d_s.font_size = 42
		d_s.font_color = Color(1.0, 0.4, 0.4) if d > 0 else Color(0.4, 1.0, 0.5)
		d_s.outline_size = 3
		d_s.outline_color = Color.BLACK
		delta.label_settings = d_s
		time_box.add_child(delta)

	if medal != "none":
		UIStyle.pulse(medal_label, 1.12, 0.55)

	# --- Targets row (only when author_time known) ---
	if author_time > 0.0:
		var targets := GridContainer.new()
		targets.columns = 4
		targets.add_theme_constant_override("h_separation", 32)
		targets.add_theme_constant_override("v_separation", 2)
		_finish_vbox.add_child(targets)

		var row_names: Array[String] = ["Author", "Gold", "Silver", "Bronze"]
		var row_keys: Array[String] = ["author", "gold", "silver", "bronze"]
		var row_times: Array[float] = [author_time, author_time * 1.1, author_time * 1.3, author_time * 1.6]
		var earned_rank: int = TrackData.medal_rank(medal)

		# Two passes: names row, then times row (GridContainer fills left-to-right top-to-bottom)
		for i in range(row_names.size()):
			var key: String = row_keys[i]
			var earned: bool = TrackData.medal_rank(key) <= earned_rank
			var name_lbl := Label.new()
			name_lbl.text = row_names[i]
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var nl_s := LabelSettings.new()
			nl_s.font_size = 24
			nl_s.font_color = TrackData.medal_color(key) if earned else Color(0.4, 0.4, 0.45)
			nl_s.outline_size = 2
			nl_s.outline_color = Color.BLACK
			name_lbl.label_settings = nl_s
			targets.add_child(name_lbl)

		for i in range(row_times.size()):
			var key2: String = row_keys[i]
			var earned2: bool = TrackData.medal_rank(key2) <= earned_rank
			var t_lbl := Label.new()
			t_lbl.text = RaceManager.get_time_string(row_times[i])
			t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var tl_lbl_s := LabelSettings.new()
			tl_lbl_s.font_size = 32
			tl_lbl_s.font_color = Color(0.9, 0.9, 0.95) if earned2 else Color(0.35, 0.35, 0.4)
			tl_lbl_s.outline_size = 2
			tl_lbl_s.outline_color = Color.BLACK
			t_lbl.label_settings = tl_lbl_s
			targets.add_child(t_lbl)

	# --- Checkpoints grid (2 columns, compact) ---
	if not RaceManager.checkpoint_times.is_empty():
		var cp_title := Label.new()
		cp_title.text = "CHECKPOINTS"
		cp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cpt_s := LabelSettings.new()
		cpt_s.font_size = 26
		cpt_s.font_color = Color(0.5, 0.5, 0.55)
		cpt_s.outline_size = 2
		cpt_s.outline_color = Color.BLACK
		cp_title.label_settings = cpt_s
		_finish_vbox.add_child(cp_title)

		var cp_grid := GridContainer.new()
		cp_grid.columns = 2
		cp_grid.add_theme_constant_override("h_separation", 48)
		cp_grid.add_theme_constant_override("v_separation", 4)
		_finish_vbox.add_child(cp_grid)

		for i in range(RaceManager.checkpoint_times.size()):
			var cp_time: float = RaceManager.checkpoint_times[i]
			var cp_text := "CP%d  %s" % [i + 1, RaceManager.get_time_string(cp_time)]
			var delta_col := Color(0.8, 0.8, 0.85)
			if i < RaceManager.best_checkpoint_times.size():
				var d2: float = cp_time - RaceManager.best_checkpoint_times[i]
				if absf(d2) > 0.001:
					cp_text += "   %s%s" % ["+" if d2 > 0 else "-", RaceManager.get_time_string(absf(d2))]
					delta_col = Color(1.0, 0.5, 0.5) if d2 > 0 else Color(0.5, 1.0, 0.5)
			var cp_lbl := Label.new()
			cp_lbl.text = cp_text
			cp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var cp_s := LabelSettings.new()
			cp_s.font_size = 28
			cp_s.font_color = delta_col
			cp_s.outline_size = 2
			cp_s.outline_color = Color.BLACK
			cp_lbl.label_settings = cp_s
			cp_grid.add_child(cp_lbl)

	# --- Actions row ---
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	_finish_vbox.add_child(btn_row)

	var restart_btn := Button.new()
	restart_btn.text = "RESTART"
	restart_btn.custom_minimum_size = Vector2(240, 72)
	restart_btn.add_theme_font_size_override("font_size", 32)
	restart_btn.focus_mode = Control.FOCUS_NONE
	var r_sb := StyleBoxFlat.new()
	r_sb.bg_color = Color(0.15, 0.5, 0.2)
	r_sb.set_corner_radius_all(8)
	restart_btn.add_theme_stylebox_override("normal", r_sb)
	restart_btn.pressed.connect(func():
		_finish_overlay.visible = false
		_finish_shown = false
		_on_reset_pressed()
	)
	btn_row.add_child(restart_btn)

	var menu_btn := Button.new()
	menu_btn.text = "MENU"
	menu_btn.custom_minimum_size = Vector2(240, 72)
	menu_btn.add_theme_font_size_override("font_size", 32)
	menu_btn.focus_mode = Control.FOCUS_NONE
	var m_sb := StyleBoxFlat.new()
	m_sb.bg_color = Color(0.3, 0.3, 0.35)
	m_sb.set_corner_radius_all(8)
	menu_btn.add_theme_stylebox_override("normal", m_sb)
	menu_btn.pressed.connect(_on_pause_pressed)
	btn_row.add_child(menu_btn)

	_finish_overlay.visible = true

	# Refresh leaderboard after finish
	refresh_leaderboard()


# === LEADERBOARD ===

func _create_leaderboard_panel() -> void:
	_lb_panel = PanelContainer.new()
	_lb_panel.anchor_left = 0.0
	_lb_panel.anchor_top = 0.0
	_lb_panel.offset_left = 10.0
	_lb_panel.offset_top = 120.0
	_lb_panel.offset_right = 320.0
	_lb_panel.offset_bottom = 500.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.05, 0.7)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	_lb_panel.add_theme_stylebox_override("panel", sb)
	add_child(_lb_panel)

	_lb_vbox = VBoxContainer.new()
	_lb_vbox.add_theme_constant_override("separation", 2)
	_lb_panel.add_child(_lb_vbox)

	# Title
	var title := Label.new()
	title.text = "LEADERBOARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ts := LabelSettings.new()
	ts.font_size = 22
	ts.font_color = Color(1.0, 0.85, 0.2)
	ts.outline_size = 2
	ts.outline_color = Color.BLACK
	title.label_settings = ts
	_lb_vbox.add_child(title)

	# Loading placeholder
	var loading := Label.new()
	loading.text = "..."
	loading.name = "LBLoading"
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.add_theme_font_size_override("font_size", 18)
	loading.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	_lb_vbox.add_child(loading)


func _load_leaderboard() -> void:
	var track_id: int = TrackData.current_server_id
	if track_id <= 0:
		_lb_panel.visible = false
		return

	ApiClient.get_leaderboard(track_id, func(data: Dictionary):
		_lb_loaded = true
		_populate_leaderboard(data)
	)


func _populate_leaderboard(data: Dictionary) -> void:
	# Clear old entries (keep title)
	while _lb_vbox.get_child_count() > 1:
		var child := _lb_vbox.get_child(1)
		_lb_vbox.remove_child(child)
		child.queue_free()

	var scores: Array = data.get("scores", [])
	if scores.is_empty():
		var empty := Label.new()
		empty.text = "No results"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		_lb_vbox.add_child(empty)
		return

	var medal_colors := [
		Color(1.0, 0.85, 0.0),   # gold
		Color(0.75, 0.75, 0.8),  # silver
		Color(0.8, 0.5, 0.2),    # bronze
	]

	for i in range(mini(scores.size(), 10)):
		var s: Dictionary = scores[i]
		var rank: int = s.get("rank", i + 1)
		var pname: String = str(s.get("player_name", "???"))
		var time_ms: int = int(s.get("lap_time_ms", 0))
		var nationality: String = str(s.get("player_nationality", ""))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		# Rank
		var rank_lbl := Label.new()
		rank_lbl.text = "#%d" % rank
		rank_lbl.custom_minimum_size = Vector2(40, 0)
		var rank_s := LabelSettings.new()
		rank_s.font_size = 20
		rank_s.font_color = medal_colors[i] if i < 3 else Color(0.6, 0.6, 0.65)
		rank_s.outline_size = 2
		rank_s.outline_color = Color.BLACK
		rank_lbl.label_settings = rank_s
		row.add_child(rank_lbl)

		# Flag + name
		var name_lbl := Label.new()
		var flag_str := "[%s] " % nationality if nationality != "" else ""
		name_lbl.text = flag_str + pname
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text = true
		var name_s := LabelSettings.new()
		name_s.font_size = 18
		# Highlight own player
		if pname == ApiClient.player_name:
			name_s.font_color = Color(0.3, 0.9, 1.0)
		else:
			name_s.font_color = Color(0.8, 0.8, 0.85)
		name_s.outline_size = 1
		name_s.outline_color = Color.BLACK
		name_lbl.label_settings = name_s
		row.add_child(name_lbl)

		# Time
		var time_lbl := Label.new()
		var secs: float = float(time_ms) / 1000.0
		var mins: int = int(secs) / 60
		var sec_rem: float = secs - float(mins * 60)
		time_lbl.text = "%d:%05.2f" % [mins, sec_rem]
		time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var time_s := LabelSettings.new()
		time_s.font_size = 18
		time_s.font_color = Color(0.7, 0.9, 0.7) if i == 0 else Color(0.7, 0.7, 0.75)
		time_s.outline_size = 1
		time_s.outline_color = Color.BLACK
		time_lbl.label_settings = time_s
		row.add_child(time_lbl)

		_lb_vbox.add_child(row)


func refresh_leaderboard() -> void:
	_load_leaderboard()
