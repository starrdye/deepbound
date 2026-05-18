extends RefCounted
class_name StructureGenerator

const VillageCatalog = preload("res://scripts/catalogs/VillageCatalog.gd")
const PrefabTemplateRegistry = preload("res://scripts/systems/PrefabTemplateRegistry.gd")

const CHUNK_SIZE := 32
const REGION_SIZE := Vector2i(96, 56)
const BAND1_MIN_Y := 48
const BAND1_MAX_Y := 340
const VILLAGE_CHANCE := 0.46
const MAX_BASELINE_JITTER := 2
const BUILDING_GAP := 5
const DOORWAY_CARVE_DEPTH := 6
const RECT_PADDING := 2
const STRUCTURE_SEARCH_MARGIN := 96
const STARTER_AVOID_RECT := Rect2i(Vector2i(-40, 0), Vector2i(80, 48))
const GOBLIN_SETPIECE_BUILDINGS := [
	"goblin_ladder_shaft",
	"goblin_raised_hut",
	"goblin_scaffold_market",
]

static func hash_i(value: int) -> int:
	var h := value & 0x7fffffff
	h = int((h ^ (h >> 16)) & 0x7fffffff)
	h = int((h * 1103515245 + 12345) & 0x7fffffff)
	h = int((h ^ (h >> 13)) & 0x7fffffff)
	return h

static func _region_hash(seed: int, region_coord: Vector2i, salt: int) -> int:
	return hash_i(seed ^ (region_coord.x * 73856093) ^ (region_coord.y * 19349663) ^ (salt * 83492791))

static func _roll01(seed: int, region_coord: Vector2i, salt: int) -> float:
	return float(_region_hash(seed, region_coord, salt) % 10000) / 9999.0

static func _rand_range(seed: int, region_coord: Vector2i, salt: int, min_value: int, max_value: int) -> int:
	return min_value + int(_region_hash(seed, region_coord, salt) % (max_value - min_value + 1))

static func get_structures_overlapping_chunk(seed: int, chunk: Vector2i) -> Array[Dictionary]:
	return PrefabTemplateRegistry.get_structures_overlapping_chunk(seed, chunk)

static func build_goblin_village(seed: int, region_coord: Vector2i) -> Dictionary:
	if not _is_goblin_region_eligible(seed, region_coord):
		return {}
	var village := VillageCatalog.get_village("goblin_village")
	if village.is_empty():
		return {}

	var region_origin := Vector2i(region_coord.x * REGION_SIZE.x, region_coord.y * REGION_SIZE.y)
	var baseline := clampi(region_origin.y + 18 + _rand_range(seed, region_coord, 11, 0, 18), BAND1_MIN_Y + 10, BAND1_MAX_Y - 10)
	var base_x := region_origin.x + 16 + _rand_range(seed, region_coord, 12, 0, 12)
	var hub_left := _rand_range(seed, region_coord, 13, 0, 1) == 0
	var buildings: Array[Dictionary] = []
	var connectors: Array[Dictionary] = []
	var tiles: Dictionary = {}
	var backgrounds: Dictionary = {}
	var spawns: Array[Dictionary] = []
	var props: Array[Dictionary] = []

	var hub := _make_building_instance("goblin_hub", Vector2i.ZERO, baseline)
	var chamber := _make_building_instance("goblin_village_chamber", Vector2i.ZERO, baseline)
	if hub.is_empty() or chamber.is_empty():
		return {}

	if hub_left:
		hub = _make_building_instance("goblin_hub", Vector2i(base_x, baseline - int(hub.floor_row)), baseline)
		chamber = _make_building_instance("goblin_village_chamber", Vector2i(base_x + int(hub.footprint.x) + BUILDING_GAP, baseline - int(chamber.floor_row)), baseline)
	else:
		chamber = _make_building_instance("goblin_village_chamber", Vector2i(base_x, baseline - int(chamber.floor_row)), baseline)
		hub = _make_building_instance("goblin_hub", Vector2i(base_x + int(chamber.footprint.x) + BUILDING_GAP, baseline - int(hub.floor_row)), baseline)

	buildings.append(hub)
	buildings.append(chamber)
	_add_connector(_entrance_tile(hub, "right" if hub_left else "left"), int(hub.baseline), _entrance_tile(chamber, "left" if hub_left else "right"), int(chamber.baseline), connectors)

	var current_left := mini(int(hub.rect.position.x), int(chamber.rect.position.x))
	var current_right := maxi(int(hub.rect.position.x + hub.rect.size.x), int(chamber.rect.position.x + chamber.rect.size.x))
	var optional_ids := _optional_building_order(seed, region_coord, village)
	var optional_count := mini(optional_ids.size(), 3 + _rand_range(seed, region_coord, 21, 0, 2))
	var side_start := _rand_range(seed, region_coord, 22, 0, 1)
	for index in range(optional_count):
		var building_id := String(optional_ids[index])
		var def := VillageCatalog.get_building(building_id)
		if def.is_empty():
			continue
		var footprint := Vector2i(int(def.footprint[0]), int(def.footprint[1]))
		var building_baseline := baseline + _rand_range(seed, region_coord, 30 + index, -MAX_BASELINE_JITTER, MAX_BASELINE_JITTER)
		var side := -1 if (index + side_start) % 2 == 0 else 1
		var origin_x := current_left - BUILDING_GAP - footprint.x if side < 0 else current_right + BUILDING_GAP
		var origin := Vector2i(origin_x, building_baseline - int(def.floor_row))
		var instance := _make_building_instance(building_id, origin, building_baseline)
		if instance.is_empty() or _overlaps_existing(instance, buildings):
			continue
		buildings.append(instance)
		if side < 0:
			current_left = origin_x
			_add_connector(_entrance_tile(instance, "right"), int(instance.baseline), _entrance_tile(chamber, "left"), int(chamber.baseline), connectors, _goblin_connector_floor_tile(building_id))
		else:
			current_right = origin_x + footprint.x
			_add_connector(_entrance_tile(chamber, "right"), int(chamber.baseline), _entrance_tile(instance, "left"), int(instance.baseline), connectors, _goblin_connector_floor_tile(building_id))

	for building in buildings:
		_stamp_building(building, village, tiles, backgrounds, props, spawns)
	var connector_air_tiles := {}
	var connector_floor_tiles := {}
	for connector in connectors:
		_collect_connector_tiles(connector, connector_air_tiles, connector_floor_tiles)
	for tile in connector_air_tiles.keys():
		tiles[tile] = "air"
		backgrounds[tile] = _goblin_connector_background_id(tile)
	for tile in connector_floor_tiles.keys():
		if not connector_air_tiles.has(tile):
			tiles[tile] = String(connector_floor_tiles[tile])

	var rect := _tiles_rect(tiles)
	if rect.size == Vector2i.ZERO:
		return {}
	if rect.position.y < BAND1_MIN_Y or rect.position.y + rect.size.y - 1 > BAND1_MAX_Y:
		return {}

	return {
		"id": "goblin_village_%d_%d" % [region_coord.x, region_coord.y],
		"type": "goblin_village",
		"region": region_coord,
		"baseline": baseline,
		"rect": rect,
		"buildings": buildings,
		"connectors": connectors,
		"tiles": tiles,
		"backgrounds": backgrounds,
		"props": props,
		"spawns": spawns,
	}

static func apply_structure_tiles(seed: int, chunk: Vector2i, base_tiles: Array[String]) -> Array[String]:
	var result: Array[String] = base_tiles.duplicate()
	var chunk_rect := Rect2i(Vector2i(chunk.x * CHUNK_SIZE, chunk.y * CHUNK_SIZE), Vector2i(CHUNK_SIZE, CHUNK_SIZE))
	for structure in get_structures_overlapping_chunk(seed, chunk):
		for tile in Dictionary(structure.tiles).keys():
			var tile_coord: Vector2i = tile
			if not _rect_contains_tile(chunk_rect, tile_coord):
				continue
			var local := Vector2i(tile_coord.x - chunk_rect.position.x, tile_coord.y - chunk_rect.position.y)
			result[local.y * CHUNK_SIZE + local.x] = String(structure.tiles[tile_coord])
	return result

static func apply_structure_backgrounds(seed: int, chunk: Vector2i, base_backgrounds: Array[String]) -> Array[String]:
	var result: Array[String] = base_backgrounds.duplicate()
	var chunk_rect := Rect2i(Vector2i(chunk.x * CHUNK_SIZE, chunk.y * CHUNK_SIZE), Vector2i(CHUNK_SIZE, CHUNK_SIZE))
	for structure in get_structures_overlapping_chunk(seed, chunk):
		for tile in Dictionary(structure.get("backgrounds", {})).keys():
			var tile_coord: Vector2i = tile
			if not _rect_contains_tile(chunk_rect, tile_coord):
				continue
			var local := Vector2i(tile_coord.x - chunk_rect.position.x, tile_coord.y - chunk_rect.position.y)
			result[local.y * CHUNK_SIZE + local.x] = String(structure.backgrounds[tile_coord])
	return result

static func get_structure_spawns_near(seed: int, center_tile: Vector2i, radius_tiles: int) -> Array[Dictionary]:
	return PrefabTemplateRegistry.get_structure_spawns_near(seed, center_tile, radius_tiles)

static func get_structure_lights_near(seed: int, center_tile: Vector2i, radius_tiles: int) -> Array[Dictionary]:
	return PrefabTemplateRegistry.get_structure_lights_near(seed, center_tile, radius_tiles)

static func get_structure_containers_near(seed: int, center_tile: Vector2i, radius_tiles: int) -> Array[Dictionary]:
	return PrefabTemplateRegistry.get_structure_containers_near(seed, center_tile, radius_tiles)

static func _is_goblin_region_eligible(seed: int, region_coord: Vector2i) -> bool:
	var region_rect := Rect2i(Vector2i(region_coord.x * REGION_SIZE.x, region_coord.y * REGION_SIZE.y), REGION_SIZE)
	if region_rect.position.y + region_rect.size.y < BAND1_MIN_Y or region_rect.position.y > BAND1_MAX_Y:
		return false
	if _rects_intersect(region_rect, STARTER_AVOID_RECT):
		return false
	return _roll01(seed, region_coord, 5) <= VILLAGE_CHANCE

static func _make_building_instance(building_id: String, origin: Vector2i, baseline: int) -> Dictionary:
	var def := VillageCatalog.get_building(building_id)
	if def.is_empty():
		return {}
	var footprint := Vector2i(int(def.footprint[0]), int(def.footprint[1]))
	var rect := Rect2i(origin, footprint)
	var entrances := {}
	for side in Dictionary(def.entrances).keys():
		var local: Array = def.entrances[side]
		entrances[side] = origin + Vector2i(int(local[0]), int(local[1]))
	return {
		"id": building_id,
		"origin": origin,
		"footprint": footprint,
		"floor_row": int(def.floor_row),
		"baseline": baseline,
		"rect": rect,
		"padded_rect": _grow_rect(rect, RECT_PADDING),
		"entrances": entrances,
	}

static func _optional_building_order(seed: int, region_coord: Vector2i, village: Dictionary) -> Array:
	var ordered: Array = village.optional_buildings.duplicate()
	var start := _rand_range(seed, region_coord, 23, 0, ordered.size() - 1)
	var rotated: Array = []
	for i in range(ordered.size()):
		rotated.append(ordered[(start + i) % ordered.size()])
	if _rand_range(seed, region_coord, 24, 0, 1) == 1:
		rotated.reverse()
	var setpiece := String(GOBLIN_SETPIECE_BUILDINGS[_rand_range(seed, region_coord, 25, 0, GOBLIN_SETPIECE_BUILDINGS.size() - 1)])
	if rotated.has(setpiece):
		rotated.erase(setpiece)
		rotated.insert(0, setpiece)
	return rotated

static func _overlaps_existing(instance: Dictionary, buildings: Array[Dictionary]) -> bool:
	for existing in buildings:
		if _rects_intersect(instance.padded_rect, existing.padded_rect):
			return true
	return false

static func _stamp_building(building: Dictionary, village: Dictionary, tiles: Dictionary, backgrounds: Dictionary, props: Array[Dictionary], spawns: Array[Dictionary]) -> void:
	var def := VillageCatalog.get_building(String(building.id))
	var legend: Dictionary = village.symbol_legend
	var origin: Vector2i = building.origin
	for y in range(def.layout.size()):
		var row_text := String(def.layout[y])
		for x in range(row_text.length()):
			var symbol := row_text.substr(x, 1)
			var entry: Dictionary = Dictionary(legend.get(symbol, {}))
			if entry.is_empty() or String(entry.kind) == "ignore":
				continue
			var tile := origin + Vector2i(x, y)
			match String(entry.kind):
				"tile":
					tiles[tile] = String(entry.id)
				"empty":
					tiles[tile] = "air"
					backgrounds[tile] = _goblin_building_background_id(String(building.id), symbol, Vector2i(x, y))
				"prop":
					tiles[tile] = "air"
					backgrounds[tile] = _goblin_building_background_id(String(building.id), symbol, Vector2i(x, y))
					var marker := {"id": String(entry.id), "tile": tile, "building": String(building.id)}
					for metadata_key in ["size", "offset", "layer", "alpha"]:
						if entry.has(metadata_key):
							marker[metadata_key] = entry[metadata_key]
					props.append(marker)
				"spawn":
					tiles[tile] = "air"
					backgrounds[tile] = _goblin_building_background_id(String(building.id), symbol, Vector2i(x, y))
					spawns.append({"enemy_id": String(entry.id), "tile": tile, "building": String(building.id)})

static func _goblin_building_background_id(building_id: String, symbol: String, local_tile: Vector2i) -> String:
	if symbol in ["B", "D"] or local_tile.y <= 2:
		return "goblin_hide_background"
	var salt := building_id.length() * 19
	if hash_i(local_tile.x * 37 + local_tile.y * 71 + salt) % 11 == 0:
		return "goblin_packed_earth_background"
	return "goblin_timber_background"

static func _goblin_connector_background_id(tile: Vector2i) -> String:
	var h := hash_i(tile.x * 92821 + tile.y * 68917)
	if h % 7 == 0:
		return "goblin_timber_background"
	return "goblin_packed_earth_background"

static func _add_connector(a: Vector2i, a_baseline: int, b: Vector2i, b_baseline: int, connectors: Array[Dictionary], floor_tile := "goblin_packed_floor") -> void:
	connectors.append({"from": a, "to": b, "baseline_a": a_baseline, "baseline_b": b_baseline, "floor_tile": floor_tile})

static func _collect_connector_tiles(connector: Dictionary, air_tiles: Dictionary, floor_tiles: Dictionary) -> void:
	var a: Vector2i = connector.from
	var b: Vector2i = connector.to
	var a_baseline := int(connector.baseline_a)
	var b_baseline := int(connector.baseline_b)
	var floor_tile := String(connector.get("floor_tile", "goblin_packed_floor"))
	var min_x := mini(a.x, b.x) - DOORWAY_CARVE_DEPTH
	var max_x := maxi(a.x, b.x) + DOORWAY_CARVE_DEPTH
	var top_air := mini(a_baseline, b_baseline) - 3
	var bottom_air := maxi(a_baseline, b_baseline) - 1
	var floor_y := maxi(a_baseline, b_baseline)
	for x in range(min_x, max_x + 1):
		for y in range(top_air, bottom_air + 1):
			air_tiles[Vector2i(x, y)] = true
		floor_tiles[Vector2i(x, floor_y)] = floor_tile

static func _goblin_connector_floor_tile(building_id: String) -> String:
	return "goblin_plank_platform" if building_id in GOBLIN_SETPIECE_BUILDINGS else "goblin_packed_floor"

static func _entrance_tile(building: Dictionary, side: String) -> Vector2i:
	return building.entrances[side]

static func _tiles_rect(tiles: Dictionary) -> Rect2i:
	if tiles.is_empty():
		return Rect2i(Vector2i.ZERO, Vector2i.ZERO)
	var first := true
	var min_x := 0
	var min_y := 0
	var max_x := 0
	var max_y := 0
	for tile in tiles.keys():
		var tile_coord: Vector2i = tile
		if first:
			min_x = tile_coord.x
			max_x = tile_coord.x
			min_y = tile_coord.y
			max_y = tile_coord.y
			first = false
		else:
			min_x = mini(min_x, tile_coord.x)
			max_x = maxi(max_x, tile_coord.x)
			min_y = mini(min_y, tile_coord.y)
			max_y = maxi(max_y, tile_coord.y)
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))

static func _grow_rect(rect: Rect2i, amount: int) -> Rect2i:
	return Rect2i(rect.position - Vector2i(amount, amount), rect.size + Vector2i(amount * 2, amount * 2))

static func _rect_contains_tile(rect: Rect2i, tile: Vector2i) -> bool:
	return tile.x >= rect.position.x and tile.y >= rect.position.y and tile.x < rect.position.x + rect.size.x and tile.y < rect.position.y + rect.size.y

static func _rects_intersect(a: Rect2i, b: Rect2i) -> bool:
	return a.position.x < b.position.x + b.size.x and a.position.x + a.size.x > b.position.x and a.position.y < b.position.y + b.size.y and a.position.y + a.size.y > b.position.y
