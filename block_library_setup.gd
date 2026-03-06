extends Node3D
## Sets up VoxelBlockyLibrary with colored cube blocks at runtime.

# Block IDs - order matters!
# 0 = AIR, 1 = ASPHALT, 2 = GRASS, 3 = WALL, 4 = CURB, 5 = SAND
# 6 = RAMP_N, 7 = RAMP_E, 8 = RAMP_S, 9 = RAMP_W (slopes rising toward that direction)
# 10 = RAMP_SURFACE (looks like asphalt, NO collision - for smooth ramp driving)

var _cube_blocks := [
	{"name": "air", "color": Color.TRANSPARENT, "is_empty": true},
	{"name": "asphalt", "color": Color(0.25, 0.25, 0.28)},
	{"name": "grass", "color": Color(0.2, 0.55, 0.15)},
	{"name": "wall", "color": Color(0.75, 0.2, 0.15)},
	{"name": "curb", "color": Color(0.9, 0.9, 0.9)},
	{"name": "sand", "color": Color(0.76, 0.7, 0.5)},
]

var _ramp_colors := [
	Color(0.3, 0.3, 0.33),  # RAMP_N (id 6)
	Color(0.3, 0.3, 0.33),  # RAMP_E (id 7)
	Color(0.3, 0.3, 0.33),  # RAMP_S (id 8)
	Color(0.3, 0.3, 0.33),  # RAMP_W (id 9)
]

@onready var terrain: VoxelTerrain = $VoxelTerrain


func _ready() -> void:
	var library := VoxelBlockyLibrary.new()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true

	# Add cube blocks (IDs 0-5)
	for block in _cube_blocks:
		var model: VoxelBlockyModel
		if block.get("is_empty", false):
			model = VoxelBlockyModelEmpty.new()
		else:
			var cube := VoxelBlockyModelCube.new()
			cube.set_material_override(0, mat)
			model = cube
		model.color = block.color
		library.add_model(model)

	# Add ramp blocks (IDs 6-9) - wedge meshes for 4 directions
	# Directions: N(+Z), E(+X), S(-Z), W(-X) - slope rises toward that direction
	var rotations := [0.0, 90.0, 180.0, 270.0]
	for i in range(4):
		var mesh := _create_wedge_mesh(rotations[i])
		var model := VoxelBlockyModelMesh.new()
		model.mesh = mesh
		model.set_material_override(0, mat)
		model.color = _ramp_colors[i]
		# Collision AABB - full block so car doesn't fall through
		model.collision_aabbs = [AABB(Vector3(0, 0, 0), Vector3(1, 1, 1))]
		library.add_model(model)

	# Add RAMP_SURFACE (ID 10) - looks like asphalt, NO voxel collision
	# Must use VoxelBlockyModelMesh (not Cube) so collision_aabbs=[] is respected
	var ramp_surface_mesh := _create_cube_array_mesh()
	var ramp_surface := VoxelBlockyModelMesh.new()
	ramp_surface.mesh = ramp_surface_mesh
	ramp_surface.set_material_override(0, mat)
	ramp_surface.color = Color(0.25, 0.25, 0.28)
	ramp_surface.collision_aabbs = []  # NO collision!
	library.add_model(ramp_surface)

	library.bake()
	terrain.mesher.library = library


func _create_cube_array_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	# Unit cube vertices (0 to 1 range for voxel model)
	var v := [
		Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1),
		Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1),
	]

	_add_quad(verts, normals, indices, v[3], v[2], v[1], v[0], Vector3.DOWN)    # bottom
	_add_quad(verts, normals, indices, v[4], v[5], v[6], v[7], Vector3.UP)      # top
	_add_quad(verts, normals, indices, v[0], v[1], v[5], v[4], Vector3.BACK)    # -Z
	_add_quad(verts, normals, indices, v[2], v[3], v[7], v[6], Vector3.FORWARD) # +Z
	_add_quad(verts, normals, indices, v[3], v[0], v[4], v[7], Vector3.LEFT)    # -X
	_add_quad(verts, normals, indices, v[1], v[2], v[6], v[5], Vector3.RIGHT)   # +X

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _create_wedge_mesh(rotation_deg: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	# Wedge: bottom is full square, top edge is at one side
	# Default: rises toward +Z (north)
	# Bottom face (y=0): full square
	var b0 := Vector3(0, 0, 0)
	var b1 := Vector3(1, 0, 0)
	var b2 := Vector3(1, 0, 1)
	var b3 := Vector3(0, 0, 1)
	# Top edge: at +Z side, y=1
	var t2 := Vector3(1, 1, 1)
	var t3 := Vector3(0, 1, 1)

	# Apply rotation around center (0.5, 0, 0.5)
	var center := Vector3(0.5, 0, 0.5)
	var rot := Basis(Vector3.UP, deg_to_rad(rotation_deg))
	b0 = rot * (b0 - center) + center
	b1 = rot * (b1 - center) + center
	b2 = rot * (b2 - center) + center
	b3 = rot * (b3 - center) + center
	t2 = rot * (t2 - center) + center
	t3 = rot * (t3 - center) + center

	# Bottom face (2 triangles)
	_add_quad(verts, normals, indices, b0, b1, b2, b3, Vector3.DOWN)
	# Slope face (b0-b1 to t3-t2)
	var slope_normal := (t3 - b0).cross(b1 - b0).normalized()
	_add_quad(verts, normals, indices, b0, b1, t2, t3, slope_normal)
	# Back face (t3-t2 vertical at +Z)
	_add_quad(verts, normals, indices, b2, b3, t3, t2, (rot * Vector3.FORWARD))
	# Left triangle (b3, b0, t3)
	_add_tri(verts, normals, indices, b3, b0, t3, (rot * Vector3.LEFT))
	# Right triangle (b1, b2, t2)
	_add_tri(verts, normals, indices, b1, b2, t2, (rot * Vector3.RIGHT))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_quad(verts: PackedVector3Array, normals: PackedVector3Array,
		indices: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		normal: Vector3) -> void:
	var idx := verts.size()
	verts.append(a); verts.append(b); verts.append(c); verts.append(d)
	for _i in range(4):
		normals.append(normal)
	indices.append(idx); indices.append(idx + 1); indices.append(idx + 2)
	indices.append(idx); indices.append(idx + 2); indices.append(idx + 3)


func _add_tri(verts: PackedVector3Array, normals: PackedVector3Array,
		indices: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3,
		normal: Vector3) -> void:
	var idx := verts.size()
	verts.append(a); verts.append(b); verts.append(c)
	for _i in range(3):
		normals.append(normal)
	indices.append(idx); indices.append(idx + 1); indices.append(idx + 2)
