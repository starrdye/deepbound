extends SceneTree

const DeepboundWorld = preload("res://scripts/World.gd")
const BackgroundCatalog = preload("res://scripts/catalogs/BackgroundCatalog.gd")
const ChunkStore = preload("res://scripts/systems/ChunkStore.gd")
const MainController = preload("res://scripts/Main.gd")
const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")

var failures: Array[String] = []

class TestPlayer:
	extends Node2D
	var inventory := InventorySystem.new()
	var facing := 1

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_generated_caves_have_background_blocks()
	_test_background_placement_is_non_solid_and_independent()
	_test_background_placement_rejects_existing_background_without_consuming()
	_test_mining_targets_foreground_before_background()
	_test_background_blocks_break_after_foreground_is_gone()
	if failures.is_empty():
		print("Deepbound Godot background tests passed.")
		quit(0)
	else:
		print("Deepbound Godot background tests failed: %d" % failures.size())
		quit(1)

func _test_generated_caves_have_background_blocks() -> void:
	var store := ChunkStore.new(133742)
	var background_id := store.get_background_tile(Vector2i(0, 12))
	_assert(not BackgroundCatalog.is_empty(background_id), "generated underground starter cave should have a natural background wall")
	_assert(store.get_tile(Vector2i(0, 12)) == "air", "starter cave foreground should stay air while background fills behind it")
	_assert(store.get_background_tile(Vector2i(0, -2)) == BackgroundCatalog.EMPTY_ID, "surface sky tiles should keep an empty background")

func _test_background_placement_is_non_solid_and_independent() -> void:
	var main := MainController.new()
	var world := DeepboundWorld.new()
	var player := TestPlayer.new()
	player.global_position = Vector2.ZERO
	main.world = world
	main.player = player
	player.inventory.set_hotbar_slot(0, "wooden_background_block", 2)
	main._select_hotbar_index(0)

	var target := Vector2i(2, -1)
	_assert(main._try_place_selected_hotbar_item(world.tile_to_world_center(target)), "background block should place from the selected hotbar item")
	_assert(world.get_background_tile(target) == "wooden_background_block", "background placement should update the background layer")
	_assert(world.get_tile(target) == "air", "background placement should not create foreground terrain")
	_assert(not world.is_solid_tile(target), "background block should not affect collision solidity")
	_assert(int(player.inventory.get_hotbar_slot(0).count) == 1, "successful background placement should consume one item")

	var behind_solid := Vector2i(3, -1)
	world.set_tile(behind_solid, "soft_stone")
	_assert(main._try_place_selected_hotbar_item(world.tile_to_world_center(behind_solid)), "background blocks should place behind a foreground block")
	_assert(world.get_tile(behind_solid) == "soft_stone", "placing a background should preserve foreground terrain")
	_assert(world.get_background_tile(behind_solid) == "wooden_background_block", "background layer should update behind foreground terrain")
	player.free()
	world.free()
	main.free()

func _test_mining_targets_foreground_before_background() -> void:
	var world := DeepboundWorld.new()
	var target := Vector2i(1, -1)
	var origin := Vector2(8, -8)
	world.set_tile(target, "loose_dirt")
	world.set_background_tile(target, "wooden_background_block")

	var foreground_target: Dictionary = world.find_mining_target_info(origin, Vector2.RIGHT)
	_assert(bool(foreground_target.found), "mining target should find a foreground block before the background wall")
	_assert(String(foreground_target.layer) == "foreground", "foreground terrain should be the first mining target when both layers exist")
	_assert(Vector2i(foreground_target.tile) == target, "foreground target should be the tile under the cursor ray")

	world.set_tile(target, "air")
	world.set_background_tile(Vector2i(0, -1), "dirt_background_block")
	var background_target: Dictionary = world.find_mining_target_info(origin, Vector2.RIGHT)
	_assert(bool(background_target.found), "mining target should find background when foreground is gone")
	_assert(String(background_target.layer) == "background", "background wall should become the target after terrain is absent")
	_assert(Vector2i(background_target.tile) == target, "background targeting should prefer the aimed reachable wall rather than the nearest wall behind the player")
	_assert(String(background_target.id) == "wooden_background_block", "background target should identify the wall block")
	world.free()

func _test_background_blocks_break_after_foreground_is_gone() -> void:
	var world := DeepboundWorld.new()
	var inventory := InventorySystem.new()
	var target := Vector2i(1, -1)
	world.set_tile(target, "loose_dirt")
	world.set_background_tile(target, "wooden_background_block")

	var foreground_result: Dictionary = world.mine_at(target, inventory, 1.0, 0.0, "foreground")
	_assert(bool(foreground_result.broke), "foreground terrain should break before background mining starts")
	_assert(world.get_tile(target) == "air", "foreground mining should clear the terrain layer")
	_assert(world.get_background_tile(target) == "wooden_background_block", "foreground mining should leave the background block in place")
	_assert(is_zero_approx(world.store.get_background_damage(target)), "foreground mining should not damage the background in the same tick")

	var partial_background: Dictionary = world.mine_at(target, inventory, 0.25, 0.0, "background")
	_assert(not bool(partial_background.broke), "background mining should accumulate damage before breaking")
	_assert(world.store.get_background_damage(target) > 0.0, "background damage should be tracked separately")

	var broken_background: Dictionary = world.mine_at(target, inventory, 1.0, 0.0, "background")
	_assert(bool(broken_background.broke), "background mining should eventually break the wall block")
	_assert(world.get_background_tile(target) == BackgroundCatalog.EMPTY_ID, "breaking a background block should clear the background layer")
	_assert(inventory.count_item("wooden_background_block") == 1, "broken background block should drop back into inventory")
	world.free()

func _test_background_placement_rejects_existing_background_without_consuming() -> void:
	var main := MainController.new()
	var world := DeepboundWorld.new()
	var player := TestPlayer.new()
	player.global_position = Vector2.ZERO
	main.world = world
	main.player = player
	player.inventory.set_hotbar_slot(0, "stone_background_block", 2)
	main._select_hotbar_index(0)
	var target := Vector2i(2, -1)
	world.set_background_tile(target, "wooden_background_block")
	_assert(not main._try_place_selected_hotbar_item(world.tile_to_world_center(target)), "background placement should reject an occupied background tile")
	_assert(world.get_background_tile(target) == "wooden_background_block", "failed background placement should not overwrite an existing wall")
	_assert(int(player.inventory.get_hotbar_slot(0).count) == 2, "failed background placement should not consume the selected wall item")
	player.free()
	world.free()
	main.free()
