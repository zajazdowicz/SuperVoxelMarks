extends Node3D
## Loads saved track data and builds it on the voxel terrain.
## Spawns collision for ramps and trigger zones for start/checkpoints.

const GRID := TrackPieces.SEGMENT_SIZE

@onready var terrain: VoxelTerrain = $"../VoxelTerrain"
@onready var car: CharacterBody3D = $"../Car"

var _checkpoint_count := 0


func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	_build_track()


func _build_track() -> void:
	var pieces := TrackData.load_track(TrackData.current_track)
	if pieces.is_empty():
		return

	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE

	var spawn_pos := Vector3(0, 3, 0)
	var spawn_rot := 0.0
	_checkpoint_count = 0

	for p in pieces:
		var piece := TrackPieces.get_piece(p.piece)
		var rotated := TrackPieces.rotate_piece(piece, p.rotation)
		var bh: int = p.get("base_height", 0)
		var offset := Vector3i(p.grid.x * GRID, bh, p.grid.y * GRID)
		for block in rotated:
			tool.set_voxel(offset + block.pos, block.type)

		var world_pos := Vector3(p.grid.x * GRID, float(bh), p.grid.y * GRID)
		var rot_y: float = -float(p.rotation) * PI / 2.0

		# Spawn ramp collision
		if p.piece == 3 or p.piece == 4:
			RampSpawner.spawn_ramp(self, p.grid, p.piece, p.rotation, bh)

		# Start/Meta - spawn car + trigger
		if p.piece == 5:
			spawn_pos = Vector3(p.grid.x * GRID, bh + 3, p.grid.y * GRID)
			spawn_rot = rot_y
			_spawn_trigger(world_pos + Vector3(0, 2, 0), rot_y, "start_finish")

		# Checkpoint - spawn trigger
		if p.piece == 8:
			_spawn_trigger(world_pos + Vector3(0, 2, 0), rot_y, "checkpoint_%d" % _checkpoint_count)
			_checkpoint_count += 1

	RaceManager.total_checkpoints = _checkpoint_count

	if car:
		car.global_position = spawn_pos
		car.rotation.y = spawn_rot


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
	# Connect only to car (layer 1)
	area.collision_layer = 0
	area.collision_mask = 1

	area.body_entered.connect(_on_trigger_entered.bind(trigger_name))
	add_child(area)


func _on_trigger_entered(body: Node3D, trigger_name: String) -> void:
	if body != car:
		return

	if trigger_name == "start_finish":
		if RaceManager.state == RaceManager.State.IDLE:
			RaceManager.start_race()
		elif RaceManager.state == RaceManager.State.RACING:
			RaceManager.finish_race()

	elif trigger_name.begins_with("checkpoint_"):
		var idx: int = int(trigger_name.split("_")[1])
		RaceManager.hit_checkpoint(idx)
