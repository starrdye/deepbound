extends SceneTree

const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")
const BackgroundCatalog = preload("res://scripts/catalogs/BackgroundCatalog.gd")
const EnemyCatalog = preload("res://scripts/catalogs/EnemyCatalog.gd")
const DeepboundWorld = preload("res://scripts/World.gd")
const PrefabTemplateRegistry = preload("res://scripts/systems/PrefabTemplateRegistry.gd")
const StructureGenerator = preload("res://scripts/systems/StructureGenerator.gd")
const ChunkStore = preload("res://scripts/systems/ChunkStore.gd")

const TEMPLATE_PATH := "res://data/templates/dwarf_fortress_full.json"
const BAND2_MIN_Y := 384
const BAND2_MAX_Y := 767

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	PrefabTemplateRegistry.clear_cache()
	_test_template_loads_and_assets_exist()
	_test_direct_instantiation_has_fortress_content()
	_test_template_worldgen_spawns_in_second_band()
	await _test_world_visible_cache_draws_dwarf_props()
	if failures.is_empty():
		print("Deepbound Godot dwarf fortress tests passed.")
		quit(0)
	else:
		print("Deepbound Godot dwarf fortress tests failed: %d" % failures.size())
		quit(1)

func _test_template_loads_and_assets_exist() -> void:
	var template := PrefabTemplateRegistry.load_template(TEMPLATE_PATH)
	_assert(not template.is_empty(), "dwarf fortress prefab should load and validate")
	_assert(String(template.id) == "dwarf_fortress_full", "dwarf fortress template should use the expected id")
	_assert(Array(template.metadata.bands).has("colossal_ant_chambers"), "dwarf fortress should belong to Band 2")
	_assert(String(template.metadata.structure_type) == "dwarf_fortress", "dwarf fortress should expose a settlement structure type")
	for tile_id in ["dwarf_granite_brick", "dwarf_cut_granite_floor", "dwarf_ironbound_block", "dwarf_rune_block", "dwarf_iron_platform"]:
		_assert(TileCatalog.TILES.has(tile_id), "dwarf tile should be cataloged: %s" % tile_id)
		_assert(FileAccess.file_exists("res://assets/tiles/%s.png" % tile_id), "dwarf tile PNG should exist: %s" % tile_id)
		_assert(FileAccess.file_exists("res://assets/effects/tile_breaking_%s_sheet.png" % tile_id), "dwarf tile should have a breaking sheet: %s" % tile_id)
	for background_id in ["dwarf_granite_background", "dwarf_forge_background", "dwarf_rune_background"]:
		_assert(BackgroundCatalog.BACKGROUNDS.has(background_id), "dwarf background should be cataloged: %s" % background_id)
		_assert(FileAccess.file_exists("res://assets/backgrounds/%s.png" % background_id), "dwarf background PNG should exist: %s" % background_id)
	for prop_id in ["dwarf_forge", "dwarf_lantern", "dwarf_ladder", "dwarf_gate", "dwarf_chest", "dwarf_bridge", "dwarf_back_tower_lit"]:
		_assert(FileAccess.file_exists("res://assets/props/%s.png" % prop_id), "dwarf prop PNG should exist: %s" % prop_id)
	for enemy_id in ["dwarf_guard", "dwarf_crossbowman", "dwarf_smith"]:
		_assert(String(EnemyCatalog.get_enemy(enemy_id).band) == "colossal_ant_chambers", "dwarf enemy should belong to Band 2: %s" % enemy_id)
		_assert(FileAccess.file_exists("res://assets/enemies/%s.png" % enemy_id), "dwarf enemy animation sheet should exist: %s" % enemy_id)
	_assert(FileAccess.file_exists("res://assets/source_ai/dwarf_fortress_ai_reference.png"), "dwarf fortress source art board should exist")
	_assert(FileAccess.file_exists("res://assets/previews/dwarf_fortress_kit_preview.png"), "dwarf fortress kit preview should exist")

func _test_direct_instantiation_has_fortress_content() -> void:
	var template := PrefabTemplateRegistry.load_template(TEMPLATE_PATH)
	var structure := PrefabTemplateRegistry.instantiate_template(template, Vector2i(96, 520))
	_assert(String(structure.type) == "dwarf_fortress", "direct dwarf template instantiation should keep structure type")
	var rect: Rect2i = structure.rect
	_assert(rect.position.y >= BAND2_MIN_Y and rect.position.y + rect.size.y - 1 <= BAND2_MAX_Y, "direct dwarf fortress should fit inside Band 2")
	_assert(Dictionary(structure.tiles).values().has("air"), "dwarf fortress should carve explicit air interiors")
	_assert(Dictionary(structure.tiles).values().has("dwarf_granite_brick"), "dwarf fortress should stamp granite shell blocks")
	_assert(Dictionary(structure.tiles).values().has("dwarf_rune_block"), "dwarf fortress should include rune structural blocks")
	_assert(Dictionary(structure.backgrounds).values().has("dwarf_forge_background"), "dwarf fortress should include forge room walls")
	_assert(Array(structure.props).size() >= 30, "dwarf fortress should include a full decorative prop layout")
	_assert(Array(structure.lights).size() >= 8, "dwarf fortress should expose lantern and forge lights")
	_assert(Array(structure.containers).size() >= 2, "dwarf fortress should expose storage/container markers")
	_assert(Array(structure.spawns).size() >= 6, "dwarf fortress should expose dwarf spawn markers")
	for spawn in structure.spawns:
		var enemy_id := String(spawn.enemy_id)
		_assert(enemy_id.begins_with("dwarf_"), "dwarf fortress spawn should use dwarf enemies: %s" % enemy_id)
		_assert(String(EnemyCatalog.get_enemy(enemy_id).band) == "colossal_ant_chambers", "dwarf fortress spawn should stay in Band 2: %s" % enemy_id)

func _test_template_worldgen_spawns_in_second_band() -> void:
	PrefabTemplateRegistry.clear_cache()
	var structure := _find_first_dwarf_structure()
	_assert(not structure.is_empty(), "template registry should spawn at least one Band 2 dwarf fortress")
	if structure.is_empty():
		return
	var rect: Rect2i = structure.rect
	_assert(rect.position.y >= BAND2_MIN_Y and rect.position.y + rect.size.y - 1 <= BAND2_MAX_Y, "generated dwarf fortress should remain inside Band 2")
	_assert(String(structure.source_template_id) == "dwarf_fortress_full", "generated dwarf fortress should come from the prefab template")
	var center := rect.position + rect.size / 2
	var spawns := StructureGenerator.get_structure_spawns_near(133742, center, 96)
	_assert(_has_structure_record(spawns, String(structure.id)), "nearby spawn query should expose dwarf fortress spawns")
	var lights := StructureGenerator.get_structure_lights_near(133742, center, 96)
	_assert(_has_light_or_container_from_template(lights), "nearby light query should expose dwarf lanterns or forge light")
	var containers := StructureGenerator.get_structure_containers_near(133742, center, 96)
	_assert(_has_light_or_container_from_template(containers), "nearby container query should expose dwarf storage")
	var sample_tile := _first_tile_with_id(structure, "dwarf_granite_brick")
	var sample_background := _first_background_tile(structure)
	var store_a := ChunkStore.new(133742)
	var store_b := ChunkStore.new(133742)
	store_b.get_tile(sample_tile + Vector2i(32, 0))
	_assert(store_a.get_tile(sample_tile) == "dwarf_granite_brick", "chunk foreground generation should apply dwarf fortress overlays")
	_assert(store_b.get_tile(sample_tile) == store_a.get_tile(sample_tile), "dwarf fortress foreground overlay should be chunk-order stable")
	_assert(store_a.get_background_tile(sample_background) == String(structure.backgrounds[sample_background]), "chunk background generation should apply dwarf fortress wall overlays")

func _test_world_visible_cache_draws_dwarf_props() -> void:
	PrefabTemplateRegistry.clear_cache()
	var structure := _find_first_dwarf_structure()
	_assert(not structure.is_empty(), "world visual cache test needs a generated Band 2 dwarf fortress")
	if structure.is_empty():
		return
	var rect: Rect2i = structure.rect
	var camera := Camera2D.new()
	camera.name = "DwarfFortressVisualCamera"
	camera.enabled = true
	camera.zoom = Vector2(2, 2)
	camera.global_position = Vector2(
		float((rect.position.x + rect.size.x / 2) * DeepboundWorld.TILE_SIZE),
		float((rect.position.y + rect.size.y / 2) * DeepboundWorld.TILE_SIZE)
	)
	get_root().add_child(camera)
	camera.make_current()
	var world := DeepboundWorld.new()
	world.name = "DwarfFortressVisualWorld"
	get_root().add_child(world)
	world.set_process(false)
	await _flush_frames(2)
	world.enable_debug_perf_counters(true)
	world.refresh_visible_chunk_window(true)
	_assert(world.get_debug_perf_counter("visible_structure_chunk_query") > 0, "world visual cache should query visible structure chunks")
	_assert(_has_template_structure(world._cached_visible_structures(), "dwarf_fortress_full"), "world visual cache should include Band 2 dwarf fortress structures")
	world.reset_debug_perf_counters()
	world._queue_prop_overlay_redraw()
	await _flush_frames(2)
	_assert(world.get_debug_perf_counter("structure_prop_drawn") > 0, "world prop overlays should draw Band 2 dwarf fortress props")
	world.queue_free()
	camera.queue_free()
	await _flush_frames(1)

func _find_first_dwarf_structure() -> Dictionary:
	for chunk_y in range(12, 25):
		for chunk_x in range(-36, 37):
			for structure in StructureGenerator.get_structures_overlapping_chunk(133742, Vector2i(chunk_x, chunk_y)):
				if String(structure.get("source_template_id", "")) == "dwarf_fortress_full":
					return structure
	return {}

func _has_template_structure(structures: Array, template_id: String) -> bool:
	for structure in structures:
		if String(structure.get("source_template_id", "")) == template_id:
			return true
	return false

func _has_structure_record(records: Array, structure_id: String) -> bool:
	for record in records:
		if String(record.get("structure_id", "")) == structure_id:
			return true
	return false

func _has_light_or_container_from_template(records: Array) -> bool:
	for record in records:
		if String(record.get("template_id", "")) == "dwarf_fortress_full":
			return true
	return false

func _first_tile_with_id(structure: Dictionary, tile_id: String) -> Vector2i:
	for tile in Dictionary(structure.tiles).keys():
		var tile_coord: Vector2i = tile
		if String(structure.tiles[tile_coord]) == tile_id:
			return tile_coord
	return Vector2i(999999, 999999)

func _first_background_tile(structure: Dictionary) -> Vector2i:
	for tile in Dictionary(structure.backgrounds).keys():
		return tile
	return Vector2i(999999, 999999)

func _flush_frames(count: int) -> void:
	for _i in range(count):
		await process_frame
