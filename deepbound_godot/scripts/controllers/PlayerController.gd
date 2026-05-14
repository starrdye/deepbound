extends Node2D
class_name PlayerController

const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")
const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")

const TILE_SIZE := 16
const PLAYER_WIDTH := 14
const PLAYER_HEIGHT := 28
const GRAVITY := 1900.0
const MAX_FALL := 520.0
const MOVE_ACCEL := 1800.0
const FRICTION := 2200.0
const MAX_SPEED := 94.0
const JUMP_VELOCITY := -410.0

@export var world_path: NodePath

var world
var velocity := Vector2.ZERO
var on_ground := false
var inventory := InventorySystem.new()
var health := 5
var max_health := 5
var invulnerable_until := 0.0
var drill_heat := 0.0
var overheated_until := 0.0
var target_tile := Vector2i(999999, 999999)
var target_tile_id := "air"
var last_mining_result := {}

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	world = get_node_or_null(world_path)
	sprite.texture = TextureFactory.make_delver_texture()
	inventory.add_item("dirt_clod", 3)
	inventory.add_item("stone_chunk", 2)

func _physics_process(delta: float) -> void:
	if world == null:
		return
	var input_axis := Input.get_axis("move_left", "move_right")
	if input_axis != 0.0:
		velocity.x = move_toward(velocity.x, input_axis * MAX_SPEED, MOVE_ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	if Input.is_action_just_pressed("jump") and on_ground:
		velocity.y = JUMP_VELOCITY
		on_ground = false
	velocity.y = minf(MAX_FALL, velocity.y + GRAVITY * delta)
	_move_axis(Vector2(velocity.x * delta, 0.0))
	_move_axis(Vector2(0.0, velocity.y * delta))
	if absf(velocity.x) > 3.0:
		sprite.flip_h = velocity.x < 0.0
	_update_mining(delta)

func _update_mining(delta: float) -> void:
	var origin := global_position + Vector2(0, -14)
	var aim := get_global_mouse_position() - origin
	target_tile = world.find_mining_target(origin, aim)
	target_tile_id = "air" if target_tile.x == 999999 else world.get_tile(target_tile)
	if Input.is_action_pressed("drill") and Time.get_ticks_msec() / 1000.0 >= overheated_until:
		drill_heat = minf(1.0, drill_heat + 0.16 * delta)
		if target_tile.x != 999999:
			last_mining_result = world.mine_at(target_tile, inventory, delta, drill_heat)
	else:
		drill_heat = maxf(0.0, drill_heat - 0.34 * delta)
	if drill_heat >= 1.0:
		overheated_until = Time.get_ticks_msec() / 1000.0 + 0.7

func _move_axis(motion: Vector2) -> void:
	if motion == Vector2.ZERO:
		return
	position += motion
	if not _collides():
		if motion.y > 0.0:
			on_ground = false
		return
	var step := Vector2(signf(motion.x), signf(motion.y))
	var guard := 0
	while _collides() and guard < 48:
		position -= step
		guard += 1
	if motion.y > 0.0:
		on_ground = true
	velocity.x = 0.0 if motion.x != 0.0 else velocity.x
	velocity.y = 0.0 if motion.y != 0.0 else velocity.y

func _collides() -> bool:
	var left := floori((global_position.x - PLAYER_WIDTH / 2.0) / TILE_SIZE)
	var right := floori((global_position.x + PLAYER_WIDTH / 2.0 - 1.0) / TILE_SIZE)
	var top := floori((global_position.y - PLAYER_HEIGHT) / TILE_SIZE)
	var bottom := floori((global_position.y - 1.0) / TILE_SIZE)
	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			if world.is_solid_tile(Vector2i(x, y)):
				return true
	return false

func damage(amount: int, impulse: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < invulnerable_until:
		return
	health = maxi(0, health - amount)
	invulnerable_until = now + 0.8
	velocity += impulse
	if health <= 0:
		health = max_health
		global_position = Vector2(-8 * TILE_SIZE, 13 * TILE_SIZE)
		velocity = Vector2.ZERO

func place_beacon() -> void:
	world.add_beacon(global_position + Vector2(0, -12))

func use_flare() -> void:
	world.add_flare(global_position + Vector2(0, -12))
