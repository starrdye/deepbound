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

class DrawCountingWorld:
	extends DeepboundWorld
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		super._draw()

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_generated_caves_have_background_blocks()
	_test_block_interaction_reach_is_tripled()
	_test_background_placement_is_non_solid_and_independent()
	_test_background_placement_rejects_existing_background_without_consuming()
	_test_mining_targets_foreground_before_background()
	_test_background_blocks_break_after_foreground_is_gone()
	await _test_mining_redraws_only_on_damage_stage_changes()
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

func _test_block_interaction_reach_is_tripled() -> void:
	var world := DeepboundWorld.new()
	var origin := Vector2(8, -8)
	var far_target := Vector2i(4, -1)
	_clear_ray_corridor(world, -1, 0, 5)
	world.set_tile(far_target, "soft_stone")
	var target: Dictionary = world.find_mining_target_info(origin, Vector2.RIGHT)
	_assert(bool(target.found), "block interaction should reach three times farther than the old starter range")
	_assert(Vector2i(target.tile) == far_target, "tripled block interaction range should find a four-tile-away block")

	world.set_tile(far_target, "air")
	world.set_background_tile(far_target, "wooden_background_block")
	var ignored_background: Dictionary = world.find_mining_target_info(origin, Vector2.RIGHT)
	_assert(not bool(ignored_background.found), "far background walls should still be ignored without hammer selected")
	var hammered_background: Dictionary = world.find_mining_target_info(origin, Vector2.RIGHT, DeepboundWorld.BLOCK_INTERACTION_REACH_TILES, true)
	_assert(bool(hammered_background.found), "hammer-selected background walls should use the tripled block interaction range")
	_assert(Vector2i(hammered_background.tile) == far_target, "hammer targeting should find the far background wall")
	world.free()

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
	world.set_background_tile(behind_solid, BackgroundCatalog.EMPTY_ID)
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
	_clear_ray_corridor(world, -1, 0, 5)
	world.set_tile(target, "loose_dirt")
	world.set_background_tile(target, "wooden_background_block")

	var foreground_target: Dictionary = world.find_mining_target_info(origin, Vector2.RIGHT)
	_assert(bool(foreground_target.found), "mining target should find a foreground block before the background wall")
	_assert(String(foreground_target.layer) == "foreground", "foreground terrain should be the first mining target when both layers exist")
	_assert(Vector2i(foreground_target.tile) == target, "foreground target should be the tile under the cursor ray")

	world.set_tile(target, "air")
	world.set_background_tile(Vector2i(0, -1), "dirt_background_block")
	var ignored_background: Dictionary = world.find_mining_target_info(origin, Vector2.RIGHT)
	_assert(not bool(ignored_background.found), "background walls should be ignored when no hammer is selected")
	var background_target: Dictionary = world.find_mining_target_info(origin, Vector2.RIGHT, 1.45, true)
	_assert(bool(background_target.found), "mining target should find background when foreground is gone")
	_assert(String(background_target.layer) == "background", "hammer-selected background wall should become the target after terrain is absent")
	_assert(Vector2i(background_target.tile) == target, "background targeting should prefer the aimed reachable wall rather than the nearest wall behind the player")
	_assert(String(background_target.id) == "wooden_background_block", "background target should identify the wall block")
	world.free()

func _clear_ray_corridor(world: DeepboundWorld, y: int, min_x: int, max_x: int) -> void:
	for x in range(min_x, max_x + 1):
		var tile := Vector2i(x, y)
		world.set_tile(tile, "air")
		world.set_background_tile(tile, BackgroundCatalog.EMPTY_ID)

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

	var blocked_background: Dictionary = world.mine_at(target, inventory, 1.0, 0.0, "background")
	_assert(not bool(blocked_background.broke) and String(blocked_background.get("blocked", "")) == "missing_hammer", "background mining should require a selected hammer")
	_assert(is_zero_approx(world.store.get_background_damage(target)), "missing hammer should not damage background walls")

	var partial_background: Dictionary = world.mine_at(target, inventory, 0.25, 0.0, "background", "hammer")
	_assert(not bool(partial_background.broke), "background mining should accumulate damage before breaking")
	_assert(world.store.get_background_damage(target) > 0.0, "background damage should be tracked separately")

	var broken_background: Dictionary = world.mine_at(target, inventory, 1.0, 0.0, "background", "hammer")
	_assert(bool(broken_background.broke), "background mining should eventually break the wall block")
	_assert(world.get_background_tile(target) == BackgroundCatalog.EMPTY_ID, "breaking a background block should clear the background layer")
	_assert(inventory.count_item("wooden_background_block") == 1, "broken background block should drop back into inventory")
	world.free()

func _test_mining_redraws_only_on_damage_stage_changes() -> void:
	var world := DrawCountingWorld.new()
	var inventory := InventorySystem.new()
	var target := Vector2i(1, 1)
	get_root().add_child(world)
	world.enable_debug_perf_counters(true)
	world.set_tile(target, "soft_stone")
	await process_frame
	world.draw_count = 0
	world.reset_debug_perf_counters()

	var first_result: Dictionary = world.mine_at(target, inventory, 0.01)
	_assert(int(first_result.stage) == 1, "first partial mining tick should enter break overlay stage one")
	await process_frame
	_assert(world.get_debug_perf_counter("chunk_foreground_invalidated") == 1, "first visible damage stage should invalidate one foreground chunk")

	var same_stage_result: Dictionary = world.mine_at(target, inventory, 0.01)
	_assert(int(same_stage_result.stage) == 1, "second tiny mining tick should remain in the same break stage")
	await process_frame
	_assert(world.get_debug_perf_counter("chunk_foreground_invalidated") == 1, "same-stage mining damage should not invalidate the chunk again")

	var next_stage_result: Dictionary = world.mine_at(target, inventory, 0.42)
	_assert(int(next_stage_result.stage) == 2, "larger mining tick should advance the visible break stage")
	await process_frame
	_assert(world.get_debug_perf_counter("chunk_foreground_invalidated") == 2, "new visible damage stage should invalidate the foreground chunk again")
	world.queue_free()

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
