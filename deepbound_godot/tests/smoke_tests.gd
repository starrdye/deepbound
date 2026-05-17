extends SceneTree

const BandCatalog = preload("res://scripts/catalogs/BandCatalog.gd")
const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")
const EconomyModel = preload("res://scripts/catalogs/EconomyModel.gd")
const ChunkStore = preload("res://scripts/systems/ChunkStore.gd")
const WorldGenerator = preload("res://scripts/systems/WorldGenerator.gd")
const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")
const MiningSystem = preload("res://scripts/systems/MiningSystem.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_bands()
	_test_generation()
	_test_mining_inventory()
	_test_economy()
	_test_sprint_4_5_hooks()
	if failures.is_empty():
		print("Deepbound Godot smoke tests passed.")
		quit(0)
	else:
		print("Deepbound Godot smoke tests failed: %d" % failures.size())
		quit(1)

func _test_bands() -> void:
	_assert(BandCatalog.resolve_band_id(0) == "standard_caverns", "tileY 0 should be Band 1")
	_assert(BandCatalog.resolve_band_id(384) == "colossal_ant_chambers", "tileY 384 should be Band 2")
	_assert(BandCatalog.resolve_band_id(768) == "buried_pyramids", "tileY 768 should be Band 3")
	_assert(BandCatalog.resolve_band_id(1152) == "drow_enclaves", "tileY 1152 should be Band 4")
	_assert(BandCatalog.resolve_band_id(1536) == "abyssal_lava_slums", "tileY 1536 should be Band 5")
	_assert(BandCatalog.resolve_band_id(1920) == "solid_dark_blocks", "tileY 1920 should be Solid Dark Blocks")

func _test_generation() -> void:
	var a := WorldGenerator.generate_chunk(42, Vector2i(-3, 7))
	var b := WorldGenerator.generate_chunk(42, Vector2i(-3, 7))
	var c := WorldGenerator.generate_chunk(43, Vector2i(-3, 7))
	_assert(a == b, "generation should be deterministic for same seed/chunk")
	_assert(a != c, "generation should vary by seed")
	_assert(WorldGenerator.generate_tile_id(42, Vector2i(0, 1920)) == "solid_dark_block", "dark boundary should generate dark blocks")

func _test_mining_inventory() -> void:
	var store := ChunkStore.new(1)
	var inventory := InventorySystem.new()
	var mining := MiningSystem.new()
	var target := Vector2i(40, 40)
	store.set_tile(target, "loose_dirt")
	var partial := mining.mine_tile(store, target, inventory, 0.25, 0.0)
	_assert(not partial.broke, "first mining tick should damage but not break")
	_assert(int(partial.stage) > 0, "damaged tile should report a visible break stage")
	var heavier_damage := mining.mine_tile(store, target, inventory, 0.25, 0.0)
	_assert(int(heavier_damage.stage) >= int(partial.stage), "break stage should increase or hold as damage accumulates")
	var broken := mining.mine_tile(store, target, inventory, 2.0, 0.0)
	_assert(broken.broke, "second mining tick should break loose dirt")
	_assert(int(broken.stage) == MiningSystem.BREAK_STAGE_COUNT, "broken tile should report final break stage")
	_assert(store.get_tile(target) == "air", "broken tile should become air")
	_assert(inventory.count_item("dirt_clod") == 1, "broken dirt should enter inventory")

func _test_economy() -> void:
	var dirt := EconomyModel.mining_roi("loose_dirt")
	var copper := EconomyModel.mining_roi("copper_ore")
	_assert(float(dirt.break_seconds) < 1.0, "loose dirt should break quickly")
	_assert(float(copper.expected_value) > float(dirt.expected_value), "copper should be higher value than dirt")

func _test_sprint_4_5_hooks() -> void:
	var band2_seen := false
	var jelly_seen := false
	var band3_seen := false
	var treasure_seen := false
	for y in range(384, 768):
		for x in range(-40, 41):
			var tile2 := WorldGenerator.generate_tile_id(133742, Vector2i(x, y))
			band2_seen = band2_seen or tile2 == "hardened_resin"
			jelly_seen = jelly_seen or tile2 == "royal_jelly"
	for y in range(768, 1152):
		for x in range(-40, 41):
			var tile3 := WorldGenerator.generate_tile_id(133742, Vector2i(x, y))
			band3_seen = band3_seen or tile3 == "sandstone_block"
			treasure_seen = treasure_seen or tile3 == "cursed_treasure"
	_assert(band2_seen, "Sprint 4 should generate Band 2 resin")
	_assert(jelly_seen, "Sprint 4 should generate royal jelly hooks")
	_assert(band3_seen, "Sprint 5 should generate Band 3 sandstone")
	_assert(treasure_seen, "Sprint 5 should generate cursed treasure hooks")
