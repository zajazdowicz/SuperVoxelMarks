class_name RampSpawner

## Spawns smooth ramp: trimesh collision surface + visible mesh.
## Road voxels in ramp area are AIR - this is the ONLY collision surface.
## Ground surface = y=1 (top of y=0 voxel blocks).
## hl = HALF exactly — blocks fit the grid perfectly.

const GRID := TrackPieces.SEGMENT_SIZE
const ROAD_W := TrackPieces.ROAD_W
const RAMP_H := TrackPieces.RAMP_HEIGHT
const HALF := TrackPieces.HALF


static func spawn_ramp(parent: Node3D, grid_pos: Vector2i, piece_id: int, rotation: int, base_height: int = 0) -> void:
	var is_up := piece_id == 3
	var is_down := piece_id == 4
	if not is_up and not is_down:
		return

	var ramp := StaticBody3D.new()
	ramp.name = "RampCollision_%d_%d" % [grid_pos.x, grid_pos.y]

	var hw: float = float(ROAD_W) + 0.5  # half-width of road
	var hl: float = float(HALF)            # exact grid fit
	var h: float = float(RAMP_H)

	var ground: float = 1.0
	var low_y: float = ground
	var high_y: float = ground + h

	# 4 corner points of the ramp surface
	var tl_s: Vector3  # top-left south
	var tr_s: Vector3  # top-right south
	var tl_n: Vector3  # top-left north
	var tr_n: Vector3  # top-right north

	if is_up:
		tl_s = Vector3(-hw, low_y, -hl)
		tr_s = Vector3(hw, low_y, -hl)
		tl_n = Vector3(-hw, high_y, hl)
		tr_n = Vector3(hw, high_y, hl)
	else:
		tl_s = Vector3(-hw, high_y, -hl)
		tr_s = Vector3(hw, high_y, -hl)
		tl_n = Vector3(-hw, low_y, hl)
		tr_n = Vector3(hw, low_y, hl)

	# Apply piece rotation around Y
	var rot_angle: float = -float(rotation) * PI / 2.0
	var basis_rot := Basis(Vector3.UP, rot_angle)
	tl_s = basis_rot * tl_s
	tr_s = basis_rot * tr_s
	tl_n = basis_rot * tl_n
	tr_n = basis_rot * tr_n

	# Trimesh collision (ConcavePolygonShape3D) — just the driving surface
	# Two triangles forming a quad, plus a thin bottom to give it volume
	var bl_s := basis_rot * Vector3(-hw, low_y - 0.5, -hl)
	var br_s := basis_rot * Vector3(hw, low_y - 0.5, -hl)
	var bl_n := basis_rot * Vector3(-hw, low_y - 0.5, hl)
	var br_n := basis_rot * Vector3(hw, low_y - 0.5, hl)

	# Use ConvexPolygonShape3D but with entry edge at surface level (no lip)
	var points := PackedVector3Array()
	if is_up:
		# Entry (south): bottom matches surface — no lip
		points.append(Vector3(-hw, low_y - 0.05, -hl))
		points.append(Vector3(hw, low_y - 0.05, -hl))
		# Exit (north): deep bottom for support
		points.append(Vector3(hw, -0.5, hl))
		points.append(Vector3(-hw, -0.5, hl))
	else:
		# Entry (south): deep bottom for support
		points.append(Vector3(-hw, -0.5, -hl))
		points.append(Vector3(hw, -0.5, -hl))
		# Exit (north): bottom matches surface — no lip
		points.append(Vector3(hw, low_y - 0.05, hl))
		points.append(Vector3(-hw, low_y - 0.05, hl))
	# Top surface points
	points.append(tl_s)
	points.append(tr_s)
	points.append(tr_n)
	points.append(tl_n)

	# Rotate bottom points
	for i in range(4):
		points[i] = basis_rot * points[i]

	var col_shape := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	col_shape.shape = shape
	ramp.add_child(col_shape)

	# Visual mesh
	var visual := _create_ramp_visual(hw, hl, h, ground, is_up, basis_rot)
	ramp.add_child(visual)

	# Position at grid center + base height
	var world_x: float = float(grid_pos.x * GRID)
	var world_z: float = float(grid_pos.y * GRID)
	ramp.position = Vector3(world_x, float(base_height), world_z)

	parent.add_child(ramp)


static func _create_ramp_visual(hw: float, hl: float, h: float, ground: float, is_up: bool, basis_rot: Basis) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	var low_y: float = ground
	var high_y: float = ground + h

	var bl_s := Vector3(-hw, low_y, -hl)
	var br_s := Vector3(hw, low_y, -hl)
	var bl_n := Vector3(-hw, low_y, hl)
	var br_n := Vector3(hw, low_y, hl)

	var tl_s: Vector3
	var tr_s: Vector3
	var tl_n: Vector3
	var tr_n: Vector3

	if is_up:
		tl_s = Vector3(-hw, low_y, -hl)
		tr_s = Vector3(hw, low_y, -hl)
		tl_n = Vector3(-hw, high_y, hl)
		tr_n = Vector3(hw, high_y, hl)
	else:
		tl_s = Vector3(-hw, high_y, -hl)
		tr_s = Vector3(hw, high_y, -hl)
		tl_n = Vector3(-hw, low_y, hl)
		tr_n = Vector3(hw, low_y, hl)

	# Apply rotation
	bl_s = basis_rot * bl_s
	br_s = basis_rot * br_s
	bl_n = basis_rot * bl_n
	br_n = basis_rot * br_n
	tl_s = basis_rot * tl_s
	tr_s = basis_rot * tr_s
	tl_n = basis_rot * tl_n
	tr_n = basis_rot * tr_n

	# Top face (slope - driving surface)
	var slope_normal := (tl_n - tl_s).cross(tr_s - tl_s).normalized()
	_add_quad(verts, normals, indices, tl_s, tr_s, tr_n, tl_n, slope_normal)

	# Bottom face
	_add_quad(verts, normals, indices, bl_n, br_n, br_s, bl_s, -slope_normal)

	# Back face (tall end)
	if is_up:
		_add_quad(verts, normals, indices, bl_n, tl_n, tr_n, br_n, basis_rot * Vector3.FORWARD)
	else:
		_add_quad(verts, normals, indices, bl_s, tl_s, tr_s, br_s, basis_rot * Vector3.BACK)

	# Side triangles
	if is_up:
		_add_tri(verts, normals, indices, bl_n, tl_n, tl_s, basis_rot * Vector3.LEFT)
		_add_tri(verts, normals, indices, br_n, tr_s, tr_n, basis_rot * Vector3.RIGHT)
	else:
		_add_tri(verts, normals, indices, bl_s, tl_s, tl_n, basis_rot * Vector3.LEFT)
		_add_tri(verts, normals, indices, br_s, tr_n, tr_s, basis_rot * Vector3.RIGHT)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.35)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat

	return mi


static func _add_quad(verts: PackedVector3Array, normals: PackedVector3Array,
		indices: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		normal: Vector3) -> void:
	var idx := verts.size()
	verts.append(a); verts.append(b); verts.append(c); verts.append(d)
	for _i in range(4):
		normals.append(normal)
	indices.append(idx); indices.append(idx + 1); indices.append(idx + 2)
	indices.append(idx); indices.append(idx + 2); indices.append(idx + 3)


static func _add_tri(verts: PackedVector3Array, normals: PackedVector3Array,
		indices: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3,
		normal: Vector3) -> void:
	var idx := verts.size()
	verts.append(a); verts.append(b); verts.append(c)
	for _i in range(3):
		normals.append(normal)
	indices.append(idx); indices.append(idx + 1); indices.append(idx + 2)
