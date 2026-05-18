extends Node2D
class_name DroppedItemController

const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")
const CollisionSystem = preload("res://scripts/systems/CollisionSystem.gd")

const AUTO_PICKUP_RADIUS := 42.0
const COLLECT_RADIUS := 12.0
const CLICK_PICKUP_HALF_SIZE := Vector2(10, 10)
const ITEM_COLLIDER := {"width": 10.0, "height": 12.0, "bottom_offset": Vector2(0, 8)}
const GRAVITY := 760.0
const MAX_FALL_SPEED := 360.0
const AIR_DRAG := 55.0
const GROUND_FRICTION := 260.0

var item_id := ""
var count := 0
var velocity := Vector2.ZERO
var pickup_delay := 0.55
var player
var inventory
var world
var auto_pickup_enabled := false
var manual_dragging := false

func setup(id: String, amount: int, player_node, inventory_ref, toss_velocity := Vector2.ZERO, world_ref = null, enable_auto_pickup := false) -> void:
	item_id = id
	count = amount
	player = player_node
	inventory = inventory_ref
	velocity = toss_velocity
	world = world_ref
	auto_pickup_enabled = enable_auto_pickup
	queue_redraw()

func _process(delta: float) -> void:
	if item_id == "" or count <= 0:
		queue_free()
		return
	if manual_dragging:
		return
	var magnetizing := false
	if pickup_delay > 0.0:
		pickup_delay = maxf(0.0, pickup_delay - delta)
	elif auto_pickup_enabled:
		magnetizing = _update_pickup(delta)
		if is_queued_for_deletion():
			return
	if not magnetizing:
		velocity.y = minf(MAX_FALL_SPEED, velocity.y + GRAVITY * delta)
	_move_with_physics(delta, magnetizing)

func _move_with_physics(delta: float, magnetizing: bool) -> void:
	if world != null and is_instance_valid(world):
		var attempted_velocity := velocity
		var collision := CollisionSystem.move_actor(global_position, velocity, delta, ITEM_COLLIDER, world)
		global_position = collision.position
		velocity = collision.velocity
		if bool(collision.blocked_y) and attempted_velocity.y >= 0.0:
			velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
		elif not magnetizing:
			velocity.x = move_toward(velocity.x, 0.0, AIR_DRAG * delta)
		return
	global_position += velocity * delta
	velocity = velocity.move_toward(Vector2.ZERO, (GROUND_FRICTION if not magnetizing else AIR_DRAG) * delta)

func _update_pickup(_delta: float) -> bool:
	if player == null or inventory == null or not is_instance_valid(player):
		return false
	var player_target: Vector2 = player.global_position + Vector2(0, -12)
	var distance := global_position.distance_to(player_target)
	if distance > AUTO_PICKUP_RADIUS or not inventory.can_accept_item(item_id, count):
		return false
	if distance <= COLLECT_RADIUS:
		var remaining: int = inventory.add_item(item_id, count)
		if remaining <= 0:
			queue_free()
		else:
			count = remaining
		return true
	var direction: Vector2 = (player_target - global_position).normalized()
	velocity = direction * 130.0
	return true

func contains_world_point(point: Vector2) -> bool:
	return Rect2(global_position - CLICK_PICKUP_HALF_SIZE, CLICK_PICKUP_HALF_SIZE * 2.0).has_point(point)

func try_collect(target_inventory = null) -> bool:
	var destination = inventory if target_inventory == null else target_inventory
	if destination == null or item_id == "" or count <= 0:
		return false
	if not destination.can_accept_item(item_id, count):
		return false
	var remaining: int = destination.add_item(item_id, count)
	if remaining <= 0:
		count = 0
		queue_free()
	else:
		count = remaining
	return true

func begin_manual_drag() -> void:
	manual_dragging = true
	velocity = Vector2.ZERO

func drag_to_world(point: Vector2) -> void:
	if not manual_dragging:
		return
	global_position = point
	velocity = Vector2.ZERO

func end_manual_drag() -> void:
	manual_dragging = false
	velocity = Vector2.ZERO

func _draw() -> void:
	var texture := TextureFactory.make_item_texture(item_id)
	if texture != null:
		draw_texture_rect(texture, Rect2(Vector2(-8, -8), Vector2(16, 16)), false)
	else:
		draw_rect(Rect2(Vector2(-5, -5), Vector2(10, 10)), Color8(255, 214, 107), true)
