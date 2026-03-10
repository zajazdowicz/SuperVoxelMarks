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

	if car:
		car.set_physics_process(false)

	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE

	_spawn_pos = Vector3(0, 3, 0)
	_spawn_rot = 0.0
	_checkpoint_count = 0
	var has_finish := false

	for p in pieces:
		var piece := TrackPieces.get_piece(p.piece)
		var rotated := TrackPieces.rotate_piece(piece, p.rotation)
		var bh: int = p.get("base_height", 0)
		var offset := Vector3i(p.grid.x * GRID, bh, p.grid.y * GRID)
		for block in rotated:
			tool.set_voxel(offset + block.pos, block.type)

		var world_pos := Vector3(p.grid.x * GRID, float(bh), p.grid.y * GRID)
		var rot_y: float = -float(p.rotation) * PI / 2.0

		if p.piece == 3 or p.piece == 4:
			RampSpawner.spawn_ramp(self, p.grid, p.piece, p.rotation, bh)

		if p.piece >= 12 and p.piece <= 14:
			RampSpawner.spawn_wall_ride(self, p.grid, p.piece, p.rotation, bh)

		if p.piece >= 15 and p.piece <= 18:
			RampSpawner.spawn_loop_quarter(self, p.grid, p.piece, p.rotation, bh)

		if p.piece == 5:
			_spawn_pos = Vector3(p.grid.x * GRID, bh + 3, p.grid.y * GRID)
			_spawn_rot = rot_y
			_spawn_trigger(world_pos + Vector3(0, 2, 0), rot_y, "start")

		if p.piece == 11:
			_spawn_trigger(world_pos + Vector3(0, 2, 0), rot_y, "finish")
			has_finish = true

		if p.piece == 8:
			_spawn_trigger(world_pos + Vector3(0, 2, 0), rot_y, "checkpoint_%d" % _checkpoint_count)
			_checkpoint_count += 1

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

	# Start ghost playback
	if _ghost_best and _ghost_best.has_method("start_playback"):
		_ghost_best.start_playback()


func _start_ghost() -> void:
	if _ghost_best and _ghost_best.has_method("start_playback"):
		_ghost_best.start_playback()


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
				RaceManager.start_race()
				_start_ghost()
			elif RaceManager.state == RaceManager.State.IDLE:
				RaceManager.cross_start()
				_start_ghost()
		else:
			if RaceManager.state == RaceManager.State.TIME_UP or RaceManager.state == RaceManager.State.FINISHED:
				RaceManager.reset()
				RaceManager.start_race()
				_start_ghost()
			else:
				var prev_lap := RaceManager.lap_count
				RaceManager.cross_start_finish()
				if RaceManager.state == RaceManager.State.RACING and RaceManager.lap_count != prev_lap:
					_start_ghost()

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
