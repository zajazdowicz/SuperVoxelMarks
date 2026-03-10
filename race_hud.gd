extends CanvasLayer
## Race HUD: lap timer, remaining time, speed, lap list, best time.

var timer_label: Label
var remaining_label: Label
var speed_label: Label
var info_label: Label
var laps_label: Label
var car: CharacterBody3D

var _last_lap_count := 0


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

	# Info (center)
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
	match RaceManager.state:
		RaceManager.State.IDLE:
			timer_label.text = "0:00.000"
			remaining_label.text = "2:00"
			info_label.text = "Jedz przez Start!"
		RaceManager.State.RACING:
			timer_label.text = RaceManager.get_time_string()
			remaining_label.text = RaceManager.get_remaining_string()
			# Flash remaining when low
			if RaceManager.race_time > RaceManager.TIME_LIMIT - 30.0:
				remaining_label.label_settings.font_color = Color(1.0, 0.3, 0.3)
			# Show new lap info briefly
			if RaceManager.lap_count > _last_lap_count:
				_last_lap_count = RaceManager.lap_count
				_show_lap_complete()
			elif RaceManager.lap_count == 0:
				info_label.text = ""
		RaceManager.State.TIME_UP:
			timer_label.text = RaceManager.get_time_string()
			remaining_label.text = "0:00"
			info_label.text = "CZAS MINOL!\nOkrazenia: %d" % RaceManager.lap_count
			if RaceManager.best_time < INF:
				info_label.text += "\nBest Lap: %s" % RaceManager.get_time_string(RaceManager.best_time)
		RaceManager.State.FINISHED:
			var finish_time := RaceManager.get_last_lap_time()
			timer_label.text = RaceManager.get_time_string(finish_time)
			remaining_label.text = ""
			var msg := "FINISH!\n%s" % RaceManager.get_time_string(finish_time)
			if finish_time == RaceManager.best_time:
				msg += "\nNOWY REKORD!"
			msg += "\nR = restart | G = duch | ESC = menu"
			info_label.text = msg

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

	# Best + Last lap always visible
	var extra := ""
	if RaceManager.best_time < INF:
		extra += "Best: %s" % RaceManager.get_time_string(RaceManager.best_time)
	if not RaceManager.laps.is_empty():
		var last: float = RaceManager.laps[-1]
		if not extra.is_empty():
			extra += "  |  "
		extra += "Last: %s" % RaceManager.get_time_string(last)
	timer_label.text += "\n" + extra if not extra.is_empty() else ""

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
			prefix = "* "
		text += "%sLap %d: %s\n" % [prefix, i + 1, RaceManager.get_time_string(t)]
	laps_label.text = text


func _show_lap_complete() -> void:
	var last_time := RaceManager.get_last_lap_time()
	if last_time < 0:
		return
	var msg := "LAP %d: %s" % [RaceManager.lap_count, RaceManager.get_time_string(last_time)]
	if last_time == RaceManager.best_time:
		msg += "\nNOWY REKORD!"
	info_label.text = msg

	# Auto-hide after 2 seconds
	var timer := get_tree().create_timer(2.0)
	var current_lap := RaceManager.lap_count
	timer.timeout.connect(func():
		if RaceManager.lap_count == current_lap:
			info_label.text = ""
	)
