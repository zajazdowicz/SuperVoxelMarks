extends Node3D
## Simple touch camera controller for mobile voxel demo.
## Drag to look around, pinch to zoom, double tap to move forward.

@export var move_speed: float = 20.0
@export var look_sensitivity: float = 0.003

var _touch_positions: Dictionary = {}
var _last_drag_distance: float = 0.0

@onready var camera: Camera3D = $Camera3D


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_positions[event.index] = event.position
		else:
			_touch_positions.erase(event.index)

	elif event is InputEventScreenDrag:
		_touch_positions[event.index] = event.position

		if _touch_positions.size() == 1:
			# Single finger drag = look around
			rotation.y -= event.relative.x * look_sensitivity
			rotation.x -= event.relative.y * look_sensitivity
			rotation.x = clampf(rotation.x, -PI / 2.0, PI / 2.0)

		elif _touch_positions.size() == 2:
			# Two finger pinch = move forward/backward
			var keys = _touch_positions.keys()
			var dist = _touch_positions[keys[0]].distance_to(_touch_positions[keys[1]])
			if _last_drag_distance > 0.0:
				var diff = dist - _last_drag_distance
				translate(Vector3.FORWARD * diff * 0.1)
			_last_drag_distance = dist
			return

	if _touch_positions.size() != 2:
		_last_drag_distance = 0.0


func _process(delta: float) -> void:
	# Keyboard fallback for desktop testing
	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	if Input.is_key_pressed(KEY_SPACE):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_SHIFT):
		input_dir.y -= 1

	if input_dir != Vector3.ZERO:
		var movement = basis * input_dir.normalized() * move_speed * delta
		global_position += movement


func _input(event: InputEvent) -> void:
	# Mouse look for desktop testing
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rotation.y -= event.relative.x * look_sensitivity
		rotation.x -= event.relative.y * look_sensitivity
		rotation.x = clampf(rotation.x, -PI / 2.0, PI / 2.0)
