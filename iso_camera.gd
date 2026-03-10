extends Camera3D
## Isometric follow camera that rotates behind the car's direction.

@export var target: NodePath
@export var height := 30.0
@export var distance := 20.0
@export var smoothing := 5.0
@export var rotation_smoothing := 3.0

var _target_node: Node3D
var _follow_angle := 0.0  # smoothed Y rotation of car


func _ready() -> void:
	if target:
		_target_node = get_node(target)


func _process(delta: float) -> void:
	if not _target_node:
		return

	# Smoothly follow car's Y rotation
	var car_angle: float = _target_node.rotation.y
	_follow_angle = lerp_angle(_follow_angle, car_angle, rotation_smoothing * delta)

	# Camera offset rotated by car's direction
	var offset := Vector3(0, height, distance).rotated(Vector3.UP, _follow_angle)
	var target_pos := _target_node.global_position
	var desired := target_pos + offset

	global_position = global_position.lerp(desired, smoothing * delta)
	look_at(target_pos, Vector3.UP)
