extends RefCounted
class_name ChunkStore

const WorldGenerator = preload("res://scripts/systems/WorldGenerator.gd")
const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")

const CHUNK_SIZE := 32
var seed := 133742
var chunks: Dictionary = {}
var background_chunks: Dictionary = {}
var overrides: Dictionary = {}
var background_overrides: Dictionary = {}
var damage: Dictionary = {}
var background_damage: Dictionary = {}
var generated_chunk_count := 0
var generated_background_chunk_count := 0

func _init(world_seed := 133742) -> void:
	seed = world_seed

func to_chunk_coord(tile: Vector2i) -> Vector2i:
	return Vector2i(floori(float(tile.x) / CHUNK_SIZE), floori(float(tile.y) / CHUNK_SIZE))

func to_local_tile(tile: Vector2i) -> Vector2i:
	return Vector2i(((tile.x % CHUNK_SIZE) + CHUNK_SIZE) % CHUNK_SIZE, ((tile.y % CHUNK_SIZE) + CHUNK_SIZE) % CHUNK_SIZE)

func get_chunk(chunk: Vector2i) -> Array[String]:
	if not chunks.has(chunk):
		chunks[chunk] = WorldGenerator.generate_chunk(seed, chunk)
		generated_chunk_count += 1
	return chunks[chunk]

func get_background_chunk(chunk: Vector2i) -> Array[String]:
	if not background_chunks.has(chunk):
		background_chunks[chunk] = WorldGenerator.generate_background_chunk(seed, chunk)
		generated_background_chunk_count += 1
	return background_chunks[chunk]

func warm_chunk(chunk: Vector2i, include_background := true) -> int:
	var generated := 0
	if not chunks.has(chunk):
		get_chunk(chunk)
		generated += 1
	if include_background and not background_chunks.has(chunk):
		get_background_chunk(chunk)
		generated += 1
	return generated

func is_chunk_warmed(chunk: Vector2i, include_background := true) -> bool:
	return chunks.has(chunk) and (not include_background or background_chunks.has(chunk))

func reset_debug_counters() -> void:
	generated_chunk_count = 0
	generated_background_chunk_count = 0

func has_generated_chunk(chunk: Vector2i) -> bool:
	return chunks.has(chunk)

func has_generated_background_chunk(chunk: Vector2i) -> bool:
	return background_chunks.has(chunk)

func get_generated_chunk_coords(include_background := true) -> Array[Vector2i]:
	var seen := {}
	for raw_chunk in chunks.keys():
		seen[_chunk_key(_data_to_chunk(raw_chunk))] = _data_to_chunk(raw_chunk)
	if include_background:
		for raw_chunk in background_chunks.keys():
			seen[_chunk_key(_data_to_chunk(raw_chunk))] = _data_to_chunk(raw_chunk)
	var coords: Array[Vector2i] = []
	for key in seen.keys():
		coords.append(seen[key])
	coords.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y if a.x == b.x else a.x < b.x)
	return coords

func export_generated_chunks() -> Dictionary:
	return _chunk_dictionary_to_data(chunks)

func export_generated_background_chunks() -> Dictionary:
	return _chunk_dictionary_to_data(background_chunks)

func import_generated_chunks(data: Dictionary) -> void:
	chunks = _chunk_dictionary_from_data(data)

func import_generated_background_chunks(data: Dictionary) -> void:
	background_chunks = _chunk_dictionary_from_data(data)

func get_tile(tile: Vector2i) -> String:
	if overrides.has(tile):
		return String(overrides[tile])
	var chunk := get_chunk(to_chunk_coord(tile))
	var local := to_local_tile(tile)
	return String(chunk[local.y * CHUNK_SIZE + local.x])

func get_background_tile(tile: Vector2i) -> String:
	if background_overrides.has(tile):
		return String(background_overrides[tile])
	var chunk := get_background_chunk(to_chunk_coord(tile))
	var local := to_local_tile(tile)
	return String(chunk[local.y * CHUNK_SIZE + local.x])

func set_tile(tile: Vector2i, tile_id: String) -> void:
	overrides[tile] = tile_id
	damage.erase(tile)

func set_background_tile(tile: Vector2i, background_id: String) -> void:
	background_overrides[tile] = background_id
	background_damage.erase(tile)

func get_damage(tile: Vector2i) -> float:
	return float(damage.get(tile, 0.0))

func set_damage(tile: Vector2i, value: float) -> void:
	damage[tile] = value

func clear_damage(tile: Vector2i) -> void:
	damage.erase(tile)

func get_background_damage(tile: Vector2i) -> float:
	return float(background_damage.get(tile, 0.0))

func set_background_damage(tile: Vector2i, value: float) -> void:
	background_damage[tile] = value

func clear_background_damage(tile: Vector2i) -> void:
	background_damage.erase(tile)

func is_solid(tile: Vector2i) -> bool:
	return TileCatalog.is_solid(get_tile(tile))

static func _chunk_dictionary_to_data(source: Dictionary) -> Dictionary:
	var result := {}
	var coords: Array[Vector2i] = []
	for raw_chunk in source.keys():
		coords.append(_data_to_chunk(raw_chunk))
	coords.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y if a.x == b.x else a.x < b.x)
	for chunk in coords:
		var tiles := _normalized_chunk_tiles(source.get(chunk, []))
		if tiles.size() == CHUNK_SIZE * CHUNK_SIZE:
			result[_chunk_key(chunk)] = tiles
	return result

static func _chunk_dictionary_from_data(data: Dictionary) -> Dictionary:
	var result := {}
	var keys := data.keys()
	keys.sort()
	for raw_key in keys:
		var chunk := _chunk_from_key(String(raw_key))
		var tiles := _normalized_chunk_tiles(data.get(raw_key, []))
		if tiles.size() == CHUNK_SIZE * CHUNK_SIZE:
			result[chunk] = tiles
	return result

static func _normalized_chunk_tiles(data) -> Array[String]:
	var tiles: Array[String] = []
	if not (data is Array):
		return tiles
	var source: Array = data
	if source.size() != CHUNK_SIZE * CHUNK_SIZE:
		return tiles
	for tile_id in source:
		tiles.append(String(tile_id))
	return tiles

static func _chunk_key(chunk: Vector2i) -> String:
	return "%d,%d" % [chunk.x, chunk.y]

static func _chunk_from_key(key: String) -> Vector2i:
	var parts := key.split(",", false)
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

static func _data_to_chunk(data) -> Vector2i:
	if data is Vector2i:
		return data
	if data is Vector2:
		return Vector2i(int(data.x), int(data.y))
	if data is Dictionary:
		var dict := Dictionary(data)
		return Vector2i(int(dict.get("x", 0)), int(dict.get("y", 0)))
	if data is String:
		return _chunk_from_key(String(data))
	return Vector2i.ZERO
