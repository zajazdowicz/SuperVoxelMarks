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

	# Sort by base_height — higher pieces built last so their voxels win
	var sorted := pieces.duplicate()
	sorted.sort_custom(func(a, b): return a.get("base_height", 0) < b.get("base_height", 0))

	for p in sorted:
		var piece := TrackPieces.get_piece(p.piece)
		var rotated := TrackPieces.rotate_piece(piece, p.rotation)
		var bh: int = p.get("base_height", 0)
		var offset := Vector3i(p.grid.x * GRID, bh, p.grid.y * GRID)
		for block in rotated:
			tool.set_voxel(offset + block.pos, block.type)

		var world_pos := Vector3(p.grid.x * GRID, float(bh), p.grid.y * GRID)
		var rot_y: float = -float(p.rotation) * PI / 2.0

		if p.piece in [3, 4, 30, 31]:
			RampSpawner.spawn_ramp(self, p.grid, p.piece, p.rotation, bh)

		if p.piece >= 12 and p.piece <= 14:
			RampSpawner.spawn_wall_ride(self, p.grid, p.piece, p.rotation, bh)

		if p.piece >= 15 and p.piece <= 18:
			RampSpawner.spawn_loop(self, p.grid, p.piece, p.rotation, bh)

		if p.piece == 19:
			RampSpawner.spawn_vloop(self, p.grid, p.piece, p.rotation, bh)

		if p.piece == 22 or p.piece == 23:
			RampSpawner.spawn_transition(self, p.grid, p.piece, p.rotation, bh)

		if p.piece == 28 or p.piece == 29:
			RampSpawner.spawn_banked_turn(self, p.grid, p.piece, p.rotation, bh)

		if p.piece == 34 or p.piece == 35:
			RampSpawner.spawn_ramp_turn(self, p.grid, p.piece, p.rotation, bh)

		if p.piece == 39:
			RampSpawner.spawn_jump_pad(self, p.grid, p.piece, p.rotation, bh)

		if p.piece >= 42 and p.piece <= 47:
			RampSpawner.spawn_slope(self, p.grid, p.piece, p.rotation, bh)

		if p.piece >= 48 and p.piece <= 53:
			var qp_down: bool = p.get("down", false)
			RampSpawner.spawn_quarter_pipe(self, p.grid, p.piece, p.rotation, bh, qp_down)

		if p.piece >= 57 and p.piece <= 62:
			RampSpawner.spawn_slope_turn(self, p.grid, p.piece, p.rotation, bh)

		if p.piece == 5:
			_spawn_pos = Vector3(p.grid.x * GRID, bh + 3, p.grid.y * GRID)
			# Car faces the exit direction of the start piece
			var ports := TrackPieces.get_ports(p.piece)
			var rot_ports := TrackPieces.rotate_ports(ports, p.rotation)
			var exit_dir: Vector2i = rot_ports[1].dir
			_spawn_rot = atan2(-float(exit_dir.x), -float(exit_dir.y))
			_spawn_trigger(world_pos + Vector3(0, 2, 0), rot_y, "start")

		if p.piece == 11:
			_spawn_trigger(world_pos + Vector3(0, 2, 0), rot_y, "finish")
			has_finish = true

		if p.piece == 8:
			_spawn_trigger(world_pos + Vector3(0, 2, 0), rot_y, "checkpoint_%d" % _checkpoint_count)
			_checkpoint_count += 1

	# Second pass: clear boundary voxels at ramp HIGH end.
	# Neighbor pieces may have re-filled these with ASPHALT, creating a
	# side face that blocks the car when ascending. Clearing to AIR lets
	# the ramp's ConvexPolygon be the sole collision at the boundary.
	for p in pieces:
		if p.piece not in [3, 4, 30, 31]:
			continue
		var bh2: int = p.get("base_height", 0)
		var offset2 := Vector3i(p.grid.x * GRID, bh2, p.grid.y * GRID)
		var is_up4: bool = p.piece == 3 or p.piece == 30
		var high_z: int = TrackPieces.HI if is_up4 else TrackPieces.LO
		var rh4: int = TrackPieces.RAMP_HEIGHT if (p.piece == 3 or p.piece == 4) else TrackPieces.HALF_RAMP_HEIGHT
		for x2 in range(-TrackPieces.ROAD_W, TrackPieces.ROAD_W + 1):
			var rx := x2
			var rz := high_z
			for _r in range(p.rotation % 4):
				var tmp := rx
				rx = -rz
				rz = tmp
			for h2 in range(0, rh4 + 1):
				tool.set_voxel(offset2 + Vector3i(rx, h2, rz), TrackPieces.AIR)

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

	# Start countdown
	RaceManager.start_countdown()


func _spawn_ghost() -> void:
	print("GHOST: best_ghost size=%d best_time=%.2f" % [RaceManager.best_ghost.size(), RaceManager.best_time])
	if RaceManager.best_ghost.is_empty():
		print("GHOST: No ghost data — skipping spawn")
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

	# Start ghost playback
	if _ghost_best and _ghost_best.has_method("start_playback"):
		_ghost_best.start_playback()


func _start_ghost() -> void:
	if _ghost_best and _ghost_best.has_method("start_playback"):
		var loop: bool = not RaceManager.is_sprint
		_ghost_best.start_playback(loop)


func toggle_ghost() -> void:
	_ghost_visible = not _ghost_visible
	if _ghost_best and _ghost_best.has_method("toggle_visible"):
		_ghost_best.toggle_visible()


func _spawn_trigger(pos: Vector3, rot_y: float, trigger_name: String) -> void:
	var area := Area3D.new()
	area.name = trigger_name

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(float(TrackPieces.ROAD_W) * 2.0 + 2.0, 4.0, 2.0)
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
