class_name VehicleStats extends Resource
## Defines all car physics properties.
## Same for all players - only visual customization differs.

@export_group("Speed")
@export var max_speed := 45.0
@export var acceleration := 28.0
@export var brake_force := 38.0
@export var reverse_speed := 20.0

@export_group("Handling")
@export var turn_speed := 2.5
@export var drift_factor := 0.82       # 1.0 = no drift, 0.0 = full drift
@export var air_control := 0.3         # steering in air (0-1)

@export_group("Physics")
@export var gravity := 40.0
@export var floor_snap := 1.5
@export var floor_angle := 75.0        # degrees

@export_group("Special")
@export var min_wallride_speed := 20.0
@export var min_loop_speed := 25.0
@export var boost_multiplier := 1.5
@export var boost_duration := 1.0
