extends RefCounted
class_name WorldGenerator

const BandCatalog = preload("res://scripts/catalogs/BandCatalog.gd")
const BackgroundCatalog = preload("res://scripts/catalogs/BackgroundCatalog.gd")
const StructureGenerator = preload("res://scripts/systems/StructureGenerator.gd")
const CHUNK_SIZE := 32

static func hash_i(value: int) -> int:
	var h := value & 0x7fffffff
	h = int((h ^ (h >> 16)) & 0x7fffffff)
	h = int((h * 1103515245 + 12345) & 0x7fffffff)
	h = int((h ^ (h >> 13)) & 0x7fffffff)
	return h

static func noise01(seed: int, x: int, y: int) -> float:
	var h := hash_i(seed ^ (x * 73856093) ^ (y * 19349663))
	return float(h % 10000) / 9999.0

static func _is_starter_cave(tile: Vector2i) -> bool:
	if tile.y < 0:
		return true
	var ellipse: float = (float(tile.x * tile.x) / float(19 * 19)) + (float((tile.y - 7) * (tile.y - 7)) / float(7 * 7))
	var shaft: bool = abs(tile.x) <= 2 and tile.y >= 7 and tile.y <= 28
	return ellipse <= 1.0 or shaft

static func _is_main_tunnel(seed: int, tile: Vector2i) -> bool:
	var drift: float = sin(float(tile.y) * 0.075 + float(seed) * 0.001) * 7.0 + sin(float(tile.y) * 0.021) * 12.0
	var half_width: float = 2.7 + noise01(seed, 3, floori(float(tile.y) / 9.0)) * 2.4
	return abs(float(tile.x) - drift) <= half_width

static func _is_side_pocket(seed: int, tile: Vector2i) -> bool:
	var cell_x: int = floori(float(tile.x) / 11.0)
	var cell_y: int = floori(float(tile.y) / 8.0)
	var n: float = noise01(seed + 17, cell_x, cell_y)
	if n < 0.83:
		return false
	var center: Vector2 = Vector2(float(cell_x * 11 + 5), float(cell_y * 8 + 4))
	var radius: float = 3.0 + n * 3.0
	return Vector2(float(tile.x), float(tile.y)).distance_to(center) < radius

static func generate_tile_id(seed: int, tile: Vector2i) -> String:
	if tile.y < 0:
		return "air"
	if tile.y >= BandCatalog.SOLID_DARK_START_TILE_Y:
		return "solid_dark_block"
	if _is_starter_cave(tile):
		return "air"
	if _is_main_tunnel(seed, tile) or _is_side_pocket(seed, tile):
		if tile.y >= 768 and tile.y < 1152 and tile.x % 13 == 0 and tile.y % 17 == 0:
			return "pressure_plate"
		return "air"

	var band_id: String = BandCatalog.resolve_band_id(tile.y)
	var local_noise: float = noise01(seed, tile.x, tile.y)
	var vein_noise: float = noise01(seed + 222, floori(float(tile.x) / 3.0), floori(float(tile.y) / 3.0))
	match band_id:
		"standard_caverns":
			if tile.y > 36 and vein_noise > 0.965:
				return "copper_ore"
			if tile.y < 96:
				return "compacted_dirt" if local_noise > 0.7 else "loose_dirt"
			if tile.y < 240:
				return "soft_stone" if local_noise > 0.42 else "compacted_dirt"
			return "soft_stone" if local_noise > 0.25 else "compacted_dirt"
		"colossal_ant_chambers":
			if tile.x % 17 == 0 and tile.y % 47 == 0:
				return "royal_jelly"
			return "hardened_resin" if local_noise > 0.38 else "compacted_dirt"
		"buried_pyramids":
			if tile.x % 19 == 0 and tile.y % 83 == 0:
				return "cursed_treasure"
			return "sandstone_block"
		"drow_enclaves":
			return "glow_mushroom_loam" if local_noise > 0.62 else "soft_stone"
		"abyssal_lava_slums":
			return "obsidian_ash" if local_noise > 0.2 else "soft_stone"
		_:
			return "solid_dark_block"

static func generate_chunk(seed: int, chunk: Vector2i) -> Array[String]:
	if chunk.y < 0:
		return _filled_chunk("air")
	var tiles: Array[String] = []
	for local_y in CHUNK_SIZE:
		for local_x in CHUNK_SIZE:
			var tile := Vector2i(chunk.x * CHUNK_SIZE + local_x, chunk.y * CHUNK_SIZE + local_y)
			tiles.append(generate_tile_id(seed, tile))
	if not _chunk_can_contain_band1_structure(chunk):
		return tiles
	return StructureGenerator.apply_structure_tiles(seed, chunk, tiles)

static func generate_background_id(seed: int, tile: Vector2i) -> String:
	if tile.y < 0 or tile.y >= BandCatalog.SOLID_DARK_START_TILE_Y:
		return BackgroundCatalog.EMPTY_ID
	var n := noise01(seed + 9091, tile.x, tile.y)
	match BandCatalog.resolve_band_id(tile.y):
		"standard_caverns":
			if tile.y < 96:
				return "dirt_background_block" if n > 0.18 else "stone_background_block"
			return "stone_background_block" if n > 0.24 else "dirt_background_block"
		"colossal_ant_chambers":
			return "dirt_background_block" if n > 0.36 else "stone_background_block"
		"buried_pyramids":
			return "stone_background_block"
		"drow_enclaves":
			return "stone_background_block"
		"abyssal_lava_slums":
			return "stone_background_block"
		_:
			return BackgroundCatalog.EMPTY_ID

static func generate_background_chunk(seed: int, chunk: Vector2i) -> Array[String]:
	if chunk.y < 0:
		return _filled_chunk(BackgroundCatalog.EMPTY_ID)
	var backgrounds: Array[String] = []
	for local_y in CHUNK_SIZE:
		for local_x in CHUNK_SIZE:
			var tile := Vector2i(chunk.x * CHUNK_SIZE + local_x, chunk.y * CHUNK_SIZE + local_y)
			backgrounds.append(generate_background_id(seed, tile))
	return backgrounds

static func _filled_chunk(tile_id: String) -> Array[String]:
	var tiles: Array[String] = []
	tiles.resize(CHUNK_SIZE * CHUNK_SIZE)
	tiles.fill(tile_id)
	return tiles

static func _chunk_can_contain_band1_structure(chunk: Vector2i) -> bool:
	var min_y := chunk.y * CHUNK_SIZE
	var max_y := min_y + CHUNK_SIZE - 1
	return max_y >= StructureGenerator.BAND1_MIN_Y and min_y <= StructureGenerator.BAND1_MAX_Y
