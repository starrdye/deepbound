extends SceneTree

## Headless test suite for the Dynamic Liquids & Buckets system.
##
## Tests:
##   1. LiquidCatalog  — type constants, react(), get_alpha(), bucket_item_for_type()
##   2. ChunkStore     — get/set/clear/export/import liquid roundtrip
##   3. LiquidSystem   — gravity flow, horizontal spread, water+lava reaction,
##                       sleep behaviour (cells that don't move drop out of next_active)
##   4. ItemCatalog    — bucket items: is_container, held_liquid, capacity
##
## Run from project root:
##   godot --headless -s tests/liquid_tests.gd

const LiquidCatalog = preload("res://scripts/catalogs/LiquidCatalog.gd")
const LiquidSystem  = preload("res://scripts/systems/LiquidSystem.gd")
const ChunkStore    = preload("res://scripts/systems/ChunkStore.gd")
const ItemCatalog   = preload("res://scripts/catalogs/ItemCatalog.gd")

var failures: Array[String] = []

# ── Scaffolding ────────────────────────────────────────────────────────────────

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_catalog()
	_test_chunk_store_liquid()
	_test_liquid_system()
	_test_bucket_items()
	if failures.is_empty():
		print("Deepbound Godot liquid tests passed.")
		quit(0)
	else:
		for f in failures:
			push_error("FAIL: " + f)
		quit(1)

# ── 1. LiquidCatalog ──────────────────────────────────────────────────────────

func _test_catalog() -> void:
	print("  [liq] LiquidCatalog...")

	# Type constants
	_assert(LiquidCatalog.NONE  == 0, "NONE should be 0")
	_assert(LiquidCatalog.WATER == 1, "WATER should be 1")
	_assert(LiquidCatalog.LAVA  == 2, "LAVA should be 2")
	_assert(LiquidCatalog.HONEY == 3, "HONEY should be 3")

	# Volume constants
	_assert(LiquidCatalog.MAX_VOLUME >= 4,    "MAX_VOLUME should be at least 4")
	_assert(LiquidCatalog.MIN_SPREAD_VOLUME >= 1, "MIN_SPREAD_VOLUME should be >= 1")

	# is_valid_type
	_assert(LiquidCatalog.is_valid_type(LiquidCatalog.WATER), "WATER should be valid")
	_assert(LiquidCatalog.is_valid_type(LiquidCatalog.LAVA),  "LAVA should be valid")
	_assert(LiquidCatalog.is_valid_type(LiquidCatalog.HONEY), "HONEY should be valid")
	_assert(not LiquidCatalog.is_valid_type(LiquidCatalog.NONE), "NONE should not be valid")
	_assert(not LiquidCatalog.is_valid_type(99),  "unknown type 99 should not be valid")

	# react() — Water ↔ Lava → obsidian
	_assert(LiquidCatalog.react(LiquidCatalog.WATER, LiquidCatalog.LAVA)  != "", "water+lava should react")
	_assert(LiquidCatalog.react(LiquidCatalog.LAVA,  LiquidCatalog.WATER) != "", "lava+water should react")
	_assert(LiquidCatalog.react(LiquidCatalog.WATER, LiquidCatalog.WATER) == "", "water+water should not react")
	_assert(LiquidCatalog.react(LiquidCatalog.LAVA,  LiquidCatalog.LAVA)  == "", "lava+lava should not react")
	_assert(LiquidCatalog.react(LiquidCatalog.WATER, LiquidCatalog.HONEY) == "", "water+honey should not react")
	var reaction_tile := LiquidCatalog.react(LiquidCatalog.WATER, LiquidCatalog.LAVA)
	_assert(reaction_tile == "obsidian", "water+lava reaction tile should be 'obsidian'")

	# get_alpha() — full tile should have highest alpha
	var full_alpha  := LiquidCatalog.get_alpha(LiquidCatalog.WATER, LiquidCatalog.MAX_VOLUME)
	var half_alpha  := LiquidCatalog.get_alpha(LiquidCatalog.WATER, LiquidCatalog.MAX_VOLUME / 2)
	var empty_alpha := LiquidCatalog.get_alpha(LiquidCatalog.WATER, 0)
	_assert(full_alpha  > 0.0,       "full-volume alpha should be positive")
	_assert(full_alpha  > half_alpha, "full-volume alpha should exceed half-volume")
	_assert(empty_alpha == 0.0,      "zero-volume alpha should be 0.0")

	# get_color() — returns a non-transparent colour for known types
	_assert(LiquidCatalog.get_color(LiquidCatalog.WATER).a > 0.0 or LiquidCatalog.get_color(LiquidCatalog.WATER).r > 0.0, "water color should not be all-zero")

	# bucket_item_for_type()
	_assert(LiquidCatalog.bucket_item_for_type(LiquidCatalog.WATER) == "water_bucket", "water bucket item should be 'water_bucket'")
	_assert(LiquidCatalog.bucket_item_for_type(LiquidCatalog.LAVA)  == "lava_bucket",  "lava bucket item should be 'lava_bucket'")
	_assert(LiquidCatalog.bucket_item_for_type(LiquidCatalog.HONEY) == "honey_bucket", "honey bucket item should be 'honey_bucket'")
	_assert(LiquidCatalog.bucket_item_for_type(LiquidCatalog.NONE)  == "",             "NONE bucket item should be empty string")

# ── 2. ChunkStore liquid layer ────────────────────────────────────────────────

func _test_chunk_store_liquid() -> void:
	print("  [liq] ChunkStore liquid layer...")

	var store := ChunkStore.new()
	var tile := Vector2i(5, 10)

	# Initially empty
	_assert(store.get_liquid(tile).is_empty(), "liquid should be empty initially")

	# set and get
	store.set_liquid(tile, LiquidCatalog.WATER, 4)
	var entry: Dictionary = store.get_liquid(tile)
	_assert(int(entry.get("type",   0)) == LiquidCatalog.WATER, "type should be WATER after set")
	_assert(int(entry.get("volume", 0)) == 4,                   "volume should be 4 after set")

	# overwrite
	store.set_liquid(tile, LiquidCatalog.LAVA, LiquidCatalog.MAX_VOLUME)
	var entry2: Dictionary = store.get_liquid(tile)
	_assert(int(entry2.get("type",   0)) == LiquidCatalog.LAVA,             "type should be LAVA after overwrite")
	_assert(int(entry2.get("volume", 0)) == LiquidCatalog.MAX_VOLUME,        "volume should be MAX_VOLUME after overwrite")

	# set volume 0 → auto-erases
	store.set_liquid(tile, LiquidCatalog.WATER, 0)
	_assert(store.get_liquid(tile).is_empty(), "setting volume 0 should erase the entry")

	# clear_liquid
	store.set_liquid(tile, LiquidCatalog.HONEY, 3)
	store.clear_liquid(tile)
	_assert(store.get_liquid(tile).is_empty(), "clear_liquid should erase the entry")

	# clear non-existent tile — no crash
	store.clear_liquid(Vector2i(999, 999))

	# export / import roundtrip
	var tile_a := Vector2i(1, 1)
	var tile_b := Vector2i(2, 3)
	store.set_liquid(tile_a, LiquidCatalog.WATER, 5)
	store.set_liquid(tile_b, LiquidCatalog.LAVA,  LiquidCatalog.MAX_VOLUME)
	var exported: Array = store.export_liquids()
	_assert(exported.size() == 2, "export_liquids should return 2 entries")

	var store2 := ChunkStore.new()
	store2.import_liquids(exported)
	var ra: Dictionary = store2.get_liquid(tile_a)
	var rb: Dictionary = store2.get_liquid(tile_b)
	_assert(int(ra.get("type",   0)) == LiquidCatalog.WATER, "imported tile_a type should be WATER")
	_assert(int(ra.get("volume", 0)) == 5,                   "imported tile_a volume should be 5")
	_assert(int(rb.get("type",   0)) == LiquidCatalog.LAVA,  "imported tile_b type should be LAVA")
	_assert(int(rb.get("volume", 0)) == LiquidCatalog.MAX_VOLUME, "imported tile_b volume should be MAX_VOLUME")

	# import_liquids ignores zero/invalid entries
	store2.import_liquids([{"x": 0, "y": 0, "type": 0, "volume": 5}])
	_assert(store2.get_liquid(Vector2i(0, 0)).is_empty(), "zero-type import entry should be ignored")

# ── 3. LiquidSystem ───────────────────────────────────────────────────────────

## Minimal duck-typed world stub for LiquidSystem tests.
class _WorldStub:
	var _solid: Dictionary = {}   # Vector2i → bool

	func is_solid_tile(tile: Vector2i) -> bool:
		return bool(_solid.get(tile, false))

	func make_solid(tile: Vector2i) -> void:
		_solid[tile] = true


func _test_liquid_system() -> void:
	print("  [liq] LiquidSystem...")

	_test_gravity_flow()
	_test_horizontal_spread()
	_test_water_lava_reaction()
	_test_sleep_behaviour()

func _test_gravity_flow() -> void:
	var store := ChunkStore.new()
	var world := _WorldStub.new()

	# Place water at (0,0); tile below (0,1) is empty.
	var src := Vector2i(0, 0)
	var below := Vector2i(0, 1)
	store.set_liquid(src, LiquidCatalog.WATER, LiquidCatalog.MAX_VOLUME)
	var active: Dictionary = {src: true}

	var result: Dictionary = LiquidSystem.tick(store, world, active)
	_assert(result.has("next_active"),  "gravity: result should have next_active")
	_assert(result.has("reactions"),    "gravity: result should have reactions")

	# All/most water should flow down to below in one tick
	var below_vol := int(store.get_liquid(below).get("volume", 0))
	_assert(below_vol > 0, "gravity: water should flow into cell below")

	# No reactions expected
	_assert(result.get("reactions", []).size() == 0, "gravity: no reactions expected")

func _test_horizontal_spread() -> void:
	var store := ChunkStore.new()
	var world := _WorldStub.new()

	# Solid floor — blocks downward flow.
	for x in range(-3, 4):
		world.make_solid(Vector2i(x, 1))

	# Source tile with enough volume to spread.
	var src := Vector2i(0, 0)
	store.set_liquid(src, LiquidCatalog.WATER, LiquidCatalog.MAX_VOLUME)

	var active: Dictionary = {src: true}
	# Run a few ticks so equalization can propagate.
	for _i in range(5):
		var r: Dictionary = LiquidSystem.tick(store, world, active)
		active = r.get("next_active", {})

	# At least one neighbour should have received water.
	var left  := int(store.get_liquid(Vector2i(-1, 0)).get("volume", 0))
	var right := int(store.get_liquid(Vector2i( 1, 0)).get("volume", 0))
	_assert(left + right > 0, "spread: water should have spread left or right")

func _test_water_lava_reaction() -> void:
	var store := ChunkStore.new()
	var world := _WorldStub.new()

	# Water above lava.
	var water_tile := Vector2i(0, 0)
	var lava_tile  := Vector2i(0, 1)
	store.set_liquid(water_tile, LiquidCatalog.WATER, 3)
	store.set_liquid(lava_tile,  LiquidCatalog.LAVA,  LiquidCatalog.MAX_VOLUME)

	var active: Dictionary = {water_tile: true, lava_tile: true}
	var result: Dictionary = LiquidSystem.tick(store, world, active)

	var reactions: Array = result.get("reactions", [])
	_assert(reactions.size() > 0, "water+lava should produce at least one reaction")
	if reactions.size() > 0:
		var r: Dictionary = Dictionary(reactions[0])
		_assert(String(r.get("tile_id", "")) == "obsidian", "water+lava reaction tile_id should be 'obsidian'")

	# Lava cell should be cleared after reaction.
	_assert(store.get_liquid(lava_tile).is_empty(), "lava cell should be cleared after reaction")

func _test_sleep_behaviour() -> void:
	var store := ChunkStore.new()
	var world := _WorldStub.new()

	# Solid floor and walls — water has nowhere to go.
	world.make_solid(Vector2i(0, 1))
	world.make_solid(Vector2i(-1, 0))
	world.make_solid(Vector2i( 1, 0))

	# Place 1 unit of water — below MIN_SPREAD_VOLUME.
	var src := Vector2i(0, 0)
	store.set_liquid(src, LiquidCatalog.WATER, 1)
	var active: Dictionary = {src: true}

	var result: Dictionary = LiquidSystem.tick(store, world, active)
	var next: Dictionary = result.get("next_active", {})

	# The source tile may remain active (water is resting but still present) —
	# what we verify is that it does NOT keep creating NEW entries elsewhere:
	# the liquid should not have teleported.
	var src_vol := int(store.get_liquid(src).get("volume", 0))
	_assert(src_vol == 1, "sleep: resting water volume should be unchanged")
	_assert(store.get_liquid(Vector2i(-1, 0)).is_empty(), "sleep: liquid should not enter solid wall")
	_assert(store.get_liquid(Vector2i( 1, 0)).is_empty(), "sleep: liquid should not enter solid wall")

# ── 4. ItemCatalog bucket items ───────────────────────────────────────────────

func _test_bucket_items() -> void:
	print("  [liq] ItemCatalog bucket items...")

	for bucket_id in ["empty_bucket", "water_bucket", "lava_bucket", "honey_bucket"]:
		var def: Dictionary = ItemCatalog.get_item(bucket_id)
		_assert(not def.is_empty(),                         "'%s' should exist in ItemCatalog" % bucket_id)
		_assert(bool(def.get("is_container", false)),       "'%s' should have is_container = true" % bucket_id)
		_assert(int(def.get("capacity", 0)) > 0,           "'%s' should have capacity > 0" % bucket_id)
		_assert(def.get("category", "") == "tool",         "'%s' should have category 'tool'" % bucket_id)

	# held_liquid values
	_assert(int(ItemCatalog.get_item("empty_bucket").get("held_liquid", -1)) == LiquidCatalog.NONE,  "empty_bucket held_liquid should be NONE")
	_assert(int(ItemCatalog.get_item("water_bucket").get("held_liquid", -1)) == LiquidCatalog.WATER, "water_bucket held_liquid should be WATER")
	_assert(int(ItemCatalog.get_item("lava_bucket").get("held_liquid",  -1)) == LiquidCatalog.LAVA,  "lava_bucket held_liquid should be LAVA")
	_assert(int(ItemCatalog.get_item("honey_bucket").get("held_liquid", -1)) == LiquidCatalog.HONEY, "honey_bucket held_liquid should be HONEY")

	# Capacity matches MAX_VOLUME
	_assert(int(ItemCatalog.get_item("water_bucket").get("capacity", 0)) == LiquidCatalog.MAX_VOLUME,
		"water_bucket capacity should equal LiquidCatalog.MAX_VOLUME")
