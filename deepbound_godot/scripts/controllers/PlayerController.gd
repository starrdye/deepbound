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
const JUMP_HEIGHT_TILES := 4.0
const JUMP_VELOCITY := -510.0
const AIRBORNE_FRAME_SMOOTHING := 18.0
const WEAPON_SWING_SECONDS := 0.34
const DRILL_SPEED_ITEM_IDS := {
	"drill": true,
	"starter_drill": true,
	"copper_drill": true,
	"crystal_drill": true,
	"cursed_drill": true,
}
const WEAPON_READY_ITEM_IDS := {
	"wooden_sword": true,
	"crystal_sword": true,
	"cursed_sword": true,
}
const HELD_ITEM_HIDDEN_ROWS := {
	3: true,
	4: true,
	5: true,
}

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
var target_tile := Vector2i(999999, 999999)
var target_tile_id := "air"
var target_layer := "foreground"
var last_mining_result := {}
var animation_time := 0.0
var animation_row := -1
var airborne_animation_active := false
var airborne_frame_float := 0.0
var facing := 1
var drill_aim := Vector2.RIGHT
var weapon_swing_started_at := -999.0
var weapon_swing_until := -999.0
var weapon_aim := Vector2.RIGHT
var equipped_weapon_id := "wooden_sword"
var selected_hotbar_item_id := ""
var held_item_texture: Texture2D
var weapon_ready_texture: Texture2D
var controls_locked := false

@onready var sprite: Sprite2D = $Sprite2D
var weapon_sprite: Sprite2D
var weapon_hand_sprite: Sprite2D
var weapon_ready_sprite: Sprite2D
var weapon_ready_hand_sprite: Sprite2D
var held_item_sprite: Sprite2D
var held_hand_sprite: Sprite2D

func _ready() -> void:
	world = get_node_or_null(world_path)
	sprite.texture = TextureFactory.make_delver_sprite_sheet()
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, SPRITE_FRAME_SIZE.x, SPRITE_FRAME_SIZE.y)
	sprite.centered = true
	sprite.position = Vector2(0, -SPRITE_FRAME_SIZE.y / 2.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite = _ensure_overlay_sprite("WeaponSprite", TextureFactory.make_weapon_swing_texture(equipped_weapon_id), 1)
	weapon_hand_sprite = _ensure_overlay_sprite("WeaponHandSprite", TextureFactory.make_weapon_hand_swing_texture(), 2)
	weapon_ready_sprite = _ensure_overlay_sprite("WeaponReadySprite", TextureFactory.make_weapon_ready_texture(equipped_weapon_id), 3)
	weapon_ready_hand_sprite = _ensure_overlay_sprite("WeaponReadyHandSprite", TextureFactory.make_weapon_ready_hand_texture(), 4)
	held_item_sprite = _ensure_held_item_sprite()
	held_hand_sprite = _ensure_overlay_sprite("HeldItemHandSprite", TextureFactory.make_held_item_hand_texture(), 4)
	_refresh_held_item_overlay()
	inventory.set_hotbar_slot(0, "dirt_clod", 3)
	inventory.set_hotbar_slot(1, "stone_chunk", 2)

func _ensure_overlay_sprite(node_name: String, texture: Texture2D, z_offset: int) -> Sprite2D:
	var overlay := get_node_or_null(node_name) as Sprite2D
	if overlay == null:
		overlay = Sprite2D.new()
		overlay.name = node_name
		add_child(overlay)
	overlay.texture = texture
	overlay.region_enabled = true
	overlay.region_rect = Rect2(0, 0, SPRITE_FRAME_SIZE.x, SPRITE_FRAME_SIZE.y)
	overlay.centered = true
	overlay.position = sprite.position
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.z_index = sprite.z_index + z_offset
	overlay.visible = false
	return overlay

func _ensure_held_item_sprite() -> Sprite2D:
	var overlay := get_node_or_null("HeldItemSprite") as Sprite2D
	if overlay == null:
		overlay = Sprite2D.new()
		overlay.name = "HeldItemSprite"
		add_child(overlay)
	overlay.centered = true
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.z_index = sprite.z_index + 3
	overlay.visible = false
	return overlay

func _physics_process(delta: float) -> void:
	if world == null:
		return
	var input_axis := 0.0 if controls_locked else Input.get_axis("move_left", "move_right")
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
	if world.has_method("find_mining_target_info"):
		var target_info: Dictionary = world.find_mining_target_info(origin, aim)
		target_tile = target_info.tile
		target_layer = String(target_info.layer)
		target_tile_id = String(target_info.id)
	else:
		target_tile = world.find_mining_target(origin, aim)
		target_layer = "foreground"
		target_tile_id = "air" if target_tile.x == 999999 else world.get_tile(target_tile)
	if _is_drill_active():
		var use_drill_speed_logic := _selected_item_modifies_drill_speed()
		drill_heat = minf(1.0, drill_heat + 0.16 * delta) if use_drill_speed_logic else 0.0
		if target_tile.x != 999999:
			var effective_drill_heat := drill_heat if use_drill_speed_logic else 0.0
			if world.has_method("find_mining_target_info"):
				last_mining_result = world.mine_at(target_tile, inventory, delta, effective_drill_heat, target_layer)
			else:
				last_mining_result = world.mine_at(target_tile, inventory, delta, effective_drill_heat)
	else:
		drill_heat = maxf(0.0, drill_heat - 0.34 * delta)

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
		fps = 0.0
		fixed_frame = _airborne_animation_frame(delta)
	elif absf(velocity.x) > 8.0 or absf(input_axis) > 0.01:
		row = 1
		frame_count = SPRITE_FRAMES_PER_MOVE
		fps = 10.0
	else:
		row = 0
		frame_count = SPRITE_FRAMES_PER_MOVE
		fps = 4.0

	if row != 2:
		airborne_animation_active = false

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
	_update_held_item_overlay(row, frame, drilling, weapon_swinging)
	_update_weapon_overlay(weapon_swinging, frame)

func _airborne_animation_frame(delta: float) -> int:
	var target_frame := _airborne_target_frame()
	if not airborne_animation_active:
		airborne_frame_float = target_frame
		airborne_animation_active = true
	else:
		var smoothing_weight := 1.0 - exp(-AIRBORNE_FRAME_SMOOTHING * maxf(0.0, delta))
		airborne_frame_float = lerpf(airborne_frame_float, target_frame, smoothing_weight)
	return clampi(roundi(airborne_frame_float), 0, SPRITE_FRAMES_PER_MOVE - 1)

func _airborne_target_frame() -> float:
	var velocity_ratio := clampf((velocity.y - JUMP_VELOCITY) / (MAX_FALL - JUMP_VELOCITY), 0.0, 1.0)
	return lerpf(1.0, 6.0, velocity_ratio)

func _update_weapon_overlay(active: bool, frame: int) -> void:
	for overlay in [weapon_sprite, weapon_hand_sprite]:
		if overlay == null:
			continue
		overlay.visible = active and overlay.texture != null
		if not overlay.visible:
			continue
		overlay.position = sprite.position
		overlay.flip_h = sprite.flip_h
		overlay.region_rect = Rect2(frame * SPRITE_FRAME_SIZE.x, 0, SPRITE_FRAME_SIZE.x, SPRITE_FRAME_SIZE.y)

func _update_held_item_overlay(row: int, frame: int, drilling: bool, weapon_swinging: bool) -> void:
	var overlay_row := _held_overlay_row(row)
	var can_show := selected_hotbar_item_id != "" and not controls_locked and not drilling and not weapon_swinging and overlay_row >= 0
	var weapon_ready_active := can_show and _selected_item_is_ready_weapon() and weapon_ready_texture != null
	var held_item_active := can_show and not weapon_ready_active and held_item_texture != null
	if held_item_sprite != null:
		held_item_sprite.visible = held_item_active
	if held_hand_sprite != null:
		held_hand_sprite.visible = held_item_active and held_hand_sprite.texture != null
	if weapon_ready_sprite != null:
		weapon_ready_sprite.visible = weapon_ready_active
	if weapon_ready_hand_sprite != null:
		weapon_ready_hand_sprite.visible = weapon_ready_active and weapon_ready_hand_sprite.texture != null
	if not held_item_active and not weapon_ready_active:
		return

	var anchor := _held_item_anchor(row, frame)
	var offset := Vector2(anchor.x - SPRITE_FRAME_SIZE.x / 2.0, anchor.y - SPRITE_FRAME_SIZE.y / 2.0)
	if facing < 0:
		offset.x = -offset.x
	if held_item_active:
		held_item_sprite.texture = held_item_texture
		held_item_sprite.position = sprite.position + offset
		held_item_sprite.flip_h = facing < 0
		held_item_sprite.rotation_degrees = 0.0
		held_item_sprite.scale = Vector2.ONE * _held_item_scale()
	if held_item_active and held_hand_sprite != null:
		held_hand_sprite.position = sprite.position
		held_hand_sprite.flip_h = sprite.flip_h
		held_hand_sprite.region_rect = Rect2(frame * SPRITE_FRAME_SIZE.x, overlay_row * SPRITE_FRAME_SIZE.y, SPRITE_FRAME_SIZE.x, SPRITE_FRAME_SIZE.y)
	if weapon_ready_active and weapon_ready_sprite != null:
		weapon_ready_sprite.texture = weapon_ready_texture
		weapon_ready_sprite.position = sprite.position
		weapon_ready_sprite.flip_h = sprite.flip_h
		weapon_ready_sprite.region_rect = Rect2(frame * SPRITE_FRAME_SIZE.x, overlay_row * SPRITE_FRAME_SIZE.y, SPRITE_FRAME_SIZE.x, SPRITE_FRAME_SIZE.y)
	if weapon_ready_active and weapon_ready_hand_sprite != null:
		weapon_ready_hand_sprite.position = sprite.position
		weapon_ready_hand_sprite.flip_h = sprite.flip_h
		weapon_ready_hand_sprite.region_rect = Rect2(frame * SPRITE_FRAME_SIZE.x, overlay_row * SPRITE_FRAME_SIZE.y, SPRITE_FRAME_SIZE.x, SPRITE_FRAME_SIZE.y)

func _held_overlay_row(row: int) -> int:
	if bool(HELD_ITEM_HIDDEN_ROWS.get(row, false)):
		return -1
	if row >= 0 and row <= 2:
		return row
	return 0

func _selected_item_is_ready_weapon() -> bool:
	return bool(WEAPON_READY_ITEM_IDS.get(selected_hotbar_item_id, false))

func _held_item_anchor(row: int, frame: int) -> Vector2:
	var cycle := frame % SPRITE_FRAMES_PER_MOVE
	var y := 23.0
	match row:
		1:
			y += [1, 0, -1, -1, 0, 1, 1, 0][cycle]
		2:
			y += [-1, -2, -2, -1, 0, 1, 1, 0][cycle]
		_:
			if cycle in [2, 3, 4]:
				y += 1.0
	return Vector2(25.0, y)

func _held_item_scale() -> float:
	if held_item_texture == null:
		return 1.0
	var texture_size := held_item_texture.get_size()
	var largest_edge := maxf(texture_size.x, texture_size.y)
	if largest_edge >= 32.0:
		return 0.34
	return 0.64

func _is_action_pressed(action_name: String) -> bool:
	return InputMap.has_action(action_name) and Input.is_action_pressed(action_name)

func _is_action_just_pressed(action_name: String) -> bool:
	return InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name)

func _is_jump_requested() -> bool:
	return not controls_locked and (_is_action_just_pressed("jump") or _is_action_just_pressed("move_up"))

func _is_drill_active() -> bool:
	return not controls_locked and _is_action_pressed("drill")

func _selected_item_modifies_drill_speed() -> bool:
	return bool(DRILL_SPEED_ITEM_IDS.get(selected_hotbar_item_id, false))

func _is_weapon_swinging() -> bool:
	return not controls_locked and Time.get_ticks_msec() / 1000.0 < weapon_swing_until

func cancel_transient_input() -> void:
	velocity.x = 0.0
	animation_row = -1
	animation_time = 0.0
	_update_weapon_overlay(false, 0)
	if held_item_sprite != null:
		held_item_sprite.visible = false
	if held_hand_sprite != null:
		held_hand_sprite.visible = false
	if weapon_ready_sprite != null:
		weapon_ready_sprite.visible = false
	if weapon_ready_hand_sprite != null:
		weapon_ready_hand_sprite.visible = false

func set_controls_locked(locked: bool) -> void:
	if controls_locked == locked:
		return
	controls_locked = locked
	if controls_locked:
		cancel_transient_input()

func set_selected_hotbar_item(item_id: String) -> void:
	selected_hotbar_item_id = item_id
	if not _selected_item_modifies_drill_speed():
		drill_heat = 0.0
	_refresh_held_item_overlay()

func _refresh_held_item_overlay() -> void:
	var ready_weapon := _selected_item_is_ready_weapon()
	if ready_weapon:
		equipped_weapon_id = selected_hotbar_item_id
		weapon_ready_texture = TextureFactory.make_weapon_ready_texture(equipped_weapon_id)
		if weapon_sprite != null:
			weapon_sprite.texture = TextureFactory.make_weapon_swing_texture(equipped_weapon_id)
	else:
		weapon_ready_texture = null
	held_item_texture = null if selected_hotbar_item_id == "" or ready_weapon else TextureFactory.make_held_item_texture(selected_hotbar_item_id)
	if held_item_sprite != null:
		held_item_sprite.texture = held_item_texture
		held_item_sprite.visible = false
	if held_hand_sprite != null:
		held_hand_sprite.visible = false
	if weapon_ready_sprite != null:
		weapon_ready_sprite.texture = weapon_ready_texture
		weapon_ready_sprite.visible = false
	if weapon_ready_hand_sprite != null:
		weapon_ready_hand_sprite.visible = false

func start_weapon_swing(aim := Vector2.ZERO) -> void:
	if controls_locked:
		return
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
