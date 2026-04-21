extends Node
class_name TrackDecorator
## TrackDecorator — spawns decorative meshes at/near certain pieces.
## Call decorate() after voxel build. Decorations are added as children
## of the passed parent node.

const GRID := 12  # must match TrackPieces.SEGMENT_SIZE

# Palette for decorations
const GATE_COLOR := Color("d0d5de")
const BANNER_ORANGE := Color("ff6b35")
const BANNER_PURPLE := Color("8b5cf6")
const BANNER_GREEN := Color("22c55e")
const POST_COLOR := Color("30363f")
const LIGHT_COLOR := Color("ffe16b")
const STAND_COLOR := Color("4a5160")
const STAND_SEAT := Color("2d3240")


static func decorate(parent: Node3D, pieces: Array, center_offset: Vector2i) -> void:
	var container := Node3D.new()
	container.name = "TrackDecorations"
	parent.add_child(container)

	for p in pieces:
		var centered_grid: Vector2i = p.grid - center_offset
		var bh: int = p.get("base_height", 0)
		var world_pos := Vector3(centered_grid.x * GRID, float(bh) + 1.0, centered_grid.y * GRID)
		var rot_y: float = -float(p.rotation) * PI / 2.0
		var piece_id: int = p.piece

		match piece_id:
			5:  # Start
				_spawn_gate(container, world_pos, rot_y, BANNER_GREEN, "START")
				_spawn_flags_pair(container, world_pos, rot_y, BANNER_GREEN)
			11:  # Finish
				_spawn_gate(container, world_pos, rot_y, BANNER_ORANGE, "FINISH")
				_spawn_stands(container, world_pos, rot_y)
			8:  # Checkpoint
				_spawn_gate(container, world_pos, rot_y, BANNER_PURPLE, "")
			0, 26, 27:  # Straight + s-curves
				# Randomly place light posts and flags (seed by grid for determinism)
				var h := hash(Vector2(centered_grid.x, centered_grid.y))
				if (h & 0x3) == 0:
					_spawn_light_post(container, world_pos, rot_y, 4.5)
				elif (h & 0x3) == 1:
					_spawn_banner(container, world_pos, rot_y, BANNER_PURPLE if (h & 0x8) == 0 else BANNER_ORANGE)


# =============================================================================
# GATE — arch over road (start/finish/checkpoint)
# =============================================================================

static func _spawn_gate(parent: Node3D, world_pos: Vector3, rot_y: float, banner_color: Color, text: String) -> void:
	var gate := Node3D.new()
	gate.name = "Gate"
	gate.position = world_pos
	gate.rotation.y = rot_y
	parent.add_child(gate)

	var post_height := 5.5
	var span := 10.0
	# Two posts
	for dx in [-span * 0.5, span * 0.5]:
		var post := _make_box(Vector3(0.6, post_height, 0.6), GATE_COLOR)
		post.position = Vector3(dx, post_height * 0.5, 0)
		gate.add_child(post)
		# Small top cap
		var cap := _make_box(Vector3(1.0, 0.3, 1.0), GATE_COLOR.darkened(0.3))
		cap.position = Vector3(dx, post_height + 0.15, 0)
		gate.add_child(cap)

	# Crossbar/banner
	var banner := _make_box(Vector3(span + 0.4, 1.2, 0.25), banner_color)
	banner.position = Vector3(0, post_height - 0.3, 0)
	gate.add_child(banner)

	# Banner text — two labels back-to-back so it's readable from both sides
	if text != "":
		for side in [1.0, -1.0]:
			var label := Label3D.new()
			label.text = text
			label.font_size = 72
			label.outline_size = 8
			label.modulate = Color.WHITE
			label.outline_modulate = Color.BLACK
			label.position = Vector3(0, post_height - 0.3, 0.15 * side)
			label.rotation.y = 0.0 if side > 0.0 else PI
			label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			label.no_depth_test = false
			label.double_sided = false
			label.pixel_size = 0.012
			gate.add_child(label)


# =============================================================================
# LIGHT POST — vertical post with glowing bulb
# =============================================================================

static func _spawn_light_post(parent: Node3D, world_pos: Vector3, rot_y: float, side_offset: float) -> void:
	var post_node := Node3D.new()
	post_node.position = world_pos
	post_node.rotation.y = rot_y
	parent.add_child(post_node)

	var post := _make_box(Vector3(0.4, 5.0, 0.4), POST_COLOR)
	post.position = Vector3(side_offset, 2.5, 0)
	post_node.add_child(post)

	# Arm
	var arm := _make_box(Vector3(0.8, 0.2, 0.2), POST_COLOR.darkened(0.2))
	arm.position = Vector3(side_offset - 0.4, 4.9, 0)
	post_node.add_child(arm)

	# Light bulb
	var bulb := _make_sphere(0.35, LIGHT_COLOR, LIGHT_COLOR * 3.0)
	bulb.position = Vector3(side_offset - 0.8, 4.9, 0)
	post_node.add_child(bulb)


# =============================================================================
# BANNER — standalone vertical banner on a pole
# =============================================================================

static func _spawn_banner(parent: Node3D, world_pos: Vector3, rot_y: float, color: Color) -> void:
	var banner_node := Node3D.new()
	banner_node.position = world_pos
	banner_node.rotation.y = rot_y
	parent.add_child(banner_node)

	var side: float = 5.0 if (hash(world_pos) & 1) == 0 else -5.0

	var pole := _make_box(Vector3(0.2, 4.0, 0.2), POST_COLOR)
	pole.position = Vector3(side, 2.0, 0)
	banner_node.add_child(pole)

	var flag := _make_box(Vector3(2.0, 1.5, 0.1), color)
	var flag_x := side + (1.0 if side > 0 else -1.0)
	flag.position = Vector3(flag_x, 3.2, 0)
	banner_node.add_child(flag)


# =============================================================================
# FLAG PAIR — start line checkered flags
# =============================================================================

static func _spawn_flags_pair(parent: Node3D, world_pos: Vector3, rot_y: float, color: Color) -> void:
	for dx in [-6.0, 6.0]:
		var flag_node := Node3D.new()
		flag_node.position = world_pos
		flag_node.rotation.y = rot_y
		parent.add_child(flag_node)
		var pole := _make_box(Vector3(0.2, 3.5, 0.2), POST_COLOR)
		pole.position = Vector3(dx, 1.75, 0)
		flag_node.add_child(pole)
		var flag := _make_box(Vector3(1.3, 0.8, 0.05), color)
		flag.position = Vector3(dx + (0.8 if dx > 0 else -0.8), 3.2, 0)
		flag_node.add_child(flag)


# =============================================================================
# STANDS — tribune block beside piece
# =============================================================================

static func _spawn_stands(parent: Node3D, world_pos: Vector3, rot_y: float) -> void:
	for side in [-8.0, 8.0]:
		var stand := Node3D.new()
		stand.position = world_pos
		stand.rotation.y = rot_y
		parent.add_child(stand)
		# 3 tiered rows
		for tier in range(3):
			var y := 0.5 + tier * 0.9
			var depth := 1.5 + tier * 0.8
			var base := _make_box(Vector3(8.0, 0.6, depth), STAND_COLOR)
			base.position = Vector3(side + (depth * 0.5 if side > 0 else -depth * 0.5), y, 0)
			stand.add_child(base)
			# Seat line
			var seat := _make_box(Vector3(8.0, 0.15, 0.4), STAND_SEAT)
			seat.position = Vector3(side + (depth * 0.5 if side > 0 else -depth * 0.5), y + 0.37, 0)
			stand.add_child(seat)


# =============================================================================
# MESH HELPERS
# =============================================================================

static func _make_box(size: Vector3, color: Color, emission: Color = Color.BLACK) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if emission.r + emission.g + emission.b > 0.01:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 1.5
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


static func _make_sphere(radius: float, color: Color, emission: Color = Color.BLACK) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.3
	if emission.r + emission.g + emission.b > 0.01:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	return mi
