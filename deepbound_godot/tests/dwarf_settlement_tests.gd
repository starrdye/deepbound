extends SceneTree

const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")
const BackgroundCatalog = preload("res://scripts/catalogs/BackgroundCatalog.gd")
const EnemyCatalog = preload("res://scripts/catalogs/EnemyCatalog.gd")
const PrefabTemplateRegistry = preload("res://scripts/systems/PrefabTemplateRegistry.gd")
const StructureGenerator = preload("res://scripts/systems/StructureGenerator.gd")
const ChunkStore = preload("res://scripts/systems/ChunkStore.gd")
const PrefabDesignerController = preload("res://scripts/controllers/PrefabDesignerController.gd")

const TEMPLATE_PATH := "res://data/templates/dwarf_settlement_full.json"
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
	_test_direct_instantiation_has_settlement_content()
	_test_template_worldgen_spawns_in_second_band()
	if failures.is_empty():
		print("Deepbound Godot dwarf settlement tests passed.")
		quit(0)
	else:
		print("Deepbound Godot dwarf settlement tests failed: %d" % failures.size())
		quit(1)

func _test_template_loads_and_assets_exist() -> void:
	var template := PrefabTemplateRegistry.load_template(TEMPLATE_PATH)
	_assert(not template.is_empty(), "dwarf settlement prefab should load and validate")
	_assert(String(template.id) == "dwarf_settlement_full", "dwarf settlement template should use the expected id")
	_assert(Vector2i(int(template.size.x), int(template.size.y)) == Vector2i(128, 64), "dwarf settlement should keep the editor-friendly canvas size")
	_assert(Array(template.metadata.bands).has("colossal_ant_chambers"), "dwarf settlement should belong to Band 2")
	_assert(String(template.metadata.structure_type) == "dwarf_settlement", "dwarf settlement should expose a settlement structure type")
	for tile_id in ["dwarf_granite_brick", "dwarf_cut_granite_floor", "dwarf_ironbound_block", "dwarf_rune_block", "dwarf_iron_platform"]:
		_assert(TileCatalog.TILES.has(tile_id), "dwarf settlement tile should be cataloged: %s" % tile_id)
		_assert(FileAccess.file_exists("res://assets/tiles/%s.png" % tile_id), "dwarf settlement tile PNG should exist: %s" % tile_id)
	for background_id in ["dwarf_granite_background", "dwarf_forge_background", "dwarf_rune_background"]:
		_assert(BackgroundCatalog.BACKGROUNDS.has(background_id), "dwarf settlement background should be cataloged: %s" % background_id)
		_assert(FileAccess.file_exists("res://assets/backgrounds/%s.png" % background_id), "dwarf settlement background PNG should exist: %s" % background_id)
	for prop_id in ["dwarf_great_hall_gate", "dwarf_back_house_lit", "dwarf_back_house_dark", "dwarf_rail_segment", "dwarf_stair_brace", "dwarf_glow_crystal", "dwarf_cistern_pool"]:
		_assert(FileAccess.file_exists("res://assets/props/%s.png" % prop_id), "dwarf settlement prop PNG should exist: %s" % prop_id)
	_assert(FileAccess.file_exists("res://assets/source_ai/dwarf_settlement_ai_reference.png"), "dwarf settlement source art board should exist")
	_assert(FileAccess.file_exists("res://assets/previews/dwarf_settlement_kit_preview.png"), "dwarf settlement kit preview should exist")
	var designer := PrefabDesignerController.new()
	_assert(designer.load_template_data(template), "dwarf settlement should load into the prefab designer")
	_assert(designer.props.size() == template.layers.props.size(), "prefab designer should preserve all dwarf settlement props")
	designer.free()

func _test_direct_instantiation_has_settlement_content() -> void:
	var template := PrefabTemplateRegistry.load_template(TEMPLATE_PATH)
	var structure := PrefabTemplateRegistry.instantiate_template(template, Vector2i(96, 620))
	_assert(String(structure.type) == "dwarf_settlement", "direct dwarf settlement instantiation should keep structure type")
	var rect: Rect2i = structure.rect
	_assert(rect.position.y >= BAND2_MIN_Y and rect.position.y + rect.size.y - 1 <= BAND2_MAX_Y, "direct dwarf settlement should fit inside Band 2")
	_assert(Dictionary(structure.tiles).values().has("air"), "dwarf settlement should carve explicit air interiors")
	_assert(Dictionary(structure.tiles).values().has("dwarf_iron_platform"), "dwarf settlement should include bridge and ladder platform tiles")
	_assert(Dictionary(structure.tiles).values().has("dwarf_ironbound_block"), "dwarf settlement should include ironbound structural walls")
	_assert(Dictionary(structure.backgrounds).values().has("dwarf_forge_background"), "dwarf settlement should include forge room walls")
	_assert(Dictionary(structure.backgrounds).values().has("dwarf_rune_background"), "dwarf settlement should include rune hall walls")
	_assert(Array(structure.props).size() >= 60, "dwarf settlement should include a full multi-level decorative prop layout")
	_assert(Array(structure.lights).size() >= 20, "dwarf settlement should expose lantern, rune, forge, and crystal lights")
	_assert(Array(structure.containers).size() >= 2, "dwarf settlement should expose storage/container markers")
	_assert(Array(structure.spawns).size() >= 8, "dwarf settlement should expose dwarf spawn markers")
	_assert(_has_backdrop_prop(structure, "dwarf_back_house_lit"), "dwarf settlement should keep lit houses as backdrop props")
	_assert(_has_backdrop_prop(structure, "dwarf_back_house_dark"), "dwarf settlement should keep dark houses as backdrop props")
	for spawn in structure.spawns:
		var enemy_id := String(spawn.enemy_id)
		_assert(enemy_id.begins_with("dwarf_"), "dwarf settlement spawn should use dwarf enemies: %s" % enemy_id)
		_assert(String(EnemyCatalog.get_enemy(enemy_id).band) == "colossal_ant_chambers", "dwarf settlement spawn should stay in Band 2: %s" % enemy_id)

func _test_template_worldgen_spawns_in_second_band() -> void:
	PrefabTemplateRegistry.clear_cache()
	var structure := _find_first_dwarf_settlement()
	_assert(not structure.is_empty(), "template registry should spawn at least one Band 2 dwarf settlement")
	if structure.is_empty():
		return
	var rect: Rect2i = structure.rect
	_assert(rect.position.y >= BAND2_MIN_Y and rect.position.y + rect.size.y - 1 <= BAND2_MAX_Y, "generated dwarf settlement should remain inside Band 2")
	_assert(String(structure.source_template_id) == "dwarf_settlement_full", "generated dwarf settlement should come from the prefab template")
	var center := rect.position + rect.size / 2
	var spawns := StructureGenerator.get_structure_spawns_near(133742, center, 112)
	_assert(_has_structure_record(spawns, String(structure.id)), "nearby spawn query should expose dwarf settlement spawns")
	var lights := StructureGenerator.get_structure_lights_near(133742, center, 112)
	_assert(_has_template_record(lights, "dwarf_settlement_full"), "nearby light query should expose dwarf settlement lights")
	var containers := StructureGenerator.get_structure_containers_near(133742, center, 112)
	_assert(_has_template_record(containers, "dwarf_settlement_full"), "nearby container query should expose dwarf settlement storage")
	var sample_tile := _first_tile_with_id(structure, "dwarf_ironbound_block")
	var sample_background := _first_background_tile(structure)
	var store_a := ChunkStore.new(133742)
	var store_b := ChunkStore.new(133742)
	store_b.get_tile(sample_tile + Vector2i(32, 0))
	_assert(store_a.get_tile(sample_tile) == "dwarf_ironbound_block", "chunk foreground generation should apply dwarf settlement overlays")
	_assert(store_b.get_tile(sample_tile) == store_a.get_tile(sample_tile), "dwarf settlement foreground overlay should be chunk-order stable")
	_assert(store_a.get_background_tile(sample_background) == String(structure.backgrounds[sample_background]), "chunk background generation should apply dwarf settlement wall overlays")

func _find_first_dwarf_settlement() -> Dictionary:
	for chunk_y in range(12, 25):
		for chunk_x in range(-48, 49):
			for structure in StructureGenerator.get_structures_overlapping_chunk(133742, Vector2i(chunk_x, chunk_y)):
				if String(structure.get("source_template_id", "")) == "dwarf_settlement_full":
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
