extends CharacterBody3D
## Arcade car controller with surface physics, boost, drift, explosion and ghost.

@export var stats: VehicleStats

var speed := 0.0
var _boost_timer := 0.0
var _boost_mult := 1.0
var _gravity_dir := Vector3.DOWN
var _terrain: VoxelTerrain
var _voxel_tool: VoxelTool

# Off-track / explosion
var _offtrack_timer := 0.0
var _is_dead := false
var _respawn_timer := 0.0
var _last_safe_pos := Vector3(0, 3, 0)
var _last_safe_rot := 0.0
var _spawn_pos := Vector3(0, 3, 0)
var _spawn_rot := 0.0

const OFFTRACK_TIME := 0.8    # seconds on grass before boom
const RESPAWN_DELAY := 2.5
const FALL_THRESHOLD := -15.0
const SPAWN_GRACE := 3.0      # seconds of immunity after spawn/respawn

var _grace_timer := SPAWN_GRACE

@onready var mesh: Node3D = $Mesh
@onready var collision: CollisionShape3D = $CollisionShape3D

var _front_wheels: Array[Node3D] = []
var _rear_wheels: Array[Node3D] = []
var _wheel_spin := 0.0


func _ready() -> void:
	if not stats:
		stats = VehicleStats.new()
	floor_snap_length = stats.floor_snap
	floor_max_angle = deg_to_rad(stats.floor_angle)

	# Find VoxelTerrain in sibling nodes
	for child in get_parent().get_children():
		if child is VoxelTerrain:
			_terrain = child
			break

	_spawn_pos = global_position
	_spawn_rot = rotation.y
	_last_safe_pos = _spawn_pos
	_last_safe_rot = _spawn_rot

	# Load F1 car model
	_load_car_model()


func _load_car_model() -> void:
	var f1_scene: PackedScene = load("res://assets/models/f1_car.glb")
	if not f1_scene:
		push_warning("F1 model not found, keeping default mesh")
		return

	for child in mesh.get_children():
		child.queue_free()

	var model := f1_scene.instantiate()
	model.rotation.y = PI  # Model faces +Z in Blender, flip to -Z for Godot
	model.scale = Vector3(1.1, 1.0, 1.0)  # Slightly wider
	mesh.add_child(model)

	# Find wheel nodes by name pattern and position
	_find_wheels(model)


func _find_wheels(root: Node3D) -> void:
	_front_wheels.clear()
	_rear_wheels.clear()
	# Front wheel empties: pCylinder2-11 (Blender Y≈-8.76 → Godot Z≈+1.0 before flip)
	# Rear wheel empties: pCylinder12-21 (Blender Y≈2.84-2.99 → Godot Z≈-0.35 before flip)
	var front_names := ["pCylinder2", "pCylinder3", "pCylinder4", "pCylinder5",
		"pCylinder6", "pCylinder7", "pCylinder8", "pCylinder9",
		"pCylinder10", "pCylinder11"]
	var rear_names := ["pCylinder12", "pCylinder13", "pCylinder14", "pCylinder15",
		"pCylinder16", "pCylinder17", "pCylinder18", "pCylinder19",
		"pCylinder20", "pCylinder21"]
	_collect_named_nodes(root, front_names, _front_wheels)
	_collect_named_nodes(root, rear_names, _rear_wheels)


func _collect_named_nodes(node: Node, names: Array, result: Array[Node3D]) -> void:
	if node is Node3D and node.name in names:
		result.append(node)
	for child in node.get_children():
		_collect_named_nodes(child, names, result)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://menu.tscn")
			KEY_R:
				RaceManager.reset()
				get_tree().reload_current_scene()
			KEY_G:
				# Toggle ghost visibility
				var loader := get_parent().get_node_or_null("TrackLoader")
				if loader and loader.has_method("toggle_ghost"):
					loader.toggle_ghost()


func _physics_process(delta: float) -> void:
	# --- Dead state ---
	if _is_dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0:
			_respawn()
		return

	var surface := _detect_surface()
	var airborne := not is_on_floor()

	# --- Off-track detection ---
	_check_offtrack(surface, airborne, delta)

	var throttle := Input.get_axis("ui_down", "ui_up")
	var steer := Input.get_axis("ui_right", "ui_left")

	# --- Surface properties ---
	var grip: float = surface.grip
	var friction: float = surface.friction
	var speed_limit: float = stats.max_speed * surface.speed_mult * _boost_mult

	# --- Boost pad ---
	if surface.get("is_boost", false) and is_on_floor():
		_apply_boost()

	# --- Acceleration ---
	if throttle > 0:
		speed = move_toward(speed, speed_limit, stats.acceleration * delta)
	elif throttle < 0:
		speed = move_toward(speed, -stats.reverse_speed, stats.brake_force * delta)
	else:
		speed = move_toward(speed, 0, friction * delta)

	# --- Steering ---
	var turn_mult: float = stats.air_control if airborne else grip
	if abs(speed) > 1.0:
		var turn: float = steer * stats.turn_speed * delta * signf(speed) * turn_mult
		rotation.y += turn

	# --- Movement ---
	var forward := -transform.basis.z

	if airborne:
		var target_vel := forward * speed
		velocity.x = lerp(velocity.x, target_vel.x, stats.air_control * delta * 5.0)
		velocity.z = lerp(velocity.z, target_vel.z, stats.air_control * delta * 5.0)
		# Gravity in air
		velocity += _gravity_dir * stats.gravity * delta
	else:
		# Project forward direction onto floor plane
		var fn := get_floor_normal()
		var slope_forward := (forward - fn * forward.dot(fn)).normalized()
		var target_vel := slope_forward * speed

		var drift_blend: float = grip * stats.drift_factor
		velocity = velocity.lerp(target_vel, clampf(drift_blend, 0.1, 1.0))

		# Slope gravity: accelerate downhill, decelerate uphill
		var slope_dot := fn.dot(Vector3.UP)  # 1.0 = flat, <1.0 = slope
		if slope_dot < 0.99:
			var gravity_along_slope := Vector3.DOWN - fn * Vector3.DOWN.dot(fn)
			velocity += gravity_along_slope * stats.gravity * 0.5 * delta

	# --- Boost timer ---
	if _boost_timer > 0:
		_boost_timer -= delta
		if _boost_timer <= 0:
			_boost_mult = 1.0

	var pre_speed := velocity.length()
	move_and_slide()

	# --- Wall bounce ---
	if get_slide_collision_count() > 0:
		var col := get_slide_collision(0)
		var normal := col.get_normal()
		if absf(normal.y) < 0.3 and pre_speed > 3.0:
			# Reflect velocity off wall
			var reflect := velocity.reflect(normal)
			velocity = reflect * 0.4
			speed = maxf(speed * 0.5, 0.0)
			# Nudge car away from wall
			global_position += normal * 0.15

	# --- Track safe position ---
	if is_on_floor() and surface.grip >= 0.8:
		_last_safe_pos = global_position
		_last_safe_rot = rotation.y

	# --- Visual ---
	if mesh:
		# Body roll on steering
		mesh.rotation.z = lerp(mesh.rotation.z, steer * 0.15, 5.0 * delta)
		# Pitch: align to floor slope
		var pitch_target: float = 0.0
		if airborne:
			pitch_target = -0.1
		elif is_on_floor():
			var fn := get_floor_normal()
			var right := transform.basis.x
			var forward_on_slope := fn.cross(right).normalized()
			pitch_target = asin(clampf(-forward_on_slope.y, -0.8, 0.8))
			if throttle < 0 and speed > 5.0:
				pitch_target += 0.05
		mesh.rotation.x = lerp(mesh.rotation.x, pitch_target, 8.0 * delta)

		# Front wheel steering
		var steer_angle: float = steer * 0.4
		for w in _front_wheels:
			w.rotation.y = lerp(w.rotation.y, steer_angle, 10.0 * delta)

		# Wheel spin (all wheels)
		_wheel_spin += speed * delta * 3.0
		for w in _front_wheels + _rear_wheels:
			w.rotation.x = _wheel_spin

	# --- Ghost recording ---
	RaceManager.record_frame(global_position, rotation.y)


func _check_offtrack(surface: Dictionary, airborne: bool, delta: float) -> void:
	# Grace period after spawn/respawn
	if _grace_timer > 0:
		_grace_timer -= delta
		return

	# Fall off the world
	if global_position.y < FALL_THRESHOLD:
		_respawn()
		return

	# On grass = off track → instant respawn
	if not airborne and surface.grip <= 0.5:
		_offtrack_timer += delta
		if _offtrack_timer >= OFFTRACK_TIME:
			_respawn()
	else:
		_offtrack_timer = 0.0


func _explode() -> void:
	_is_dead = true
	_respawn_timer = RESPAWN_DELAY
	speed = 0.0
	velocity = Vector3.ZERO

	# Hide car
	if mesh:
		mesh.visible = false
	if collision:
		collision.disabled = true

	# Spawn debris
	_spawn_debris()


func _spawn_debris() -> void:
	var debris_root := Node3D.new()
	debris_root.name = "Debris"
	get_parent().add_child(debris_root)
	debris_root.global_position = Vector3.ZERO

	var car_color := Color(0.9, 0.15, 0.1)
	var colors := [
		car_color,
		car_color.darkened(0.3),
		car_color.lightened(0.3),
		Color(0.2, 0.2, 0.2),  # dark parts
		Color(0.8, 0.8, 0.8),  # glass
		Color(1.0, 0.6, 0.0),  # fire/sparks
	]

	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.3, 0.3)

	for i in range(25):
		var piece := MeshInstance3D.new()
		piece.mesh = box

		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i % colors.size()]
		piece.material_override = mat

		# Random position near car center
		piece.global_position = global_position + Vector3(
			randf_range(-0.6, 0.6),
			randf_range(-0.2, 0.4),
			randf_range(-1.0, 1.0),
		)

		# Store velocity as metadata
		var vel := Vector3(
			randf_range(-8.0, 8.0),
			randf_range(5.0, 15.0),
			randf_range(-8.0, 8.0),
		)
		piece.set_meta("vel", vel)
		piece.set_meta("rot_speed", Vector3(
			randf_range(-10.0, 10.0),
			randf_range(-10.0, 10.0),
			randf_range(-10.0, 10.0),
		))
		piece.set_meta("life", 0.0)

		debris_root.add_child(piece)

	# Animate debris
	var tween := get_tree().create_tween()
	tween.tween_method(_update_debris.bind(debris_root), 0.0, RESPAWN_DELAY, RESPAWN_DELAY)
	tween.tween_callback(debris_root.queue_free)


func _update_debris(progress: float, debris_root: Node3D) -> void:
	var delta: float = get_physics_process_delta_time()
	if delta <= 0:
		delta = 0.016

	for piece in debris_root.get_children():
		if not piece is MeshInstance3D:
			continue
		var vel: Vector3 = piece.get_meta("vel")
		var rot_speed: Vector3 = piece.get_meta("rot_speed")

		# Apply gravity
		vel.y -= 30.0 * delta
		piece.set_meta("vel", vel)

		piece.global_position += vel * delta
		piece.rotation += rot_speed * delta

		# Fade out near end
		if progress > RESPAWN_DELAY * 0.6:
			var fade: float = 1.0 - (progress - RESPAWN_DELAY * 0.6) / (RESPAWN_DELAY * 0.4)
			var mat: StandardMaterial3D = piece.material_override
			if mat:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = clampf(fade, 0.0, 1.0)

		# Floor bounce
		if piece.global_position.y < 1.0:
			piece.global_position.y = 1.0
			vel.y = abs(vel.y) * 0.3
			vel.x *= 0.7
			vel.z *= 0.7
			piece.set_meta("vel", vel)


func _respawn() -> void:
	_is_dead = false
	_offtrack_timer = 0.0
	speed = 0.0
	velocity = Vector3.ZERO

	global_position = _last_safe_pos + Vector3(0, 1, 0)
	rotation.y = _last_safe_rot

	_grace_timer = SPAWN_GRACE

	if mesh:
		mesh.visible = true
		mesh.rotation = Vector3.ZERO
	if collision:
		collision.disabled = false


func _detect_surface() -> Dictionary:
	if not _terrain:
		return SurfaceData.DEFAULT

	if not _voxel_tool:
		_voxel_tool = _terrain.get_voxel_tool()
		_voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE

	var pos := global_position
	var check_y: float = pos.y - 1.5
	var voxel_pos := Vector3i(roundi(pos.x), roundi(check_y), roundi(pos.z))
	var block_type: int = _voxel_tool.get_voxel(voxel_pos)
	return SurfaceData.get_surface(block_type)


func _apply_boost() -> void:
	if _boost_timer > 0:
		return
	_boost_mult = stats.boost_multiplier
	_boost_timer = stats.boost_duration
	speed = maxf(speed, stats.max_speed * 0.9)


func set_gravity_direction(dir: Vector3) -> void:
	_gravity_dir = dir.normalized()


func reset_gravity() -> void:
	_gravity_dir = Vector3.DOWN
