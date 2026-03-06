extends Camera3D
## Isometric follow camera for top-down racing.

@export var target: NodePath
@export var height := 30.0
@export var distance := 20.0
@export var smoothing := 5.0

var _target_node: Node3D


func _ready() -> void:
	if target:
		_target_node = get_node(target)


func _process(delta: float) -> void:
	if not _target_node:
		return

	var target_pos := _target_node.global_position
	var desired := target_pos + Vector3(0, height, distance)

	global_position = global_position.lerp(desired, smoothing * delta)
	look_at(target_pos, Vector3.UP)
