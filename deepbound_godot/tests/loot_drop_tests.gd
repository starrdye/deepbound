extends SceneTree

## Headless test suite for the LootDrop physics-pop system.
##
## Tests:
##   1. EnemyCatalog.roll_drops — table rolling, chance bounds, count range
##   2. LootDropController      — setup, pickup delay timer, magnet state machine,
##                                rarity color resolution, bounce physics
##   3. Integration             — enemy died signal → roll_drops → loot count
##
## Run from project root:
##   godot --headless -s tests/loot_drop_tests.gd

const EnemyCatalog       = preload("res://scripts/catalogs/EnemyCatalog.gd")
const LootDropController = preload("res://scripts/controllers/LootDropController.gd")
const LootDropScene      = preload("res://scenes/LootDrop.tscn")
const EnemyScene         = preload("res://scenes/Enemy.tscn")
const ItemCatalog        = preload("res://scripts/catalogs/ItemCatalog.gd")

var failures: Array[String] = []

# ── Scaffolding ───────────────────────────────────────────────────────────────

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_enemy_catalog_drops()
	await _test_loot_drop_controller()
	_test_enemy_died_signal()
	if failures.is_empty():
		print("Deepbound Godot loot drop tests passed.")
		quit(0)
	else:
		for f in failures:
			push_error("FAIL: " + f)
		quit(1)

# ── 1. EnemyCatalog.roll_drops ────────────────────────────────────────────────

func _test_enemy_catalog_drops() -> void:
	print("  [loot] EnemyCatalog.roll_drops...")

	# Every known enemy id should have a DROPS entry.
	var known_ids := ["cave_skitter", "goblin_grunt", "goblin_slinger", "goblin_shaman",
	                  "worker_ant", "soldier_ant", "dwarf_guard", "dwarf_crossbowman",
	                  "dwarf_smith", "mummy_sentry", "drow_warrior", "drow_acolyte"]
	for eid in known_ids:
		_assert(EnemyCatalog.DROPS.has(eid), "DROPS table missing entry for '%s'" % eid)

	# roll_drops always returns an Array.
	var result := EnemyCatalog.roll_drops("cave_skitter")
	_assert(result is Array, "roll_drops should return an Array")

	# Unknown enemy → empty array (no crash).
	var unknown := EnemyCatalog.roll_drops("nonexistent_enemy_xyz")
	_assert(unknown.is_empty(), "roll_drops for unknown enemy should return empty array")

	# Each returned stack must have item + count fields with valid values.
	# Run many trials to get at least one drop.
	var got_drop := false
	for _i in range(60):
		var drops := EnemyCatalog.roll_drops("goblin_shaman")
		for stack in drops:
			_assert(stack.has("item"),  "drop stack missing 'item' key")
			_assert(stack.has("count"), "drop stack missing 'count' key")
			_assert(String(stack.get("item", "")) != "", "drop item_id must not be empty")
			_assert(int(stack.get("count", 0)) >= 1,  "drop count must be >= 1")
			got_drop = true
	_assert(got_drop, "goblin_shaman should produce at least one drop across 60 rolls (check chance values)")

	# Count must stay within declared min/max for goblin_grunt copper_nugget (min=1, max=2).
	for _i in range(40):
		for stack in EnemyCatalog.roll_drops("goblin_grunt"):
			if String(stack.get("item", "")) == "copper_nugget":
				var c: int = int(stack.get("count", 0))
				_assert(c >= 1 and c <= 2, "goblin_grunt copper_nugget count out of [1,2] range: %d" % c)

	# Mummy rare drop (chance 0.05) must not exceed count of 1 when it fires.
	for _i in range(100):
		for stack in EnemyCatalog.roll_drops("mummy_sentry"):
			if String(stack.get("item", "")) == "cursed_relic":
				_assert(int(stack.get("count", 0)) == 1, "mummy cursed_relic count should be 1")

# ── 2. LootDropController ─────────────────────────────────────────────────────

func _test_loot_drop_controller() -> void:
	print("  [loot] LootDropController setup and state...")

	# Instantiate via scene so node hierarchy is correct.
	var drop = LootDropScene.instantiate()
	get_root().add_child(drop)
	drop.global_position = Vector2(100.0, 200.0)

	# Before setup: item_id is empty, can_be_picked_up is false.
	_assert(drop.item_id == "",           "item_id should be empty before setup")
	_assert(not drop.can_be_picked_up,    "can_be_picked_up should start false")

	# Call setup with a known item and no player (null is safe — magnet won't fire).
	drop.setup("copper_nugget", 3, null, null, null)

	_assert(drop.item_id == "copper_nugget", "item_id should be set after setup")
	_assert(drop.count   == 3,               "count should be 3")
	_assert(not drop.can_be_picked_up,    "can_be_picked_up should still be false immediately after setup")

	# PickupDelay Timer should exist and be running.
	var timer := drop.get_node_or_null("PickupDelay")
	_assert(timer != null, "PickupDelay Timer node should exist after setup")
	if timer != null:
		_assert(not timer.is_stopped(), "PickupDelay Timer should be running after setup")
		_assert(timer.one_shot,         "PickupDelay Timer should be one_shot")
		_assert(timer.wait_time == 0.5, "PickupDelay Timer wait_time should be 0.5 s")

	# Pop impulse — velocity should be non-zero upward.
	_assert(drop.velocity.y < 0.0, "initial velocity.y should be negative (upward pop)")
	_assert(absf(drop.velocity.x) > 0.0, "initial velocity.x should have horizontal component")

	# Angular velocity should be non-zero after setup (random spin).
	_assert(drop._angular_vel != 0.0, "_angular_vel should be non-zero for spin")

	# Physics material properties are accessible.
	_assert(drop.bounce   == 0.4, "default bounce should be 0.4")
	_assert(drop.friction == 0.8, "default friction should be 0.8")

	# Rarity: copper_nugget is 'common' → no glow (TRANSPARENT).
	_assert(drop._rarity_color == Color.TRANSPARENT, "common item should have no rarity glow")

	# Test rarity resolution for known rare item.
	var rare_drop = LootDropScene.instantiate()
	get_root().add_child(rare_drop)
	# cursed_relic is epic — should get a purple glow.
	rare_drop.setup("cursed_relic", 1, null, null, null)
	_assert(rare_drop._rarity_color != Color.TRANSPARENT, "epic item should have a rarity glow color")
	rare_drop.queue_free()

	# try_collect should return false before can_be_picked_up is true.
	var result: bool = drop.try_collect()
	_assert(not result, "try_collect should return false before pickup delay expires")

	# Manually fire pickup delay.
	drop.can_be_picked_up = true

	# try_collect with null inventory should return false gracefully.
	var result2: bool = drop.try_collect(null)
	_assert(not result2, "try_collect with null inventory should return false")

	# Wait a frame for the timer to tick.
	await process_frame

	# Test explicit pop impulse overrides random.
	var forced_drop = LootDropScene.instantiate()
	get_root().add_child(forced_drop)
	var forced_vel := Vector2(50.0, -200.0)
	forced_drop.setup("stone_chunk", 1, null, null, null, forced_vel)
	_assert(forced_drop.velocity.is_equal_approx(forced_vel),
		"explicit pop_impulse should override random velocity")
	forced_drop.queue_free()

	drop.queue_free()

# ── 3. Enemy died → loot signal ───────────────────────────────────────────────

func _test_enemy_died_signal() -> void:
	print("  [loot] EnemyController died signal...")

	var enemy = EnemyScene.instantiate()
	get_root().add_child(enemy)
	enemy.global_position = Vector2(200.0, 200.0)

	_assert(enemy.has_signal("died"), "EnemyController should have 'died' signal")

	# Connect signal with Array-container closure (GDScript lambda capture gotcha).
	var fired_ids  := [""]
	var fired_pos  := [Vector2.ZERO]
	enemy.died.connect(func(eid, pos):
		fired_ids[0]  = eid
		fired_pos[0]  = pos
	)

	# Manually prime enemy state so take_damage kills it.
	enemy.enemy_id = "cave_skitter"
	enemy.alive    = true
	enemy.health   = 1
	enemy.take_damage(999)

	_assert(not enemy.alive,         "enemy should be dead after lethal damage")
	_assert(fired_ids[0] == "cave_skitter", "died signal should carry the enemy_id")
	_assert(fired_pos[0] == enemy.global_position, "died signal should carry the enemy position")

	# Verify roll_drops doesn't crash when called with the emitted id.
	var drops := EnemyCatalog.roll_drops(fired_ids[0])
	_assert(drops is Array, "roll_drops should not crash on valid enemy id from died signal")

	enemy.queue_free()
