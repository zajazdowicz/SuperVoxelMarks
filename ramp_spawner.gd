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


static func _add_col_box(body: StaticBody3D, p0l: Vector3, p0r: Vector3,
		p1l: Vector3, p1r: Vector3, bottom_y: float, basis_rot: Basis) -> void:
	## Shorthand: 4 surface points + 4 bottom support points → ConvexPolygon.
	var col_points := PackedVector3Array()
	col_points.append(p0l); col_points.append(p0r)
	col_points.append(p1l); col_points.append(p1r)
	col_points.append(Vector3(p0l.x, bottom_y, p0l.z))
	col_points.append(Vector3(p0r.x, bottom_y, p0r.z))
	col_points.append(Vector3(p1l.x, bottom_y, p1l.z))
	col_points.append(Vector3(p1r.x, bottom_y, p1r.z))
	var col_shape := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = col_points
	col_shape.shape = shape
	body.add_child(col_shape)


static func _add_collision_quad(body: StaticBody3D, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, bottom_y: float, basis_rot: Basis) -> void:
	## Add a flat collision quad with bottom support.
	var col_points := PackedVector3Array()
	col_points.append(a); col_points.append(b)
	col_points.append(c); col_points.append(d)
	# Bottom support
	col_points.append(Vector3(a.x, bottom_y, a.z))
	col_points.append(Vector3(b.x, bottom_y, b.z))
	col_points.append(Vector3(c.x, bottom_y, c.z))
	col_points.append(Vector3(d.x, bottom_y, d.z))
	var col_shape := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = col_points
	col_shape.shape = shape
	body.add_child(col_shape)


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
# LOOP / BARREL ROLL (corkscrew — road twists 360° around forward axis)
# =======================================================================
# The road rotates around the Z-axis (driving direction) while rising and falling.
# Entry and exit are flat at ground level — NO blocking geometry.
# At t=0.5 the road is inverted at max height. Wall-ride physics handles adhesion.

const LOOP_SEG_PER_QUARTER := 8  # segments per quarter (8 = smooth enough)

static func spawn_loop(parent: Node3D, grid_pos: Vector2i, piece_id: int, rotation: int, base_height: int = 0) -> void:
	var body := StaticBody3D.new()
	body.name = "Loop_%d_%d" % [grid_pos.x, grid_pos.y]

	var quarter := piece_id - 15  # 0..3
	var angle_start: float = float(quarter) * PI / 2.0
	var angle_end: float = float(quarter + 1) * PI / 2.0

	var hw: float = float(ROAD_W) + 0.5  # 4.5 — twist radius
	var hl: float = float(HALF)  # 6
	var ground: float = 1.0
	var rot_angle: float = -float(rotation) * PI / 2.0
	var basis_rot := Basis(Vector3.UP, rot_angle)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var tri_faces := PackedVector3Array()

	for seg in range(LOOP_SEG_PER_QUARTER):
		var t0: float = float(seg) / float(LOOP_SEG_PER_QUARTER)
		var t1: float = float(seg + 1) / float(LOOP_SEG_PER_QUARTER)

		var z0: float = lerpf(-hl, hl, t0)
		var z1: float = lerpf(-hl, hl, t1)

		var a0: float = lerpf(angle_start, angle_end, t0)
		var a1: float = lerpf(angle_start, angle_end, t1)

		var cy0: float = ground + hw * (1.0 - cos(a0))
		var cy1: float = ground + hw * (1.0 - cos(a1))

		var p0l := basis_rot * Vector3(-hw * cos(a0), cy0 - hw * sin(a0), z0)
		var p0r := basis_rot * Vector3(hw * cos(a0), cy0 + hw * sin(a0), z0)
		var p1l := basis_rot * Vector3(-hw * cos(a1), cy1 - hw * sin(a1), z1)
		var p1r := basis_rot * Vector3(hw * cos(a1), cy1 + hw * sin(a1), z1)

		var n := (p1l - p0l).cross(p0r - p0l).normalized()
		_add_quad(verts, normals, indices, p0l, p0r, p1r, p1l, n)

		tri_faces.append(p0l); tri_faces.append(p0r); tri_faces.append(p1r)
		tri_faces.append(p0l); tri_faces.append(p1r); tri_faces.append(p1l)

	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(tri_faces)
	var col_shape := CollisionShape3D.new()
	col_shape.shape = concave
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


# =======================================================================
# VERTICAL LOOP (2 segments: up + down)
# =======================================================================
# Larger radius than barrel roll for a more dramatic loop.
# Piece 19: "Petla gora" — 0° → 180° (ground → inverted at top)
# Piece 20: "Petla dol"  — 180° → 360° (inverted → ground)

const VLOOP_R := 7.0  # loop radius (max height = ground + 2*R = 15)
const VLOOP_SEGS := 12  # segments per half

static func spawn_vloop(parent: Node3D, grid_pos: Vector2i, piece_id: int, rotation: int, base_height: int = 0) -> void:
	var body := StaticBody3D.new()
	body.name = "VLoop_%d_%d" % [grid_pos.x, grid_pos.y]

	var half_idx := piece_id - 19  # 0 = up, 1 = down
	var angle_start: float = float(half_idx) * PI
	var angle_end: float = float(half_idx + 1) * PI

	var hw: float = float(ROAD_W) + 0.5
	var R: float = VLOOP_R
	var hl: float = float(HALF)
	var ground: float = 1.0
	var rot_angle: float = -float(rotation) * PI / 2.0
	var basis_rot := Basis(Vector3.UP, rot_angle)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var tri_faces := PackedVector3Array()

	for seg in range(VLOOP_SEGS):
		var t0: float = float(seg) / float(VLOOP_SEGS)
		var t1: float = float(seg + 1) / float(VLOOP_SEGS)

		var z0: float = lerpf(-hl, hl, t0)
		var z1: float = lerpf(-hl, hl, t1)

		var a0: float = lerpf(angle_start, angle_end, t0)
		var a1: float = lerpf(angle_start, angle_end, t1)

		var cy0: float = ground + R * (1.0 - cos(a0))
		var cy1: float = ground + R * (1.0 - cos(a1))

		# Road cross-section: hw for width, R for loop height
		var p0l := basis_rot * Vector3(-hw * cos(a0), cy0 - hw * sin(a0), z0)
		var p0r := basis_rot * Vector3(hw * cos(a0), cy0 + hw * sin(a0), z0)
		var p1l := basis_rot * Vector3(-hw * cos(a1), cy1 - hw * sin(a1), z1)
		var p1r := basis_rot * Vector3(hw * cos(a1), cy1 + hw * sin(a1), z1)

		var n := (p1l - p0l).cross(p0r - p0l).normalized()
		_add_quad(verts, normals, indices, p0l, p0r, p1r, p1l, n)

		tri_faces.append(p0l); tri_faces.append(p0r); tri_faces.append(p1r)
		tri_faces.append(p0l); tri_faces.append(p1r); tri_faces.append(p1l)

	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(tri_faces)
	var col_shape := CollisionShape3D.new()
	col_shape.shape = concave
	body.add_child(col_shape)

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
	mat.albedo_color = Color(0.35, 0.3, 0.35)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	body.add_child(mi)

	body.position = Vector3(float(grid_pos.x * GRID), float(base_height), float(grid_pos.y * GRID))
	parent.add_child(body)
