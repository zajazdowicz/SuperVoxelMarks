extends Node3D
## Replays ghost data as a transparent car following recorded frames.

var ghost_data: Array[Dictionary] = []
var _mesh: MeshInstance3D
var _time := 0.0
var _playing := false
var visible_ghost := true


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


func start_playback() -> void:
	if ghost_data.is_empty():
		return
	_time = 0.0
	_playing = true
	visible = visible_ghost


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

	# Find the two frames to interpolate between
	var last_frame := ghost_data[0]
	var next_frame := ghost_data[0]

	for i in range(ghost_data.size()):
		if ghost_data[i]["t"] > _time:
			next_frame = ghost_data[i]
			if i > 0:
				last_frame = ghost_data[i - 1]
			break
		last_frame = ghost_data[i]
		next_frame = ghost_data[i]

	# Past the end — stop
	if _time > ghost_data[-1]["t"]:
		stop_playback()
		return

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
