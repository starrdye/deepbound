extends SceneTree

const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")
const BackgroundCatalog = preload("res://scripts/catalogs/BackgroundCatalog.gd")
const EnemyCatalog = preload("res://scripts/catalogs/EnemyCatalog.gd")
const VillageCatalog = preload("res://scripts/catalogs/VillageCatalog.gd")
const PrefabTemplateRegistry = preload("res://scripts/systems/PrefabTemplateRegistry.gd")
const StructureGenerator = preload("res://scripts/systems/StructureGenerator.gd")
const ChunkStore = preload("res://scripts/systems/ChunkStore.gd")
const PrefabDesignerController = preload("res://scripts/controllers/PrefabDesignerController.gd")

const TEMPLATE_PATH := "res://data/templates/drow_village_full.json"
const BAND4_MIN_Y := 1152
const BAND4_MAX_Y := 1535

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
	_test_direct_instantiation_has_village_content()
	_test_template_worldgen_spawns_in_fourth_band()
	if failures.is_empty():
		print("Deepbound Godot drow village tests passed.")
		quit(0)
	else:
		print("Deepbound Godot drow village tests failed: %d" % failures.size())
		quit(1)

func _test_template_loads_and_assets_exist() -> void:
	var template := PrefabTemplateRegistry.load_template(TEMPLATE_PATH)
	_assert(not template.is_empty(), "drow village prefab should load and validate")
	_assert(String(template.id) == "drow_village_full", "drow village template should use the expected id")
	_assert(Vector2i(int(template.size.x), int(template.size.y)) == Vector2i(128, 64), "drow village should keep the editor-friendly canvas size")
	_assert(Array(template.metadata.bands).has("drow_enclaves"), "drow village should belong to Band 4 Drow Enclaves")
	_assert(String(template.metadata.structure_type) == "drow_village", "drow village should expose a village structure type")

	for tile_id in VillageCatalog.DROW_TILE_IDS:
		_assert(TileCatalog.TILES.has(tile_id), "drow village tile should be cataloged: %s" % tile_id)
		_assert(FileAccess.file_exists("res://assets/tiles/%s.png" % tile_id), "drow village tile PNG should exist: %s" % tile_id)

	for background_id in VillageCatalog.DROW_SETTLEMENT_BACKGROUND_IDS:
		_assert(BackgroundCatalog.BACKGROUNDS.has(background_id), "drow settlement background should be cataloged: %s" % background_id)
		_assert(FileAccess.file_exists("res://assets/backgrounds/%s.png" % background_id), "drow settlement background PNG should exist: %s" % background_id)

	for prop_id in VillageCatalog.DROW_SETTLEMENT_PROP_IDS:
		_assert(FileAccess.file_exists("res://assets/props/%s.png" % prop_id), "drow settlement prop PNG should exist: %s" % prop_id)

	_assert(FileAccess.file_exists("res://assets/source_ai/drow_settlement_structures_ai_reference.png"), "drow settlement source art board should exist")
	_assert(FileAccess.file_exists("res://assets/previews/drow_settlement_kit_preview.png"), "drow settlement kit preview should exist")

	var designer := PrefabDesignerController.new()
	_assert(designer.load_template_data(template), "drow village should load into the prefab designer")
	_assert(designer.props.size() == template.layers.props.size(), "prefab designer should preserve all drow village props")
	designer.free()

func _test_direct_instantiation_has_village_content() -> void:
	var template := PrefabTemplateRegistry.load_template(TEMPLATE_PATH)
	var structure := PrefabTemplateRegistry.instantiate_template(template, Vector2i(96, 1300))
	_assert(String(structure.type) == "drow_village", "direct drow village instantiation should keep structure type")

	var rect: Rect2i = structure.rect
	_assert(rect.position.y >= BAND4_MIN_Y and rect.position.y + rect.size.y - 1 <= BAND4_MAX_Y, "direct drow village should fit inside Band 4")
	_assert(Dictionary(structure.tiles).values().has("air"), "drow village should carve explicit air interiors")
	_assert(Dictionary(structure.tiles).values().has("drow_carved_floor"), "drow village should include carved floor tiles")
	_assert(Dictionary(structure.tiles).values().has("drow_basalt_brick"), "drow village should include basalt brick walls")
	_assert(Dictionary(structure.backgrounds).values().has("drow_carved_background"), "drow village should include carved background walls")
	_assert(Dictionary(structure.backgrounds).values().has("drow_scriptuarium_background"), "drow village should include scriptuarium walls")
	_assert(Array(structure.props).size() >= 40, "drow village should include a full multi-room decorative prop layout")
	_assert(Array(structure.lights).size() >= 16, "drow village should expose spectral torch and crystal lights")
	_assert(Array(structure.containers).size() >= 2, "drow village should expose market crate container markers")
	_assert(Array(structure.spawns).size() >= 8, "drow village should expose drow spawn markers")
	_assert(_has_backdrop_prop(structure, "drow_back_house_lit"), "drow village should keep lit houses as backdrop props")
	_assert(_has_backdrop_prop(structure, "drow_back_house_dark"), "drow village should keep dark houses as backdrop props")

	for spawn in structure.spawns:
		var enemy_id := String(spawn.enemy_id)
		_assert(enemy_id.begins_with("drow_"), "drow village spawn should use drow enemies: %s" % enemy_id)
		_assert(String(EnemyCatalog.get_enemy(enemy_id).band) == "drow_enclaves", "drow village spawn should stay in Band 4: %s" % enemy_id)

func _test_template_worldgen_spawns_in_fourth_band() -> void:
	PrefabTemplateRegistry.clear_cache()
	var structure := _find_first_drow_village()
	_assert(not structure.is_empty(), "template registry should spawn at least one Band 4 drow village")
	if structure.is_empty():
		return

	var rect: Rect2i = structure.rect
	_assert(rect.position.y >= BAND4_MIN_Y and rect.position.y + rect.size.y - 1 <= BAND4_MAX_Y, "generated drow village should remain inside Band 4")
	_assert(String(structure.source_template_id) == "drow_village_full", "generated drow village should come from the prefab template")

	var center := rect.position + rect.size / 2
	var spawns := StructureGenerator.get_structure_spawns_near(133742, center, 112)
	_assert(_has_structure_record(spawns, String(structure.id)), "nearby spawn query should expose drow village spawns")
	var lights := StructureGenerator.get_structure_lights_near(133742, center, 112)
	_assert(_has_template_record(lights, "drow_village_full"), "nearby light query should expose drow village lights")
	var containers := StructureGenerator.get_structure_containers_near(133742, center, 112)
	_assert(_has_template_record(containers, "drow_village_full"), "nearby container query should expose drow village storage")

	var sample_tile := _first_tile_with_id(structure, "drow_basalt_brick")
	var sample_background := _first_background_tile(structure)
	var store_a := ChunkStore.new(133742)
	var store_b := ChunkStore.new(133742)
	store_b.get_tile(sample_tile + Vector2i(32, 0))
	_assert(store_a.get_tile(sample_tile) == "drow_basalt_brick", "chunk foreground generation should apply drow village overlays")
	_assert(store_b.get_tile(sample_tile) == store_a.get_tile(sample_tile), "drow village foreground overlay should be chunk-order stable")
	_assert(store_a.get_background_tile(sample_background) == String(structure.backgrounds[sample_background]), "chunk background generation should apply drow village wall overlays")

func _find_first_drow_village() -> Dictionary:
	for chunk_y in range(36, 48):
		for chunk_x in range(-48, 49):
			for structure in StructureGenerator.get_structures_overlapping_chunk(133742, Vector2i(chunk_x, chunk_y)):
				if String(structure.get("source_template_id", "")) == "drow_village_full":
					return structure
	return {}

func _has_backdrop_prop(structure: Dictionary, prop_id: String) -> bool:
	for prop in structure.props:
		if String(prop.id) == prop_id and String(prop.layer) == "backdrop" and float(prop.alpha) < 1.0:
			return true
	return false

func _has_structure_record(records: Array, structure_id: String) -> bool:
	for record in records:
		if String(record.get("structure_id", "")) == structure_id:
			return true
	return false

func _has_template_record(records: Array, template_id: String) -> bool:
	for record in records:
		if String(record.get("template_id", "")) == template_id:
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
