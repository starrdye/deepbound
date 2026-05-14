extends RefCounted
class_name EconomyModel

const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")

const CRAFTING_COSTS := {
	"flare_bundle": {"dirt_clod": 3, "stone_chunk": 2},
	"copper_brace": {"copper_nugget": 6, "stone_chunk": 4},
	"outpost_beacon": {"copper_nugget": 4, "stone_chunk": 6},
	"resin_seal": {"resin_shard": 5, "royal_jelly": 1},
	"tomb_key": {"sandstone_shard": 8, "cursed_relic": 1}
}

static func expected_tile_value(tile_id: String) -> float:
	var tile := TileCatalog.get_tile(tile_id)
	var value := 0.0
	for drop in tile.drops:
		var avg_count := (float(drop.min) + float(drop.max)) * 0.5
		value += avg_count * float(drop.chance) * float(tile.value)
	return value

static func mining_roi(tile_id: String, drill_power := 1.0) -> Dictionary:
	var tile := TileCatalog.get_tile(tile_id)
	var seconds := INF
	if tile.breakable:
		seconds = float(tile.hardness) / drill_power
	var expected := expected_tile_value(tile_id)
	return {
		"tile": tile_id,
		"break_seconds": seconds,
		"expected_value": expected,
		"value_per_second": 0.0 if seconds == INF else expected / seconds
	}

