extends Node2D
class_name EnemyController

const EnemyCatalog = preload("res://scripts/catalogs/EnemyCatalog.gd")
const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")
const CollisionSystem = preload("res://scripts/systems/CollisionSystem.gd")
const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")

const TILE_SIZE := 16
const SPRITE_FRAME_SIZE := Vector2(32, 32)
const SPRITE_FRAMES_PER_MOVE := 8
const GRAVITY := 1900.0
const MAX_FALL := 520.0

var enemy_id := "cave_skitter"
var data := {}
var world
var player
var velocity := Vector2.ZERO
var health := 1
var alive := true
var anim_time := 0.0
var last_player_distance := 1000000.0
var hurt_until := 0.0
var applied_draw_frame := -1
var applied_draw_row := -1

func setup(id: String, player_node, world_node) -> void:
	enemy_id = id
	player = player_node
	world = world_node
	data = EnemyCatalog.get_enemy(enemy_id)
	health = int(data.health)
	_invalidate_draw_frame()

func _physics_process(delta: float) -> void:
	if not alive or player == null or world == null:
		return
	anim_time += delta
	last_player_distance = global_position.distance_to(player.global_position)
	if last_player_distance < float(data.aggro_tiles) * TILE_SIZE:
		velocity.x = move_toward(velocity.x, signf(player.global_position.x - global_position.x) * float(data.speed), float(data.speed) * 8.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, float(data.speed) * 3.0 * delta)
	velocity.y = minf(MAX_FALL, velocity.y + GRAVITY * delta)
	var collision := CollisionSystem.move_actor(global_position, velocity, delta, _collider(), world)
	global_position = collision.position
	velocity = collision.velocity
	if last_player_distance < 18.0:
		player.damage(int(data.damage), (player.global_position - global_position).normalized() * 150.0 + Vector2(0, -160))
	_queue_redraw_if_animation_changed()

func _collider() -> Dictionary:
	return EnemyCatalog.get_collider(enemy_id)

func take_damage(amount: int) -> void:
	health -= amount
	modulate = Color.WHITE
	hurt_until = Time.get_ticks_msec() / 1000.0 + 0.18
	if health <= 0:
		alive = false
		visible = false
		return
	_invalidate_draw_frame()

func _draw() -> void:
	if data.is_empty():
		data = EnemyCatalog.get_enemy(enemy_id)
	var texture := TextureFactory.make_enemy_texture(enemy_id)
	if texture != null:
		var move_row := _animation_row()
		var frame := int(floorf(anim_time * 10.0)) % SPRITE_FRAMES_PER_MOVE
		applied_draw_frame = frame
		applied_draw_row = move_row
		draw_texture_rect_region(
			texture,
			Rect2(Vector2(-SPRITE_FRAME_SIZE.x / 2.0, -SPRITE_FRAME_SIZE.y), SPRITE_FRAME_SIZE),
			Rect2(Vector2(frame * SPRITE_FRAME_SIZE.x, move_row * SPRITE_FRAME_SIZE.y), SPRITE_FRAME_SIZE)
		)
		return
	draw_rect(Rect2(Vector2(-10, -12), Vector2(20, 12)), Color8(32, 21, 29))
	draw_rect(Rect2(Vector2(-7, -10), Vector2(14, 8)), data.color)
	draw_rect(Rect2(Vector2(6, -9), Vector2(3, 2)), Color8(232, 213, 161))
	draw_line(Vector2(-5, -2), Vector2(-9, 2), Color8(32, 21, 29))
	draw_line(Vector2(5, -2), Vector2(9, 2), Color8(32, 21, 29))

func _animation_row() -> int:
	var now := Time.get_ticks_msec() / 1000.0
	if now < hurt_until:
		return 3
	if last_player_distance < 18.0:
		return 2
	if absf(velocity.x) > 2.0:
		return 1
	return 0

func _queue_redraw_if_animation_changed() -> void:
	var row := _animation_row()
	var frame := int(floorf(anim_time * 10.0)) % SPRITE_FRAMES_PER_MOVE
	if frame == applied_draw_frame and row == applied_draw_row:
		return
	queue_redraw()

func _invalidate_draw_frame() -> void:
	applied_draw_frame = -1
	applied_draw_row = -1
	queue_redraw()
