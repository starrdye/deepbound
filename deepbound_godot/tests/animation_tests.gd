extends SceneTree

const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")
const PlayerController = preload("res://scripts/controllers/PlayerController.gd")
const CameraController = preload("res://scripts/controllers/CameraController.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_sprite_sheet_dimensions()
	_test_tile_textures_remain_native_size()
	_test_missing_texture_lookups_are_cached()
	await _test_player_animation_rows()
	await _test_airborne_animation_tracks_velocity_smoothly()
	await _test_camera_dead_zone_follow()
	await _test_drag_lock_keeps_idle_animating()
	if failures.is_empty():
		print("Deepbound Godot animation tests passed.")
		quit(0)
	else:
		print("Deepbound Godot animation tests failed: %d" % failures.size())
		quit(1)

func _test_sprite_sheet_dimensions() -> void:
	var sheet := TextureFactory.make_delver_sprite_sheet()
	_assert(sheet.get_width() == 256, "delver sheet should be eight 32px columns")
	_assert(sheet.get_height() == 224, "delver sheet should be seven 32px rows including weapon swing")
	var idle := TextureFactory.make_delver_texture()
	_assert(idle.get_width() == 32, "single idle delver texture should be 32px wide")
	_assert(idle.get_height() == 32, "single idle delver texture should be 32px tall")
	var hand_sheet := TextureFactory.make_weapon_hand_swing_texture()
	var sword_sheet := TextureFactory.make_weapon_swing_texture("wooden_sword")
	var held_hand_sheet := TextureFactory.make_held_item_hand_texture()
	var ready_hand_sheet := TextureFactory.make_weapon_ready_hand_texture()
	var ready_sword_sheet := TextureFactory.make_weapon_ready_texture("wooden_sword")
	_assert(hand_sheet != null and hand_sheet.get_width() == 256 and hand_sheet.get_height() == 32, "weapon hand overlay should be an eight-frame 32px sheet")
	_assert(sword_sheet != null and sword_sheet.get_width() == 256 and sword_sheet.get_height() == 32, "wooden sword overlay should be an eight-frame 32px sheet")
	_assert(held_hand_sheet != null and held_hand_sheet.get_width() == 256 and held_hand_sheet.get_height() == 96, "held item hand overlay should be an eight-frame three-row 32px sheet")
	_assert(ready_hand_sheet != null and ready_hand_sheet.get_width() == 256 and ready_hand_sheet.get_height() == 96, "weapon ready hand overlay should be an eight-frame three-row 32px sheet")
	_assert(ready_sword_sheet != null and ready_sword_sheet.get_width() == 256 and ready_sword_sheet.get_height() == 96, "wooden sword ready overlay should be an eight-frame three-row 32px sheet")

func _test_tile_textures_remain_native_size() -> void:
	var dirt := TextureFactory.make_tile_texture("loose_dirt", {"color": Color8(122, 75, 46), "highlight": Color8(168, 111, 60)})
	var resin := TextureFactory.make_tile_texture("hardened_resin", {"color": Color8(143, 95, 34), "highlight": Color8(241, 184, 91)})
	_assert(dirt.get_width() == 16 and dirt.get_height() == 16, "dirt texture should stay 16x16")
	_assert(resin.get_width() == 16 and resin.get_height() == 16, "resin texture should stay 16x16")

func _test_missing_texture_lookups_are_cached() -> void:
	var key := "item:missing_animation_test_item"
	TextureFactory.cache.erase(key)
	var missing := TextureFactory.make_item_texture("missing_animation_test_item")
	_assert(missing == null, "missing texture lookup should return null")
	_assert(TextureFactory.cache.has(key), "missing texture lookup should be cached to avoid repeated filesystem probes")

func _test_player_animation_rows() -> void:
	var player := PlayerController.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	player.add_child(sprite)
	get_root().add_child(player)
	await process_frame

	player.on_ground = true
	player.velocity = Vector2(70, 0)
	player._update_animation(0.2, 1.0)
	_assert(sprite.region_rect.position.y == 32.0, "walking should use sprite sheet row 1")
	_assert(sprite.region_rect.size == Vector2(32, 32), "active sprite region should stay 32x32")

	player.on_ground = false
	player.velocity = Vector2(0, -120)
	player._update_animation(0.2, 0.0)
	_assert(sprite.region_rect.position.y == 64.0, "airborne movement should use sprite sheet row 2")
	_assert(_frame_index(sprite) >= 1 and _frame_index(sprite) <= 3, "rising jump should use an early airborne pose")

	if not InputMap.has_action("drill"):
		InputMap.add_action("drill")
	player.target_tile = Vector2i(0, 0)
	player.drill_aim = Vector2.UP
	player.global_position = Vector2.ZERO
	Input.action_press("drill")
	player._update_animation(0.2, 0.0)
	_assert(sprite.region_rect.position.y == 128.0, "upward drilling should use sprite sheet row 4")

	player.target_tile = Vector2i(999999, 999999)
	player.drill_aim = Vector2.RIGHT
	player.on_ground = true
	player.velocity = Vector2.ZERO
	player._update_animation(0.1, 0.0)
	_assert(sprite.region_rect.position.y == 96.0, "held drill should keep animating even when no solid target is found")
	player._update_animation(0.2, 0.0)
	_assert(sprite.region_rect.position.y == 96.0, "drill animation should not fall back to idle during a held no-target drill")
	_assert(sprite.region_rect.position.x == 64.0, "held drill animation should keep advancing frames")
	Input.action_release("drill")

	player.set_selected_hotbar_item("dirt_clod")
	player._update_animation(0.05, 0.0)
	var held_item_sprite := player.get_node_or_null("HeldItemSprite")
	var held_hand_sprite := player.get_node_or_null("HeldItemHandSprite")
	_assert(held_item_sprite != null and bool(held_item_sprite.visible), "selected placeable blocks should show a held item overlay")
	_assert(held_hand_sprite != null and bool(held_hand_sprite.visible), "selected placeable blocks should show the reusable held hand overlay")
	if held_item_sprite != null:
		_assert(held_item_sprite.texture != null and held_item_sprite.texture.get_width() == 16, "held dirt should use the placed mini-block texture")
	if held_hand_sprite != null:
		_assert(held_hand_sprite.region_rect.position.y == 0.0, "idle held item hand should use overlay row 0")

	player.velocity = Vector2(70, 0)
	player.on_ground = true
	player._update_animation(0.1, 1.0)
	if held_hand_sprite != null:
		_assert(held_hand_sprite.region_rect.position.y == 32.0, "walking held item hand should use overlay row 1")

	player.velocity = Vector2(0, -120)
	player.on_ground = false
	player._update_animation(0.1, 0.0)
	if held_hand_sprite != null:
		_assert(held_hand_sprite.region_rect.position.y == 64.0, "jumping held item hand should use overlay row 2")

	player.velocity = Vector2.ZERO
	player.on_ground = true
	player.set_selected_hotbar_item("wooden_sword")
	player._update_animation(0.05, 0.0)
	var weapon_ready_sprite := player.get_node_or_null("WeaponReadySprite")
	var weapon_ready_hand_sprite := player.get_node_or_null("WeaponReadyHandSprite")
	_assert(weapon_ready_sprite != null and bool(weapon_ready_sprite.visible), "selected weapon should show a modular ready weapon overlay before attacking")
	_assert(weapon_ready_hand_sprite != null and bool(weapon_ready_hand_sprite.visible), "selected weapon should show a reusable ready weapon hand overlay")
	if held_item_sprite != null:
		_assert(not bool(held_item_sprite.visible), "selected weapon should not reuse the block held item sprite")
	if weapon_ready_sprite != null:
		_assert(weapon_ready_sprite.region_rect.position.y == 0.0, "idle ready weapon should use overlay row 0")

	player.start_weapon_swing(Vector2.RIGHT)
	player._update_animation(0.05, 0.0)
	_assert(sprite.region_rect.position.y == 192.0, "weapon strike should use sprite sheet row 6")
	var weapon_sprite := player.get_node_or_null("WeaponSprite")
	var weapon_hand_sprite := player.get_node_or_null("WeaponHandSprite")
	_assert(weapon_sprite != null and bool(weapon_sprite.visible), "weapon strike should show the modular weapon overlay")
	_assert(weapon_hand_sprite != null and bool(weapon_hand_sprite.visible), "weapon strike should show the reusable hand overlay")
	if held_item_sprite != null:
		_assert(not bool(held_item_sprite.visible), "ready held item overlay should hide during the weapon swing overlay")
	if weapon_ready_sprite != null:
		_assert(not bool(weapon_ready_sprite.visible), "ready weapon overlay should hide during the weapon swing overlay")
	if weapon_sprite != null and weapon_hand_sprite != null:
		_assert(weapon_sprite.region_rect.position.x == sprite.region_rect.position.x, "weapon overlay frame should track the player swing frame")
		_assert(weapon_hand_sprite.region_rect.position.x == sprite.region_rect.position.x, "hand overlay frame should track the player swing frame")
	player._update_animation(0.15, 0.0)
	_assert(sprite.region_rect.position.y == 192.0, "weapon strike animation should stay active during the swing window")

	player.queue_free()

func _test_airborne_animation_tracks_velocity_smoothly() -> void:
	var player := PlayerController.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	player.add_child(sprite)
	get_root().add_child(player)
	await process_frame

	player.on_ground = false
	var previous_frame := -1
	for y_velocity in [-420.0, -180.0, 0.0, 180.0, 420.0]:
		player.velocity = Vector2(0, y_velocity)
		player._update_animation(0.08, 0.0)
		var frame := _frame_index(sprite)
		_assert(sprite.region_rect.position.y == 64.0, "airborne velocity states should stay on jump/fall row")
		if previous_frame >= 0:
			_assert(frame >= previous_frame, "airborne animation should progress forward as vertical velocity moves from rise to fall")
			_assert(frame - previous_frame <= 2, "airborne animation should not snap across distant frames")
		previous_frame = frame

	player.velocity = Vector2(0, -460)
	player._update_animation(0.08, 0.0)
	var rising_frame := _frame_index(sprite)
	player.velocity = Vector2.ZERO
	player._update_animation(0.08, 0.0)
	var apex_frame := _frame_index(sprite)
	player.velocity = Vector2(0, 460)
	player._update_animation(0.08, 0.0)
	var falling_frame := _frame_index(sprite)
	_assert(rising_frame <= 2, "strong upward velocity should use early airborne frames")
	_assert(apex_frame >= 2 and apex_frame <= 4, "near-apex velocity should use middle airborne frames")
	_assert(falling_frame >= 4, "falling velocity should use late airborne frames")

	player.on_ground = true
	player.velocity = Vector2.ZERO
	player._update_animation(0.08, 0.0)
	_assert(not bool(player.get("airborne_animation_active")), "landing should reset airborne frame smoothing")
	player.queue_free()

func _test_camera_dead_zone_follow() -> void:
	var player := Node2D.new()
	var camera := CameraController.new()
	player.add_child(camera)
	get_root().add_child(player)
	await process_frame

	player.global_position = Vector2.ZERO
	camera.global_position = Vector2.ZERO
	camera.camera_target = Vector2.ZERO
	camera.smoothed_position = Vector2.ZERO
	player.global_position = Vector2(0, 20)
	camera.update_follow(1.0 / 60.0)
	_assert(absf(camera.global_position.y) <= 0.01, "camera should ignore small vertical movement inside the dead zone")

	player.global_position = Vector2(0, 96)
	camera.update_follow(0.2)
	_assert(camera.global_position.y > 0.0, "camera should catch up after the player leaves the vertical dead zone")
	_assert(camera.global_position.y < player.global_position.y, "camera catch-up should remain smooth instead of snapping to the player")

	player.global_position = Vector2(48, 96)
	camera.update_follow(0.2)
	_assert(camera.global_position.x > 0.0, "camera should follow horizontal movement")
	_assert(camera.global_position.x < player.global_position.x, "horizontal camera follow should smooth toward the target")

	player.queue_free()

func _test_drag_lock_keeps_idle_animating() -> void:
	var player := PlayerController.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	player.add_child(sprite)
	get_root().add_child(player)
	await process_frame

	player.on_ground = true
	player.velocity = Vector2.ZERO
	player.set_controls_locked(true)
	player._update_animation(0.01, 0.0)
	var first_frame_x := sprite.region_rect.position.x
	for i in range(4):
		player.set_controls_locked(true)
		player._update_animation(0.1, 0.0)
	_assert(sprite.region_rect.position.y == 0.0, "drag-locked Delver should use the idle animation row")
	_assert(sprite.region_rect.position.x > first_frame_x, "drag-locked Delver should keep idling instead of freezing on one frame")

	player.queue_free()

func _frame_index(sprite: Sprite2D) -> int:
	return int(sprite.region_rect.position.x / PlayerController.SPRITE_FRAME_SIZE.x)
