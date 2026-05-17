extends Node2D
class_name PlayerController

const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")
const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")
const CollisionSystem = preload("res://scripts/systems/CollisionSystem.gd")
const HeartSystem = preload("res://scripts/systems/HeartSystem.gd")

const TILE_SIZE := 16
const SPRITE_FRAME_SIZE := Vector2i(32, 32)
const SPRITE_FRAMES_PER_MOVE := 8
const PLAYER_COLLIDER := {"width": 14.0, "height": 28.0}
const GRAVITY := 1900.0
const MAX_FALL := 520.0
const MOVE_ACCEL := 1800.0
const FRICTION := 2200.0
const MAX_SPEED := 94.0
const JUMP_VELOCITY := -410.0
const WEAPON_SWING_SECONDS := 0.34

@export var world_path: NodePath

var world
var velocity := Vector2.ZERO
var on_ground := false
var inventory := InventorySystem.new()
var base_max_health := HeartSystem.DEFAULT_MAX_HP
var equipment_health_delta := 0
var health := HeartSystem.DEFAULT_MAX_HP
var max_health := HeartSystem.DEFAULT_MAX_HP
var invulnerable_until := 0.0
var drill_heat := 0.0
var overheated_until := 0.0
var target_tile := Vector2i(999999, 999999)
var target_tile_id := "air"
var last_mining_result := {}
var animation_time := 0.0
var animation_row := -1
var facing := 1
var drill_aim := Vector2.RIGHT
var weapon_swing_started_at := -999.0
var weapon_swing_until := -999.0
var weapon_aim := Vector2.RIGHT

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	world = get_node_or_null(world_path)
	sprite.texture = TextureFactory.make_delver_sprite_sheet()
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, SPRITE_FRAME_SIZE.x, SPRITE_FRAME_SIZE.y)
	sprite.centered = true
	sprite.position = Vector2(0, -SPRITE_FRAME_SIZE.y / 2.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	if _is_jump_requested() and on_ground:
		velocity.y = JUMP_VELOCITY
		on_ground = false
	velocity.y = minf(MAX_FALL, velocity.y + GRAVITY * delta)
	var collision := CollisionSystem.move_actor(global_position, velocity, delta, PLAYER_COLLIDER, world)
	global_position = collision.position
	velocity = collision.velocity
	on_ground = bool(collision.on_ground)
	if absf(velocity.x) > 3.0:
		facing = -1 if velocity.x < 0.0 else 1
	_update_mining(delta)
	_update_animation(delta, input_axis)

func _update_mining(delta: float) -> void:
	var origin := global_position + Vector2(0, -14)
	var aim := get_global_mouse_position() - origin
	if aim.length_squared() > 0.001:
		drill_aim = aim
	target_tile = world.find_mining_target(origin, aim)
	target_tile_id = "air" if target_tile.x == 999999 else world.get_tile(target_tile)
	if _is_drill_active():
		drill_heat = minf(1.0, drill_heat + 0.16 * delta)
		if target_tile.x != 999999:
			last_mining_result = world.mine_at(target_tile, inventory, delta, drill_heat)
	else:
		drill_heat = maxf(0.0, drill_heat - 0.34 * delta)
	if drill_heat >= 1.0:
		overheated_until = Time.get_ticks_msec() / 1000.0 + 0.7

func _update_animation(delta: float, input_axis: float) -> void:
	var row := 0
	var frame_count := SPRITE_FRAMES_PER_MOVE
	var fps := 4.0
	var fixed_frame := -1
	var drilling := _is_drill_active()
	var weapon_swinging := _is_weapon_swinging()
	var aim := drill_aim
	if aim.length_squared() <= 0.001:
		aim = Vector2(float(facing), 0.0)

	if weapon_swinging:
		row = 6
		frame_count = SPRITE_FRAMES_PER_MOVE
		fps = 22.0
		var progress := clampf((Time.get_ticks_msec() / 1000.0 - weapon_swing_started_at) / WEAPON_SWING_SECONDS, 0.0, 0.999)
		fixed_frame = clampi(floori(progress * SPRITE_FRAMES_PER_MOVE), 0, SPRITE_FRAMES_PER_MOVE - 1)
		if absf(weapon_aim.x) > 0.1:
			facing = -1 if weapon_aim.x < 0.0 else 1
	elif drilling:
		frame_count = SPRITE_FRAMES_PER_MOVE
		fps = 13.0
		if absf(aim.y) > absf(aim.x) * 1.15:
			if aim.y < 0.0:
				row = 4
			else:
				row = 5
		else:
			row = 3
			if absf(aim.x) > 0.1:
				facing = -1 if aim.x < 0.0 else 1
	elif not on_ground:
		row = 2
		frame_count = SPRITE_FRAMES_PER_MOVE
		fps = 1.0
		if velocity.y < -80.0:
			fixed_frame = 2
		elif velocity.y > 90.0:
			fixed_frame = 5
		else:
			fixed_frame = 0
	elif absf(velocity.x) > 8.0 or absf(input_axis) > 0.01:
		row = 1
		frame_count = SPRITE_FRAMES_PER_MOVE
		fps = 10.0
	else:
		row = 0
		frame_count = SPRITE_FRAMES_PER_MOVE
		fps = 4.0

	if row != animation_row:
		animation_row = row
		animation_time = 0.0
	else:
		animation_time += delta

	var frame := fixed_frame
	if frame < 0:
		frame = int(floorf(animation_time * fps)) % frame_count
	sprite.flip_h = facing < 0
	sprite.region_rect = Rect2(frame * SPRITE_FRAME_SIZE.x, row * SPRITE_FRAME_SIZE.y, SPRITE_FRAME_SIZE.x, SPRITE_FRAME_SIZE.y)

func _is_action_pressed(action_name: String) -> bool:
	return InputMap.has_action(action_name) and Input.is_action_pressed(action_name)

func _is_action_just_pressed(action_name: String) -> bool:
	return InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name)

func _is_jump_requested() -> bool:
	return _is_action_just_pressed("jump") or _is_action_just_pressed("move_up")

func _is_drill_active() -> bool:
	return _is_action_pressed("drill") and Time.get_ticks_msec() / 1000.0 >= overheated_until

func _is_weapon_swinging() -> bool:
	return Time.get_ticks_msec() / 1000.0 < weapon_swing_until

func cancel_transient_input() -> void:
	velocity.x = 0.0
	animation_row = -1
	animation_time = 0.0

func start_weapon_swing(aim := Vector2.ZERO) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	weapon_swing_started_at = now
	weapon_swing_until = now + WEAPON_SWING_SECONDS
	if aim.length_squared() > 0.001:
		weapon_aim = aim
	else:
		weapon_aim = Vector2(float(facing), 0.0)

func damage(amount: int, impulse: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < invulnerable_until:
		return
	health = HeartSystem.clamp_hp(health - amount, max_health)
	invulnerable_until = now + 0.8
	velocity += impulse
	if health <= 0:
		health = max_health
		global_position = Vector2(-8 * TILE_SIZE, 13 * TILE_SIZE)
		velocity = Vector2.ZERO

func set_equipment_health_delta(delta_hp: int) -> void:
	equipment_health_delta = delta_hp
	max_health = HeartSystem.resolve_max_hp(base_max_health, equipment_health_delta)
	health = HeartSystem.clamp_hp(health, max_health)

func heal(amount: int) -> void:
	health = HeartSystem.clamp_hp(health + amount, max_health)

func place_beacon() -> void:
	world.add_beacon(global_position + Vector2(0, -12))

func use_flare() -> void:
	world.add_flare(global_position + Vector2(0, -12))
