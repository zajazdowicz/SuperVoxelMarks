extends Node3D
## Replays ghost data as a transparent car following recorded frames.

var ghost_data: Array[Dictionary] = []
var _mesh: MeshInstance3D
var _time := 0.0
var _playing := false
var visible_ghost := true
var _looping := false  # true for lap mode (restart ghost after last frame)


func setup(data: Array, color: Color = Color(0.2, 0.5, 1.0, 0.35)) -> void:
	ghost_data.clear()
	for frame in data:
		ghost_data.append(frame)

	if ghost_data.is_empty():
		return

	# Create ghost car mesh
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 0.6, 2.0)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.no_depth_test = false
	_mesh.material_override = mat
	add_child(_mesh)

	visible = false


func start_playback(loop: bool = false) -> void:
	if ghost_data.is_empty():
		return
	_time = 0.0
	_playing = true
	_looping = loop
	visible = visible_ghost

	# Snap to first frame position immediately
	var first := ghost_data[0]
	global_position = Vector3(first["px"], first["py"], first["pz"])
	rotation.y = first["ry"]


func stop_playback() -> void:
	_playing = false
	visible = false


func toggle_visible() -> void:
	visible_ghost = not visible_ghost
	if _playing:
		visible = visible_ghost


func _process(delta: float) -> void:
	if not _playing or ghost_data.is_empty():
		return

	_time += delta

	var last_t: float = ghost_data[-1]["t"]

	# Past the end
	if _time > last_t:
		if _looping:
			_time = fmod(_time, last_t + 0.05)
		else:
			stop_playback()
			return

	# Binary search for frame bracket (much faster than linear scan)
	var lo := 0
	var hi: int = ghost_data.size() - 1
	while lo < hi - 1:
		var mid: int = (lo + hi) / 2
		if ghost_data[mid]["t"] <= _time:
			lo = mid
		else:
			hi = mid

	var last_frame: Dictionary = ghost_data[lo]
	var next_frame: Dictionary = ghost_data[hi]

	# Interpolate
	var dt: float = next_frame["t"] - last_frame["t"]
	var t: float = 0.0
	if dt > 0.001:
		t = clampf((_time - last_frame["t"]) / dt, 0.0, 1.0)

	global_position = Vector3(
		lerpf(last_frame["px"], next_frame["px"], t),
		lerpf(last_frame["py"], next_frame["py"], t),
		lerpf(last_frame["pz"], next_frame["pz"], t),
	)
	rotation.y = lerp_angle(last_frame["ry"], next_frame["ry"], t)
