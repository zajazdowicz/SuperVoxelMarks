extends CharacterBody3D
## Arcade car controller for top-down voxel racing.

@export var max_speed := 30.0
@export var acceleration := 20.0
@export var brake_force := 30.0
@export var friction := 8.0
@export var turn_speed := 3.0
@export var drift_factor := 0.9

var speed := 0.0
var steer_angle := 0.0

@onready var mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	# Allow car to climb ramps smoothly
	floor_snap_length = 1.5
	floor_max_angle = deg_to_rad(60.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://menu.tscn")


func _physics_process(delta: float) -> void:
	var throttle := Input.get_axis("ui_down", "ui_up")
	var steer := Input.get_axis("ui_right", "ui_left")

	if throttle > 0:
		speed = move_toward(speed, max_speed, acceleration * delta)
	elif throttle < 0:
		speed = move_toward(speed, -max_speed * 0.4, brake_force * delta)
	else:
		speed = move_toward(speed, 0, friction * delta)

	if abs(speed) > 1.0:
		var turn: float = steer * turn_speed * delta * signf(speed)
		rotation.y += turn

	var forward := -transform.basis.z
	velocity = forward * speed
	velocity.y -= 30.0 * delta  # gravity

	move_and_slide()

	if mesh:
		mesh.rotation.z = lerp(mesh.rotation.z, steer * 0.15, 5.0 * delta)
