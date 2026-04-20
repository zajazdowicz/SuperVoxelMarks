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
var _spawn_pos := Vector3(0, 3, 0)
var _spawn_rot := 0.0

const OFFTRACK_TIME := 0.8    # seconds on grass before boom
const RESPAWN_DELAY := 2.5
const FALL_THRESHOLD := -15.0
const SPAWN_GRACE := 3.0      # seconds of immunity after spawn/respawn

var _grace_timer := SPAWN_GRACE

# Touch controls
var _touch_left := false      # left side of screen touched
var _touch_right := false     # right side of screen touched
var _touch_ids := {}          # touch_index → "left" or "right"
var _auto_gas := true         # auto-gas enabled (mobile mode)
var _touch_brake := false     # bottom of screen touched = brake
var _swipe_start := {}        # touch_index → start position (for swipe detection)
const SWIPE_DOWN_THRESHOLD := 150.0  # pixels to trigger reset swipe
const BRAKE_ZONE := 0.8      # bottom 20% of screen = brake zone

@onready var mesh: Node3D = $Mesh
@onready var collision: CollisionShape3D = $CollisionShape3D

var _smooth_floor_normal := Vector3.UP  # smoothed floor normal for visual alignment
var _in_zero_g := 0  # >0 = inside zero-gravity zone (loop)

var _front_wheels: Array[Node3D] = []
var _rear_wheels: Array[Node3D] = []
var _all_wheels: Array[Node3D] = []
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
var _drift_smoke_emitters: Array = []


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

	# Lower mesh so wheels sit on ground (capsule radius = 0.6, mesh offset compensates)
	if mesh:
		mesh.position.y = -0.35

	# Load F1 car model
	_load_car_model()
	_setup_particles()
	_setup_occluded_silhouette()


func _load_car_model() -> void:
	var f1_scene: PackedScene = load("res://assets/models/f1_car_new.glb")
	if not f1_scene:
		push_warning("F1 model not found, keeping default mesh")
		return

	for child in mesh.get_children():
		child.queue_free()

	var model := f1_scene.instantiate()
	model.rotation.y = 0  # New model faces correct direction
	model.scale = Vector3(1.1, 1.0, 1.0)  # Slightly wider
	mesh.add_child(model)

	# Find wheel nodes by name pattern and position
	_find_wheels(model)


func _find_wheels(root: Node3D) -> void:
	_front_wheels.clear()
	_rear_wheels.clear()
	# New model: WheelFront.000/.001 = front, .002/.003 = rear
	var front_names := ["WheelFront.000", "WheelFront.001"]
	var rear_names := ["WheelFront.002", "WheelFront.003"]
	_collect_named(root, front_names, _front_wheels)
	_collect_named(root, rear_names, _rear_wheels)
	_all_wheels = _front_wheels + _rear_wheels
	print("Wheels found: %d front, %d rear" % [_front_wheels.size(), _rear_wheels.size()])


func _collect_named(node: Node, names: Array, result: Array[Node3D]) -> void:
	if node is Node3D and String(node.name) in names:
		result.append(node)
	for child in node.get_children():
		_collect_named(child, names, result)
	# For now wheels are static (model looks correct without rotation)


func _setup_particles() -> void:
	# Boost flame (behind car)
	_boost_flame = _create_boost_emitter()
	_boost_flame.position = Vector3(0, 0.0, 1.2)
	add_child(_boost_flame)

	# Drift smoke — 4 emitters at wheel positions
	_drift_smoke_emitters = []
	var wheel_positions := [
		Vector3(-0.35, -0.3, 0.85),   # front left
		Vector3(0.35, -0.3, 0.85),    # front right
		Vector3(-0.45, -0.3, -0.3),   # rear left
		Vector3(0.45, -0.3, -0.3),    # rear right
	]
	for wpos in wheel_positions:
		var emitter := _create_smoke_emitter()
		emitter.position = wpos
		add_child(emitter)
		_drift_smoke_emitters.append(emitter)


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
	p.amount = 25
	p.lifetime = 2.0
	p.randomness = 0.5
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var pmat := ParticleProcessMaterial.new()
	pmat.angle_max = 1.0
	pmat.initial_velocity_min = 0.4
	pmat.initial_velocity_max = 1.2
	pmat.angular_velocity_max = 10.0
	pmat.gravity = Vector3(0, 0.5, 0)
	pmat.linear_accel_min = -0.5
	pmat.linear_accel_max = -0.5
	p.process_material = pmat

	# Generate soft circle texture (no external file needed)
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var dx := (float(x) - 31.5) / 31.5
			var dy := (float(y) - 31.5) / 31.5
			var dist := sqrt(dx * dx + dy * dy)
			var alpha := clampf(1.0 - dist * dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	var tex := ImageTexture.create_from_image(img)

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = tex
	mat.albedo_color = Color(0.7, 0.7, 0.72, 0.65)
	mat.vertex_color_use_as_albedo = true
	var q := QuadMesh.new()
	q.size = Vector2(0.8, 0.8)
	q.material = mat
	p.draw_pass_1 = q

	return p


func _setup_occluded_silhouette() -> void:
	# Semi-transparent car shape visible ONLY when behind obstacles.
	# depth_test_disabled lets ALL fragments reach the shader,
	# then we discard fragments that are NOT occluded.
	var silhouette := MeshInstance3D.new()
	silhouette.name = "OccludedSilhouette"
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.5, 1.8)
	silhouette.mesh = box
	silhouette.position = Vector3(0, 0.1, 0)
	silhouette.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

void fragment() {
	float raw_depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	float scene_dist = -upos.z / upos.w;
	float frag_dist = -VERTEX.z;
	if (frag_dist < scene_dist + 0.5) {
		discard;
	}
	ALBEDO = vec3(0.3, 0.6, 1.0);
	ALPHA = 0.4;
}
"""
	mat.shader = shader
	silhouette.material_override = mat
	mesh.add_child(silhouette)

	# Green arrow showing driving direction (same occluded shader)
	var arrow := MeshInstance3D.new()
	arrow.name = "OccludedArrow"
	# Flat arrow shape: triangle tip + rectangle shaft, lying in XZ plane
	var arr_mesh := ArrayMesh.new()
	var av := PackedVector3Array()
	var an := PackedVector3Array()
	var ai := PackedInt32Array()
	# Arrowhead triangle (tip at -Z = forward)
	av.append(Vector3(0.0, 0.0, -0.9))   # tip
	av.append(Vector3(-0.5, 0.0, -0.2))   # back-left
	av.append(Vector3(0.5, 0.0, -0.2))    # back-right
	# Shaft rectangle
	av.append(Vector3(-0.15, 0.0, -0.2))  # front-left
	av.append(Vector3(0.15, 0.0, -0.2))   # front-right
	av.append(Vector3(-0.15, 0.0, 0.4))   # back-left
	av.append(Vector3(0.15, 0.0, 0.4))    # back-right
	for _i in range(7):
		an.append(Vector3.UP)
	# Arrowhead (both sides for cull_disabled)
	ai.append(0); ai.append(1); ai.append(2)
	# Shaft quad
	ai.append(3); ai.append(5); ai.append(4)
	ai.append(4); ai.append(5); ai.append(6)
	var arr_arrays := []
	arr_arrays.resize(Mesh.ARRAY_MAX)
	arr_arrays[Mesh.ARRAY_VERTEX] = av
	arr_arrays[Mesh.ARRAY_NORMAL] = an
	arr_arrays[Mesh.ARRAY_INDEX] = ai
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr_arrays)
	arrow.mesh = arr_mesh
	arrow.position = Vector3(0, 0.5, -0.2)
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var arrow_mat := ShaderMaterial.new()
	var arrow_shader := Shader.new()
	arrow_shader.code = """shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

void fragment() {
	float raw_depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	float scene_dist = -upos.z / upos.w;
	float frag_dist = -VERTEX.z;
	if (frag_dist < scene_dist + 0.5) {
		discard;
	}
	ALBEDO = vec3(0.2, 0.9, 0.3);
	ALPHA = 0.6;
}
"""
	arrow_shader.code = arrow_shader.code
	arrow_mat.shader = arrow_shader
	arrow.material_override = arrow_mat
	mesh.add_child(arrow)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var screen_w := get_viewport().get_visible_rect().size.x
		var screen_h := get_viewport().get_visible_rect().size.y
		var half_w := screen_w * 0.5
		if event.pressed:
			if event.position.y > screen_h * BRAKE_ZONE:
				# Bottom zone = brake
				_touch_ids[event.index] = "brake"
			else:
				var side := "left" if event.position.x < half_w else "right"
				_touch_ids[event.index] = side
			_swipe_start[event.index] = event.position
		else:
			# Check for swipe down on release
			if _swipe_start.has(event.index):
				var delta_y: float = event.position.y - _swipe_start[event.index].y
				if delta_y > SWIPE_DOWN_THRESHOLD:
					_soft_restart()
					return
				_swipe_start.erase(event.index)
			_touch_ids.erase(event.index)
		_touch_left = _touch_ids.values().has("left")
		_touch_right = _touch_ids.values().has("right")
		_touch_brake = _touch_ids.values().has("brake")

	elif event is InputEventScreenDrag:
		var screen_w := get_viewport().get_visible_rect().size.x
		var screen_h := get_viewport().get_visible_rect().size.y
		var half_w := screen_w * 0.5
		if _touch_ids.has(event.index):
			if event.position.y > screen_h * BRAKE_ZONE:
				_touch_ids[event.index] = "brake"
			else:
				_touch_ids[event.index] = "left" if event.position.x < half_w else "right"
			_touch_left = _touch_ids.values().has("left")
			_touch_right = _touch_ids.values().has("right")
			_touch_brake = _touch_ids.values().has("brake")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://menu.tscn")
			KEY_R:
				_soft_restart()
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

	# --- Countdown freeze ---
	if RaceManager.state == RaceManager.State.COUNTDOWN:
		speed = 0.0
		velocity = Vector3.ZERO
		return

	var surface := _detect_surface()
	var airborne := not is_on_floor()

	# --- Off-track detection ---
	_check_offtrack(surface, airborne, delta)

	# --- Input: keyboard + touch combined ---
	var kb_throttle := Input.get_axis("ui_down", "ui_up")
	var kb_steer := Input.get_axis("ui_right", "ui_left")
	var kb_handbrake := Input.is_action_pressed("ui_accept")  # Space

	# Touch: L/R = steer, both = drift, bottom = brake, auto-gas
	var touch_throttle := 0.0
	var touch_steer := 0.0
	var touch_handbrake := false
	var touch_active := _touch_left or _touch_right or _touch_brake

	# Steering (always works, even while braking)
	if _touch_left and _touch_right:
		touch_handbrake = true
	elif _touch_left:
		touch_steer = 1.0
	elif _touch_right:
		touch_steer = -1.0

	# Throttle
	if _touch_brake:
		touch_throttle = -1.0  # brake / reverse
	elif touch_active:
		touch_throttle = 1.0 if not touch_handbrake else 0.5
	elif _auto_gas:
		touch_throttle = 1.0  # auto-gas when no touch

	# Combine: keyboard takes priority if active, otherwise touch
	var has_kb := absf(kb_throttle) > 0.01 or absf(kb_steer) > 0.01 or kb_handbrake
	var throttle := kb_throttle if has_kb else touch_throttle
	var steer := kb_steer if has_kb else touch_steer
	var handbrake := kb_handbrake or touch_handbrake

	# --- Surface properties ---
	var grip: float = surface.grip
	var friction: float = surface.friction
	var speed_limit: float = stats.max_speed * surface.speed_mult * _boost_mult

	# --- Boost pad ---
	if surface.get("is_boost", false) and is_on_floor():
		var bmult: float = surface.get("boost_mult", stats.boost_multiplier)
		var bdur: float = surface.get("boost_dur", stats.boost_duration)
		_apply_boost(bmult, bdur)

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
		# Handbrake slows down (surface grip affects braking)
		speed = move_toward(speed, speed * 0.7, stats.brake_force * 0.8 * grip * delta)
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

	# --- Steering (only on ground) ---
	if not airborne and abs(speed) > 1.0:
		var turn_mult: float
		if _drifting:
			turn_mult = grip * DRIFT_TURN_MULT
		else:
			turn_mult = grip
		var turn: float = steer * stats.turn_speed * delta * signf(speed) * turn_mult
		rotation.y += turn

	# --- Movement ---
	var forward := -transform.basis.z

	if _in_zero_g > 0:
		# Zero-gravity zone (loop) — car sticks to any surface
		floor_max_angle = deg_to_rad(170.0)
		floor_snap_length = stats.floor_snap * 2.0
		if is_on_floor():
			var fn := get_floor_normal()
			up_direction = fn
			_gravity_dir = -fn
			var slope_forward := (forward - fn * forward.dot(fn)).normalized()
			var target_vel := slope_forward * speed
			var blend: float = grip * stats.drift_factor if not _drifting else DRIFT_GRIP * grip
			velocity = velocity.lerp(target_vel, clampf(blend, 0.1, 1.0))
			# Gentle push toward surface to maintain contact
			velocity += -fn * 5.0 * delta
		else:
			# Airborne in zero-G — no gravity, coast
			velocity *= 0.999  # very slight drag
	elif airborne:
		up_direction = Vector3.UP
		_gravity_dir = Vector3.DOWN
		# No air control — maintain horizontal velocity, only gravity affects
		velocity += Vector3.DOWN * stats.gravity * delta
	else:
		var fn := get_floor_normal()
		var slope_forward := (forward - fn * forward.dot(fn)).normalized()
		var target_vel := slope_forward * speed

		var blend: float
		if _drifting:
			blend = DRIFT_GRIP * grip  # surface grip modulates drift slide
		else:
			blend = grip * stats.drift_factor
		velocity = velocity.lerp(target_vel, clampf(blend, 0.1, 1.0))

		# Adaptive gravity & up_direction for wall ride / loop
		var slope_dot := fn.dot(Vector3.UP)
		if slope_dot < 0.7:
			# Steep surface (wall ride / loop)
			# Speed-based adhesion: need minimum speed to stick to wall
			var min_speed := stats.min_wallride_speed
			var hold_speed := stats.min_loop_speed
			var speed_factor := clampf((absf(speed) - min_speed) / (hold_speed - min_speed), 0.0, 1.0)

			if speed_factor > 0.0:
				# Enough speed — stick to wall
				up_direction = fn
				_gravity_dir = -fn
				floor_snap_length = stats.floor_snap
				floor_max_angle = deg_to_rad(85.0)  # allow steep surfaces as floor
				velocity += -fn * stats.gravity * speed_factor * delta
			else:
				# Too slow — make wall NOT count as floor so car falls off
				up_direction = Vector3.UP
				_gravity_dir = Vector3.DOWN
				floor_snap_length = 0.0
				floor_max_angle = deg_to_rad(30.0)  # 60° wall is no longer "floor"
				velocity += Vector3.DOWN * stats.gravity * delta
		else:
			# Normal / mild slope — standard physics
			up_direction = Vector3.UP
			floor_snap_length = stats.floor_snap
			floor_max_angle = deg_to_rad(stats.floor_angle)  # restore default (75°)
			_gravity_dir = Vector3.DOWN
			if slope_dot < 0.97:
				var gravity_along_slope := Vector3.DOWN - fn * Vector3.DOWN.dot(fn)
				velocity += gravity_along_slope * stats.gravity * 0.3 * delta

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
				velocity = reflect * 0.07
				speed = maxf(speed * 0.93, 0.0)
				global_position += normal * 0.05
				_spawn_wall_sparks(global_position, normal)

	# --- Visual ---
	if mesh:
		# Smooth floor normal to prevent jitter on collision segment edges
		if is_on_floor():
			_smooth_floor_normal = _smooth_floor_normal.lerp(get_floor_normal(), 6.0 * delta).normalized()
		else:
			_smooth_floor_normal = _smooth_floor_normal.lerp(Vector3.UP, 4.0 * delta).normalized()

		var pitch_target := 0.0
		var roll_target := 0.0
		var surface_basis := Basis()

		if is_on_floor():
			var fn := _smooth_floor_normal
			var slope_dot2 := fn.dot(Vector3.UP)

			if slope_dot2 < 0.85:
				# Surface alignment — steep slopes, wall ride, ramps
				var car_forward := -transform.basis.z
				var right := car_forward.cross(fn).normalized()
				var aligned_forward := fn.cross(right).normalized()
				surface_basis = Basis(right, fn, -aligned_forward)
			else:
				# Flat/gentle slope — pitch from slope
				var right := transform.basis.x
				var forward_on_slope := fn.cross(right).normalized()
				pitch_target = -asin(clampf(-forward_on_slope.y, -0.5, 0.5))
		else:
			# Airborne — pitch from velocity
			if velocity.length() > 3.0:
				var vel_dir := velocity.normalized()
				pitch_target = -asin(clampf(-vel_dir.y, -0.4, 0.4))

		# Cosmetic roll from steering — scale with speed for arcade feel
		var speed_factor: float = clampf(absf(speed) / 30.0, 0.5, 1.2)
		roll_target = steer * 0.22 * speed_factor
		if _drifting:
			roll_target = _drift_dir * 0.38 + steer * 0.12

		# Acceleration pitch — lean forward when boosting, back when braking hard
		if _boost_timer > 0:
			pitch_target += -0.08
		elif throttle < -0.1 and speed > 10.0:
			pitch_target += 0.06

		# Apply: surface alignment OR euler pitch/roll
		if surface_basis != Basis():
			mesh.basis = mesh.basis.slerp(surface_basis, 5.0 * delta)
		else:
			# Smoothly return to identity then apply pitch/roll as euler
			mesh.basis = mesh.basis.slerp(Basis(), 6.0 * delta)
			mesh.rotation.x = lerp(mesh.rotation.x, pitch_target, 8.0 * delta)
			mesh.rotation.z = lerp(mesh.rotation.z, roll_target, 5.0 * delta)

		# Front wheel steering
		var steer_angle: float = steer * 0.4
		if _drifting:
			steer_angle = steer * 0.6
		for w in _front_wheels:
			w.rotation.y = lerp(w.rotation.y, steer_angle, 10.0 * delta)

		# Wheel spin (all wheels) — Y axis confirmed
		_wheel_spin += speed * delta * 3.0
		for w in _all_wheels:
			w.rotation.y = _wheel_spin

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
	var smoke_on: bool = _drifting and not airborne and _drift_timer > 0.3
	for emitter in _drift_smoke_emitters:
		emitter.emitting = smoke_on
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


func _check_offtrack(surface: Dictionary, airborne: bool, delta: float) -> void:
	# No offtrack after finishing (sprint: grass after finish line)
	if RaceManager.state == RaceManager.State.FINISHED or RaceManager.state == RaceManager.State.TIME_UP:
		_offtrack_timer = 0.0
		return

	# Grace period after spawn/respawn
	if _grace_timer > 0:
		_grace_timer -= delta
		return

	# Fall off the world → full restart
	if global_position.y < FALL_THRESHOLD:
		_soft_restart()
		return

	# Off track (grass/sand terrain) → full restart after OFFTRACK_TIME
	if not airborne and not surface.get("is_road", false):
		_offtrack_timer += delta
		if _offtrack_timer >= OFFTRACK_TIME:
			_soft_restart()
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


func _soft_restart() -> void:
	# Reset race state without reloading scene (preserves ghosts, skidmarks)

	# Move car to track start (from track_loader, not car's initial position)
	var loader := get_parent().get_node_or_null("TrackLoader")
	if loader:
		global_position = loader._spawn_pos + Vector3(0, 1, 0)
		rotation.y = loader._spawn_rot
	else:
		global_position = _spawn_pos + Vector3(0, 1, 0)
		rotation.y = _spawn_rot
	speed = 0.0
	velocity = Vector3.ZERO
	_is_dead = false
	_offtrack_timer = 0.0
	_grace_timer = SPAWN_GRACE + 0.5  # extra grace to avoid trigger re-fire

	RaceManager.reset()
	RaceManager.start_countdown()

	if mesh:
		mesh.visible = true
		mesh.basis = Basis()
	if collision:
		collision.disabled = false

	# Stop and re-arm ghosts
	if loader:
		if loader.has_method("_start_ghost"):
			# Ghosts will restart on race_started signal from countdown
			pass
		if loader._ghost_best and loader._ghost_best.has_method("stop_playback"):
			loader._ghost_best.stop_playback()
		for g in loader._ghost_server:
			if g.has_method("stop_playback"):
				g.stop_playback()
		# Re-connect ghost start to race_started
		if not RaceManager.race_started.is_connected(loader._start_ghost):
			RaceManager.race_started.connect(loader._start_ghost)


func _respawn() -> void:
	_is_dead = false
	_offtrack_timer = 0.0
	speed = 0.0
	velocity = Vector3.ZERO
	up_direction = Vector3.UP
	_gravity_dir = Vector3.DOWN
	_smooth_floor_normal = Vector3.UP
	floor_snap_length = stats.floor_snap
	floor_max_angle = deg_to_rad(stats.floor_angle)

	# Respawn at last checkpoint, or start if none hit
	if RaceManager.respawn_pos != Vector3.ZERO:
		global_position = RaceManager.respawn_pos + Vector3(0, 1, 0)
		rotation.y = RaceManager.respawn_rot
	else:
		global_position = _spawn_pos + Vector3(0, 1, 0)
		rotation.y = _spawn_rot

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


func _apply_boost(mult: float = 0.0, dur: float = 0.0) -> void:
	if _boost_timer > 0:
		return
	_boost_mult = mult if mult > 0.0 else stats.boost_multiplier
	_boost_timer = dur if dur > 0.0 else stats.boost_duration
	speed = maxf(speed, stats.max_speed * 0.9)


func is_boosting() -> bool:
	return _boost_timer > 0


func get_speed_ratio() -> float:
	return clampf(absf(speed) / stats.max_speed, 0.0, 1.5)


func set_gravity_direction(dir: Vector3) -> void:
	_gravity_dir = dir.normalized()


func reset_gravity() -> void:
	_gravity_dir = Vector3.DOWN


func enter_zero_g() -> void:
	_in_zero_g += 1
	# Switch camera to chase mode
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("set_chase_mode"):
		cam.set_chase_mode(true)

func exit_zero_g() -> void:
	_in_zero_g = maxi(0, _in_zero_g - 1)
	if _in_zero_g == 0:
		up_direction = Vector3.UP
		_gravity_dir = Vector3.DOWN
		floor_max_angle = deg_to_rad(stats.floor_angle)
		floor_snap_length = stats.floor_snap
		# Switch camera back to iso
		var cam := get_viewport().get_camera_3d()
		if cam and cam.has_method("set_chase_mode"):
			cam.set_chase_mode(false)
