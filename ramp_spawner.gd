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

	# Apply piece rotation around Y
	var rot_angle: float = -float(rotation) * PI / 2.0
	var basis_rot := Basis(Vector3.UP, rot_angle)

	# Segmented collision: 4 ConvexPolygon slices along the ramp +
	# 1 flat landing at HIGH end (boundary voxels are cleared to AIR in
	# second pass, so this extension is safe — no overlapping collision).
	var ramp_segs := 4
	for seg in range(ramp_segs):
		var t0: float = float(seg) / float(ramp_segs)
		var t1: float = float(seg + 1) / float(ramp_segs)
		var z0: float = lerpf(-hl, hl, t0)
		var z1: float = lerpf(-hl, hl, t1)

		var y0: float
		var y1: float
		if is_up:
			y0 = lerpf(low_y, high_y, t0)
			y1 = lerpf(low_y, high_y, t1)
		else:
			y0 = lerpf(high_y, low_y, t0)
			y1 = lerpf(high_y, low_y, t1)

		_add_col_box(ramp,
			basis_rot * Vector3(-hw, y0, z0),
			basis_rot * Vector3(hw, y0, z0),
			basis_rot * Vector3(-hw, y1, z1),
			basis_rot * Vector3(hw, y1, z1),
			min(y0, y1) - 0.5, basis_rot)

	# Flat landing at HIGH end — covers the cleared boundary zone (1 unit)
	if is_up:
		_add_col_box(ramp,
			basis_rot * Vector3(-hw, high_y, hl),
			basis_rot * Vector3(hw, high_y, hl),
			basis_rot * Vector3(-hw, high_y, hl + 1.0),
			basis_rot * Vector3(hw, high_y, hl + 1.0),
			high_y - 0.5, basis_rot)
	else:
		_add_col_box(ramp,
			basis_rot * Vector3(-hw, high_y, -hl),
			basis_rot * Vector3(hw, high_y, -hl),
			basis_rot * Vector3(-hw, high_y, -hl - 1.0),
			basis_rot * Vector3(hw, high_y, -hl - 1.0),
			high_y - 0.5, basis_rot)

	# Visual mesh (includes flat landing at HIGH end)
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
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idxs := PackedInt32Array()

	var low_y := ground
	var high_y := ground + h
	var col_asphalt := Color(0.25, 0.25, 0.28)
	var col_curb := Color(0.9, 0.9, 0.9)

	# Grid of quads matching voxel-style road: curb dashes at edges
	var num_cols := int(2.0 * hw)   # 9 columns across road width
	var num_rows := int(2.0 * hl)   # 12 rows along ramp length
	var col_w := 2.0 * hw / float(num_cols)
	var row_l := 2.0 * hl / float(num_rows)

	# Slope surface
	for row in range(num_rows):
		var t0 := float(row) / float(num_rows)
		var t1 := float(row + 1) / float(num_rows)
		var z0 := lerpf(-hl, hl, t0)
		var z1 := lerpf(-hl, hl, t1)
		var y0: float
		var y1: float
		if is_up:
			y0 = lerpf(low_y, high_y, t0)
			y1 = lerpf(low_y, high_y, t1)
		else:
			y0 = lerpf(high_y, low_y, t0)
			y1 = lerpf(high_y, low_y, t1)

		for col in range(num_cols):
			var x0 := -hw + float(col) * col_w
			var x1 := x0 + col_w
			var is_edge := (col == 0 or col == num_cols - 1)
			var qcol := col_curb if (is_edge and row % 3 == 0) else col_asphalt

			var p0 := basis_rot * Vector3(x0, y0, z0)
			var p1 := basis_rot * Vector3(x1, y0, z0)
			var p2 := basis_rot * Vector3(x1, y1, z1)
			var p3 := basis_rot * Vector3(x0, y1, z1)
			var n := (p3 - p0).cross(p1 - p0).normalized()

			var vi := verts.size()
			verts.append(p0); verts.append(p1); verts.append(p2); verts.append(p3)
			for _i in 4:
				norms.append(n)
				cols.append(qcol)
			idxs.append(vi); idxs.append(vi + 1); idxs.append(vi + 2)
			idxs.append(vi); idxs.append(vi + 2); idxs.append(vi + 3)

	# Flat landing at HIGH end (covers cleared boundary zone)
	var lz0: float
	var lz1: float
	if is_up:
		lz0 = hl; lz1 = hl + 1.0
	else:
		lz0 = -hl; lz1 = -hl - 1.0
	for col in range(num_cols):
		var x0 := -hw + float(col) * col_w
		var x1 := x0 + col_w
		var is_edge := (col == 0 or col == num_cols - 1)
		var qcol := col_curb if is_edge else col_asphalt

		var p0 := basis_rot * Vector3(x0, high_y, lz0)
		var p1 := basis_rot * Vector3(x1, high_y, lz0)
		var p2 := basis_rot * Vector3(x1, high_y, lz1)
		var p3 := basis_rot * Vector3(x0, high_y, lz1)

		var vi := verts.size()
		verts.append(p0); verts.append(p1); verts.append(p2); verts.append(p3)
		for _i in 4:
			norms.append(Vector3.UP)
			cols.append(qcol)
		idxs.append(vi); idxs.append(vi + 1); idxs.append(vi + 2)
		idxs.append(vi); idxs.append(vi + 2); idxs.append(vi + 3)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idxs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
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
# BANKED TURN (30° tilt, 90° arc)
# =======================================================================
# Banked turns use the same arc geometry as gentle turns but with a tilted
# collision/visual mesh. Inner edge at ground level, outer edge raised.

const BANKED_SEGS := 8
const BANKED_ANGLE := 30.0  # degrees
const BANKED_RADIAL := 4    # subdivisions across road width (for visual)

static func spawn_banked_turn(parent: Node3D, grid_pos: Vector2i, piece_id: int, rotation: int, base_height: int = 0) -> void:
	var body := StaticBody3D.new()
	body.name = "BankedTurn_%d_%d" % [grid_pos.x, grid_pos.y]

	var ground: float = 1.0
	var bank_rad: float = deg_to_rad(BANKED_ANGLE)
	var r: float = float(HALF)          # 6.0 — road center radius
	var inner_r: float = r - float(ROAD_W)  # 2.0
	var outer_r: float = r + float(ROAD_W)  # 10.0
	var road_w: float = outer_r - inner_r   # 8.0
	var bank_h: float = road_w * sin(bank_rad)  # ~4.0

	var is_right: bool = piece_id == 28
	var cx: float
	var cz: float
	var a_start: float
	var a_end: float
	if is_right:
		cx = float(HALF); cz = float(-HALF)
		a_start = PI; a_end = PI / 2.0
	else:
		cx = float(-HALF); cz = float(-HALF)
		a_start = 0.0; a_end = PI / 2.0

	var rot_angle: float = -float(rotation) * PI / 2.0
	var basis_rot := Basis(Vector3.UP, rot_angle)

	# Visual mesh arrays
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idxs := PackedInt32Array()
	var col_asphalt := Color(0.25, 0.25, 0.28)
	var col_curb := Color(0.9, 0.9, 0.9)

	for seg in range(BANKED_SEGS):
		var t0: float = float(seg) / float(BANKED_SEGS)
		var t1: float = float(seg + 1) / float(BANKED_SEGS)
		var theta0: float = lerpf(a_start, a_end, t0)
		var theta1: float = lerpf(a_start, a_end, t1)

		# Bank factor: 0 at entry/exit, 1.0 in the middle (smooth transition)
		var bf0: float = sin(t0 * PI)
		var bf1: float = sin(t1 * PI)
		var bh0: float = bank_h * bf0
		var bh1: float = bank_h * bf1

		# Surface corner points (inner=ground, outer=ground+banked height)
		var pi0 := basis_rot * Vector3(cx + inner_r * cos(theta0), ground, cz + inner_r * sin(theta0))
		var po0 := basis_rot * Vector3(cx + outer_r * cos(theta0), ground + bh0, cz + outer_r * sin(theta0))
		var pi1 := basis_rot * Vector3(cx + inner_r * cos(theta1), ground, cz + inner_r * sin(theta1))
		var po1 := basis_rot * Vector3(cx + outer_r * cos(theta1), ground + bh1, cz + outer_r * sin(theta1))

		# Collision: ConvexPolygon (surface + bottom support)
		var col_points := PackedVector3Array()
		col_points.append(pi0); col_points.append(po0)
		col_points.append(pi1); col_points.append(po1)
		# Bottom support
		col_points.append(basis_rot * Vector3(cx + inner_r * cos(theta0), ground - 0.5, cz + inner_r * sin(theta0)))
		col_points.append(basis_rot * Vector3(cx + outer_r * cos(theta0), ground - 0.5, cz + outer_r * sin(theta0)))
		col_points.append(basis_rot * Vector3(cx + inner_r * cos(theta1), ground - 0.5, cz + inner_r * sin(theta1)))
		col_points.append(basis_rot * Vector3(cx + outer_r * cos(theta1), ground - 0.5, cz + outer_r * sin(theta1)))
		var col_shape := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = col_points
		col_shape.shape = shape
		body.add_child(col_shape)

		# Visual: subdivide radially for curb markings
		for rseg in range(BANKED_RADIAL):
			var r0: float = lerpf(inner_r, outer_r, float(rseg) / float(BANKED_RADIAL))
			var r1: float = lerpf(inner_r, outer_r, float(rseg + 1) / float(BANKED_RADIAL))
			var ry0: float = lerpf(0.0, bh0, float(rseg) / float(BANKED_RADIAL))
			var ry1_0: float = lerpf(0.0, bh0, float(rseg + 1) / float(BANKED_RADIAL))
			var ry0_1: float = lerpf(0.0, bh1, float(rseg) / float(BANKED_RADIAL))
			var ry1_1: float = lerpf(0.0, bh1, float(rseg + 1) / float(BANKED_RADIAL))
			var is_edge: bool = rseg == 0 or rseg == BANKED_RADIAL - 1
			var qcol: Color = col_curb if (is_edge and seg % 2 == 0) else col_asphalt

			var q00 := basis_rot * Vector3(cx + r0 * cos(theta0), ground + ry0, cz + r0 * sin(theta0))
			var q10 := basis_rot * Vector3(cx + r1 * cos(theta0), ground + ry1_0, cz + r1 * sin(theta0))
			var q01 := basis_rot * Vector3(cx + r0 * cos(theta1), ground + ry0_1, cz + r0 * sin(theta1))
			var q11 := basis_rot * Vector3(cx + r1 * cos(theta1), ground + ry1_1, cz + r1 * sin(theta1))

			var n := (q01 - q00).cross(q10 - q00).normalized()
			var vi := verts.size()
			verts.append(q00); verts.append(q10); verts.append(q11); verts.append(q01)
			for _i in 4:
				norms.append(n)
				cols.append(qcol)
			idxs.append(vi); idxs.append(vi + 1); idxs.append(vi + 2)
			idxs.append(vi); idxs.append(vi + 2); idxs.append(vi + 3)

	# Wall barriers along inner and outer edges
	var col_wall := Color(0.75, 0.2, 0.15)
	var wall_h := 2.0  # wall height above road surface
	for seg in range(BANKED_SEGS):
		var t0w: float = float(seg) / float(BANKED_SEGS)
		var t1w: float = float(seg + 1) / float(BANKED_SEGS)
		var theta0w: float = lerpf(a_start, a_end, t0w)
		var theta1w: float = lerpf(a_start, a_end, t1w)
		var bf0w: float = sin(t0w * PI)
		var bf1w: float = sin(t1w * PI)
		var bh0w: float = bank_h * bf0w
		var bh1w: float = bank_h * bf1w

		# Inner wall (at inner_r, from ground to ground+wall_h)
		var wi0b := basis_rot * Vector3(cx + inner_r * cos(theta0w), ground, cz + inner_r * sin(theta0w))
		var wi0t := basis_rot * Vector3(cx + inner_r * cos(theta0w), ground + wall_h, cz + inner_r * sin(theta0w))
		var wi1b := basis_rot * Vector3(cx + inner_r * cos(theta1w), ground, cz + inner_r * sin(theta1w))
		var wi1t := basis_rot * Vector3(cx + inner_r * cos(theta1w), ground + wall_h, cz + inner_r * sin(theta1w))
		var nwi := (wi1b - wi0b).cross(wi0t - wi0b).normalized()
		var vii := verts.size()
		verts.append(wi0b); verts.append(wi0t); verts.append(wi1t); verts.append(wi1b)
		for _i in 4:
			norms.append(nwi); cols.append(col_wall)
		idxs.append(vii); idxs.append(vii + 1); idxs.append(vii + 2)
		idxs.append(vii); idxs.append(vii + 2); idxs.append(vii + 3)

		# Outer wall (at outer_r, from banked surface to surface+wall_h)
		var wo0b := basis_rot * Vector3(cx + outer_r * cos(theta0w), ground + bh0w, cz + outer_r * sin(theta0w))
		var wo0t := basis_rot * Vector3(cx + outer_r * cos(theta0w), ground + bh0w + wall_h, cz + outer_r * sin(theta0w))
		var wo1b := basis_rot * Vector3(cx + outer_r * cos(theta1w), ground + bh1w, cz + outer_r * sin(theta1w))
		var wo1t := basis_rot * Vector3(cx + outer_r * cos(theta1w), ground + bh1w + wall_h, cz + outer_r * sin(theta1w))
		var nwo := (wo1b - wo0b).cross(wo0t - wo0b).normalized()
		var vio := verts.size()
		verts.append(wo0b); verts.append(wo0t); verts.append(wo1t); verts.append(wo1b)
		for _i in 4:
			norms.append(nwo); cols.append(col_wall)
		idxs.append(vio); idxs.append(vio + 1); idxs.append(vio + 2)
		idxs.append(vio); idxs.append(vio + 2); idxs.append(vio + 3)

		# Wall collision (inner)
		var wci_points := PackedVector3Array()
		wci_points.append(wi0b); wci_points.append(wi0t)
		wci_points.append(wi1b); wci_points.append(wi1t)
		var wi0b2 := basis_rot * Vector3(cx + (inner_r - 0.5) * cos(theta0w), ground, cz + (inner_r - 0.5) * sin(theta0w))
		var wi0t2 := basis_rot * Vector3(cx + (inner_r - 0.5) * cos(theta0w), ground + wall_h, cz + (inner_r - 0.5) * sin(theta0w))
		var wi1b2 := basis_rot * Vector3(cx + (inner_r - 0.5) * cos(theta1w), ground, cz + (inner_r - 0.5) * sin(theta1w))
		var wi1t2 := basis_rot * Vector3(cx + (inner_r - 0.5) * cos(theta1w), ground + wall_h, cz + (inner_r - 0.5) * sin(theta1w))
		wci_points.append(wi0b2); wci_points.append(wi0t2)
		wci_points.append(wi1b2); wci_points.append(wi1t2)
		var wci_shape := CollisionShape3D.new()
		var wci := ConvexPolygonShape3D.new()
		wci.points = wci_points
		wci_shape.shape = wci
		body.add_child(wci_shape)

		# Wall collision (outer)
		var wco_points := PackedVector3Array()
		wco_points.append(wo0b); wco_points.append(wo0t)
		wco_points.append(wo1b); wco_points.append(wo1t)
		var wo0b2 := basis_rot * Vector3(cx + (outer_r + 0.5) * cos(theta0w), ground + bh0w, cz + (outer_r + 0.5) * sin(theta0w))
		var wo0t2 := basis_rot * Vector3(cx + (outer_r + 0.5) * cos(theta0w), ground + bh0w + wall_h, cz + (outer_r + 0.5) * sin(theta0w))
		var wo1b2 := basis_rot * Vector3(cx + (outer_r + 0.5) * cos(theta1w), ground + bh1w, cz + (outer_r + 0.5) * sin(theta1w))
		var wo1t2 := basis_rot * Vector3(cx + (outer_r + 0.5) * cos(theta1w), ground + bh1w + wall_h, cz + (outer_r + 0.5) * sin(theta1w))
		wco_points.append(wo0b2); wco_points.append(wo0t2)
		wco_points.append(wo1b2); wco_points.append(wo1t2)
		var wco_shape := CollisionShape3D.new()
		var wco := ConvexPolygonShape3D.new()
		wco.points = wco_points
		wco_shape.shape = wco
		body.add_child(wco_shape)

	# Build mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idxs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	body.add_child(mi)

	var world_x: float = float(grid_pos.x * GRID)
	var world_z: float = float(grid_pos.y * GRID)
	body.position = Vector3(world_x, float(base_height), world_z)
	parent.add_child(body)


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

	var wall_h: float = 2.0  # barrier height

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

		# Barriers (same logic as vloop)
		var up0_local := Vector3(-sin(a0), cos(a0), 0.0) * wall_h
		var up1_local := Vector3(-sin(a1), cos(a1), 0.0) * wall_h

		var w0lt := basis_rot * (Vector3(-hw * cos(a0), cy0 - hw * sin(a0), z0) + up0_local)
		var w1lt := basis_rot * (Vector3(-hw * cos(a1), cy1 - hw * sin(a1), z1) + up1_local)
		var wn_l := (p0l - w0lt).cross(p1l - w0lt).normalized()
		_add_quad(verts, normals, indices, p0l, p1l, w1lt, w0lt, wn_l)
		tri_faces.append(p0l); tri_faces.append(p1l); tri_faces.append(w1lt)
		tri_faces.append(p0l); tri_faces.append(w1lt); tri_faces.append(w0lt)

		var w0rt := basis_rot * (Vector3(hw * cos(a0), cy0 + hw * sin(a0), z0) + up0_local)
		var w1rt := basis_rot * (Vector3(hw * cos(a1), cy1 + hw * sin(a1), z1) + up1_local)
		var wn_r := (w0rt - p0r).cross(p1r - p0r).normalized()
		_add_quad(verts, normals, indices, p0r, w0rt, w1rt, p1r, wn_r)
		tri_faces.append(p0r); tri_faces.append(w0rt); tri_faces.append(w1rt)
		tri_faces.append(p0r); tri_faces.append(w1rt); tri_faces.append(p1r)

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

	var wall_h: float = 2.0  # barrier height above road surface

	for seg in range(VLOOP_SEGS):
		var t0: float = float(seg) / float(VLOOP_SEGS)
		var t1: float = float(seg + 1) / float(VLOOP_SEGS)

		var z0: float = lerpf(-hl, hl, t0)
		var z1: float = lerpf(-hl, hl, t1)

		var a0: float = lerpf(angle_start, angle_end, t0)
		var a1: float = lerpf(angle_start, angle_end, t1)

		var cy0: float = ground + R * (1.0 - cos(a0))
		var cy1: float = ground + R * (1.0 - cos(a1))

		# Road surface
		var p0l := basis_rot * Vector3(-hw * cos(a0), cy0 - hw * sin(a0), z0)
		var p0r := basis_rot * Vector3(hw * cos(a0), cy0 + hw * sin(a0), z0)
		var p1l := basis_rot * Vector3(-hw * cos(a1), cy1 - hw * sin(a1), z1)
		var p1r := basis_rot * Vector3(hw * cos(a1), cy1 + hw * sin(a1), z1)

		var n := (p1l - p0l).cross(p0r - p0l).normalized()
		_add_quad(verts, normals, indices, p0l, p0r, p1r, p1l, n)

		tri_faces.append(p0l); tri_faces.append(p0r); tri_faces.append(p1r)
		tri_faces.append(p0l); tri_faces.append(p1r); tri_faces.append(p1l)

		# Barriers: walls rising from road edges perpendicular to road surface.
		# Surface "up" direction at angle a (perpendicular to road, in local space):
		#   up = (-sin(a), cos(a), 0) — rotates with the road
		# Wall top = road edge + up * wall_h (computed in local space, then rotated)
		var up0_local := Vector3(-sin(a0), cos(a0), 0.0) * wall_h
		var up1_local := Vector3(-sin(a1), cos(a1), 0.0) * wall_h

		# Left wall top points (local, then rotated)
		var w0lt := basis_rot * (Vector3(-hw * cos(a0), cy0 - hw * sin(a0), z0) + up0_local)
		var w1lt := basis_rot * (Vector3(-hw * cos(a1), cy1 - hw * sin(a1), z1) + up1_local)
		var wn_l := (p0l - w0lt).cross(p1l - w0lt).normalized()
		_add_quad(verts, normals, indices, p0l, p1l, w1lt, w0lt, wn_l)
		tri_faces.append(p0l); tri_faces.append(p1l); tri_faces.append(w1lt)
		tri_faces.append(p0l); tri_faces.append(w1lt); tri_faces.append(w0lt)

		# Right wall top points
		var w0rt := basis_rot * (Vector3(hw * cos(a0), cy0 + hw * sin(a0), z0) + up0_local)
		var w1rt := basis_rot * (Vector3(hw * cos(a1), cy1 + hw * sin(a1), z1) + up1_local)
		var wn_r := (w0rt - p0r).cross(p1r - p0r).normalized()
		_add_quad(verts, normals, indices, p0r, w0rt, w1rt, p1r, wn_r)
		tri_faces.append(p0r); tri_faces.append(w0rt); tri_faces.append(w1rt)
		tri_faces.append(p0r); tri_faces.append(w1rt); tri_faces.append(p1r)

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


# =======================================================================
# TRANSITION (smooth flat↔ramp, anti-lip)
# =======================================================================
# A gentle curved ramp surface (height=2) that eliminates the sharp edge
# between flat road and steep ramp. Uses a sine curve for smooth entry.

const TRANSITION_H := 2.0

static func spawn_transition(parent: Node3D, grid_pos: Vector2i, piece_id: int, rotation: int, base_height: int = 0) -> void:
	var is_up := piece_id == 22
	var body := StaticBody3D.new()
	body.name = "RampCollision_%d_%d" % [grid_pos.x, grid_pos.y]

	var hw: float = float(ROAD_W) + 0.5
	var hl: float = float(HALF)
	var ground: float = 1.0
	var rot_angle: float = -float(rotation) * PI / 2.0
	var basis_rot := Basis(Vector3.UP, rot_angle)

	# Build curved surface with 4 segments
	var segs := 4
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	for seg in range(segs):
		var t0: float = float(seg) / float(segs)
		var t1: float = float(seg + 1) / float(segs)
		var z0 := lerpf(-hl, hl, t0)
		var z1 := lerpf(-hl, hl, t1)

		# Sine curve for smooth transition (0 at entry, TRANSITION_H at exit)
		var h0: float
		var h1: float
		if is_up:
			h0 = sin(t0 * PI / 2.0) * TRANSITION_H
			h1 = sin(t1 * PI / 2.0) * TRANSITION_H
		else:
			h0 = sin((1.0 - t0) * PI / 2.0) * TRANSITION_H
			h1 = sin((1.0 - t1) * PI / 2.0) * TRANSITION_H

		var p0l := basis_rot * Vector3(-hw, ground + h0, z0)
		var p0r := basis_rot * Vector3(hw, ground + h0, z0)
		var p1l := basis_rot * Vector3(-hw, ground + h1, z1)
		var p1r := basis_rot * Vector3(hw, ground + h1, z1)

		var n := (p1l - p0l).cross(p0r - p0l).normalized()
		_add_quad(verts, normals, indices, p0l, p0r, p1r, p1l, n)

		# Collision
		var bottom_y := ground - 0.5
		_add_collision_quad(body, p0l, p0r, p1r, p1l, bottom_y, basis_rot)

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
	mat.albedo_color = Color(0.3, 0.3, 0.35)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	body.add_child(mi)

	body.position = Vector3(float(grid_pos.x * GRID), float(base_height), float(grid_pos.y * GRID))
	parent.add_child(body)
