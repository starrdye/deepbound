extends RefCounted
class_name SaveGameSystem

const ChunkStore             = preload("res://scripts/systems/ChunkStore.gd")
const MiningSystem           = preload("res://scripts/systems/MiningSystem.gd")
const ChestController        = preload("res://scripts/controllers/ChestController.gd")
const DroppedItemController  = preload("res://scripts/controllers/DroppedItemController.gd")
const BossEncounterSystem    = preload("res://scripts/systems/BossEncounterSystem.gd")

const SCHEMA_VERSION := 3
const SAVE_PATH := "user://saves/slot_1.json"
const PENDING_SAVE_META_KEY := "deepbound_pending_save_data"

static func has_save(path := SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)

static func save_game(main, path := SAVE_PATH) -> Dictionary:
	return write_save_data(snapshot_game_state(main), path)

static func load_game(path := SAVE_PATH) -> Dictionary:
	return read_save_data(path)

static func write_save_data(data: Dictionary, path := SAVE_PATH) -> Dictionary:
	var normalized := normalize_save_data(data)
	var validation_error := _validate_save_data(normalized)
	if validation_error != "":
		return {"ok": false, "path": path, "error": validation_error, "data": {}}
	_ensure_parent_dir(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "path": path, "error": "Unable to open save file for writing.", "data": {}}
	file.store_string(JSON.stringify(normalized, "\t", true))
	file.store_string("\n")
	return {"ok": true, "path": path, "error": "", "data": normalized}

static func read_save_data(path := SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "path": path, "error": "No save found.", "data": {}}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {"ok": false, "path": path, "error": "Save file is not valid JSON.", "data": {}}
	var normalized := normalize_save_data(Dictionary(parsed))
	var validation_error := _validate_save_data(normalized)
	if validation_error != "":
		return {"ok": false, "path": path, "error": validation_error, "data": {}}
	return {"ok": true, "path": path, "error": "", "data": normalized}

static func snapshot_game_state(main) -> Dictionary:
	var world = main.get("world")
	var player = main.get("player")
	return normalize_save_data({
		"schema_version": SCHEMA_VERSION,
		"world": _snapshot_world(world),
		"player": _snapshot_player(player),
		"inventory": _inventory_to_data(player.inventory if player != null and player.get("inventory") != null else null),
		"selected_hotbar_index": int(main.get("selected_hotbar_index")),
		"containers": _snapshot_containers(world),
		"drops": _snapshot_drops(main.get("drops_node")),
		"beacons": _vec2_array_to_data(world.beacons if world != null and world.get("beacons") != null else []),
		"flares": _flares_to_data(world.flares if world != null and world.get("flares") != null else []),
		"defeated_bosses": BossEncounterSystem.defeated_bosses.duplicate(),
		"time": _snapshot_time(main),
	})

static func apply_game_state(main, data: Dictionary) -> Dictionary:
	var normalized := normalize_save_data(data)
	var validation_error := _validate_save_data(normalized)
	if validation_error != "":
		return {"ok": false, "error": validation_error}
	var world = main.get("world")
	var player = main.get("player")
	if world == null or player == null:
		return {"ok": false, "error": "Main scene is missing world or player nodes."}

	if main.has_method("_close_active_container"):
		main._close_active_container()
	var hud = main.get("hud")
	if hud != null and hud.has_method("close_inventory"):
		hud.close_inventory()
	if main.get("held_world_drop") != null and main.has_method("_clear_world_drop_interaction"):
		main._clear_world_drop_interaction()

	var world_data: Dictionary = normalized.world
	if world.has_method("reset_for_loaded_state"):
		world.reset_for_loaded_state(int(world_data.seed))
	else:
		world.store = ChunkStore.new(int(world_data.seed))
		world.mining = MiningSystem.new()
		world.container_blocks.clear()
		world.beacons.clear()
		world.flares.clear()
	_apply_world_store_state(world, world_data)

	var props_node = main.get("props_node")
	if props_node != null:
		_clear_children(props_node)
	world.container_parent = props_node
	_restore_containers(world, props_node, normalized.containers)

	var drops_node = main.get("drops_node")
	if drops_node != null:
		_clear_children(drops_node)
	_restore_drops(drops_node, player, player.inventory, world, normalized.drops)

	world.beacons = _vec2_array_from_data(normalized.beacons)
	world.flares = _flares_from_data(normalized.flares)

	_apply_player_state(player, normalized.player)
	_apply_inventory_data(player.inventory, normalized.inventory)
	if main.has_method("_select_hotbar_index"):
		main._select_hotbar_index(int(normalized.selected_hotbar_index))
	else:
		main.selected_hotbar_index = int(normalized.selected_hotbar_index)

	if world.has_method("refresh_after_loaded_state"):
		world.refresh_after_loaded_state()
	elif world.has_method("refresh_visible_chunk_window"):
		world.refresh_visible_chunk_window(true)

	# Restore defeated boss flags.
	var saved_bosses = normalized.get("defeated_bosses", {})
	if saved_bosses is Dictionary:
		BossEncounterSystem.defeated_bosses = Dictionary(saved_bosses)

	if main.has_method("_refresh_encounters_after_load"):
		main._refresh_encounters_after_load()
	if main.has_method("_sync_selected_hotbar_item"):
		main._sync_selected_hotbar_item()
	if main.has_method("_update_hud"):
		main._update_hud()

	# Restore TimeManager state (autoload, accessed via the scene tree).
	_restore_time(main, normalized.get("time", {}))

	return {"ok": true, "error": ""}

static func stash_pending_save(root: Node, data: Dictionary) -> void:
	if root == null:
		return
	root.set_meta(PENDING_SAVE_META_KEY, normalize_save_data(data))

static func consume_pending_save(root: Node) -> Dictionary:
	if root == null or not root.has_meta(PENDING_SAVE_META_KEY):
		return {}
	var data = root.get_meta(PENDING_SAVE_META_KEY)
	root.remove_meta(PENDING_SAVE_META_KEY)
	if data is Dictionary:
		return normalize_save_data(Dictionary(data))
	return {}

static func clear_pending_save(root: Node) -> void:
	if root != null and root.has_meta(PENDING_SAVE_META_KEY):
		root.remove_meta(PENDING_SAVE_META_KEY)

static func normalize_save_data(data: Dictionary) -> Dictionary:
	var world_data: Dictionary = Dictionary(data.get("world", {}))
	var player_data: Dictionary = Dictionary(data.get("player", {}))
	var input_schema_version := int(data.get("schema_version", SCHEMA_VERSION))
	return {
		"schema_version": SCHEMA_VERSION if input_schema_version == 1 else input_schema_version,
		"world": {
			"seed": int(world_data.get("seed", 133742)),
			"foreground_overrides": _tile_entries_from_data(world_data.get("foreground_overrides", []), "id"),
			"background_overrides": _tile_entries_from_data(world_data.get("background_overrides", []), "id"),
			"tile_damage": _tile_entries_from_data(world_data.get("tile_damage", []), "value"),
			"background_damage": _tile_entries_from_data(world_data.get("background_damage", []), "value"),
			"generated_chunks": _chunk_data_from_data(world_data.get("generated_chunks", {})),
			"generated_background_chunks": _chunk_data_from_data(world_data.get("generated_background_chunks", {})),
			"frozen_structures": _structures_to_data(world_data.get("frozen_structures", [])),
		},
		"player": {
			"position": _vec2_to_data(_data_to_vec2(player_data.get("position", Vector2(-128, 208)))),
			"velocity": _vec2_to_data(_data_to_vec2(player_data.get("velocity", Vector2.ZERO))),
			"facing": int(player_data.get("facing", 1)),
			"health": int(player_data.get("health", 10)),
			"max_health": int(player_data.get("max_health", 10)),
			"base_max_health": int(player_data.get("base_max_health", 10)),
			"equipment_health_delta": int(player_data.get("equipment_health_delta", 0)),
		},
		"inventory": _inventory_data_from_data(data.get("inventory", {})),
		"selected_hotbar_index": int(data.get("selected_hotbar_index", 0)),
		"containers": _containers_from_data(data.get("containers", [])),
		"drops": _drops_from_data(data.get("drops", [])),
		"beacons": _vec2_array_from_data(data.get("beacons", [])).map(func(v): return _vec2_to_data(v)),
		"flares": _flares_to_data(_flares_from_data(data.get("flares", []))),
		"defeated_bosses": _defeated_bosses_from_data(data.get("defeated_bosses", {})),
		"time": _time_from_data(data.get("time", {})),
	}

static func _snapshot_world(world) -> Dictionary:
	if world == null or world.get("store") == null:
		return {"seed": 133742, "foreground_overrides": [], "background_overrides": [], "tile_damage": [], "background_damage": [], "generated_chunks": {}, "generated_background_chunks": {}, "frozen_structures": []}
	var store = world.store
	return {
		"seed": int(store.seed),
		"foreground_overrides": _tile_dictionary_to_entries(store.overrides, "id"),
		"background_overrides": _tile_dictionary_to_entries(store.background_overrides, "id"),
		"tile_damage": _tile_dictionary_to_entries(store.damage, "value"),
		"background_damage": _tile_dictionary_to_entries(store.background_damage, "value"),
		"generated_chunks": store.export_generated_chunks() if store.has_method("export_generated_chunks") else {},
		"generated_background_chunks": store.export_generated_background_chunks() if store.has_method("export_generated_background_chunks") else {},
		"frozen_structures": _structures_to_data(world.snapshot_structures_for_generated_chunks() if world.has_method("snapshot_structures_for_generated_chunks") else []),
		"liquids": store.export_liquids() if store.has_method("export_liquids") else [],
	}

static func _snapshot_player(player) -> Dictionary:
	if player == null:
		return {}
	return {
		"position": _vec2_to_data(player.global_position),
		"velocity": _vec2_to_data(player.velocity if player.get("velocity") != null else Vector2.ZERO),
		"facing": int(player.get("facing")),
		"health": int(player.get("health")),
		"max_health": int(player.get("max_health")),
		"base_max_health": int(player.get("base_max_health")),
		"equipment_health_delta": int(player.get("equipment_health_delta")),
	}

static func _snapshot_containers(world) -> Array[Dictionary]:
	var containers: Array[Dictionary] = []
	if world == null or world.get("container_blocks") == null:
		return containers
	for tile in _sorted_vector2i_keys(world.container_blocks):
		var chest = world.container_blocks[tile]
		if chest == null or not is_instance_valid(chest):
			continue
		containers.append({
			"tile": _vec2i_to_data(tile),
			"name": String(chest.name),
			"seed_default_contents": bool(chest.get("seed_default_contents")),
			"inventory": _inventory_to_data(chest.inventory if chest.get("inventory") != null else null),
		})
	return containers

static func _snapshot_drops(drops_node) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	if drops_node == null:
		return drops
	for child in drops_node.get_children():
		if child == null or not is_instance_valid(child):
			continue
		var item_id := String(child.get("item_id"))
		var count := int(child.get("count"))
		if item_id == "" or count <= 0:
			continue
		drops.append({
			"item": item_id,
			"count": count,
			"position": _vec2_to_data(child.global_position),
			"velocity": _vec2_to_data(child.velocity if child.get("velocity") != null else Vector2.ZERO),
			"pickup_delay": float(child.get("pickup_delay")),
			"auto_pickup_enabled": bool(child.get("auto_pickup_enabled")),
		})
	return drops

static func _apply_world_store_state(world, world_data: Dictionary) -> void:
	if world.store.has_method("import_generated_chunks"):
		world.store.import_generated_chunks(Dictionary(world_data.get("generated_chunks", {})))
	if world.store.has_method("import_generated_background_chunks"):
		world.store.import_generated_background_chunks(Dictionary(world_data.get("generated_background_chunks", {})))
	world.store.overrides = _tile_entries_to_dictionary(world_data.foreground_overrides, "id", false)
	world.store.background_overrides = _tile_entries_to_dictionary(world_data.background_overrides, "id", false)
	world.store.damage = _tile_entries_to_dictionary(world_data.tile_damage, "value", true)
	world.store.background_damage = _tile_entries_to_dictionary(world_data.background_damage, "value", true)
	if world.has_method("set_frozen_world_state"):
		world.set_frozen_world_state(_structures_from_data(world_data.get("frozen_structures", [])), world.store.get_generated_chunk_coords(true))
	if world.store.has_method("import_liquids"):
		world.store.import_liquids(world_data.get("liquids", []))
		if world.has_method("_queue_liquid_redraw"):
			world._queue_liquid_redraw()

static func _restore_containers(world, props_node, containers: Array) -> void:
	if props_node == null:
		return
	for raw_container in containers:
		var container: Dictionary = Dictionary(raw_container)
		var tile := _data_to_vec2i(container.get("tile", Vector2i.ZERO))
		if world.get_tile(tile) != "chest_block":
			world.set_tile(tile, "chest_block")
		var chest := ChestController.new()
		chest.name = String(container.get("name", "Chest_%d_%d" % [tile.x, tile.y]))
		chest.anchor_tile = tile
		chest.seed_default_contents = false
		world.container_blocks[tile] = chest
		props_node.add_child(chest)
		chest.global_position = world.tile_to_world_center(tile)
		_apply_inventory_data(chest.inventory, Dictionary(container.get("inventory", {})))

static func _restore_drops(drops_node, player, inventory, world, drops: Array) -> void:
	for raw_drop in drops:
		var drop_data: Dictionary = Dictionary(raw_drop)
		var item_id := String(drop_data.get("item", ""))
		var count := int(drop_data.get("count", 0))
		if item_id == "" or count <= 0:
			continue
		var drop := DroppedItemController.new()
		drops_node.add_child(drop)
		drop.global_position = _data_to_vec2(drop_data.get("position", Vector2.ZERO))
		drop.setup(item_id, count, player, inventory, _data_to_vec2(drop_data.get("velocity", Vector2.ZERO)), world, bool(drop_data.get("auto_pickup_enabled", false)))
		drop.pickup_delay = float(drop_data.get("pickup_delay", 0.55))

static func _apply_player_state(player, player_data: Dictionary) -> void:
	if player.has_method("cancel_transient_input"):
		player.cancel_transient_input()
	player.global_position = _data_to_vec2(player_data.position)
	if player.get("velocity") != null:
		player.velocity = _data_to_vec2(player_data.velocity)
	if player.get("base_max_health") != null:
		player.base_max_health = int(player_data.base_max_health)
	if player.get("equipment_health_delta") != null:
		player.equipment_health_delta = int(player_data.equipment_health_delta)
	if player.get("max_health") != null:
		player.max_health = int(player_data.max_health)
	if player.get("health") != null:
		player.health = clampi(int(player_data.health), 0, maxi(1, int(player_data.max_health)))
	if player.get("facing") != null:
		player.facing = -1 if int(player_data.facing) < 0 else 1

static func _inventory_to_data(inventory) -> Dictionary:
	if inventory == null:
		return {"slots": [], "hotbar": []}
	return {
		"slots": _stack_array_to_data(inventory.slots),
		"hotbar": _stack_array_to_data(inventory.hotbar),
	}

static func _apply_inventory_data(inventory, data: Dictionary) -> void:
	if inventory == null:
		return
	for index in range(inventory.slots.size()):
		inventory.clear_slot(index)
	var slots: Array = data.get("slots", [])
	for index in range(mini(slots.size(), inventory.slots.size())):
		var stack: Dictionary = Dictionary(slots[index])
		var s_mod := String(stack.get("modifier", ""))
		if s_mod != "" and inventory.has_method("restore_slot"):
			inventory.restore_slot(index, stack)
		else:
			inventory.set_slot(index, String(stack.get("item", "")), int(stack.get("count", 0)), int(stack.get("stack_cap", inventory.stack_cap)))
	for index in range(inventory.hotbar.size()):
		inventory.clear_hotbar_slot(index)
	var hotbar: Array = data.get("hotbar", [])
	for index in range(mini(hotbar.size(), inventory.hotbar.size())):
		var stack: Dictionary = Dictionary(hotbar[index])
		var s_mod := String(stack.get("modifier", ""))
		if s_mod != "" and inventory.has_method("restore_hotbar_slot"):
			inventory.restore_hotbar_slot(index, stack)
		else:
			inventory.set_hotbar_slot(index, String(stack.get("item", "")), int(stack.get("count", 0)), int(stack.get("stack_cap", inventory.stack_cap)))

static func _stack_array_to_data(stacks: Array) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for stack in stacks:
		results.append(_stack_to_data(Dictionary(stack)))
	return results

static func _stack_to_data(stack: Dictionary) -> Dictionary:
	var item_id := String(stack.get("item", ""))
	var count := int(stack.get("count", 0))
	var result := {
		"item": item_id if count > 0 else "",
		"count": maxi(0, count),
		"stack_cap": maxi(1, int(stack.get("stack_cap", 99))),
	}
	var mod_id := String(stack.get("modifier", ""))
	if mod_id != "" and count > 0:
		result["modifier"] = mod_id
	return result

static func _inventory_data_from_data(data) -> Dictionary:
	var source := Dictionary(data) if data is Dictionary else {}
	return {
		"slots": _stack_array_data_from_data(source.get("slots", [])),
		"hotbar": _stack_array_data_from_data(source.get("hotbar", [])),
	}

static func _stack_array_data_from_data(data) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not (data is Array):
		return results
	for raw_stack in data:
		results.append(_stack_to_data(Dictionary(raw_stack) if raw_stack is Dictionary else {}))
	return results

static func _containers_from_data(data) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not (data is Array):
		return results
	for raw_container in data:
		if not (raw_container is Dictionary):
			continue
		var container := Dictionary(raw_container)
		results.append({
			"tile": _vec2i_to_data(_data_to_vec2i(container.get("tile", Vector2i.ZERO))),
			"name": String(container.get("name", "")),
			"seed_default_contents": bool(container.get("seed_default_contents", false)),
			"inventory": _inventory_data_from_data(container.get("inventory", {})),
		})
	return results

static func _drops_from_data(data) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not (data is Array):
		return results
	for raw_drop in data:
		if not (raw_drop is Dictionary):
			continue
		var drop := Dictionary(raw_drop)
		var item_id := String(drop.get("item", ""))
		var count := int(drop.get("count", 0))
		if item_id == "" or count <= 0:
			continue
		results.append({
			"item": item_id,
			"count": count,
			"position": _vec2_to_data(_data_to_vec2(drop.get("position", Vector2.ZERO))),
			"velocity": _vec2_to_data(_data_to_vec2(drop.get("velocity", Vector2.ZERO))),
			"pickup_delay": float(drop.get("pickup_delay", 0.55)),
			"auto_pickup_enabled": bool(drop.get("auto_pickup_enabled", false)),
		})
	return results

static func _flares_to_data(flares: Array) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for flare in flares:
		var data := Dictionary(flare)
		results.append({
			"position": _vec2_to_data(_data_to_vec2(data.get("position", Vector2.ZERO))),
			"life": maxf(0.0, float(data.get("life", 0.0))),
		})
	return results

static func _flares_from_data(data) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not (data is Array):
		return results
	for raw_flare in data:
		if not (raw_flare is Dictionary):
			continue
		var flare := Dictionary(raw_flare)
		results.append({
			"position": _data_to_vec2(flare.get("position", Vector2.ZERO)),
			"life": maxf(0.0, float(flare.get("life", 0.0))),
		})
	return results

static func _chunk_data_from_data(data) -> Dictionary:
	var results := {}
	if data is Dictionary:
		var source: Dictionary = Dictionary(data)
		var keys := source.keys()
		keys.sort()
		for raw_key in keys:
			var key := _chunk_key_from_data(raw_key)
			var tiles := _chunk_tiles_from_data(source[raw_key])
			if key != "" and tiles.size() == ChunkStore.CHUNK_SIZE * ChunkStore.CHUNK_SIZE:
				results[key] = tiles
	elif data is Array:
		for raw_entry in data:
			if not (raw_entry is Dictionary):
				continue
			var entry: Dictionary = Dictionary(raw_entry)
			var key := _chunk_key_from_data(entry)
			var tiles := _chunk_tiles_from_data(entry.get("tiles", []))
			if key != "" and tiles.size() == ChunkStore.CHUNK_SIZE * ChunkStore.CHUNK_SIZE:
				results[key] = tiles
	return results

static func _chunk_tiles_from_data(data) -> Array[String]:
	var tiles: Array[String] = []
	if not (data is Array):
		return tiles
	var source: Array = data
	if source.size() != ChunkStore.CHUNK_SIZE * ChunkStore.CHUNK_SIZE:
		return tiles
	for tile_id in source:
		tiles.append(String(tile_id))
	return tiles

static func _chunk_key_from_data(data) -> String:
	if data is String:
		var text := String(data)
		var parts := text.split(",", false)
		if parts.size() >= 2:
			return "%d,%d" % [int(parts[0]), int(parts[1])]
		return ""
	var chunk := _data_to_vec2i(data)
	return "%d,%d" % [chunk.x, chunk.y]

static func _structures_to_data(data) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not (data is Array):
		return results
	for raw_structure in data:
		if not (raw_structure is Dictionary):
			continue
		var structure_data := _structure_to_data(Dictionary(raw_structure))
		if String(structure_data.get("id", "")) != "":
			results.append(structure_data)
	results.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.get("id", "")) < String(b.get("id", "")))
	return results

static func _structure_to_data(structure: Dictionary) -> Dictionary:
	var rect := _data_to_rect2i(structure.get("rect", Rect2i(Vector2i.ZERO, Vector2i.ZERO)))
	return {
		"id": String(structure.get("id", "")),
		"type": String(structure.get("type", "")),
		"template_id": String(structure.get("template_id", "")),
		"source_template_id": String(structure.get("source_template_id", structure.get("template_id", ""))),
		"region": _vec2i_to_data(_data_to_vec2i(structure.get("region", Vector2i.ZERO))),
		"rect": _rect2i_to_data(rect),
		"tiles": _structure_tile_layer_to_entries(structure.get("tiles", {})),
		"backgrounds": _structure_tile_layer_to_entries(structure.get("backgrounds", {})),
		"props": _structure_props_to_data(structure.get("props", [])),
		"spawns": _structure_spawns_to_data(structure.get("spawns", [])),
		"lights": _structure_lights_to_data(structure.get("lights", [])),
		"containers": _structure_containers_to_data(structure.get("containers", [])),
	}

static func _structures_from_data(data) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for structure_data in _structures_to_data(data):
		results.append({
			"id": String(structure_data.get("id", "")),
			"type": String(structure_data.get("type", "")),
			"template_id": String(structure_data.get("template_id", "")),
			"source_template_id": String(structure_data.get("source_template_id", structure_data.get("template_id", ""))),
			"region": _data_to_vec2i(structure_data.get("region", Vector2i.ZERO)),
			"rect": _data_to_rect2i(structure_data.get("rect", Rect2i(Vector2i.ZERO, Vector2i.ZERO))),
			"tiles": _tile_entries_to_dictionary(structure_data.get("tiles", []), "id", false),
			"backgrounds": _tile_entries_to_dictionary(structure_data.get("backgrounds", []), "id", false),
			"props": _structure_props_from_data(structure_data.get("props", [])),
			"spawns": _structure_spawns_from_data(structure_data.get("spawns", [])),
			"lights": _structure_lights_from_data(structure_data.get("lights", [])),
			"containers": _structure_containers_from_data(structure_data.get("containers", [])),
		})
	return results

static func _structure_tile_layer_to_entries(data) -> Array[Dictionary]:
	if data is Dictionary:
		return _tile_dictionary_to_entries(Dictionary(data), "id")
	return _tile_entries_from_data(data, "id")

static func _structure_props_to_data(data) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not (data is Array):
		return results
	for raw_prop in data:
		if not (raw_prop is Dictionary):
			continue
		var prop: Dictionary = Dictionary(raw_prop)
		results.append({
			"id": String(prop.get("id", "")),
			"kind": String(prop.get("kind", "")),
			"tile": _vec2i_to_data(_data_to_vec2i(prop.get("tile", prop))),
			"template_id": String(prop.get("template_id", "")),
			"size": _vec2i_to_array(_data_to_vec2i(prop.get("size", [1, 1]))),
			"offset": _vec2i_to_array(_data_to_vec2i(prop.get("offset", [0, 0]))),
			"layer": String(prop.get("layer", prop.get("draw_layer", "foreground"))),
			"alpha": float(prop.get("alpha", 1.0)),
		})
	_sort_markers_by_tile(results)
	return results

static func _structure_props_from_data(data) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for prop_data in _structure_props_to_data(data):
		results.append({
			"id": String(prop_data.get("id", "")),
			"kind": String(prop_data.get("kind", "")),
			"tile": _data_to_vec2i(prop_data.get("tile", Vector2i.ZERO)),
			"template_id": String(prop_data.get("template_id", "")),
			"size": prop_data.get("size", [1, 1]),
			"offset": prop_data.get("offset", [0, 0]),
			"layer": String(prop_data.get("layer", "foreground")),
			"alpha": float(prop_data.get("alpha", 1.0)),
		})
	return results

static func _structure_spawns_to_data(data) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not (data is Array):
		return results
	for raw_spawn in data:
		if not (raw_spawn is Dictionary):
			continue
		var spawn: Dictionary = Dictionary(raw_spawn)
		var enemy_id := String(spawn.get("enemy_id", ""))
		if enemy_id == "":
			continue
		results.append({
			"enemy_id": enemy_id,
			"tile": _vec2i_to_data(_data_to_vec2i(spawn.get("tile", spawn))),
			"template_id": String(spawn.get("template_id", "")),
		})
	_sort_markers_by_tile(results)
	return results

static func _structure_spawns_from_data(data) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for spawn_data in _structure_spawns_to_data(data):
		results.append({
			"enemy_id": String(spawn_data.get("enemy_id", "")),
			"tile": _data_to_vec2i(spawn_data.get("tile", Vector2i.ZERO)),
			"template_id": String(spawn_data.get("template_id", "")),
		})
	return results

static func _structure_lights_to_data(data) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not (data is Array):
		return results
	for raw_light in data:
		if not (raw_light is Dictionary):
			continue
		var light: Dictionary = Dictionary(raw_light)
		results.append({
			"id": String(light.get("id", "")),
			"tile": _vec2i_to_data(_data_to_vec2i(light.get("tile", light))),
			"radius_tiles": float(light.get("radius_tiles", 6.0)),
			"intensity": float(light.get("intensity", 0.72)),
			"template_id": String(light.get("template_id", "")),
		})
	_sort_markers_by_tile(results)
	return results

static func _structure_lights_from_data(data) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for light_data in _structure_lights_to_data(data):
		results.append({
			"id": String(light_data.get("id", "")),
			"tile": _data_to_vec2i(light_data.get("tile", Vector2i.ZERO)),
			"radius_tiles": float(light_data.get("radius_tiles", 6.0)),
			"intensity": float(light_data.get("intensity", 0.72)),
			"template_id": String(light_data.get("template_id", "")),
		})
	return results

static func _structure_containers_to_data(data) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not (data is Array):
		return results
	for raw_container in data:
		if not (raw_container is Dictionary):
			continue
		var container: Dictionary = Dictionary(raw_container)
		results.append({
			"id": String(container.get("id", "")),
			"tile": _vec2i_to_data(_data_to_vec2i(container.get("tile", container))),
			"template_id": String(container.get("template_id", "")),
		})
	_sort_markers_by_tile(results)
	return results

static func _structure_containers_from_data(data) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for container_data in _structure_containers_to_data(data):
		results.append({
			"id": String(container_data.get("id", "")),
			"tile": _data_to_vec2i(container_data.get("tile", Vector2i.ZERO)),
			"template_id": String(container_data.get("template_id", "")),
		})
	return results

static func _tile_dictionary_to_entries(source: Dictionary, value_key: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for tile in _sorted_vector2i_keys(source):
		var entry := _vec2i_to_data(tile)
		if value_key == "value":
			entry[value_key] = float(source[tile])
		else:
			entry[value_key] = String(source[tile])
		entries.append(entry)
	return entries

static func _tile_entries_to_dictionary(entries: Array, value_key: String, numeric_value := false) -> Dictionary:
	var result := {}
	for raw_entry in entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = Dictionary(raw_entry)
		var tile := _data_to_vec2i(entry)
		result[tile] = float(entry.get(value_key, 0.0)) if numeric_value else String(entry.get(value_key, "air"))
	return result

static func _tile_entries_from_data(data, value_key: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not (data is Array):
		return results
	for raw_entry in data:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = Dictionary(raw_entry)
		var normalized := _vec2i_to_data(_data_to_vec2i(entry))
		if value_key == "value":
			normalized.value = float(entry.get("value", 0.0))
		else:
			normalized.id = String(entry.get("id", "air"))
		results.append(normalized)
	results.sort_custom(func(a, b): return int(a.y) < int(b.y) if int(a.x) == int(b.x) else int(a.x) < int(b.x))
	return results

static func _sorted_vector2i_keys(source: Dictionary) -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	for raw_key in source.keys():
		keys.append(_data_to_vec2i(raw_key))
	keys.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y if a.x == b.x else a.x < b.x)
	return keys

static func _vec2_array_to_data(values: Array) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for value in values:
		results.append(_vec2_to_data(_data_to_vec2(value)))
	return results

static func _vec2_array_from_data(values) -> Array[Vector2]:
	var results: Array[Vector2] = []
	if not (values is Array):
		return results
	for value in values:
		results.append(_data_to_vec2(value))
	return results

static func _vec2_to_data(value: Vector2) -> Dictionary:
	return {"x": float(value.x), "y": float(value.y)}

static func _vec2i_to_data(value: Vector2i) -> Dictionary:
	return {"x": int(value.x), "y": int(value.y)}

static func _vec2i_to_array(value: Vector2i) -> Array:
	return [int(value.x), int(value.y)]

static func _rect2i_to_data(value: Rect2i) -> Dictionary:
	return {"x": int(value.position.x), "y": int(value.position.y), "w": int(value.size.x), "h": int(value.size.y)}

static func _data_to_vec2(data) -> Vector2:
	if data is Vector2:
		return data
	if data is Vector2i:
		return Vector2(data)
	if data is Dictionary:
		return Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	if data is Array and data.size() >= 2:
		return Vector2(float(data[0]), float(data[1]))
	return Vector2.ZERO

static func _data_to_vec2i(data) -> Vector2i:
	if data is Vector2i:
		return data
	if data is Vector2:
		return Vector2i(roundi(data.x), roundi(data.y))
	if data is Dictionary:
		return Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	if data is Array and data.size() >= 2:
		return Vector2i(int(data[0]), int(data[1]))
	return Vector2i.ZERO

static func _data_to_rect2i(data) -> Rect2i:
	if data is Rect2i:
		return data
	if data is Dictionary:
		var dict := Dictionary(data)
		if dict.has("position") and dict.has("size"):
			return Rect2i(_data_to_vec2i(dict.position), _data_to_vec2i(dict.size))
		return Rect2i(Vector2i(int(dict.get("x", 0)), int(dict.get("y", 0))), Vector2i(int(dict.get("w", dict.get("width", 0))), int(dict.get("h", dict.get("height", 0)))))
	return Rect2i(Vector2i.ZERO, Vector2i.ZERO)

static func _sort_markers_by_tile(markers: Array[Dictionary]) -> void:
	markers.sort_custom(func(a: Dictionary, b: Dictionary): return _marker_sort_key(a) < _marker_sort_key(b))

static func _marker_sort_key(marker: Dictionary) -> String:
	var tile := _data_to_vec2i(marker.get("tile", Vector2i.ZERO))
	return "%010d,%010d,%s,%s" % [tile.x, tile.y, String(marker.get("id", "")), String(marker.get("enemy_id", ""))]

static func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.free()

static func _ensure_parent_dir(path: String) -> void:
	var parent := path.get_base_dir()
	if parent == "" or DirAccess.dir_exists_absolute(parent):
		return
	DirAccess.make_dir_recursive_absolute(parent)

static func _validate_save_data(data: Dictionary) -> String:
	if int(data.get("schema_version", -1)) != SCHEMA_VERSION:
		return "Unsupported save schema version."
	for key in ["world", "player", "inventory", "containers", "drops", "beacons", "flares", "defeated_bosses"]:
		if not data.has(key):
			return "Save file is missing '%s'." % key
	return ""

## Normalise the defeated_bosses dict from save data (keys must be strings,
## values must be bool true).
static func _defeated_bosses_from_data(data) -> Dictionary:
	var result: Dictionary = {}
	if not (data is Dictionary):
		return result
	for key in Dictionary(data).keys():
		result[String(key)] = true
	return result

## --- TimeManager persistence helpers ---

## Read current TimeManager state into a plain dict for serialisation.
static func _snapshot_time(main) -> Dictionary:
	var tm = main.get_node_or_null("/root/TimeManager")
	if tm == null:
		return {"hour": 8, "minute": 0, "day": 1}
	return {
		"hour":   int(tm.current_hour),
		"minute": int(tm.current_minute),
		"day":    int(tm.current_day),
	}

## Normalise an incoming time dict, applying clamped defaults.
static func _time_from_data(data) -> Dictionary:
	var d: Dictionary = data if data is Dictionary else {}
	return {
		"hour":   clampi(int(d.get("hour",   8)), 0, 23),
		"minute": clampi(int(d.get("minute", 0)), 0, 59),
		"day":    maxi(1, int(d.get("day", 1))),
	}

## Push a normalised time dict back into the TimeManager autoload.
static func _restore_time(main, time_data: Dictionary) -> void:
	var tm = main.get_node_or_null("/root/TimeManager")
	if tm == null:
		return
	tm.current_hour   = clampi(int(time_data.get("hour",   8)), 0, 23)
	tm.current_minute = clampi(int(time_data.get("minute", 0)), 0, 59)
	tm.current_day    = maxi(1, int(time_data.get("day",   1)))
	tm._accumulator   = 0.0
	# Don't emit hour_changed here — Main.gd calls _update_sky_modulate() on load.
