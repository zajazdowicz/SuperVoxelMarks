extends Camera3D
## Orbit editor camera. MMB=orbit, Scroll=zoom, Shift+MMB=pan.

@export var distance := 50.0
@export var min_distance := 10.0
@export var max_distance := 150.0
@export var zoom_speed := 3.0
@export var orbit_speed := 0.005
@export var smoothing := 6.0

# Orbit angles (radians)
var _yaw := 0.0        # horizontal rotation
var _pitch := -1.0      # vertical angle (~-57 deg, similar to old 55°)
var _min_pitch := -PI / 2.0 + 0.1   # almost straight down
var _max_pitch := -0.15              # almost horizontal

var _target_pos := Vector3.ZERO
var _orbiting := false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				_orbiting = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				distance = maxf(distance - zoom_speed, min_distance)
			MOUSE_BUTTON_WHEEL_DOWN:
				distance = minf(distance + zoom_speed, max_distance)

	elif event is InputEventMouseMotion and _orbiting:
		_yaw -= event.relative.x * orbit_speed
		_pitch = clampf(_pitch - event.relative.y * orbit_speed, _min_pitch, _max_pitch)


func _process(delta: float) -> void:
	var editor := get_parent().get_node_or_null("TrackEditor")
	if editor and editor.cursor_mesh:
		_target_pos = _target_pos.lerp(editor.cursor_mesh.global_position, smoothing * delta)

	# Spherical coordinates -> offset
	var offset := Vector3(
		distance * cos(_pitch) * sin(_yaw),
		distance * -sin(_pitch),
		distance * cos(_pitch) * cos(_yaw),
	)

	global_position = _target_pos + offset
	look_at(_target_pos, Vector3.UP)
