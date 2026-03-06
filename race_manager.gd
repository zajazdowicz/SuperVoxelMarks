extends Node
## Autoload singleton managing race state, timer, checkpoints, and ghost recording.

enum State { IDLE, RACING, FINISHED }

var state := State.IDLE
var race_time := 0.0
var checkpoints_hit := 0
var total_checkpoints := 0
var splits: Array[float] = []

# Ghost recording: array of {t: float, px/py/pz: float, ry: float}
var ghost_frames: Array[Dictionary] = []
var best_ghost: Array[Dictionary] = []
var best_time := INF

var _record_timer := 0.0
const GHOST_INTERVAL := 0.05  # 20 fps recording


func reset() -> void:
	state = State.IDLE
	race_time = 0.0
	checkpoints_hit = 0
	splits.clear()
	ghost_frames.clear()
	_record_timer = 0.0


func start_race() -> void:
	if state != State.IDLE:
		return
	state = State.RACING
	race_time = 0.0
	checkpoints_hit = 0
	splits.clear()
	ghost_frames.clear()
	_record_timer = 0.0


func hit_checkpoint(index: int) -> void:
	if state != State.RACING:
		return
	if index == checkpoints_hit:
		checkpoints_hit += 1
		splits.append(race_time)


func finish_race() -> void:
	if state != State.RACING:
		return
	if total_checkpoints > 0 and checkpoints_hit < total_checkpoints:
		return  # must hit all checkpoints

	state = State.FINISHED
	if race_time < best_time:
		best_time = race_time
		best_ghost = ghost_frames.duplicate()
		# Save locally
		_save_best_time()


func record_frame(pos: Vector3, rot_y: float) -> void:
	if state != State.RACING:
		return
	_record_timer += get_process_delta_time()
	if _record_timer < GHOST_INTERVAL:
		return
	_record_timer -= GHOST_INTERVAL
	ghost_frames.append({
		"t": race_time,
		"px": pos.x, "py": pos.y, "pz": pos.z,
		"ry": rot_y,
	})


func _process(delta: float) -> void:
	if state == State.RACING:
		race_time += delta


func get_time_string(t: float = -1.0) -> String:
	if t < 0:
		t = race_time
	var mins: int = int(t) / 60
	var secs: int = int(t) % 60
	var ms: int = int(fmod(t, 1.0) * 1000)
	return "%d:%02d.%03d" % [mins, secs, ms]


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
