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
	timer_s.font_size = 56
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
	best_s.font_size = 32
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
	delta_s.font_size = 34
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
	rem_s.font_size = 36
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
	speed_s.font_size = 36
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
	cd_s.font_size = 110
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
	info_s.font_size = 44
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
				countdown_label.label_settings.font_color = Color(1.0, 1.0, 1.0)
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
			info_label.text = "CZAS MINĄŁ!\nOkrążenia: %d" % RaceManager.lap_count
			if RaceManager.best_time < INF:
				info_label.text += "\nBest: %s" % RaceManager.get_time_string(RaceManager.best_time)
			info_label.text += "\nR = restart | ESC = menu"
			info_label.text += "\nDotknij aby kontynuowac"
		RaceManager.State.FINISHED:
			var finish_time := RaceManager.get_last_lap_time()
			timer_label.text = RaceManager.get_time_string(finish_time)
			remaining_label.text = ""
			var msg := "FINISH!\n%s" % RaceManager.get_time_string(finish_time)
			if finish_time == RaceManager.best_time:
				msg += "\nNOWY REKORD!"
			msg += "\nR = restart | G = duch | ESC = menu"
			info_label.text = msg

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
		msg += "\nNOWY REKORD!"
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
	reset_btn.offset_left = -120.0
	reset_btn.offset_right = -10.0
	reset_btn.anchor_top = 0.0
	reset_btn.offset_top = 50.0
	reset_btn.offset_bottom = 90.0
	reset_btn.add_theme_font_size_override("font_size", 22)
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
	pause_btn.offset_right = 110.0
	pause_btn.offset_bottom = 90.0
	pause_btn.add_theme_font_size_override("font_size", 22)
	var pause_sb := StyleBoxFlat.new()
	pause_sb.bg_color = Color(0.3, 0.3, 0.3, 0.7)
	pause_sb.corner_radius_top_left = 8
	pause_sb.corner_radius_top_right = 8
	pause_sb.corner_radius_bottom_left = 8
	pause_sb.corner_radius_bottom_right = 8
	pause_btn.add_theme_stylebox_override("normal", pause_sb)
	pause_btn.pressed.connect(_on_pause_pressed)
	add_child(pause_btn)


func _create_touch_zones() -> void:
	# Left touch zone indicator (bottom left, semi-transparent)
	_touch_left_indicator = ColorRect.new()
	_touch_left_indicator.anchor_left = 0.0
	_touch_left_indicator.anchor_right = 0.5
	_touch_left_indicator.anchor_top = 0.7
	_touch_left_indicator.anchor_bottom = 1.0
	_touch_left_indicator.color = Color(0.2, 0.5, 1.0, 0.0)  # invisible by default
	_touch_left_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_touch_left_indicator)

	# Right touch zone indicator (bottom right)
	_touch_right_indicator = ColorRect.new()
	_touch_right_indicator.anchor_left = 0.5
	_touch_right_indicator.anchor_right = 1.0
	_touch_right_indicator.anchor_top = 0.7
	_touch_right_indicator.anchor_bottom = 1.0
	_touch_right_indicator.color = Color(1.0, 0.3, 0.3, 0.0)  # invisible by default
	_touch_right_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_touch_right_indicator)


func _update_touch_indicators() -> void:
	if not car:
		return
	var left_active: bool = car.get("_touch_left") and car._touch_left
	var right_active: bool = car.get("_touch_right") and car._touch_right
	_touch_left_indicator.color.a = 0.12 if left_active else 0.0
	_touch_right_indicator.color.a = 0.12 if right_active else 0.0


func _on_reset_pressed() -> void:
	RaceManager.reset()
	get_tree().reload_current_scene()


func _on_pause_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")
