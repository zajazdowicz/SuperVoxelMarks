extends Node3D
## Loads saved track data and builds it on the voxel terrain.

const GRID := TrackPieces.SEGMENT_SIZE

@onready var terrain: VoxelTerrain = $"../VoxelTerrain"
@onready var car: CharacterBody3D = $"../Car"


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

	for p in pieces:
		var piece := TrackPieces.get_piece(p.piece)
		var rotated := TrackPieces.rotate_piece(piece, p.rotation)
		var bh: int = p.get("base_height", 0)
		var offset := Vector3i(p.grid.x * GRID, bh, p.grid.y * GRID)
		for block in rotated:
			tool.set_voxel(offset + block.pos, block.type)

		# Spawn ramp collision
		if p.piece == 3 or p.piece == 4:
			RampSpawner.spawn_ramp(self, p.grid, p.piece, p.rotation, bh)

		# Spawn car at Start/Meta piece
		if p.piece == 5:
			spawn_pos = Vector3(p.grid.x * GRID, bh + 3, p.grid.y * GRID)

	if car:
		car.global_position = spawn_pos
