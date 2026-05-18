extends Camera2D
class_name CameraController

@export var target_path: NodePath
@export var horizontal_dead_zone_px := 10.0
@export var vertical_dead_zone_px := 42.0
@export var follow_smoothing := 12.0
@export var fall_catchup_speed := 760.0
@export var rise_catchup_speed := 520.0
@export var snap_distance_px := 480.0

var target: Node2D
var camera_target := Vector2.ZERO
var smoothed_position := Vector2.ZERO

func _ready() -> void:
	position_smoothing_enabled = false
	target = _resolve_target()
	var start_position := global_position
	if target != null:
		start_position = target.global_position
	camera_target = start_position
	smoothed_position = start_position
	global_position = smoothed_position

func _process(delta: float) -> void:
	update_follow(delta)

func update_follow(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		target = _resolve_target()
	if target == null:
		return

	var target_position := target.global_position
	camera_target = _dead_zone_target(camera_target, target_position)
	if smoothed_position.distance_to(camera_target) > snap_distance_px:
		smoothed_position = camera_target
	else:
		var smoothing_weight := 1.0 - exp(-follow_smoothing * maxf(0.0, delta))
		smoothed_position.x = lerpf(smoothed_position.x, camera_target.x, smoothing_weight)
		var smooth_y_step := (camera_target.y - smoothed_position.y) * smoothing_weight
		var y_speed := fall_catchup_speed if smooth_y_step > 0.0 else rise_catchup_speed
		smoothed_position.y += clampf(smooth_y_step, -y_speed * delta, y_speed * delta)
	global_position = smoothed_position

func _resolve_target() -> Node2D:
	if String(target_path) != "":
		return get_node_or_null(target_path) as Node2D
	return get_parent() as Node2D

func _dead_zone_target(current_target: Vector2, target_position: Vector2) -> Vector2:
	var next_target := current_target
	var delta_x := target_position.x - next_target.x
	if absf(delta_x) > horizontal_dead_zone_px:
		next_target.x = target_position.x - signf(delta_x) * horizontal_dead_zone_px
	var delta_y := target_position.y - next_target.y
	if absf(delta_y) > vertical_dead_zone_px:
		next_target.y = target_position.y - signf(delta_y) * vertical_dead_zone_px
	return next_target
