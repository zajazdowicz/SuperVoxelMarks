extends Node
## Autoload singleton managing race state, lap timer, and ghost recording.
## TrackMania-style: TIME_LIMIT to drive laps, best lap time saved.

enum State { IDLE, COUNTDOWN, RACING, TIME_UP, FINISHED }

var state := State.IDLE
var countdown_timer := 0.0
const COUNTDOWN_TIME := 3.0
var race_time := 0.0         # total elapsed time
var lap_time := 0.0          # current lap timer
var lap_count := 0
var checkpoints_hit := 0
var total_checkpoints := 0
var laps: Array[float] = []  # finished lap times

# Ghost recording per lap
var ghost_frames: Array[Dictionary] = []
var _lap_ghost: Array[Dictionary] = []  # current lap ghost
var best_ghost: Array[Dictionary] = []
var best_time := INF
var is_sprint := false  # true = separate start/finish (no laps)

# Respawn position: last checkpoint or start
var respawn_pos := Vector3.ZERO
var respawn_rot := 0.0

var _record_timer := 0.0
const GHOST_INTERVAL := 0.05

const TIME_LIMIT := 120.0  # 2 minutes


func reset() -> void:
	state = State.IDLE
	race_time = 0.0
	lap_time = 0.0
	lap_count = 0
	checkpoints_hit = 0
	laps.clear()
	ghost_frames.clear()
	_lap_ghost.clear()
	_record_timer = 0.0
	respawn_pos = Vector3.ZERO
	respawn_rot = 0.0


func start_countdown() -> void:
	if state != State.IDLE:
		return
	state = State.COUNTDOWN
	countdown_timer = COUNTDOWN_TIME
	race_time = 0.0
	lap_time = 0.0
	lap_count = 0
	checkpoints_hit = 0
	laps.clear()
	ghost_frames.clear()
	_lap_ghost.clear()
	_record_timer = 0.0


signal race_started    # emitted when countdown ends and GO! begins
signal lap_completed   # emitted when a lap finishes (for ghost restart)

func start_race() -> void:
	state = State.RACING
	race_time = 0.0
	lap_time = 0.0
	race_started.emit()


func hit_checkpoint(index: int) -> void:
	if state != State.RACING:
		return
	if index == checkpoints_hit:
		checkpoints_hit += 1


func cross_start_finish() -> void:
	## Called when car crosses start/finish line.
	if state == State.IDLE:
		start_countdown()
		return

	if state == State.TIME_UP:
		reset()
		start_countdown()
		return

	if state == State.COUNTDOWN:
		return

	if state != State.RACING:
		return

	# First crossing = race start (lap_count == 0, lap_time ~0)
	if lap_count == 0 and lap_time < 1.0:
		return

	# Must hit all checkpoints
	if total_checkpoints > 0 and checkpoints_hit < total_checkpoints:
		return

	_finish_lap()


func cross_start() -> void:
	## Sprint mode: crossing start line begins the run.
	if state == State.IDLE:
		start_countdown()
	elif state == State.FINISHED:
		reset()
		start_countdown()


func cross_finish() -> void:
	## Sprint mode: crossing finish line ends the run.
	if state != State.RACING:
		return
	if total_checkpoints > 0 and checkpoints_hit < total_checkpoints:
		return
	_finish_lap()
	state = State.FINISHED


func _finish_lap() -> void:
	laps.append(lap_time)
	lap_count += 1

	# Check for best lap
	if lap_time < best_time:
		best_time = lap_time
		best_ghost = _lap_ghost.duplicate()
		_save_best_time()
		# Upload to server
		_upload_score(lap_time)

	# Reset for next lap
	checkpoints_hit = 0
	lap_time = 0.0
	_lap_ghost.clear()
	lap_completed.emit()


func record_frame(pos: Vector3, rot_y: float) -> void:
	if state != State.RACING:
		return
	_record_timer += get_process_delta_time()
	if _record_timer < GHOST_INTERVAL:
		return
	_record_timer -= GHOST_INTERVAL
	var frame := {
		"t": lap_time,
		"px": pos.x, "py": pos.y, "pz": pos.z,
		"ry": rot_y,
	}
	ghost_frames.append(frame)
	_lap_ghost.append(frame)


func _process(delta: float) -> void:
	if state == State.COUNTDOWN:
		countdown_timer -= delta
		if countdown_timer <= 0.0:
			start_race()
	elif state == State.RACING:
		race_time += delta
		lap_time += delta
		if race_time >= TIME_LIMIT:
			state = State.TIME_UP


func get_time_string(t: float = -1.0) -> String:
	if t < 0:
		t = lap_time
	var mins: int = int(t) / 60
	var secs: int = int(t) % 60
	var ms: int = int(fmod(t, 1.0) * 1000)
	return "%d:%02d.%03d" % [mins, secs, ms]


func get_remaining_string() -> String:
	var remaining := maxf(TIME_LIMIT - race_time, 0.0)
	var mins: int = int(remaining) / 60
	var secs: int = int(remaining) % 60
	return "%d:%02d" % [mins, secs]


func get_last_lap_time() -> float:
	if laps.is_empty():
		return -1.0
	return laps[-1]


func get_medal(t: float, author_time: float) -> String:
	if t <= author_time:
		return "author"
	elif t <= author_time * 1.1:
		return "gold"
	elif t <= author_time * 1.3:
		return "silver"
	elif t <= author_time * 1.6:
		return "bronze"
	return "none"


func _save_best_time() -> void:
	var track := TrackData.current_track
	if track == "":
		return
	DirAccess.make_dir_recursive_absolute("user://times")
	var file := FileAccess.open("user://times/%s.json" % track, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"time": best_time,
		"ghost": best_ghost,
	}))


func _upload_score(lap_time: float) -> void:
	if not ApiClient.is_registered():
		return
	# track_id is stored when loading from server, 0 = local track
	if _current_track_id <= 0:
		return
	var lap_ms: int = int(lap_time * 1000.0)
	var ghost_copy := best_ghost.duplicate()
	ApiClient.submit_score(_current_track_id, lap_ms, ghost_copy, func(success, data):
		if success:
			print("Score uploaded! Rank #%s" % str(data.get("rank", "?")))
	)


var _current_track_id := 0

func set_track_id(id: int) -> void:
	_current_track_id = id


func load_best(track_name: String) -> void:
	var path := "user://times/%s.json" % track_name
	if not FileAccess.file_exists(path):
		best_time = INF
		best_ghost.clear()
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	if json.data:
		best_time = float(json.data.get("time", INF))
		best_ghost.clear()
		for frame in json.data.get("ghost", []):
			best_ghost.append(frame)
