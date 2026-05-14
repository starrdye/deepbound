extends RefCounted
class_name ChunkStore

const WorldGenerator = preload("res://scripts/systems/WorldGenerator.gd")
const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")

const CHUNK_SIZE := 32
var seed := 133742
var chunks: Dictionary = {}
var overrides: Dictionary = {}
var damage: Dictionary = {}

func _init(world_seed := 133742) -> void:
	seed = world_seed

func to_chunk_coord(tile: Vector2i) -> Vector2i:
	return Vector2i(floori(float(tile.x) / CHUNK_SIZE), floori(float(tile.y) / CHUNK_SIZE))

func to_local_tile(tile: Vector2i) -> Vector2i:
	return Vector2i(((tile.x % CHUNK_SIZE) + CHUNK_SIZE) % CHUNK_SIZE, ((tile.y % CHUNK_SIZE) + CHUNK_SIZE) % CHUNK_SIZE)

func get_chunk(chunk: Vector2i) -> Array[String]:
	if not chunks.has(chunk):
		chunks[chunk] = WorldGenerator.generate_chunk(seed, chunk)
	return chunks[chunk]

func get_tile(tile: Vector2i) -> String:
	if overrides.has(tile):
		return String(overrides[tile])
	var chunk := get_chunk(to_chunk_coord(tile))
	var local := to_local_tile(tile)
	return String(chunk[local.y * CHUNK_SIZE + local.x])

func set_tile(tile: Vector2i, tile_id: String) -> void:
	overrides[tile] = tile_id
	damage.erase(tile)

func get_damage(tile: Vector2i) -> float:
	return float(damage.get(tile, 0.0))

func set_damage(tile: Vector2i, value: float) -> void:
	damage[tile] = value

func clear_damage(tile: Vector2i) -> void:
	damage.erase(tile)

func is_solid(tile: Vector2i) -> bool:
	return TileCatalog.is_solid(get_tile(tile))

