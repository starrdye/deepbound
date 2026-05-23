extends Node2D
class_name PlayerController

const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")
const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")
const CollisionSystem = preload("res://scripts/systems/CollisionSystem.gd")
const MiningSystem = preload("res://scripts/systems/MiningSystem.gd")
const HeartSystem = preload("res://scripts/systems/HeartSystem.gd")
const DebugSystem = preload("res://scripts/systems/DebugSystem.gd")

const TILE_SIZE := 16
const SPRITE_FRAME_SIZE := Vector2i(32, 32)
const GOD_MODE_FLY_SPEED := 320.0
const GOD_MODE_FLY_ACCEL := 1800.0
const GOD_MODE_TINT := Color8(255, 214, 80, 210)
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
const TARGET_SCAN_INTERVAL_SECONDS := 0.05
const TARGET_AIM_MIN_DELTA_RADIANS := 0.035
const TARGET_ORIGIN_MIN_DELTA_PX := 4.0
const WEAPON_SWING_SECONDS := 0.34
const NO_TARGET_TILE := Vector2i(999999, 999999)
const DRILL_SPEED_ITEM_IDS := {
	"drill": true,
	"starter_drill": true,
	"copper_drill": true,
	"crystal_drill": true,
	"cursed_drill": true,
}
const HAMMER_ITEM_ID := "hammer"
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
var target_tile := NO_TARGET_TILE
var target_tile_id := "air"
var target_layer := "foreground"
var target_scan_elapsed := TARGET_SCAN_INTERVAL_SECONDS
var target_scan_has_cache := false
var target_scan_was_drilling := false
var last_target_scan_origin := Vector2.ZERO
var last_target_scan_aim := Vector2.RIGHT
var last_target_scan_hammer_enabled := false
var last_target_scan_world = null
var last_mining_result := {}
var animation_time := 0.0
var animation_row := -1
var airborne_animation_active := false
var airborne_frame_float := 0.0
var applied_sprite_frame := -1
var applied_sprite_row := -1
var applied_sprite_flip_h := false
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
var _was_god_mode := false
var equipment_speed_bonus := 0.0
var equipment_defense_bonus := 0

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
	applied_sprite_frame = 0
	applied_sprite_row = 0
	applied_sprite_flip_h = sprite.flip_h
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
	var god_mode := DebugSystem.god_mode_enabled
	# On mode transition: zero velocity so no carry-over momentum.
	if god_mode != _was_god_mode:
		velocity = Vector2.ZERO
		_was_god_mode = god_mode
	sprite.modulate = GOD_MODE_TINT if god_mode else Color.WHITE
	if god_mode:
		_physics_process_god_mode(delta)
	else:
		_physics_process_normal(delta)

func _physics_process_normal(delta: float) -> void:
	var input_axis := 0.0 if controls_locked else Input.get_axis("move_left", "move_right")
	if input_axis != 0.0:
		velocity.x = move_toward(velocity.x, input_axis * MAX_SPEED * (1.0 + equipment_speed_bonus), MOVE_ACCEL * delta)
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

## God-mode physics: free flight in all directions via arrow / WASD, no
## gravity, no collision. HP is blocked in damage(). Drill is instant.
func _physics_process_god_mode(delta: float) -> void:
	var input_x := 0.0 if controls_locked else Input.get_axis("move_left", "move_right")
	# move_up maps to W/UP (-1 = move up in screen space = negative Y).
	var input_y := 0.0 if controls_locked else Input.get_axis("move_up", "move_down")
	velocity.x = move_toward(velocity.x, input_x * GOD_MODE_FLY_SPEED, GOD_MODE_FLY_ACCEL * delta)
	velocity.y = move_toward(velocity.y, input_y * GOD_MODE_FLY_SPEED, GOD_MODE_FLY_ACCEL * delta)
	global_position += velocity * delta
	on_ground = false
	if absf(velocity.x) > 3.0:
		facing = -1 if velocity.x < 0.0 else 1
	_update_mining(delta)
	_update_animation(delta, input_x)

func _update_mining(delta: float) -> void:
	var origin := global_position + Vector2(0, -14)
	var aim := get_global_mouse_position() - origin
	if aim.length_squared() > 0.001:
		drill_aim = aim
	target_scan_elapsed += delta
	var hammer_enabled := _selected_item_is_hammer()
	var drilling := _is_drill_active()
	if _should_refresh_mining_target(origin, aim, hammer_enabled, drilling):
		_refresh_mining_target(origin, aim, hammer_enabled)
	if drilling:
		var use_drill_speed_logic := _selected_item_modifies_drill_speed()
		drill_heat = minf(1.0, drill_heat + 0.16 * delta) if use_drill_speed_logic else 0.0
		if target_tile != NO_TARGET_TILE:
			var effective_drill_heat := drill_heat if use_drill_speed_logic else 0.0
			# God mode: pass a delta large enough to exceed any tile hardness instantly.
			var mine_delta := 9999.0 if DebugSystem.god_mode_enabled else delta
			if world.has_method("find_mining_target_info"):
				last_mining_result = world.mine_at(target_tile, inventory, mine_delta, effective_drill_heat, target_layer, selected_hotbar_item_id)
			else:
				last_mining_result = world.mine_at(target_tile, inventory, mine_delta, effective_drill_heat)
			if bool(last_mining_result.get("broke", false)):
				_invalidate_mining_target_cache()
	else:
		drill_heat = maxf(0.0, drill_heat - 0.34 * delta)
	target_scan_was_drilling = drilling

func _should_refresh_mining_target(origin: Vector2, aim: Vector2, hammer_enabled: bool, drilling: bool) -> bool:
	if not target_scan_has_cache:
		return true
	if world != last_target_scan_world:
		return true
	if hammer_enabled != last_target_scan_hammer_enabled:
		return true
	if drilling and not target_scan_was_drilling:
		return true
	var origin_changed := origin.distance_squared_to(last_target_scan_origin) >= TARGET_ORIGIN_MIN_DELTA_PX * TARGET_ORIGIN_MIN_DELTA_PX
	var aim_changed := _target_aim_changed_significantly(aim)
	if target_scan_elapsed < TARGET_SCAN_INTERVAL_SECONDS:
		return false
	return origin_changed or aim_changed

func _refresh_mining_target(origin: Vector2, aim: Vector2, hammer_enabled: bool) -> void:
	if world.has_method("find_mining_target_info"):
		var target_info: Dictionary = world.find_mining_target_info(origin, aim, float(MiningSystem.STARTER_DRILL.reach_tiles), hammer_enabled)
		target_tile = target_info.get("tile", NO_TARGET_TILE)
		target_layer = String(target_info.get("layer", "foreground"))
		target_tile_id = String(target_info.get("id", "air"))
	else:
		target_tile = world.find_mining_target(origin, aim)
		target_layer = "foreground"
		target_tile_id = "air" if target_tile == NO_TARGET_TILE else world.get_tile(target_tile)
	target_scan_elapsed = 0.0
	target_scan_has_cache = true
	last_target_scan_world = world
	last_target_scan_origin = origin
	last_target_scan_aim = _normalized_target_aim(aim)
	last_target_scan_hammer_enabled = hammer_enabled

func _invalidate_mining_target_cache() -> void:
	target_scan_has_cache = false
	target_scan_elapsed = TARGET_SCAN_INTERVAL_SECONDS

func _target_aim_changed_significantly(aim: Vector2) -> bool:
	var normal := _normalized_target_aim(aim)
	return absf(last_target_scan_aim.angle_to(normal)) >= TARGET_AIM_MIN_DELTA_RADIANS

func _normalized_target_aim(aim: Vector2) -> Vector2:
	if aim.length_squared() <= 0.001:
		return Vector2.RIGHT
	return aim.normalized()

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
	_apply_player_sprite(frame, row)
	_update_held_item_overlay(row, frame, drilling, weapon_swinging)
	_update_weapon_overlay(weapon_swinging, frame)

func _apply_player_sprite(frame: int, row: int) -> void:
	var flip_h := facing < 0
	if applied_sprite_flip_h != flip_h:
		sprite.flip_h = flip_h
		applied_sprite_flip_h = flip_h
	if applied_sprite_frame == frame and applied_sprite_row == row:
		return
	sprite.region_rect = Rect2(frame * SPRITE_FRAME_SIZE.x, row * SPRITE_FRAME_SIZE.y, SPRITE_FRAME_SIZE.x, SPRITE_FRAME_SIZE.y)
	applied_sprite_frame = frame
	applied_sprite_row = row

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
	_update_weapon_overlay_sprite(weapon_sprite, active, frame)
	_update_weapon_overlay_sprite(weapon_hand_sprite, active, frame)

func _update_weapon_overlay_sprite(overlay: Sprite2D, active: bool, frame: int) -> void:
	var should_show := active and overlay != null and overlay.texture != null
	_set_overlay_visible(overlay, should_show)
	if not should_show:
		return
	_set_overlay_position(overlay, sprite.position)
	_set_overlay_flip_h(overlay, sprite.flip_h)
	_set_overlay_region(overlay, frame, 0)

func _update_held_item_overlay(row: int, frame: int, drilling: bool, weapon_swinging: bool) -> void:
	var overlay_row := _held_overlay_row(row)
	var can_show := selected_hotbar_item_id != "" and not controls_locked and not drilling and not weapon_swinging and overlay_row >= 0
	var weapon_ready_active := can_show and _selected_item_is_ready_weapon() and weapon_ready_texture != null
	var held_item_active := can_show and not weapon_ready_active and held_item_texture != null
	var held_hand_active := held_item_active and held_hand_sprite != null and held_hand_sprite.texture != null
	var weapon_ready_hand_active := weapon_ready_active and weapon_ready_hand_sprite != null and weapon_ready_hand_sprite.texture != null
	_set_overlay_visible(held_item_sprite, held_item_active)
	_set_overlay_visible(held_hand_sprite, held_hand_active)
	_set_overlay_visible(weapon_ready_sprite, weapon_ready_active)
	_set_overlay_visible(weapon_ready_hand_sprite, weapon_ready_hand_active)
	if not held_item_active and not weapon_ready_active:
		return

	var anchor := _held_item_anchor(row, frame)
	var offset := Vector2(anchor.x - SPRITE_FRAME_SIZE.x / 2.0, anchor.y - SPRITE_FRAME_SIZE.y / 2.0)
	if facing < 0:
		offset.x = -offset.x
	if held_item_active:
		_set_overlay_texture(held_item_sprite, held_item_texture)
		_set_overlay_position(held_item_sprite, sprite.position + offset)
		_set_overlay_flip_h(held_item_sprite, facing < 0)
		_set_overlay_rotation_degrees(held_item_sprite, 0.0)
		_set_overlay_scale(held_item_sprite, Vector2.ONE * _held_item_scale())
	if held_hand_active:
		_set_overlay_position(held_hand_sprite, sprite.position)
		_set_overlay_flip_h(held_hand_sprite, sprite.flip_h)
		_set_overlay_region(held_hand_sprite, frame, overlay_row)
	if weapon_ready_active and weapon_ready_sprite != null:
		_set_overlay_texture(weapon_ready_sprite, weapon_ready_texture)
		_set_overlay_position(weapon_ready_sprite, sprite.position)
		_set_overlay_flip_h(weapon_ready_sprite, sprite.flip_h)
		_set_overlay_region(weapon_ready_sprite, frame, overlay_row)
	if weapon_ready_hand_active:
		_set_overlay_position(weapon_ready_hand_sprite, sprite.position)
		_set_overlay_flip_h(weapon_ready_hand_sprite, sprite.flip_h)
		_set_overlay_region(weapon_ready_hand_sprite, frame, overlay_row)

func _set_overlay_visible(overlay: Sprite2D, visible: bool) -> void:
	if overlay != null and overlay.visible != visible:
		overlay.visible = visible

func _set_overlay_texture(overlay: Sprite2D, texture: Texture2D) -> void:
	if overlay != null and overlay.texture != texture:
		overlay.texture = texture

func _set_overlay_position(overlay: Sprite2D, position: Vector2) -> void:
	if overlay != null and overlay.position != position:
		overlay.position = position

func _set_overlay_flip_h(overlay: Sprite2D, flip_h: bool) -> void:
	if overlay != null and overlay.flip_h != flip_h:
		overlay.flip_h = flip_h

func _set_overlay_region(overlay: Sprite2D, frame: int, row: int) -> void:
	if overlay == null:
		return
	var region := Rect2(frame * SPRITE_FRAME_SIZE.x, row * SPRITE_FRAME_SIZE.y, SPRITE_FRAME_SIZE.x, SPRITE_FRAME_SIZE.y)
	if overlay.region_rect != region:
		overlay.region_rect = region

func _set_overlay_scale(overlay: Sprite2D, scale: Vector2) -> void:
	if overlay != null and overlay.scale != scale:
		overlay.scale = scale

func _set_overlay_rotation_degrees(overlay: Sprite2D, rotation_degrees: float) -> void:
	if overlay != null and not is_equal_approx(overlay.rotation_degrees, rotation_degrees):
		overlay.rotation_degrees = rotation_degrees

func _held_overlay_row(row: int) -> int:
	if bool(HELD_ITEM_HIDDEN_ROWS.get(row, false)):
		return -1
	if row >= 0 and row <= 2:
		return row
	return 0

func _selected_item_is_ready_weapon() -> bool:
	return bool(WEAPON_READY_ITEM_IDS.get(selected_hotbar_item_id, false))

func _selected_item_is_hammer() -> bool:
	return selected_hotbar_item_id == HAMMER_ITEM_ID

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
	_invalidate_mining_target_cache()
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
	if selected_hotbar_item_id == item_id:
		return
	selected_hotbar_item_id = item_id
	_invalidate_mining_target_cache()
	if not _selected_item_modifies_drill_speed():
		drill_heat = 0.0
	_refresh_held_item_overlay()

func _refresh_held_item_overlay() -> void:
	var ready_weapon := _selected_item_is_ready_weapon()
	if ready_weapon:
		equipped_weapon_id = selected_hotbar_item_id
		weapon_ready_texture = TextureFactory.make_weapon_ready_texture(equipped_weapon_id)
		if weapon_sprite != null:
			_set_overlay_texture(weapon_sprite, TextureFactory.make_weapon_swing_texture(equipped_weapon_id))
	else:
		weapon_ready_texture = null
	held_item_texture = null if selected_hotbar_item_id == "" or ready_weapon else TextureFactory.make_held_item_texture(selected_hotbar_item_id)
	if held_item_sprite != null:
		_set_overlay_texture(held_item_sprite, held_item_texture)
		_set_overlay_visible(held_item_sprite, false)
	if held_hand_sprite != null:
		_set_overlay_visible(held_hand_sprite, false)
	if weapon_ready_sprite != null:
		_set_overlay_texture(weapon_ready_sprite, weapon_ready_texture)
		_set_overlay_visible(weapon_ready_sprite, false)
	if weapon_ready_hand_sprite != null:
		_set_overlay_visible(weapon_ready_hand_sprite, false)

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
	if DebugSystem.god_mode_enabled:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < invulnerable_until:
		return
	var mitigated := maxi(0, amount - equipment_defense_bonus)
	health = HeartSystem.clamp_hp(health - mitigated, max_health)
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

func set_equipment_speed_bonus(bonus: float) -> void:
	equipment_speed_bonus = bonus

func set_equipment_defense_bonus(bonus: int) -> void:
	equipment_defense_bonus = bonus

func heal(amount: int) -> void:
	health = HeartSystem.clamp_hp(health + amount, max_health)

func place_beacon() -> void:
	world.add_beacon(global_position + Vector2(0, -12))

func use_flare() -> void:
	world.add_flare(global_position + Vector2(0, -12))
