extends SceneTree

const SpawnSystem = preload("res://scripts/systems/SpawnSystem.gd")
const CollisionSystem = preload("res://scripts/systems/CollisionSystem.gd")
const EnemyCatalog = preload("res://scripts/catalogs/EnemyCatalog.gd")
const ChunkStore = preload("res://scripts/systems/ChunkStore.gd")

const TILE_SIZE := 16

var failures: Array[String] = []

class TestWorld:
	var solids: Dictionary = {}

	func is_solid_tile(tile: Vector2i) -> bool:
		return bool(solids.get(tile, false))

	func set_solid(tile: Vector2i, solid := true) -> void:
		if solid:
			solids[tile] = true
		else:
			solids.erase(tile)

	func fill_rect(from_tile: Vector2i, to_tile: Vector2i) -> void:
		for y in range(from_tile.y, to_tile.y + 1):
			for x in range(from_tile.x, to_tile.x + 1):
				set_solid(Vector2i(x, y), true)

class GeneratedWorld:
	var store := ChunkStore.new(133742)

	func is_solid_tile(tile: Vector2i) -> bool:
		return store.is_solid(tile)

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_blocked_desired_spawn_moves_to_clear_floor()
	_test_tall_enemy_requires_headroom()
	_test_generated_encounter_spawns_are_clear()
	if failures.is_empty():
		print("Deepbound Godot spawn tests passed.")
		quit(0)
	else:
		print("Deepbound Godot spawn tests failed: %d" % failures.size())
		quit(1)

func _test_blocked_desired_spawn_moves_to_clear_floor() -> void:
	var world := TestWorld.new()
	world.fill_rect(Vector2i(-10, 5), Vector2i(10, 5))
	world.fill_rect(Vector2i(3, 2), Vector2i(5, 4))

	var desired := Vector2(4.5 * TILE_SIZE, 5.0 * TILE_SIZE - CollisionSystem.SKIN_WIDTH)
	var spawn := SpawnSystem.find_enemy_spawn("soldier_ant", desired, Vector2.ZERO, world)
	var collider := EnemyCatalog.get_collider("soldier_ant")
	_assert(CollisionSystem.overlaps_tiles(desired, collider, world), "test setup should put desired spawn inside solid terrain")
	_assert(bool(spawn.found), "spawn solver should find a nearby clear floor when desired point is blocked")
	_assert(not CollisionSystem.overlaps_tiles(spawn.position, collider, world), "soldier ant spawn should not overlap terrain")

func _test_tall_enemy_requires_headroom() -> void:
	var world := TestWorld.new()
	world.fill_rect(Vector2i(-8, 6), Vector2i(8, 6))
	world.fill_rect(Vector2i(1, 4), Vector2i(4, 4))

	var desired := Vector2(2.5 * TILE_SIZE, 6.0 * TILE_SIZE - CollisionSystem.SKIN_WIDTH)
	var spawn := SpawnSystem.find_enemy_spawn("mummy_sentry", desired, Vector2.ZERO, world)
	var collider := EnemyCatalog.get_collider("mummy_sentry")
	_assert(CollisionSystem.overlaps_tiles(desired, collider, world), "test setup should put tall desired spawn under a low ceiling")
	_assert(bool(spawn.found), "spawn solver should find headroom for tall enemies")
	_assert(not CollisionSystem.overlaps_tiles(spawn.position, collider, world), "mummy sentry spawn should not overlap ceiling or floor")

func _test_generated_encounter_spawns_are_clear() -> void:
	var world := GeneratedWorld.new()
	var cases := [
		{"enemy": "cave_skitter", "anchor": Vector2(-8 * TILE_SIZE, 13 * TILE_SIZE), "offset": Vector2(220, 0)},
		{"enemy": "worker_ant", "anchor": Vector2(-8 * TILE_SIZE, 390 * TILE_SIZE + 13 * TILE_SIZE), "offset": Vector2(190, 0)},
		{"enemy": "soldier_ant", "anchor": Vector2(-8 * TILE_SIZE, 390 * TILE_SIZE + 13 * TILE_SIZE), "offset": Vector2(260, 0)},
		{"enemy": "mummy_sentry", "anchor": Vector2(-8 * TILE_SIZE, 780 * TILE_SIZE + 13 * TILE_SIZE), "offset": Vector2(210, 0)}
	]
	for spawn_case in cases:
		var enemy_id := String(spawn_case.enemy)
		var anchor := Vector2(spawn_case.anchor)
		var desired := anchor + Vector2(spawn_case.offset)
		var spawn := SpawnSystem.find_enemy_spawn(enemy_id, desired, anchor, world)
		var collider := EnemyCatalog.get_collider(enemy_id)
		_assert(bool(spawn.found), "%s should find a generated-world spawn near its encounter offset" % enemy_id)
		_assert(not CollisionSystem.overlaps_tiles(spawn.position, collider, world), "%s generated spawn should be clear of solid tiles" % enemy_id)
