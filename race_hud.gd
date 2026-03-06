extends CanvasLayer
## Race HUD showing timer, speed, checkpoints, and finish results.

@onready var timer_label: Label = $TimerLabel
@onready var speed_label: Label = $SpeedLabel
@onready var info_label: Label = $InfoLabel
@onready var car: CharacterBody3D

var _finish_shown := false


func _ready() -> void:
	# Find car node
	for child in get_parent().get_children():
		if child is CharacterBody3D:
			car = child
			break

	_create_ui()
	RaceManager.reset()
	RaceManager.load_best(TrackData.current_track)


func _create_ui() -> void:
	# Timer (top center)
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.anchor_left = 0.5
	timer_label.anchor_right = 0.5
	timer_label.offset_left = -150.0
	timer_label.offset_right = 150.0
	timer_label.offset_top = 10.0
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var timer_settings := LabelSettings.new()
	timer_settings.font_size = 36
	timer_settings.font_color = Color.WHITE
	timer_settings.outline_size = 4
	timer_settings.outline_color = Color.BLACK
	timer_label.label_settings = timer_settings
	add_child(timer_label)

	# Speed (top right)
	speed_label = Label.new()
	speed_label.name = "SpeedLabel"
	speed_label.anchor_left = 1.0
	speed_label.anchor_right = 1.0
	speed_label.offset_left = -200.0
	speed_label.offset_top = 10.0
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var speed_settings := LabelSettings.new()
	speed_settings.font_size = 24
	speed_settings.font_color = Color(0.8, 0.8, 0.8)
	speed_settings.outline_size = 3
	speed_settings.outline_color = Color.BLACK
	speed_label.label_settings = speed_settings
	add_child(speed_label)

	# Info (center, for messages)
	info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.anchor_left = 0.5
	info_label.anchor_right = 0.5
	info_label.anchor_top = 0.3
	info_label.offset_left = -200.0
	info_label.offset_right = 200.0
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var info_settings := LabelSettings.new()
	info_settings.font_size = 28
	info_settings.font_color = Color(1.0, 0.9, 0.2)
	info_settings.outline_size = 4
	info_settings.outline_color = Color.BLACK
	info_label.label_settings = info_settings
	add_child(info_label)


func _process(_delta: float) -> void:
	# Timer display
	match RaceManager.state:
		RaceManager.State.IDLE:
			timer_label.text = "0:00.000"
			if not _finish_shown:
				info_label.text = "Jedz przez Start aby rozpoczac!"
		RaceManager.State.RACING:
			timer_label.text = RaceManager.get_time_string()
			info_label.text = ""
			_finish_shown = false
		RaceManager.State.FINISHED:
			timer_label.text = RaceManager.get_time_string()
			if not _finish_shown:
				_show_finish()
				_finish_shown = true

	# Speed display
	if car and car.has_method(""):
		pass
	if car:
		var spd: int = int(abs(car.speed) * 3.6)  # convert to "km/h"
		speed_label.text = "%d km/h" % spd

	# Best time
	if RaceManager.best_time < INF:
		timer_label.text += "\nBest: %s" % RaceManager.get_time_string(RaceManager.best_time)


func _show_finish() -> void:
	var time_str := RaceManager.get_time_string()
	var msg := "FINISH!\n%s" % time_str
	if RaceManager.best_time == RaceManager.race_time:
		msg += "\nNOWY REKORD!"
	info_label.text = msg

	# Auto-hide after 3 seconds
	await get_tree().create_timer(3.0).timeout
	info_label.text = "R = restart | ESC = menu"
