extends SceneTree

const ChunkStore = preload("res://scripts/systems/ChunkStore.gd")
const StructureGenerator = preload("res://scripts/systems/StructureGenerator.gd")
const WorldGenerator = preload("res://scripts/systems/WorldGenerator.gd")
const EnemyCatalog = preload("res://scripts/catalogs/EnemyCatalog.gd")

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
	var structure := _find_first_village(133742)
	var boundary_pair := _find_boundary_pair(structure)
	_assert(boundary_pair.size() == 2, "goblin village should expose at least one tile pair for chunk stability testing")
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
	_assert(left_before_right == String(structure.tiles[left_tile]), "left boundary tile should match structure overlay")
	_assert(right_after_left == String(structure.tiles[right_tile]), "right boundary tile should match structure overlay")

func _test_spawn_markers_are_hostile_goblins() -> void:
	var structure := _find_first_village(133742)
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
	_assert(structure_ids.has(String(structure.id)), "spawn lookup should include the nearby village structure id")

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

func _rects_intersect(a: Rect2i, b: Rect2i) -> bool:
	return a.position.x < b.position.x + b.size.x and a.position.x + a.size.x > b.position.x and a.position.y < b.position.y + b.size.y and a.position.y + a.size.y > b.position.y
