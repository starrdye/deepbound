extends Node2D
class_name DroppedItemController

const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")

const SAFE_TOSS_DISTANCE := 72.0
const AUTO_PICKUP_RADIUS := 42.0
const COLLECT_RADIUS := 12.0

var item_id := ""
var count := 0
var velocity := Vector2.ZERO
var pickup_delay := 0.55
var player
var inventory

func setup(id: String, amount: int, player_node, inventory_ref, toss_velocity := Vector2.ZERO) -> void:
	item_id = id
	count = amount
	player = player_node
	inventory = inventory_ref
	velocity = toss_velocity
	queue_redraw()

func _process(delta: float) -> void:
	if item_id == "" or count <= 0:
		queue_free()
		return
	if pickup_delay > 0.0:
		pickup_delay = maxf(0.0, pickup_delay - delta)
	else:
		_update_pickup(delta)
	global_position += velocity * delta
	velocity = velocity.move_toward(Vector2.ZERO, 180.0 * delta)
	queue_redraw()

func _update_pickup(_delta: float) -> void:
	if player == null or inventory == null or not is_instance_valid(player):
		return
	var player_target: Vector2 = player.global_position + Vector2(0, -12)
	var distance := global_position.distance_to(player_target)
	if distance > AUTO_PICKUP_RADIUS or not inventory.can_accept_item(item_id, count):
		return
	if distance <= COLLECT_RADIUS:
		var remaining: int = inventory.add_item(item_id, count)
		if remaining <= 0:
			queue_free()
		else:
			count = remaining
		return
	var direction: Vector2 = (player_target - global_position).normalized()
	velocity = direction * 130.0

func _draw() -> void:
	var texture := TextureFactory.make_item_texture(item_id)
	if texture != null:
		draw_texture_rect(texture, Rect2(Vector2(-8, -8), Vector2(16, 16)), false)
	else:
		draw_rect(Rect2(Vector2(-5, -5), Vector2(10, 10)), Color8(255, 214, 107), true)
