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
