extends SceneTree

const PrefabTemplateRegistry = preload("res://scripts/systems/PrefabTemplateRegistry.gd")
const PrefabTemplateImporter = preload("res://scripts/systems/PrefabTemplateImporter.gd")
const PrefabDesignerController = preload("res://scripts/controllers/PrefabDesignerController.gd")
const StructureGenerator = preload("res://scripts/systems/StructureGenerator.gd")
const ChunkStore = preload("res://scripts/systems/ChunkStore.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	PrefabTemplateRegistry.clear_cache()
	_assert(PrefabTemplateImporter.import_current_goblin_village(PrefabTemplateImporter.DEFAULT_GOBLIN_TEMPLATE_PATH, true), "current goblin village should import as a built-in prefab template")
	PrefabTemplateRegistry.clear_cache()
	_test_serialization_round_trip_and_validation()
	_test_import_matches_current_village()
	_test_designer_tool_operations()
	await _test_designer_scene_loads_palette()
	_test_template_worldgen_replaces_live_goblin_stamping()
	if failures.is_empty():
		print("Deepbound Godot prefab template tests passed.")
		quit(0)
	else:
		print("Deepbound Godot prefab template tests failed: %d" % failures.size())
		quit(1)

func _test_serialization_round_trip_and_validation() -> void:
	var template := _small_template()
	var path := "user://templates/round_trip_prefab_test.json"
	_remove_file(path)
	_assert(PrefabTemplateRegistry.save_template(template, path), "valid sparse prefab template should save")
	var first := FileAccess.get_file_as_string(path)
	var loaded := PrefabTemplateRegistry.load_template(path)
	_assert(not loaded.is_empty(), "saved prefab template should load")
	_assert(int(loaded.schema_version) == 1, "loaded prefab template should keep schema version")
	_assert(loaded.layers.foreground.size() == 2, "foreground layer should preserve sparse entries including explicit air")
	_assert(loaded.layers.backgrounds.size() == 2, "background layer should preserve explicit empty clears")
	var direct_structure := PrefabTemplateRegistry.instantiate_template(loaded, Vector2i(20, 20))
	_assert(Dictionary(direct_structure.tiles).values().has("chest_block"), "container props should stamp chest_block tiles when instantiated")
	_assert(Array(direct_structure.containers).size() == 1, "container props should expose container markers")
	_assert(Array(direct_structure.lights).size() == 1, "light props should expose light markers")
	_assert(PrefabTemplateRegistry.save_template(loaded, path), "loaded prefab template should save again")
	var second := FileAccess.get_file_as_string(path)
	_assert(first == second, "prefab template save should be stable and deterministic")

	var duplicate := template.duplicate(true)
	duplicate.layers.foreground.append({"x": 1, "y": 1, "id": "soft_stone"})
	PrefabTemplateRegistry.set_validation_errors_enabled(false)
	_assert(PrefabTemplateRegistry.validate_template(duplicate).is_empty(), "duplicate foreground cells should be rejected")
	var bad_id := template.duplicate(true)
	bad_id.layers.foreground[0].id = "missing_tile"
	_assert(PrefabTemplateRegistry.validate_template(bad_id).is_empty(), "unknown foreground tile ids should be rejected")
	var bad_anchor := template.duplicate(true)
	bad_anchor.anchor = {"x": 99, "y": 0}
	_assert(PrefabTemplateRegistry.validate_template(bad_anchor).is_empty(), "anchor outside canvas should be rejected")
	PrefabTemplateRegistry.set_validation_errors_enabled(true)
	_remove_file(path)
	PrefabTemplateRegistry.clear_cache()

func _test_import_matches_current_village() -> void:
	var region := PrefabTemplateImporter.find_first_goblin_village_region(133742)
	var reference := StructureGenerator.build_goblin_village(133742, region)
	var imported := PrefabTemplateRegistry.load_template(PrefabTemplateImporter.DEFAULT_GOBLIN_TEMPLATE_PATH)
	_assert(not imported.is_empty(), "imported goblin village prefab should load")
	_assert(String(imported.id) == "goblin_village_full", "imported goblin village should use the expected template id")
	_assert(imported.layers.foreground.size() == Dictionary(reference.tiles).size(), "imported foreground count should match the generated reference village")
	_assert(imported.layers.backgrounds.size() == Dictionary(reference.backgrounds).size(), "imported background count should match the generated reference village")
	_assert(imported.layers.props.size() == Array(reference.props).size(), "imported prop count should match the generated reference village")
	_assert(imported.layers.spawns.size() == Array(reference.spawns).size(), "imported spawn count should match the generated reference village")
	var rect: Rect2i = reference.rect
	for source_tile in Dictionary(reference.tiles).keys().slice(0, mini(12, Dictionary(reference.tiles).size())):
		var tile: Vector2i = source_tile
		var local := Vector2i(tile.x - rect.position.x, tile.y - rect.position.y)
		_assert(_template_has_cell(imported.layers.foreground, local, String(reference.tiles[tile])), "imported foreground should preserve generated tile %s" % str(local))

func _test_designer_tool_operations() -> void:
	var designer := PrefabDesignerController.new()
	designer.new_template(6, 5)
	designer.select_palette_asset({"layer": "foreground", "kind": "foreground", "id": "soft_stone", "name": "Soft Stone"})
	designer.apply_pencil(Vector2i(1, 1))
	_assert(String(designer.foreground[Vector2i(1, 1)]) == "soft_stone", "designer pencil should place the selected foreground tile")
	designer.active_tool = PrefabDesignerController.TOOL_BUCKET
	designer.select_palette_asset({"layer": "foreground", "kind": "foreground", "id": "air", "name": "Air"})
	designer.bucket_fill(Vector2i(0, 0))
	_assert(String(designer.foreground[Vector2i(0, 0)]) == "air", "designer bucket should fill matching blank cells with explicit air")
	designer.active_layer = "backgrounds"
	designer.select_palette_asset({"layer": "backgrounds", "kind": "background", "id": "stone_background_block", "name": "Stone Background"})
	designer.apply_pencil(Vector2i(2, 2))
	designer.select_region(Rect2i(Vector2i(1, 1), Vector2i(2, 2)))
	var copied := designer.copy_selection()
	_assert(copied.foreground.size() > 0 and copied.backgrounds.size() > 0, "designer marquee copy should include all authored layers in the region")
	designer.move_selection(Vector2i(2, 0))
	_assert(designer.backgrounds.has(Vector2i(4, 2)), "designer move should shift selected background cells")
	var template := designer.to_template()
	_assert(not PrefabTemplateRegistry.validate_template(template).is_empty(), "designer-authored template should validate")
	designer.free()

func _test_designer_scene_loads_palette() -> void:
	var scene: PackedScene = load("res://scenes/PrefabDesigner.tscn")
	var designer = scene.instantiate()
	get_root().add_child(designer)
	await process_frame
	_assert(designer is PrefabDesignerController, "PrefabDesigner scene should instantiate the designer controller")
	_assert(designer.palette_list != null and designer.palette_list.item_count > 0, "PrefabDesigner scene should build a searchable asset palette")
	designer.queue_free()

func _test_template_worldgen_replaces_live_goblin_stamping() -> void:
	PrefabTemplateRegistry.clear_cache()
	var structure := _find_first_template_structure(133742)
	_assert(not structure.is_empty(), "template registry should spawn at least one goblin village prefab")
	_assert(String(structure.get("source_template_id", "")) == "goblin_village_full", "worldgen goblin village should come from the imported template")
	_assert(not structure.has("buildings"), "template-backed worldgen structures should not expose live procedural building instances")
	_assert(Dictionary(structure.tiles).size() > 0 and Dictionary(structure.backgrounds).size() > 0, "template-backed structure should expose tile and background overlays")
	var center: Vector2i = structure.rect.position + structure.rect.size / 2
	var spawns := StructureGenerator.get_structure_spawns_near(133742, center, 96)
	_assert(spawns.size() >= 3, "template-backed goblin village should expose nearby hostile spawn markers")
	var lights := StructureGenerator.get_structure_lights_near(133742, center, 96)
	_assert(lights.size() > 0, "template-backed goblin village should expose light markers from torch props")
	var sample_tile := _first_non_air_tile(structure)
	_assert(sample_tile != Vector2i(999999, 999999), "template-backed structure should include at least one solid foreground sample")
	var store_a := ChunkStore.new(133742)
	var store_b := ChunkStore.new(133742)
	var chunk := store_a.to_chunk_coord(sample_tile)
	store_b.get_tile(sample_tile + Vector2i(32, 0))
	_assert(store_a.get_tile(sample_tile) == String(structure.tiles[sample_tile]), "template overlay should apply to foreground chunk generation")
	_assert(store_b.get_tile(sample_tile) == store_a.get_tile(sample_tile), "template foreground overlay should be stable regardless of neighboring chunk generation order")

func _find_first_template_structure(seed: int) -> Dictionary:
	for chunk_y in range(0, 12):
		for chunk_x in range(-18, 19):
			for structure in StructureGenerator.get_structures_overlapping_chunk(seed, Vector2i(chunk_x, chunk_y)):
				if String(structure.get("source_template_id", "")) == "goblin_village_full":
					return structure
	return {}

func _small_template() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "round_trip_prefab_test",
		"name": "Round Trip Prefab Test",
		"size": {"x": 6, "y": 5},
		"anchor": {"x": 3, "y": 4},
		"metadata": {
			"bands": ["standard_caverns"],
			"rarity": 1.0,
			"enabled": true,
			"allow_mirror_x": false,
			"allow_mirror_y": false,
			"allow_rotation": false,
			"tags": ["test"],
			"spawn_region_size": {"x": 96, "y": 56},
			"structure_type": "test_prefab",
		},
		"layers": {
			"foreground": [
				{"x": 1, "y": 1, "id": "soft_stone"},
				{"x": 2, "y": 1, "id": "air"},
			],
			"backgrounds": [
				{"x": 1, "y": 1, "id": "stone_background_block"},
				{"x": 2, "y": 1, "id": "empty"},
			],
			"props": [
				{"x": 3, "y": 2, "id": "chest_closed", "kind": "container", "size": [1, 1], "offset": [0, 0], "draw_layer": "foreground", "alpha": 1.0},
				{"x": 1, "y": 3, "id": "goblin_torch", "kind": "light", "size": [1, 1], "offset": [0, 0], "draw_layer": "foreground", "alpha": 1.0},
			],
			"spawns": [
				{"x": 4, "y": 3, "enemy_id": "goblin_grunt"},
			],
		},
	}

func _template_has_cell(entries: Array, tile: Vector2i, id: String) -> bool:
	for entry in entries:
		if int(entry.x) == tile.x and int(entry.y) == tile.y and String(entry.id) == id:
			return true
	return false

func _remove_file(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)

func _first_non_air_tile(structure: Dictionary) -> Vector2i:
	for tile in Dictionary(structure.tiles).keys():
		var tile_coord: Vector2i = tile
		if String(structure.tiles[tile_coord]) != "air":
			return tile_coord
	return Vector2i(999999, 999999)
