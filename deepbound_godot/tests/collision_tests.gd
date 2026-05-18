extends SceneTree

const CollisionSystem = preload("res://scripts/systems/CollisionSystem.gd")
const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")
const DroppedItemController = preload("res://scripts/controllers/DroppedItemController.gd")

const PLAYER_COLLIDER := {"width": 14.0, "height": 28.0}
const SKITTER_COLLIDER := {"width": 14.0, "height": 10.0}
const SOLDIER_ANT_COLLIDER := {"width": 22.0, "height": 12.0}
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

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	_assert(absf(actual - expected) <= tolerance, "%s expected %.3f got %.3f" % [message, expected, actual])

func _run() -> void:
	_test_player_lands_on_floor()
	_test_player_cannot_clip_through_wall()
	_test_player_slides_past_corner()
	_test_removed_adjacent_tile_does_not_embed_player()
	_test_enemy_uses_own_collider()
	await _test_dropped_item_collides_with_floor()
	if failures.is_empty():
		print("Deepbound Godot collision tests passed.")
		quit(0)
	else:
		print("Deepbound Godot collision tests failed: %d" % failures.size())
		quit(1)

func _test_player_lands_on_floor() -> void:
	var world := TestWorld.new()
	world.fill_rect(Vector2i(-4, 4), Vector2i(4, 4))
	var result := CollisionSystem.move_actor(Vector2(0, 24), Vector2(0, 500), 0.12, PLAYER_COLLIDER, world)
	_assert(bool(result.on_ground), "player should report on_ground after landing")
	_assert_near(result.position.y, float(4 * TILE_SIZE) - CollisionSystem.SKIN_WIDTH, 0.01, "player bottom should clamp to floor top")
	_assert_near(result.velocity.y, 0.0, 0.01, "player vertical velocity should zero on floor")
	_assert(not CollisionSystem.overlaps_tiles(result.position, PLAYER_COLLIDER, world), "player should not overlap floor after landing")

func _test_player_cannot_clip_through_wall() -> void:
	var world := TestWorld.new()
	world.fill_rect(Vector2i(2, 0), Vector2i(2, 3))
	var result := CollisionSystem.move_actor(Vector2(8, 44), Vector2(720, 0), 0.1, PLAYER_COLLIDER, world)
	_assert(bool(result.blocked_x), "high-speed horizontal move should hit wall")
	_assert_near(result.position.x, float(2 * TILE_SIZE) - CollisionSystem.SKIN_WIDTH - 7.0, 0.01, "player right edge should clamp to wall")
	_assert_near(result.velocity.x, 0.0, 0.01, "player horizontal velocity should zero on wall")
	_assert(not CollisionSystem.overlaps_tiles(result.position, PLAYER_COLLIDER, world), "player should not overlap wall after clamp")

func _test_player_slides_past_corner() -> void:
	var world := TestWorld.new()
	world.set_solid(Vector2i(1, 2), true)
	var result := CollisionSystem.move_actor(Vector2(8, 40), Vector2(160, 220), 0.075, PLAYER_COLLIDER, world)
	_assert(bool(result.blocked_x), "corner test should block horizontal edge")
	_assert(result.position.y > 50.0, "vertical motion should continue after horizontal corner contact")
	_assert(not CollisionSystem.overlaps_tiles(result.position, PLAYER_COLLIDER, world), "corner slide should not embed player")

func _test_removed_adjacent_tile_does_not_embed_player() -> void:
	var world := TestWorld.new()
	world.fill_rect(Vector2i(1, 1), Vector2i(1, 2))
	var blocked := CollisionSystem.move_actor(Vector2(8, 44), Vector2(120, 0), 0.1, PLAYER_COLLIDER, world)
	_assert(bool(blocked.blocked_x), "adjacent wall should block player before mining")
	world.fill_rect(Vector2i(1, 1), Vector2i(1, 2))
	world.set_solid(Vector2i(1, 1), false)
	world.set_solid(Vector2i(1, 2), false)
	_assert(not CollisionSystem.overlaps_tiles(blocked.position, PLAYER_COLLIDER, world), "removing adjacent wall should not embed player")
	var open := CollisionSystem.move_actor(blocked.position, Vector2(120, 0), 0.1, PLAYER_COLLIDER, world)
	_assert(open.position.x > blocked.position.x + 4.0, "player should move into newly excavated space")
	_assert(not CollisionSystem.overlaps_tiles(open.position, PLAYER_COLLIDER, world), "player should remain clear after moving through mined tile")

func _test_enemy_uses_own_collider() -> void:
	var world := TestWorld.new()
	world.fill_rect(Vector2i(3, 1), Vector2i(3, 2))
	var result := CollisionSystem.move_actor(Vector2(34, 32), Vector2(500, 0), 0.1, SOLDIER_ANT_COLLIDER, world)
	_assert(bool(result.blocked_x), "soldier ant collider should hit wall")
	_assert_near(result.position.x, float(3 * TILE_SIZE) - CollisionSystem.SKIN_WIDTH - 11.0, 0.01, "soldier ant width should determine wall clamp")
	_assert(not CollisionSystem.overlaps_tiles(result.position, SOLDIER_ANT_COLLIDER, world), "soldier ant should not overlap wall")
	var skitter := CollisionSystem.move_actor(Vector2(34, 32), Vector2(500, 0), 0.1, SKITTER_COLLIDER, world)
	_assert(skitter.position.x > result.position.x, "narrow skitter should fit closer to the same wall than soldier ant")

func _test_dropped_item_collides_with_floor() -> void:
	var world := TestWorld.new()
	world.fill_rect(Vector2i(-3, 2), Vector2i(3, 2))
	var inventory := InventorySystem.new()
	var player := Node2D.new()
	player.global_position = Vector2(200, 200)
	var drop := DroppedItemController.new()
	get_root().add_child(drop)
	drop.global_position = Vector2(0, 8)
	drop.pickup_delay = 1.0
	drop.setup("stone_chunk", 1, player, inventory, Vector2(0, 620), world)
	drop._process(0.12)
	var floor_top := float(2 * TILE_SIZE)
	var bottom := drop.global_position.y + float(DroppedItemController.ITEM_COLLIDER.bottom_offset.y)
	_assert(bottom <= floor_top + 0.01, "dropped item should collide with floor instead of passing through blocks")
	_assert(drop.velocity.y == 0.0, "dropped item downward velocity should stop on floor collision")
	drop.free()
	player.free()
