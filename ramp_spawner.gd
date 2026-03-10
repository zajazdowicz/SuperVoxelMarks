class_name RampSpawner

## Spawns smooth collision surfaces for ramps, wall rides and loops.
## Road voxels in these areas are AIR - ConvexPolygon is the ONLY collision.
## Ground surface = y=1 (top of y=0 voxel blocks).

const GRID := TrackPieces.SEGMENT_SIZE
const ROAD_W := TrackPieces.ROAD_W
const RAMP_H := TrackPieces.RAMP_HEIGHT
const HALF := TrackPieces.HALF
const WR_H := TrackPieces.WALL_RIDE_HEIGHT
const WR_BANK := TrackPieces.WALL_RIDE_BANK_DEG


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


# =======================================================================
# WALL RIDE
# =======================================================================
# Wall ride = tilted surface on the RIGHT side of the road.
# Entry: flat road transitions to ~60° banked surface
# Straight: fully banked ~60° surface
# Exit: banked surface transitions back to flat
#
# The car drives on the tilted surface; floor_normal provides tilt info
# to car_controller for gravity adjustment.

const WR_SEGMENTS := 4  # segments for smooth wall ride transition

static func spawn_wall_ride(parent: Node3D, grid_pos: Vector2i, piece_id: int, rotation: int, base_height: int = 0) -> void:
	var body := StaticBody3D.new()
	body.name = "WallRide_%d_%d" % [grid_pos.x, grid_pos.y]

	var hw: float = float(ROAD_W) + 0.5
	var hl: float = float(HALF)
	var ground: float = 1.0
	var bank_rad: float = deg_to_rad(WR_BANK)  # 60° in radians
	var road_w: float = 2.0 * hw  # full road width (9.0)
	var rot_angle: float = -float(rotation) * PI / 2.0
	var basis_rot := Basis(Vector3.UP, rot_angle)

	var is_entry := piece_id == 12
	var is_exit := piece_id == 14

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	# Build surface as segments from south to north
	# The road surface ROTATES around the LEFT edge (-hw) by bank angle.
	# At 60°: right edge moves from (+hw, ground) to (~0, ground+7.8)
	# This creates a proper steep wall ride surface.
	var segs := WR_SEGMENTS if (is_entry or is_exit) else 1
	for seg in range(segs):
		var t0: float = float(seg) / float(segs)
		var t1: float = float(seg + 1) / float(segs)

		# Bank factor: 0 = flat road, 1 = full bank angle
		var bf0: float
		var bf1: float
		if is_entry:
			bf0 = t0
			bf1 = t1
		elif is_exit:
			bf0 = 1.0 - t0
			bf1 = 1.0 - t1
		else:  # straight
			bf0 = 1.0
			bf1 = 1.0

		var angle0 := bank_rad * bf0
		var angle1 := bank_rad * bf1

		var z0: float = lerpf(-hl, hl, t0)
		var z1: float = lerpf(-hl, hl, t1)

		# Left edge = pivot (stays at ground level)
		# Right edge rotates around left edge by bank angle
		var p0l := basis_rot * Vector3(-hw, ground, z0)
		var p0r := basis_rot * Vector3(-hw + road_w * cos(angle0), ground + road_w * sin(angle0), z0)
		var p1l := basis_rot * Vector3(-hw, ground, z1)
		var p1r := basis_rot * Vector3(-hw + road_w * cos(angle1), ground + road_w * sin(angle1), z1)

		# Visual quad
		var n := (p1l - p0l).cross(p0r - p0l).normalized()
		_add_quad(verts, normals, indices, p0l, p0r, p1r, p1l, n)

		# Collision segment — surface + bottom support
		var col_points := PackedVector3Array()
		col_points.append(p0l); col_points.append(p0r)
		col_points.append(p1l); col_points.append(p1r)
		# Bottom support below surface
		col_points.append(basis_rot * Vector3(-hw, ground - 0.5, z0))
		col_points.append(basis_rot * Vector3(-hw + road_w * cos(angle0), ground + road_w * sin(angle0) - 0.5, z0))
		col_points.append(basis_rot * Vector3(-hw, ground - 0.5, z1))
		col_points.append(basis_rot * Vector3(-hw + road_w * cos(angle1), ground + road_w * sin(angle1) - 0.5, z1))

		var col_shape := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = col_points
		col_shape.shape = shape
		body.add_child(col_shape)

	# Visual mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.3, 0.4)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	body.add_child(mi)

	var world_x: float = float(grid_pos.x * GRID)
	var world_z: float = float(grid_pos.y * GRID)
	body.position = Vector3(world_x, float(base_height), world_z)
	parent.add_child(body)


# =======================================================================
# LOOP (full 360° in one segment)
# =======================================================================
# Circle in YZ plane: car enters from south at ground, loops up and over,
# exits to north at ground. R = HALF (6) fits in SEGMENT_SIZE (12).
#
# Parametrization (angle a from 0 to 2*PI):
#   Y(a) = center_y - R * cos(a)  → bottom: ground, top: ground + 2R
#   Z(a) = R * sin(a)             → ranges -R..+R = -6..+6 = fits segment
# Road width in X (perpendicular to loop plane).

const LOOP_SEGMENTS := 24  # segments for full circle (smooth)

static func spawn_loop(parent: Node3D, grid_pos: Vector2i, rotation: int, base_height: int = 0) -> void:
	var body := StaticBody3D.new()
	body.name = "Loop_%d_%d" % [grid_pos.x, grid_pos.y]

	var hw: float = float(ROAD_W) + 0.5
	var ground: float = 1.0
	var R: float = float(HALF)  # 6.0 — fits in segment
	var center_y: float = ground + R
	var rot_angle: float = -float(rotation) * PI / 2.0
	var basis_rot := Basis(Vector3.UP, rot_angle)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	for seg in range(LOOP_SEGMENTS):
		var t0: float = float(seg) / float(LOOP_SEGMENTS)
		var t1: float = float(seg + 1) / float(LOOP_SEGMENTS)
		var a0: float = t0 * TAU  # 0 to 2*PI
		var a1: float = t1 * TAU

		# Circle positions in YZ plane
		var y0: float = center_y - R * cos(a0)
		var y1: float = center_y - R * cos(a1)
		var z0: float = R * sin(a0)
		var z1: float = R * sin(a1)

		# Road surface: left/right in X, perpendicular to loop plane
		var p0l := basis_rot * Vector3(-hw, y0, z0)
		var p0r := basis_rot * Vector3(hw, y0, z0)
		var p1l := basis_rot * Vector3(-hw, y1, z1)
		var p1r := basis_rot * Vector3(hw, y1, z1)

		# Normal: points inward (toward center) = (0, cos(a), -sin(a))
		var mid_a := (a0 + a1) * 0.5
		var n := basis_rot * Vector3(0, cos(mid_a), -sin(mid_a)).normalized()

		_add_quad(verts, normals, indices, p0l, p0r, p1r, p1l, n)

		# Collision: ConvexPolygon per segment (quad + inner support)
		var col_points := PackedVector3Array()
		col_points.append(p0l); col_points.append(p0r)
		col_points.append(p1l); col_points.append(p1r)
		# Inner support (slightly toward center)
		var inner_offset := 0.5
		var iy0: float = center_y - (R - inner_offset) * cos(a0)
		var iz0: float = (R - inner_offset) * sin(a0)
		var iy1: float = center_y - (R - inner_offset) * cos(a1)
		var iz1: float = (R - inner_offset) * sin(a1)
		col_points.append(basis_rot * Vector3(-hw, iy0, iz0))
		col_points.append(basis_rot * Vector3(hw, iy0, iz0))
		col_points.append(basis_rot * Vector3(-hw, iy1, iz1))
		col_points.append(basis_rot * Vector3(hw, iy1, iz1))

		var col_shape := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = col_points
		col_shape.shape = shape
		body.add_child(col_shape)

	# Visual mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.35, 0.4)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	body.add_child(mi)

	var world_x: float = float(grid_pos.x * GRID)
	var world_z: float = float(grid_pos.y * GRID)
	body.position = Vector3(world_x, float(base_height), world_z)
	parent.add_child(body)
