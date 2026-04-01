extends Node3D
## Loads saved track data and builds it on the voxel terrain.
## Spawns collision for ramps, trigger zones, and ghost replay.

const GRID := TrackPieces.SEGMENT_SIZE

@onready var terrain: VoxelTerrain = $"../VoxelTerrain"
@onready var car: CharacterBody3D = $"../Car"

var _checkpoint_count := 0
var _spawn_pos := Vector3(0, 3, 0)
var _spawn_rot := 0.0
var _ghost_best: Node3D
var _ghost_visible := true


func _ready() -> void:
	if car:
		car.visible = false
	await get_tree().create_timer(2.0).timeout
	_build_track()


func _build_track() -> void:
	var pieces := TrackData.load_track(TrackData.current_track)
	if pieces.is_empty():
		return

	# Set server track ID for score upload
	var sid: int = TrackData.get_server_id(TrackData.current_track)
	TrackData.current_server_id = sid
	RaceManager.set_track_id(sid)

	if car:
		car.set_physics_process(false)

	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE

	_spawn_pos = Vector3(0, 3, 0)
	_spawn_rot = 0.0
	_checkpoint_count = 0
	var has_finish := false

	# Center track around origin so it always fits in VoxelTerrain range
	var _center_offset := Vector2i.ZERO
	if not pieces.is_empty():
		var min_gx: int = pieces[0].grid.x
		var max_gx: int = pieces[0].grid.x
		var min_gz: int = pieces[0].grid.y
		var max_gz: int = pieces[0].grid.y
		for p in pieces:
			min_gx = mini(min_gx, p.grid.x)
			max_gx = maxi(max_gx, p.grid.x)
			min_gz = mini(min_gz, p.grid.y)
			max_gz = maxi(max_gz, p.grid.y)
		_center_offset = Vector2i((min_gx + max_gx) / 2, (min_gz + max_gz) / 2)

	# Sort by base_height — higher pieces built last so their voxels win
	var sorted := pieces.duplicate()
	sorted.sort_custom(func(a, b): return a.get("base_height", 0) < b.get("base_height", 0))

	for p in sorted:
		var centered_grid: Vector2i = p.grid - _center_offset
		var piece := TrackPieces.get_piece(p.piece)
		var rotated := TrackPieces.rotate_piece(piece, p.rotation)
		var bh: int = p.get("base_height", 0)
		var offset := Vector3i(centered_grid.x * GRID, bh, centered_grid.y * GRID)
		for block in rotated:
			tool.set_voxel(offset + block.pos, block.type)

		var world_pos := Vector3(centered_grid.x * GRID, float(bh), centered_grid.y * GRID)
		var rot_y: float = -float(p.rotation) * PI / 2.0

		RampSpawner.spawn_piece_collision(self, p.piece, centered_grid, p.rotation, bh, p.get("down", false))

		if p.piece == 5:
			_spawn_pos = Vector3(centered_grid.x * GRID, bh + 3, centered_grid.y * GRID)
			# Car faces the exit direction of the start piece
			var ports := PieceRegistry.get_ports(p.piece)
			var rot_ports := PieceRegistry.rotate_ports(ports, p.rotation)
			var exit_dir: Vector2i = rot_ports[1].dir
			_spawn_rot = atan2(-float(exit_dir.x), -float(exit_dir.y))
			_spawn_trigger(world_pos + Vector3(0, 2, 0), rot_y, "start")

		if p.piece == 11:
			_spawn_trigger(world_pos + Vector3(0, 2, 0), rot_y, "finish")
			has_finish = true

		if p.piece == 8:
			_spawn_trigger(world_pos + Vector3(0, 2, 0), rot_y, "checkpoint_%d" % _checkpoint_count)
			_checkpoint_count += 1

	# Build centered pieces array for ramp boundary clearing
	var centered_pieces: Array[Dictionary] = []
	for p in pieces:
		var cp := p.duplicate()
		cp.grid = p.grid - _center_offset
		centered_pieces.append(cp)

	# Second pass: clear boundary voxels at ramp HIGH end
	RampSpawner.clear_ramp_boundaries(tool, centered_pieces)

	# StaticViewer at origin (track is centered)
	var static_viewer := get_node_or_null("../StaticViewer")
	if static_viewer:
		static_viewer.global_position = Vector3.ZERO

	RaceManager.total_checkpoints = _checkpoint_count
	RaceManager.is_sprint = has_finish

	# Wait for voxel meshing to complete
	await get_tree().create_timer(0.5).timeout

	if car:
		car.global_position = _spawn_pos
		car.rotation.y = _spawn_rot
		car.velocity = Vector3.ZERO
		car.visible = true
		car.set_physics_process(true)

	# Spawn ghost for personal best
	_spawn_ghost()

	# Start ghost when countdown ends (GO!)
	if not RaceManager.race_started.is_connected(_start_ghost):
		RaceManager.race_started.connect(_start_ghost)
	# Lap mode only: restart ghost on new lap (sprint restarts via countdown)
	if not RaceManager.is_sprint:
		if not RaceManager.lap_completed.is_connected(_start_ghost):
			RaceManager.lap_completed.connect(_start_ghost)
	# Update ghost when new best is set mid-race
	if not RaceManager.new_best_set.is_connected(_update_ghost_data):
		RaceManager.new_best_set.connect(_update_ghost_data)

	# Start countdown
	RaceManager.start_countdown()


func _spawn_ghost() -> void:
	if RaceManager.best_ghost.is_empty():
		return

	var ghost_script := preload("res://ghost_player.gd")
	_ghost_best = Node3D.new()
	_ghost_best.set_script(ghost_script)
	add_child(_ghost_best)
	_ghost_best.setup(RaceManager.best_ghost, Color(0.2, 0.5, 1.0, 0.35))


func _respawn_at_start() -> void:
	if not car:
		return
	car.global_position = _spawn_pos + Vector3(0, 0.5, 0)
	car.rotation.y = _spawn_rot
	car.velocity = Vector3.ZERO
	car.speed = 0.0

	# Stop ghost — will restart on race_started signal after countdown
	if _ghost_best and _ghost_best.has_method("stop_playback"):
		_ghost_best.stop_playback()
	# Re-connect ghost to race_started (reset() disconnects all signals)
	if not RaceManager.race_started.is_connected(_start_ghost):
		RaceManager.race_started.connect(_start_ghost)


func _start_ghost() -> void:
	if _ghost_best and _ghost_best.has_method("start_playback"):
		var loop: bool = not RaceManager.is_sprint
		_ghost_best.start_playback(loop)


func _update_ghost_data() -> void:
	# New best was set — update the ghost player with fresh data
	if RaceManager.best_ghost.is_empty():
		return
	if _ghost_best and _ghost_best.has_method("setup"):
		_ghost_best.setup(RaceManager.best_ghost, Color(0.2, 0.5, 1.0, 0.35))
	elif not _ghost_best:
		_spawn_ghost()


func toggle_ghost() -> void:
	_ghost_visible = not _ghost_visible
	if _ghost_best and _ghost_best.has_method("toggle_visible"):
		_ghost_best.toggle_visible()


func _spawn_trigger(pos: Vector3, rot_y: float, trigger_name: String) -> void:
	var area := Area3D.new()
	area.name = trigger_name

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(float(TrackPieces.ROAD_W) * 2.0 + 2.0, 6.0, 6.0)
	col.shape = box
	area.add_child(col)

	area.position = pos
	area.rotation.y = rot_y
	area.monitoring = true
	area.monitorable = false
	area.collision_layer = 0
	area.collision_mask = 1

	area.body_entered.connect(_on_trigger_entered.bind(trigger_name))
	add_child(area)


func _on_trigger_entered(body: Node3D, trigger_name: String) -> void:
	if body != car:
		return

	if trigger_name == "start":
		# Set respawn to start position
		RaceManager.respawn_pos = _spawn_pos
		RaceManager.respawn_rot = _spawn_rot
		if RaceManager.is_sprint:
			if RaceManager.state == RaceManager.State.FINISHED:
				RaceManager.reset()
				RaceManager.start_countdown()
			elif RaceManager.state == RaceManager.State.IDLE:
				RaceManager.cross_start()
		else:
			if RaceManager.state == RaceManager.State.TIME_UP or RaceManager.state == RaceManager.State.FINISHED:
				RaceManager.reset()
				RaceManager.start_countdown()
			else:
				RaceManager.cross_start_finish()

	elif trigger_name == "finish":
		RaceManager.cross_finish()
		# Auto-respawn at start after sprint finish
		if RaceManager.state == RaceManager.State.FINISHED:
			# Delay respawn so player sees the result
			get_tree().create_timer(3.0).timeout.connect(_respawn_at_start)

	elif trigger_name.begins_with("checkpoint_"):
		var idx: int = int(trigger_name.split("_")[1])
		RaceManager.hit_checkpoint(idx)
		# Set respawn to this checkpoint position
		RaceManager.respawn_pos = body.global_position
		RaceManager.respawn_rot = body.rotation.y
