extends SceneTree

const ChunkStore = preload("res://scripts/systems/ChunkStore.gd")
const StructureGenerator = preload("res://scripts/systems/StructureGenerator.gd")
const WorldGenerator = preload("res://scripts/systems/WorldGenerator.gd")
const EnemyCatalog = preload("res://scripts/catalogs/EnemyCatalog.gd")
const BackgroundCatalog = preload("res://scripts/catalogs/BackgroundCatalog.gd")
const PrefabTemplateRegistry = preload("res://scripts/systems/PrefabTemplateRegistry.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_deterministic_and_varied_layouts()
	_test_no_overlap_and_level_baselines()
	_test_connectivity()
	_test_buildings_have_terraria_style_background_walls()
	_test_reference_setpieces_are_prioritized()
	_test_band_and_starter_avoidance()
	_test_chunk_boundary_stability()
	_test_spawn_markers_are_hostile_goblins()
	if failures.is_empty():
		print("Deepbound Godot goblin village tests passed.")
		quit(0)
	else:
		print("Deepbound Godot goblin village tests failed: %d" % failures.size())
		quit(1)

func _test_deterministic_and_varied_layouts() -> void:
	var region := _find_first_village_region(133742)
	_assert(region != Vector2i(999999, 999999), "test seed should produce at least one goblin village region")
	var first := StructureGenerator.build_goblin_village(133742, region)
	var second := StructureGenerator.build_goblin_village(133742, region)
	_assert(_layout_signature(first) == _layout_signature(second), "same seed and region should produce the same goblin village")
	var other_region := _find_different_village_region(133742, region)
	_assert(other_region != Vector2i(999999, 999999), "test seed should produce a second goblin village region")
	var other := StructureGenerator.build_goblin_village(133742, other_region)
	_assert(_layout_signature(first) != _layout_signature(other), "different goblin village regions should vary building order or placement")

func _test_no_overlap_and_level_baselines() -> void:
	var structure := _find_first_village(133742)
	_assert(not structure.is_empty(), "goblin village should be generated for overlap test")
	for i in range(structure.buildings.size()):
		var a: Dictionary = structure.buildings[i]
		_assert(absi(int(a.baseline) - int(structure.baseline)) <= 2, "goblin building baseline should stay near chamber level: %s" % a.id)
		for j in range(i + 1, structure.buildings.size()):
			var b: Dictionary = structure.buildings[j]
			_assert(not _rects_intersect(a.padded_rect, b.padded_rect), "goblin building padded rects should not overlap: %s / %s" % [a.id, b.id])

func _test_connectivity() -> void:
	var structure := _find_first_village(133742)
	var passable := {}
	for tile in Dictionary(structure.tiles).keys():
		if String(structure.tiles[tile]) == "air":
			passable[tile] = true
	var hub := _find_building(structure, "goblin_hub")
	var start := _first_passable_entrance(hub, passable)
	_assert(passable.has(start), "goblin hub should have a passable connected entrance")
	var reached := _flood_fill(start, passable)
	for building in structure.buildings:
		var entrance := _first_passable_entrance(building, passable)
		_assert(reached.has(entrance), "goblin village should connect hub to building entrance: %s" % building.id)

func _test_buildings_have_terraria_style_background_walls() -> void:
	var structure := _find_first_village(133742)
	var backgrounds: Dictionary = structure.get("backgrounds", {})
	_assert(not backgrounds.is_empty(), "goblin village should stamp a background wall layer behind its rooms")
	for background_id in ["goblin_timber_background", "goblin_hide_background", "goblin_packed_earth_background"]:
		var background_def := BackgroundCatalog.get_background(background_id)
		_assert(not background_def.is_empty() and BackgroundCatalog.is_breakable(background_id), "goblin village background should be a breakable wall: %s" % background_id)

	var seen_backgrounds := {}
	var connector_backing_found := false
	for tile in backgrounds.keys():
		var background_id := String(backgrounds[tile])
		seen_backgrounds[background_id] = true
		var tile_coord: Vector2i = tile
		if String(structure.tiles.get(tile_coord, "")) == "air" and not _tile_inside_any_building(structure, tile_coord):
			connector_backing_found = true
	_assert(seen_backgrounds.has("goblin_timber_background"), "goblin rooms should use timber backwalls")
	_assert(seen_backgrounds.has("goblin_hide_background"), "goblin rooms should include stitched hide backwall patches")
	_assert(seen_backgrounds.has("goblin_packed_earth_background"), "goblin corridors should use packed-earth wall backing")
	_assert(connector_backing_found, "goblin building connectors should have background wall backing")

	for building in structure.buildings:
		var passable_tiles := 0
		var backed_tiles := 0
		for tile in Dictionary(structure.tiles).keys():
			var tile_coord: Vector2i = tile
			if not _rect_contains_tile(building.rect, tile_coord):
				continue
			if String(structure.tiles[tile_coord]) != "air":
				continue
			passable_tiles += 1
			if String(backgrounds.get(tile_coord, "")).begins_with("goblin_"):
				backed_tiles += 1
		if passable_tiles > 0:
			_assert(backed_tiles >= passable_tiles, "passable goblin room interior should be fully backed by village walls: %s" % building.id)

	var template_structure := _find_first_template_village(133742)
	_assert(not template_structure.is_empty(), "template-backed goblin village should exist for chunk background overlay testing")
	var template_backgrounds: Dictionary = template_structure.get("backgrounds", {})
	var sample_tile: Vector2i = template_backgrounds.keys()[0]
	var store := ChunkStore.new(133742)
	_assert(store.get_background_tile(sample_tile) == String(template_backgrounds[sample_tile]), "chunk background generation should apply template-backed goblin village wall overlays")

func _test_reference_setpieces_are_prioritized() -> void:
	var structure := _find_first_village(133742)
	var setpiece_ids := {
		"goblin_ladder_shaft": true,
		"goblin_raised_hut": true,
		"goblin_scaffold_market": true,
	}
	var found_setpiece := false
	for building in structure.buildings:
		if setpiece_ids.has(String(building.id)):
			found_setpiece = true
	_assert(found_setpiece, "generated goblin villages should prioritize at least one reference-image ladder, hut, or scaffold setpiece")
	var found_plank_connector := false
	for connector in structure.connectors:
		if String(connector.get("floor_tile", "")) == "goblin_plank_platform":
			found_plank_connector = true
	_assert(found_plank_connector, "reference-image setpieces should connect back to the chamber with plank platform floors")

func _test_band_and_starter_avoidance() -> void:
	for ry in range(0, 8):
		for rx in range(-8, 9):
			var structure := StructureGenerator.build_goblin_village(133742, Vector2i(rx, ry))
			if structure.is_empty():
				continue
			_assert(int(structure.rect.position.y) >= 48, "goblin village should not start above Band 1 village range")
			_assert(int(structure.rect.position.y + structure.rect.size.y - 1) <= 340, "goblin village should not leave Band 1 village range")
			_assert(not _rects_intersect(structure.rect, Rect2i(Vector2i(-40, 0), Vector2i(80, 48))), "goblin village should avoid the starter cave")

func _test_chunk_boundary_stability() -> void:
	var structure := _find_first_template_village(133742)
	var boundary_pair := _find_boundary_pair(structure)
	_assert(boundary_pair.size() == 2, "template-backed goblin village should expose at least one tile pair for chunk stability testing")
	var left_tile: Vector2i = boundary_pair[0]
	var right_tile: Vector2i = boundary_pair[1]
	var store_a := ChunkStore.new(133742)
	var store_b := ChunkStore.new(133742)
	var right_before_left := store_b.get_tile(right_tile)
	var left_after_right := store_b.get_tile(left_tile)
	var left_before_right := store_a.get_tile(left_tile)
	var right_after_left := store_a.get_tile(right_tile)
	_assert(left_before_right == left_after_right, "left boundary tile should be stable regardless of neighbor chunk generation order")
	_assert(right_before_left == right_after_left, "right boundary tile should be stable regardless of neighbor chunk generation order")
	_assert(left_before_right == String(structure.tiles[left_tile]), "left boundary tile should match template structure overlay")
	_assert(right_after_left == String(structure.tiles[right_tile]), "right boundary tile should match template structure overlay")

func _test_spawn_markers_are_hostile_goblins() -> void:
	var structure := _find_first_template_village(133742)
	var structure_rect: Rect2i = structure.rect
	var center := structure_rect.position + Vector2i(structure_rect.size.x / 2, structure_rect.size.y / 2)
	var spawns: Array[Dictionary] = StructureGenerator.get_structure_spawns_near(133742, center, 80)
	_assert(spawns.size() >= 3, "nearby goblin village should expose multiple hostile spawn markers")
	var structure_ids := {}
	for spawn in spawns:
		structure_ids[String(spawn.structure_id)] = true
		var enemy_id := String(spawn.enemy_id)
		_assert(enemy_id.begins_with("goblin_"), "structure spawn should be a goblin enemy: %s" % enemy_id)
		_assert(String(EnemyCatalog.get_enemy(enemy_id).band) == "standard_caverns", "goblin village enemies should belong to Band 1")
	_assert(structure_ids.has(String(structure.id)), "spawn lookup should include the nearby template village structure id")

func _find_first_village(seed: int) -> Dictionary:
	var region := _find_first_village_region(seed)
	return {} if region == Vector2i(999999, 999999) else StructureGenerator.build_goblin_village(seed, region)

func _find_first_village_region(seed: int) -> Vector2i:
	for ry in range(1, 7):
		for rx in range(-8, 9):
			var region := Vector2i(rx, ry)
			if not StructureGenerator.build_goblin_village(seed, region).is_empty():
				return region
	return Vector2i(999999, 999999)

func _find_different_village_region(seed: int, first_region: Vector2i) -> Vector2i:
	var first := StructureGenerator.build_goblin_village(seed, first_region)
	var first_signature := _layout_signature(first)
	for ry in range(1, 7):
		for rx in range(-12, 13):
			var region := Vector2i(rx, ry)
			if region == first_region:
				continue
			var structure := StructureGenerator.build_goblin_village(seed, region)
			if not structure.is_empty() and _layout_signature(structure) != first_signature:
				return region
	return Vector2i(999999, 999999)

func _find_first_template_village(seed: int) -> Dictionary:
	PrefabTemplateRegistry.clear_cache()
	for chunk_y in range(0, 12):
		for chunk_x in range(-18, 19):
			for structure in StructureGenerator.get_structures_overlapping_chunk(seed, Vector2i(chunk_x, chunk_y)):
				if String(structure.get("source_template_id", "")) == "goblin_village_full":
					return structure
	return {}

func _layout_signature(structure: Dictionary) -> String:
	if structure.is_empty():
		return ""
	var parts: Array[String] = []
	for building in structure.buildings:
		parts.append("%s@%d,%d" % [String(building.id), int(building.origin.x), int(building.origin.y)])
	return "|".join(parts)

func _find_building(structure: Dictionary, building_id: String) -> Dictionary:
	for building in structure.buildings:
		if String(building.id) == building_id:
			return building
	return {}

func _first_passable_entrance(building: Dictionary, passable: Dictionary) -> Vector2i:
	for side in Dictionary(building.entrances).keys():
		var entrance: Vector2i = building.entrances[side]
		if passable.has(entrance):
			return entrance
	return Dictionary(building.entrances).values()[0]

func _flood_fill(start: Vector2i, passable: Dictionary) -> Dictionary:
	var reached := {}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if reached.has(current) or not passable.has(current):
			continue
		reached[current] = true
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			queue.append(current + offset)
	return reached

func _find_boundary_pair(structure: Dictionary) -> Array[Vector2i]:
	for tile in Dictionary(structure.tiles).keys():
		var tile_coord: Vector2i = tile
		var neighbor := tile_coord + Vector2i.RIGHT
		if tile_coord.x % 32 == 31 and Dictionary(structure.tiles).has(neighbor):
			return [tile_coord, neighbor]
	for tile in Dictionary(structure.tiles).keys():
		var tile_coord: Vector2i = tile
		var neighbor := tile_coord + Vector2i.RIGHT
		if Dictionary(structure.tiles).has(neighbor):
			return [tile_coord, neighbor]
	return []

func _tile_inside_any_building(structure: Dictionary, tile: Vector2i) -> bool:
	for building in structure.buildings:
		if _rect_contains_tile(building.rect, tile):
			return true
	return false

func _rect_contains_tile(rect: Rect2i, tile: Vector2i) -> bool:
	return tile.x >= rect.position.x and tile.y >= rect.position.y and tile.x < rect.position.x + rect.size.x and tile.y < rect.position.y + rect.size.y

func _rects_intersect(a: Rect2i, b: Rect2i) -> bool:
	return a.position.x < b.position.x + b.size.x and a.position.x + a.size.x > b.position.x and a.position.y < b.position.y + b.size.y and a.position.y + a.size.y > b.position.y
