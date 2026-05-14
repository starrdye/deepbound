extends Node2D
class_name EnemyController

const EnemyCatalog = preload("res://scripts/catalogs/EnemyCatalog.gd")
const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")

const TILE_SIZE := 16
const GRAVITY := 1900.0
const MAX_FALL := 520.0

var enemy_id := "cave_skitter"
var data := {}
var world
var player
var velocity := Vector2.ZERO
var health := 1
var alive := true

func setup(id: String, player_node, world_node) -> void:
	enemy_id = id
	player = player_node
	world = world_node
	data = EnemyCatalog.get_enemy(enemy_id)
	health = int(data.health)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not alive or player == null or world == null:
		return
	var distance := global_position.distance_to(player.global_position)
	if distance < float(data.aggro_tiles) * TILE_SIZE:
		velocity.x = move_toward(velocity.x, signf(player.global_position.x - global_position.x) * float(data.speed), float(data.speed) * 8.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, float(data.speed) * 3.0 * delta)
	velocity.y = minf(MAX_FALL, velocity.y + GRAVITY * delta)
	_move(Vector2(velocity.x * delta, 0.0), Vector2(14, 10))
	_move(Vector2(0.0, velocity.y * delta), Vector2(14, 10))
	if distance < 18.0:
		player.damage(int(data.damage), (player.global_position - global_position).normalized() * 150.0 + Vector2(0, -160))

func _move(motion: Vector2, size: Vector2) -> void:
	if motion == Vector2.ZERO:
		return
	position += motion
	if not _collides(size):
		return
	var step := Vector2(signf(motion.x), signf(motion.y))
	var guard := 0
	while _collides(size) and guard < 32:
		position -= step
		guard += 1
	if motion.x != 0.0:
		velocity.x = 0.0
	if motion.y != 0.0:
		velocity.y = 0.0

func _collides(size: Vector2) -> bool:
	var left := floori((global_position.x - size.x / 2.0) / TILE_SIZE)
	var right := floori((global_position.x + size.x / 2.0 - 1.0) / TILE_SIZE)
	var top := floori((global_position.y - size.y) / TILE_SIZE)
	var bottom := floori((global_position.y - 1.0) / TILE_SIZE)
	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			if world.is_solid_tile(Vector2i(x, y)):
				return true
	return false

func take_damage(amount: int) -> void:
	health -= amount
	modulate = Color.WHITE
	if health <= 0:
		alive = false
		visible = false

func _draw() -> void:
	if data.is_empty():
		data = EnemyCatalog.get_enemy(enemy_id)
	draw_rect(Rect2(Vector2(-10, -12), Vector2(20, 12)), Color8(32, 21, 29))
	draw_rect(Rect2(Vector2(-7, -10), Vector2(14, 8)), data.color)
	draw_rect(Rect2(Vector2(6, -9), Vector2(3, 2)), Color8(232, 213, 161))
	draw_line(Vector2(-5, -2), Vector2(-9, 2), Color8(32, 21, 29))
	draw_line(Vector2(5, -2), Vector2(9, 2), Color8(32, 21, 29))
