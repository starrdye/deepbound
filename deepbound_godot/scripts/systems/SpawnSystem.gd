extends RefCounted
class_name SpawnSystem

const EnemyCatalog = preload("res://scripts/catalogs/EnemyCatalog.gd")
const CollisionSystem = preload("res://scripts/systems/CollisionSystem.gd")

const TILE_SIZE := 16
const SEARCH_RADIUS_TILES := 18

static func find_enemy_spawn(enemy_id: String, desired_position: Vector2, anchor_position: Vector2, world) -> Dictionary:
	var collider := EnemyCatalog.get_collider(enemy_id)
	var desired_tile := _world_to_tile(desired_position)
	var preferred_direction := 1 if desired_position.x >= anchor_position.x else -1

	var floor_spawn := _find_floor_spawn(desired_tile, preferred_direction, collider, world)
	if bool(floor_spawn.found):
		return floor_spawn

	var open_spawn := _find_open_spawn(desired_tile, preferred_direction, collider, world)
	if bool(open_spawn.found):
		return open_spawn

	return {"found": false, "position": desired_position, "reason": "no_clearance"}

static func _find_floor_spawn(center_tile: Vector2i, preferred_direction: int, collider: Dictionary, world) -> Dictionary:
	for radius in range(SEARCH_RADIUS_TILES + 1):
		for candidate in _ring_tiles(center_tile, radius, preferred_direction):
			if not world.is_solid_tile(candidate):
				continue
			var position := Vector2((float(candidate.x) + 0.5) * TILE_SIZE, float(candidate.y * TILE_SIZE) - CollisionSystem.SKIN_WIDTH)
			if _is_clear(position, collider, world):
				return {"found": true, "position": position, "floor_tile": candidate}
	return {"found": false}

static func _find_open_spawn(center_tile: Vector2i, preferred_direction: int, collider: Dictionary, world) -> Dictionary:
	for radius in range(SEARCH_RADIUS_TILES + 1):
		for candidate in _ring_tiles(center_tile, radius, preferred_direction):
			var position := Vector2((float(candidate.x) + 0.5) * TILE_SIZE, float((candidate.y + 1) * TILE_SIZE) - CollisionSystem.SKIN_WIDTH)
			if _is_clear(position, collider, world):
				return {"found": true, "position": position, "open_tile": candidate}
	return {"found": false}

static func _is_clear(position: Vector2, collider: Dictionary, world) -> bool:
	return not CollisionSystem.overlaps_tiles(position, collider, world)

static func _world_to_tile(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / TILE_SIZE), floori(position.y / TILE_SIZE))

static func _ring_tiles(center_tile: Vector2i, radius: int, preferred_direction: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if radius == 0:
		tiles.append(center_tile)
		return tiles

	for dx_abs in range(radius + 1):
		var signed_offsets: Array[int] = []
		if dx_abs == 0:
			signed_offsets.append(0)
		else:
			signed_offsets.append(dx_abs * preferred_direction)
			signed_offsets.append(-dx_abs * preferred_direction)

		for dx in signed_offsets:
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				tiles.append(center_tile + Vector2i(dx, dy))
	return tiles
