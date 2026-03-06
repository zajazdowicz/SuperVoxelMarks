extends Camera3D
## Top-down editor camera that follows the cursor.

@export var height := 40.0
@export var angle := 55.0  # degrees from horizontal
@export var smoothing := 4.0

var target_pos := Vector3.ZERO


func _ready() -> void:
	rotation_degrees.x = -angle


func _process(delta: float) -> void:
	var editor := get_parent().get_node_or_null("TrackEditor")
	if editor and editor.cursor_mesh:
		target_pos = editor.cursor_mesh.global_position

	var offset := Vector3(0, height, height * 0.5)
	var desired := target_pos + offset
	global_position = global_position.lerp(desired, smoothing * delta)
	look_at(target_pos, Vector3.UP)
