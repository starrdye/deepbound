extends SceneTree

const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")
const PlayerController = preload("res://scripts/controllers/PlayerController.gd")

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
	_test_player_animation_rows()
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

func _test_tile_textures_remain_native_size() -> void:
	var dirt := TextureFactory.make_tile_texture("loose_dirt", {"color": Color8(122, 75, 46), "highlight": Color8(168, 111, 60)})
	var resin := TextureFactory.make_tile_texture("hardened_resin", {"color": Color8(143, 95, 34), "highlight": Color8(241, 184, 91)})
	_assert(dirt.get_width() == 16 and dirt.get_height() == 16, "dirt texture should stay 16x16")
	_assert(resin.get_width() == 16 and resin.get_height() == 16, "resin texture should stay 16x16")

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
	_assert(sprite.region_rect.position.x == 64.0, "rising jump should use the 8-frame rise pose")

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

	player.start_weapon_swing(Vector2.RIGHT)
	player._update_animation(0.05, 0.0)
	_assert(sprite.region_rect.position.y == 192.0, "weapon strike should use sprite sheet row 6")
	player._update_animation(0.15, 0.0)
	_assert(sprite.region_rect.position.y == 192.0, "weapon strike animation should stay active during the swing window")

	player.queue_free()
