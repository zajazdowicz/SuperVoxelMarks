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
	timer_s.font_size = 36
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
	best_s.font_size = 20
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
	delta_s.font_size = 22
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
	rem_s.font_size = 24
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
	speed_s.font_size = 24
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
	cd_s.font_size = 72
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
	info_s.font_size = 28
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
	laps_s.font_size = 18
	laps_s.font_color = Color(0.7, 0.9, 0.7)
	laps_s.outline_size = 3
	laps_s.outline_color = Color.BLACK
	laps_label.label_settings = laps_s
	add_child(laps_label)


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
