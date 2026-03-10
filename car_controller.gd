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

# Drift
var _drifting := false
var _drift_timer := 0.0
var _drift_dir := 0.0  # -1 left, +1 right
const DRIFT_GRIP := 0.15
const DRIFT_TURN_MULT := 1.8
const DRIFT_BOOST_TIME := 0.6  # drift this long for boost
const DRIFT_BOOST_MULT := 1.35
const DRIFT_BOOST_DUR := 0.8

# Skidmarks
var _skid_mesh: MeshInstance3D
var _skid_mat: StandardMaterial3D
var _skid_verts: PackedVector3Array = []
var _skid_indices: PackedInt32Array = []
var _skid_prev_l := Vector3.ZERO  # previous left tire pos
var _skid_prev_r := Vector3.ZERO  # previous right tire pos
var _skid_active := false
var _skid_cooldown := 0.0
const SKID_WIDTH := 0.07
const SKID_MIN_DIST := 0.3
const SKID_COOLDOWN_TIME := 0.15
const SKID_MAX_VERTS := 4000

# Particles
var _boost_flame: GPUParticles3D
var _drift_smoke: GPUParticles3D


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
	_setup_particles()


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


func _setup_particles() -> void:
	# Boost flame (behind car)
	_boost_flame = _create_boost_emitter()
	_boost_flame.position = Vector3(0, 0.0, 1.2)
	add_child(_boost_flame)

	# Drift smoke
	_drift_smoke = _create_smoke_emitter()
	_drift_smoke.position = Vector3(0, -0.2, 0.8)
	add_child(_drift_smoke)


func _make_particle_mesh(size: float, color: Color) -> QuadMesh:
	var m := QuadMesh.new()
	m.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.material = mat
	return m


func _create_boost_emitter() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.emitting = false
	p.amount = 24
	p.lifetime = 0.4
	p.speed_scale = 2.0
	p.visibility_aabb = AABB(Vector3(-5, -2, -5), Vector3(10, 6, 10))

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 20.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 10.0
	mat.gravity = Vector3(0, 3.0, 0)
	mat.scale_min = 0.15
	mat.scale_max = 0.4
	mat.color = Color(1.0, 0.5, 0.0, 0.8)
	p.process_material = mat
	p.draw_pass_1 = _make_particle_mesh(0.12, Color(1.0, 0.5, 0.0, 0.8))
	return p


func _create_smoke_emitter() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.emitting = false
	p.amount = 20
	p.lifetime = 1.0
	p.visibility_aabb = AABB(Vector3(-6, -2, -6), Vector3(12, 6, 12))

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 50.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 3.0
	mat.gravity = Vector3(0, 1.0, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.8
	mat.color = Color(0.7, 0.7, 0.7, 0.4)
	p.process_material = mat
	p.draw_pass_1 = _make_particle_mesh(0.2, Color(0.7, 0.7, 0.7, 0.4))
	return p


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
	var handbrake := Input.is_action_pressed("ui_accept")  # Space

	# --- Surface properties ---
	var grip: float = surface.grip
	var friction: float = surface.friction
	var speed_limit: float = stats.max_speed * surface.speed_mult * _boost_mult

	# --- Boost pad ---
	if surface.get("is_boost", false) and is_on_floor():
		_apply_boost()

	# --- Drift / handbrake state ---
	var was_drifting := _drifting
	var drift_end_speed := 2.0 if _drifting else 5.0  # hysteresis
	if handbrake and not airborne and abs(speed) > drift_end_speed:
		if not _drifting:
			_drifting = true
			_drift_timer = 0.0
			_drift_dir = signf(steer) if abs(steer) > 0.1 else 0.0
		_drift_timer += delta
		if abs(steer) > 0.1:
			_drift_dir = signf(steer)
		# Handbrake slows down
		speed = move_toward(speed, speed * 0.7, stats.brake_force * 0.8 * delta)
	elif _drifting:
		_drifting = false
		# Drift boost if drifted long enough while steering
		if _drift_timer >= DRIFT_BOOST_TIME and abs(_drift_dir) > 0.1:
			_boost_mult = DRIFT_BOOST_MULT
			_boost_timer = DRIFT_BOOST_DUR
			speed = minf(speed * 1.15, stats.max_speed * DRIFT_BOOST_MULT)

	# --- Acceleration ---
	if throttle > 0:
		var accel := stats.acceleration
		if _drifting:
			accel *= 0.8  # slightly less acceleration while drifting
		speed = move_toward(speed, speed_limit, accel * delta)
	elif throttle < 0:
		speed = move_toward(speed, -stats.reverse_speed, stats.brake_force * delta)
	else:
		speed = move_toward(speed, 0, friction * delta)

	# --- Steering ---
	var turn_mult: float
	if airborne:
		turn_mult = stats.air_control
	elif _drifting:
		turn_mult = grip * DRIFT_TURN_MULT
	else:
		turn_mult = grip
	if abs(speed) > 1.0:
		var turn: float = steer * stats.turn_speed * delta * signf(speed) * turn_mult
		rotation.y += turn

	# --- Movement ---
	var forward := -transform.basis.z

	if airborne:
		up_direction = Vector3.UP
		_gravity_dir = Vector3.DOWN
		var target_vel := forward * speed
		velocity.x = lerp(velocity.x, target_vel.x, stats.air_control * delta * 5.0)
		velocity.z = lerp(velocity.z, target_vel.z, stats.air_control * delta * 5.0)
		velocity += _gravity_dir * stats.gravity * delta
	else:
		var fn := get_floor_normal()
		var slope_forward := (forward - fn * forward.dot(fn)).normalized()
		var target_vel := slope_forward * speed

		var blend: float
		if _drifting:
			blend = DRIFT_GRIP
		else:
			blend = grip * stats.drift_factor
		velocity = velocity.lerp(target_vel, clampf(blend, 0.1, 1.0))

		# Adaptive gravity & up_direction for wall ride / loop
		var slope_dot := fn.dot(Vector3.UP)
		if slope_dot < 0.7:
			# Steep surface (wall ride / loop) — align car to surface
			up_direction = fn
			_gravity_dir = -fn
			# Push car into surface proportional to steepness
			var steepness := 1.0 - slope_dot
			velocity += -fn * stats.gravity * steepness * delta
		elif slope_dot < 0.99:
			# Mild slope (ramps etc) — gravity along slope
			up_direction = Vector3.UP
			var gravity_along_slope := Vector3.DOWN - fn * Vector3.DOWN.dot(fn)
			velocity += gravity_along_slope * stats.gravity * 0.5 * delta
			_gravity_dir = Vector3.DOWN
		else:
			up_direction = Vector3.UP
			_gravity_dir = Vector3.DOWN

	# --- Boost timer ---
	if _boost_timer > 0:
		_boost_timer -= delta
		if _boost_timer <= 0:
			_boost_mult = 1.0

	var pre_speed := velocity.length()
	move_and_slide()

	# --- Wall bounce (only on flat ground, not on ramps) ---
	if get_slide_collision_count() > 0 and is_on_floor():
		var fn := get_floor_normal()
		var on_slope := fn.dot(Vector3.UP) < 0.95
		if not on_slope:
			var col := get_slide_collision(0)
			var normal := col.get_normal()
			if absf(normal.y) < 0.3 and pre_speed > 3.0:
				var reflect := velocity.reflect(normal)
				velocity = reflect * 0.4
				speed = maxf(speed * 0.5, 0.0)
				global_position += normal * 0.15
				_spawn_wall_sparks(global_position, normal)

	# --- Track safe position ---
	if is_on_floor() and surface.grip >= 0.8:
		_last_safe_pos = global_position
		_last_safe_rot = rotation.y

	# --- Visual ---
	if mesh:
		if is_on_floor():
			var fn := get_floor_normal()
			var slope_dot2 := fn.dot(Vector3.UP)

			if slope_dot2 < 0.95:
				# Surface alignment — align mesh to floor normal (wall ride, ramps)
				var car_forward := -transform.basis.z
				var right := car_forward.cross(fn).normalized()
				var aligned_forward := fn.cross(right).normalized()
				var target_basis := Basis(right, fn, -aligned_forward)
				mesh.basis = mesh.basis.slerp(target_basis, 8.0 * delta)
			else:
				# Flat ground — slerp back to identity + cosmetic roll/pitch
				mesh.basis = mesh.basis.slerp(Basis(), 8.0 * delta)
				var roll_target: float = steer * 0.15
				if _drifting:
					roll_target = _drift_dir * 0.25 + steer * 0.1
				mesh.rotation.z = lerp(mesh.rotation.z, roll_target, 5.0 * delta)

				var right := transform.basis.x
				var forward_on_slope := fn.cross(right).normalized()
				var pitch_target := -asin(clampf(-forward_on_slope.y, -0.8, 0.8))
				mesh.rotation.x = lerp(mesh.rotation.x, pitch_target, 15.0 * delta)
		else:
			# Airborne — follow velocity for pitch, reset roll
			var roll_target: float = steer * 0.15
			if _drifting:
				roll_target = _drift_dir * 0.25 + steer * 0.1
			mesh.rotation.z = lerp(mesh.rotation.z, roll_target, 5.0 * delta)

			if velocity.length() > 3.0:
				var vel_dir := velocity.normalized()
				var pitch_target := -asin(clampf(-vel_dir.y, -0.6, 0.6))
				mesh.rotation.x = lerp(mesh.rotation.x, pitch_target, 8.0 * delta)

		# Front wheel steering
		var steer_angle: float = steer * 0.4
		if _drifting:
			steer_angle = steer * 0.6  # more wheel angle when drifting
		for w in _front_wheels:
			w.rotation.y = lerp(w.rotation.y, steer_angle, 10.0 * delta)

		# Wheel spin (all wheels)
		_wheel_spin += speed * delta * 3.0
		for w in _front_wheels + _rear_wheels:
			w.rotation.x = _wheel_spin

	# --- Skidmarks ---
	var skidding: bool = false
	if not airborne:
		if _drifting:
			skidding = true
		elif throttle < 0 and abs(speed) > 20.0:
			# Hard braking at high speed
			skidding = true
	if skidding:
		_skid_cooldown = SKID_COOLDOWN_TIME
		_add_skidmarks()
	elif _skid_active:
		_skid_cooldown -= delta
		if _skid_cooldown > 0:
			_add_skidmarks()
		else:
			_skid_active = false

	# --- Particles ---
	_update_particles(airborne)

	# --- Ghost recording ---
	RaceManager.record_frame(global_position, rotation.y)


func _update_particles(airborne: bool) -> void:
	if _drift_smoke:
		_drift_smoke.emitting = _drifting and not airborne
	if _boost_flame:
		_boost_flame.emitting = _boost_timer > 0


func _spawn_wall_sparks(hit_pos: Vector3, normal: Vector3) -> void:
	var sparks := GPUParticles3D.new()
	sparks.emitting = true
	sparks.amount = 20
	sparks.lifetime = 0.5
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.visibility_aabb = AABB(Vector3(-5, -2, -5), Vector3(10, 6, 10))

	var mat := ParticleProcessMaterial.new()
	mat.direction = normal
	mat.spread = 45.0
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 12.0
	mat.gravity = Vector3(0, -15.0, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.4
	mat.color = Color(1.0, 0.8, 0.2, 1.0)
	sparks.process_material = mat
	sparks.draw_pass_1 = _make_particle_mesh(0.08, Color(1.0, 0.8, 0.2, 1.0))

	sparks.global_position = hit_pos
	get_parent().add_child(sparks)
	get_tree().create_timer(1.0).timeout.connect(sparks.queue_free)


func _add_skidmarks() -> void:
	if not _skid_mesh:
		_init_skid_mesh()

	var right := transform.basis.x
	var rear_center := global_position + transform.basis.z * 0.8
	var ground_y := global_position.y - 0.4

	var lp := Vector3(rear_center.x - right.x * 0.35, ground_y, rear_center.z - right.z * 0.35)
	var rp := Vector3(rear_center.x + right.x * 0.35, ground_y, rear_center.z + right.z * 0.35)

	if not _skid_active:
		_skid_prev_l = lp
		_skid_prev_r = rp
		_skid_active = true
		return

	# Skip if haven't moved enough
	if _skid_prev_l.distance_to(lp) < SKID_MIN_DIST:
		return

	# Add quad for each tire: prev_pos → cur_pos, extruded by SKID_WIDTH
	_add_tire_quad(_skid_prev_l, lp)
	_add_tire_quad(_skid_prev_r, rp)

	_skid_prev_l = lp
	_skid_prev_r = rp

	# Trim if too many verts
	if _skid_verts.size() > SKID_MAX_VERTS:
		var trim := _skid_verts.size() - SKID_MAX_VERTS
		_skid_verts = _skid_verts.slice(trim)
		_skid_indices.clear()
		for i in range(_skid_verts.size() / 4):
			var b := i * 4
			_skid_indices.append_array([b, b+1, b+2, b+2, b+1, b+3])

	_rebuild_skid_mesh()


func _add_tire_quad(from: Vector3, to: Vector3) -> void:
	var dir := to - from
	if dir.length_squared() < 0.0001:
		return
	var perp := dir.cross(Vector3.UP).normalized() * SKID_WIDTH

	var i := _skid_verts.size()
	_skid_verts.append(from - perp)
	_skid_verts.append(from + perp)
	_skid_verts.append(to - perp)
	_skid_verts.append(to + perp)

	_skid_indices.append_array([i, i+1, i+2, i+2, i+1, i+3])
	if _skid_verts.size() % 40 == 0:
		print("SKID: %d verts, from=%s to=%s" % [_skid_verts.size(), from, to])


func _rebuild_skid_mesh() -> void:
	if _skid_verts.size() < 4:
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _skid_verts
	arr[Mesh.ARRAY_INDEX] = _skid_indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, _skid_mat)
	_skid_mesh.mesh = m


func _init_skid_mesh() -> void:
	_skid_mat = StandardMaterial3D.new()
	_skid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_skid_mat.albedo_color = Color(0.1, 0.1, 0.1, 0.8)
	_skid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_skid_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_skid_mat.render_priority = 1

	_skid_mesh = MeshInstance3D.new()
	_skid_mesh.material_override = _skid_mat
	_skid_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(_skid_mesh)
	print("SKID: mesh initialized")


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
	up_direction = Vector3.UP
	_gravity_dir = Vector3.DOWN

	global_position = _last_safe_pos + Vector3(0, 1, 0)
	rotation.y = _last_safe_rot

	_grace_timer = SPAWN_GRACE

	if mesh:
		mesh.visible = true
		mesh.basis = Basis()  # Reset to identity (model child handles PI flip)
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
