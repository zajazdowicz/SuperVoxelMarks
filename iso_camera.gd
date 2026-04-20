extends Camera3D
## Isometric follow camera that switches to chase cam in loops.

@export var target: NodePath
@export var height := 30.0
@export var distance := 20.0
@export var smoothing := 5.0
@export var rotation_smoothing := 3.0

# Chase cam settings (3rd person behind car)
@export var chase_height := 3.0
@export var chase_distance := 6.0
@export var chase_smoothing := 8.0

# Boost FOV kick — speed/boost → wider FOV for sensation of speed
@export var base_fov := 75.0
@export var boost_fov := 92.0
@export var speed_fov_bonus := 8.0  # extra fov at top speed without boost

var _target_node: Node3D
var _follow_angle := 0.0  # smoothed Y rotation of car
var _chase_mode := false
var _chase_blend := 0.0   # 0 = full iso, 1 = full chase
var _fov_current := 75.0


func _ready() -> void:
	if target:
		_target_node = get_node(target)
	_fov_current = base_fov
	fov = base_fov


func set_chase_mode(enabled: bool) -> void:
	_chase_mode = enabled


func _process(delta: float) -> void:
	if not _target_node:
		return

	# Blend toward target mode
	var blend_target := 1.0 if _chase_mode else 0.0
	_chase_blend = move_toward(_chase_blend, blend_target, delta * 2.0)

	# Smoothly follow car's Y rotation
	var car_angle: float = _target_node.rotation.y
	_follow_angle = lerp_angle(_follow_angle, car_angle, rotation_smoothing * delta)

	var target_pos := _target_node.global_position

	# ISO camera position
	var iso_offset := Vector3(0, height, distance).rotated(Vector3.UP, _follow_angle)
	var iso_pos := target_pos + iso_offset

	# CHASE camera position — behind and above car
	var car_back := _target_node.global_transform.basis.z.normalized()
	var car_up: Vector3 = _target_node.up_direction if _target_node is CharacterBody3D else Vector3.UP
	var chase_pos := target_pos + car_back * chase_distance + car_up * chase_height

	# Blend between iso and chase
	var desired: Vector3
	if _chase_blend < 0.01:
		desired = iso_pos
	elif _chase_blend > 0.99:
		desired = chase_pos
	else:
		desired = iso_pos.lerp(chase_pos, _chase_blend)

	var spd := lerpf(smoothing, chase_smoothing, _chase_blend)
	global_position = global_position.lerp(desired, spd * delta)

	# Look at car — in chase mode, use car's up direction
	var look_up := Vector3.UP.lerp(car_up, _chase_blend).normalized()
	if look_up.length() < 0.1:
		look_up = Vector3.UP
	look_at(target_pos, look_up)

	# FOV dynamics — speed + boost
	var fov_target := base_fov
	if _target_node.has_method("is_boosting") and _target_node.is_boosting():
		fov_target = boost_fov
	elif _target_node.has_method("get_speed_ratio"):
		var r: float = _target_node.get_speed_ratio()
		fov_target = base_fov + speed_fov_bonus * clampf(r, 0.0, 1.0)
	_fov_current = lerpf(_fov_current, fov_target, 4.0 * delta)
	fov = _fov_current
