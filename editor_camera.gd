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

# Touch gesture state
var _touch_points := {}  # index → position
var _prev_pinch_dist := 0.0
var _prev_touch_mid := Vector2.ZERO
var _gesture_active := false  # true when 2+ fingers detected


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

	# Touch: pinch zoom + 2-finger orbit
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
		else:
			_touch_points.erase(event.index)
			_gesture_active = false
		if _touch_points.size() == 2:
			var pts := _touch_points.values()
			_prev_pinch_dist = pts[0].distance_to(pts[1])
			_prev_touch_mid = (pts[0] + pts[1]) * 0.5
			_gesture_active = true

	elif event is InputEventScreenDrag and _touch_points.has(event.index):
		_touch_points[event.index] = event.position
		if _touch_points.size() >= 2 and _gesture_active:
			var pts := _touch_points.values()
			var cur_dist: float = pts[0].distance_to(pts[1])
			var cur_mid: Vector2 = (pts[0] + pts[1]) * 0.5

			# Pinch zoom
			var dist_delta: float = cur_dist - _prev_pinch_dist
			distance = clampf(distance - dist_delta * 0.1, min_distance, max_distance)

			# 2-finger drag = orbit
			var mid_delta: Vector2 = cur_mid - _prev_touch_mid
			_yaw -= mid_delta.x * orbit_speed * 0.5
			_pitch = clampf(_pitch - mid_delta.y * orbit_speed * 0.5, _min_pitch, _max_pitch)

			_prev_pinch_dist = cur_dist
			_prev_touch_mid = cur_mid


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
