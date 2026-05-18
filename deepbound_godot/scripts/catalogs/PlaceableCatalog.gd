extends RefCounted
class_name PlaceableCatalog

const PLACEABLES := {
	"chest": {"kind": "container", "tile": "chest_block", "count": 1},
	"dirt_clod": {"kind": "tile", "tile": "loose_dirt", "count": 1},
	"stone_chunk": {"kind": "tile", "tile": "soft_stone", "count": 1},
	"resin_shard": {"kind": "tile", "tile": "hardened_resin", "count": 1},
	"sandstone_shard": {"kind": "tile", "tile": "sandstone_block", "count": 1},
	"dirt_background_block": {"kind": "background", "background": "dirt_background_block", "count": 1},
	"stone_background_block": {"kind": "background", "background": "stone_background_block", "count": 1},
	"wooden_background_block": {"kind": "background", "background": "wooden_background_block", "count": 1},
}

static func is_placeable(item_id: String) -> bool:
	return PLACEABLES.has(item_id)

static func get_placeable(item_id: String) -> Dictionary:
	return PLACEABLES.get(item_id, {})
