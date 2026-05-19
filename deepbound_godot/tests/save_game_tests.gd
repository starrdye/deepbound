extends SceneTree

const SaveGameSystem = preload("res://scripts/systems/SaveGameSystem.gd")
const DroppedItemController = preload("res://scripts/controllers/DroppedItemController.gd")

const TEST_SAVE_PATH := "user://saves/slot_1_round_trip_test.json"
const TEST_V1_SAVE_PATH := "user://saves/slot_1_v1_compat_test.json"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_remove_file(TEST_SAVE_PATH)
	_remove_file(TEST_V1_SAVE_PATH)
	await _test_save_game_round_trip()
	await _test_frozen_structure_round_trip()
	await _test_schema_v1_payload_loads()
	_remove_file(TEST_SAVE_PATH)
	_remove_file(TEST_V1_SAVE_PATH)
	paused = false
	if failures.is_empty():
		print("Deepbound Godot save game tests passed.")
		quit(0)
	else:
		print("Deepbound Godot save game tests failed: %d" % failures.size())
		quit(1)

func _test_save_game_round_trip() -> void:
	var source = await _instantiate_main_scene()
	var foreground_tile := Vector2i(9, -6)
	var background_tile := Vector2i(10, -6)
	var chest_tile := Vector2i(12, -6)
	source.world.store.seed = 246813
	var generated_chunk: Vector2i = source.world.store.to_chunk_coord(foreground_tile)
	source.world.store.warm_chunk(generated_chunk, true)
	source.world.set_tile(foreground_tile, "soft_stone")
	source.world.store.set_damage(foreground_tile, 0.37)
	source.world.set_background_tile(background_tile, "wooden_background_block")
	source.world.store.set_background_damage(background_tile, 0.24)
	source.world.place_chest(chest_tile)
	var chest = source.world.get_chest_at_tile(chest_tile)
	_assert(chest != null, "test setup should place a restorable chest")
	if chest != null:
		chest.inventory.set_slot(0, "wooden_sword", 1)
		chest.inventory.set_slot(1, "hammer", 1)

	source.player.global_position = Vector2(123.5, 456.25)
	source.player.velocity = Vector2(14.0, -21.0)
	source.player.facing = -1
	source.player.base_max_health = 12
	source.player.equipment_health_delta = 4
	source.player.max_health = 16
	source.player.health = 9
	source.player.inventory.set_slot(0, "copper_nugget", 5)
	source.player.inventory.set_hotbar_slot(3, "stone_chunk", 7)
	source._select_hotbar_index(3)

	var drop := DroppedItemController.new()
	source.drops_node.add_child(drop)
	drop.global_position = Vector2(44.0, 88.0)
	drop.setup("dirt_clod", 3, source.player, source.player.inventory, Vector2(7.0, -8.0), source.world, false)
	drop.pickup_delay = 0.12

	source.world.beacons.clear()
	source.world.beacons.append(Vector2(11.0, 22.0))
	source.world.beacons.append(Vector2(33.0, 44.0))
	source.world.flares.clear()
	source.world.flares.append({"position": Vector2(55.0, 66.0), "life": 7.25})

	var snapshot := SaveGameSystem.snapshot_game_state(source)
	_assert(not snapshot.has("enemies"), "save payload should not persist enemies")
	_assert(int(snapshot.schema_version) == SaveGameSystem.SCHEMA_VERSION, "new save payloads should use the current schema version")
	_assert(Dictionary(snapshot.world.generated_chunks).has("%d,%d" % [generated_chunk.x, generated_chunk.y]), "save payload should freeze generated foreground chunks")
	_assert(Dictionary(snapshot.world.generated_background_chunks).has("%d,%d" % [generated_chunk.x, generated_chunk.y]), "save payload should freeze generated background chunks")
	var write_result := SaveGameSystem.write_save_data(snapshot, TEST_SAVE_PATH)
	_assert(bool(write_result.get("ok", false)), "save helper should write the single-slot JSON payload")
	var read_result := SaveGameSystem.read_save_data(TEST_SAVE_PATH)
	_assert(bool(read_result.get("ok", false)), "save helper should read the JSON payload back")
	source.queue_free()
	await process_frame

	var loaded = await _instantiate_main_scene()
	var apply_result := SaveGameSystem.apply_game_state(loaded, Dictionary(read_result.get("data", {})))
	_assert(bool(apply_result.get("ok", false)), "save helper should apply the loaded payload to the main scene")
	_assert(loaded.world.store.seed == 246813, "loaded world should restore the saved seed")
	_assert(loaded.world.store.has_generated_chunk(generated_chunk), "loaded world should restore generated foreground chunks before live generation")
	_assert(loaded.world.store.has_generated_background_chunk(generated_chunk), "loaded world should restore generated background chunks before live generation")
	_assert(loaded.world.get_tile(foreground_tile) == "soft_stone", "loaded world should restore foreground tile overrides")
	_assert(absf(loaded.world.store.get_damage(foreground_tile) - 0.37) < 0.001, "loaded world should restore foreground damage")
	_assert(loaded.world.get_background_tile(background_tile) == "wooden_background_block", "loaded world should restore background tile overrides")
	_assert(absf(loaded.world.store.get_background_damage(background_tile) - 0.24) < 0.001, "loaded world should restore background damage")
	_assert(loaded.player.global_position.distance_to(Vector2(123.5, 456.25)) < 0.001, "loaded player should restore position")
	_assert(loaded.player.velocity.distance_to(Vector2(14.0, -21.0)) < 0.001, "loaded player should restore velocity")
	_assert(loaded.player.facing == -1 and loaded.player.health == 9 and loaded.player.max_health == 16, "loaded player should restore facing and health")
	_assert(String(loaded.player.inventory.get_slot(0).item) == "copper_nugget" and int(loaded.player.inventory.get_slot(0).count) == 5, "loaded inventory should restore storage slots")
	_assert(String(loaded.player.inventory.get_hotbar_slot(3).item) == "stone_chunk" and int(loaded.player.inventory.get_hotbar_slot(3).count) == 7, "loaded inventory should restore hotbar slots")
	_assert(loaded.selected_hotbar_index == 3, "loaded game should restore selected hotbar index")
	var loaded_chest = loaded.world.get_chest_at_tile(chest_tile)
	_assert(loaded_chest != null, "loaded world should restore placed/generated chest controllers")
	if loaded_chest != null:
		_assert(loaded_chest.inventory.count_item("wooden_sword") == 1 and loaded_chest.inventory.count_item("hammer") == 1, "loaded chest should restore its inventory")
	_assert(loaded.drops_node.get_child_count() == 1, "loaded world should restore dropped item nodes")
	if loaded.drops_node.get_child_count() == 1:
		var loaded_drop = loaded.drops_node.get_child(0)
		_assert(String(loaded_drop.item_id) == "dirt_clod" and int(loaded_drop.count) == 3, "loaded drop should restore item stack")
		_assert(loaded_drop.global_position.distance_to(Vector2(44.0, 88.0)) < 0.001, "loaded drop should restore position")
	_assert(loaded.world.beacons.size() == 2 and loaded.world.beacons[1].distance_to(Vector2(33.0, 44.0)) < 0.001, "loaded world should restore beacons")
	_assert(loaded.world.flares.size() == 1 and absf(float(loaded.world.flares[0].life) - 7.25) < 0.001, "loaded world should restore flares")
	loaded.queue_free()
	await process_frame

func _test_frozen_structure_round_trip() -> void:
	var source = await _instantiate_main_scene()
	var frozen_chunk := Vector2i(240, 6)
	source.world.store.warm_chunk(frozen_chunk, true)
	var frozen_structure := _custom_frozen_structure(frozen_chunk)
	var snapshot := SaveGameSystem.snapshot_game_state(source)
	snapshot.world.frozen_structures = [frozen_structure]
	var write_result := SaveGameSystem.write_save_data(snapshot, TEST_SAVE_PATH)
	_assert(bool(write_result.get("ok", false)), "save helper should write a payload with frozen structures")
	var read_result := SaveGameSystem.read_save_data(TEST_SAVE_PATH)
	_assert(bool(read_result.get("ok", false)), "save helper should read a payload with frozen structures")
	source.queue_free()
	await process_frame

	var loaded = await _instantiate_main_scene()
	var apply_result := SaveGameSystem.apply_game_state(loaded, Dictionary(read_result.get("data", {})))
	_assert(bool(apply_result.get("ok", false)), "save helper should apply frozen structures")
	var structures: Array[Dictionary] = loaded.world.get_structures_overlapping_chunk(frozen_chunk)
	_assert(structures.size() == 1 and String(structures[0].id) == "frozen_structure_test", "frozen chunks should use saved structure records instead of live template records")
	var marker_tile := frozen_chunk * 32 + Vector2i(4, 4)
	var spawns: Array[Dictionary] = loaded.world.get_structure_spawns_near(marker_tile, 2)
	_assert(spawns.size() == 1 and String(spawns[0].enemy_id) == "cave_skitter", "frozen structure spawns should survive load")
	var lights: Array[Dictionary] = loaded.world.get_structure_lights_near(marker_tile, 2)
	_assert(lights.size() == 1 and String(lights[0].id) == "frozen_light", "frozen structure lights should survive load")
	var containers: Array[Dictionary] = loaded.world.get_structure_containers_near(marker_tile, 2)
	_assert(containers.size() == 1 and String(containers[0].id) == "frozen_container", "frozen structure containers should survive load")
	var unvisited_chunk := frozen_chunk + Vector2i(20, 0)
	_assert(not loaded.world.store.has_generated_chunk(unvisited_chunk), "unvisited chunks should not be frozen by the save payload")
	loaded.world.get_tile(unvisited_chunk * 32)
	_assert(loaded.world.store.has_generated_chunk(unvisited_chunk), "unvisited chunks should still generate from the current world generator")
	loaded.queue_free()
	await process_frame

func _test_schema_v1_payload_loads() -> void:
	var source = await _instantiate_main_scene()
	var snapshot := SaveGameSystem.snapshot_game_state(source)
	snapshot.schema_version = 1
	snapshot.world.erase("generated_chunks")
	snapshot.world.erase("generated_background_chunks")
	snapshot.world.erase("frozen_structures")
	_write_json(TEST_V1_SAVE_PATH, snapshot)
	var read_result := SaveGameSystem.read_save_data(TEST_V1_SAVE_PATH)
	_assert(bool(read_result.get("ok", false)), "schema v1 save payloads should still read")
	_assert(int(Dictionary(read_result.get("data", {})).schema_version) == SaveGameSystem.SCHEMA_VERSION, "schema v1 payloads should normalize to the current schema")
	source.queue_free()
	await process_frame

	var loaded = await _instantiate_main_scene()
	var apply_result := SaveGameSystem.apply_game_state(loaded, Dictionary(read_result.get("data", {})))
	_assert(bool(apply_result.get("ok", false)), "schema v1 save payloads should still apply")
	loaded.queue_free()
	await process_frame

func _instantiate_main_scene():
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main = scene.instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	return main

func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _write_json(path: String, payload: Dictionary) -> void:
	var parent := ProjectSettings.globalize_path(path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(parent)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t", true))
		file.store_string("\n")

func _custom_frozen_structure(chunk: Vector2i) -> Dictionary:
	var tile := chunk * 32 + Vector2i(4, 4)
	return {
		"id": "frozen_structure_test",
		"type": "frozen_test",
		"template_id": "frozen_template_test",
		"source_template_id": "frozen_template_test",
		"region": {"x": chunk.x, "y": chunk.y},
		"rect": {"x": tile.x - 1, "y": tile.y - 1, "w": 4, "h": 4},
		"tiles": [{"x": tile.x, "y": tile.y, "id": "soft_stone"}],
		"backgrounds": [{"x": tile.x, "y": tile.y, "id": "stone_background_block"}],
		"props": [{"id": "frozen_prop", "kind": "decoration", "tile": {"x": tile.x, "y": tile.y}, "template_id": "frozen_template_test", "size": [1, 1], "offset": [0, 0], "layer": "foreground", "alpha": 1.0}],
		"spawns": [{"enemy_id": "cave_skitter", "tile": {"x": tile.x, "y": tile.y}, "template_id": "frozen_template_test"}],
		"lights": [{"id": "frozen_light", "tile": {"x": tile.x, "y": tile.y}, "radius_tiles": 6.0, "intensity": 0.72, "template_id": "frozen_template_test"}],
		"containers": [{"id": "frozen_container", "tile": {"x": tile.x, "y": tile.y}, "template_id": "frozen_template_test"}],
	}
