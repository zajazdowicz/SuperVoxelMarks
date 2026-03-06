extends Node3D
## Generates a racing circuit using waypoints and blocky voxels.

const TRACK_WIDTH := 7
const WALL_HEIGHT := 2
const CURB_WIDTH := 1

# Block type IDs
const AIR := 0
const ASPHALT := 1
const GRASS := 2
const WALL := 3
const CURB := 4
const SAND := 5

@onready var terrain: VoxelTerrain = $"../VoxelTerrain"


func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	_generate_track()


func _generate_track() -> void:
	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE

	# Circuit defined as waypoints - a GP-style track
	var waypoints: Array[Vector2] = _build_circuit()

	# Interpolate smooth path from waypoints
	var path := _smooth_path(waypoints, 4)

	# Paint track along path
	for i in range(path.size()):
		var pos := path[i]
		var next_pos := path[(i + 1) % path.size()]
		var dir := (next_pos - pos).normalized()
		var normal := Vector2(-dir.y, dir.x)

		# Sand runoff
		for w in range(-TRACK_WIDTH - 3, TRACK_WIDTH + 4):
			var p := pos + normal * float(w)
			tool.set_voxel(Vector3i(int(p.x), 0, int(p.y)), SAND)

		# Asphalt
		for w in range(-TRACK_WIDTH, TRACK_WIDTH + 1):
			var p := pos + normal * float(w)
			tool.set_voxel(Vector3i(int(p.x), 0, int(p.y)), ASPHALT)

		# Curbs on edges
		for w in [TRACK_WIDTH - CURB_WIDTH, TRACK_WIDTH, -TRACK_WIDTH, -TRACK_WIDTH + CURB_WIDTH]:
			# Alternating red/white curb pattern
			if (i / 3) % 2 == 0:
				var p := pos + normal * float(w)
				tool.set_voxel(Vector3i(int(p.x), 0, int(p.y)), CURB)

		# Walls on outer edges
		for side in [-1, 1]:
			var w_offset := float(TRACK_WIDTH + 3) * float(side)
			var p := pos + normal * w_offset
			var base := Vector3i(int(p.x), 0, int(p.y))
			tool.set_voxel(base, WALL)
			for h in range(1, WALL_HEIGHT + 1):
				tool.set_voxel(base + Vector3i(0, h, 0), WALL)


func _build_circuit() -> Array[Vector2]:
	# GP-style circuit with varied corners
	var pts: Array[Vector2] = []

	# Start/finish straight
	pts.append(Vector2(50, 0))
	pts.append(Vector2(30, 0))

	# Turn 1 - tight hairpin
	pts.append(Vector2(15, 5))
	pts.append(Vector2(5, 18))
	pts.append(Vector2(0, 35))

	# Back straight
	pts.append(Vector2(-5, 50))
	pts.append(Vector2(-10, 60))

	# Chicane (S-curve)
	pts.append(Vector2(-20, 68))
	pts.append(Vector2(-30, 65))
	pts.append(Vector2(-40, 68))

	# Long sweeping left
	pts.append(Vector2(-50, 60))
	pts.append(Vector2(-55, 45))
	pts.append(Vector2(-50, 30))

	# Short straight
	pts.append(Vector2(-40, 20))

	# Final complex - tight right then left
	pts.append(Vector2(-30, 10))
	pts.append(Vector2(-15, 5))
	pts.append(Vector2(-5, -5))

	# Return to start
	pts.append(Vector2(10, -10))
	pts.append(Vector2(30, -8))
	pts.append(Vector2(45, -5))

	return pts


func _smooth_path(waypoints: Array[Vector2], subdivisions: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var count := waypoints.size()

	for i in range(count):
		var p0 := waypoints[(i - 1 + count) % count]
		var p1 := waypoints[i]
		var p2 := waypoints[(i + 1) % count]
		var p3 := waypoints[(i + 2) % count]

		for t in range(subdivisions):
			var ft := float(t) / float(subdivisions)
			# Catmull-Rom spline
			var point := 0.5 * (
				2.0 * p1 +
				(-p0 + p2) * ft +
				(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * ft * ft +
				(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * ft * ft * ft
			)
			result.append(point)

	return result
