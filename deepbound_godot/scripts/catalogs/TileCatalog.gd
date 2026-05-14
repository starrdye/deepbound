extends RefCounted
class_name TileCatalog

const TILES := {
	"air": {"name": "Air", "band": "shared", "hardness": INF, "breakable": false, "solid": false, "blocks_light": false, "occlusion": 0.0, "color": Color.TRANSPARENT, "highlight": Color.TRANSPARENT, "value": 0.0, "drops": []},
	"loose_dirt": {"name": "Loose Dirt", "band": "standard_caverns", "hardness": 0.75, "breakable": true, "solid": true, "blocks_light": true, "occlusion": 0.68, "color": Color8(122, 75, 46), "highlight": Color8(168, 111, 60), "value": 1.0, "drops": [{"item": "dirt_clod", "min": 1, "max": 1, "chance": 1.0}]},
	"compacted_dirt": {"name": "Compacted Dirt", "band": "standard_caverns", "hardness": 1.2, "breakable": true, "solid": true, "blocks_light": true, "occlusion": 0.76, "color": Color8(95, 61, 43), "highlight": Color8(141, 90, 54), "value": 1.4, "drops": [{"item": "dirt_clod", "min": 1, "max": 2, "chance": 1.0}]},
	"soft_stone": {"name": "Soft Stone", "band": "standard_caverns", "hardness": 2.1, "breakable": true, "solid": true, "blocks_light": true, "occlusion": 0.94, "color": Color8(89, 97, 106), "highlight": Color8(136, 147, 154), "value": 2.2, "drops": [{"item": "stone_chunk", "min": 1, "max": 1, "chance": 1.0}]},
	"copper_ore": {"name": "Copper Ore", "band": "standard_caverns", "hardness": 2.4, "breakable": true, "solid": true, "blocks_light": true, "occlusion": 0.88, "color": Color8(110, 81, 61), "highlight": Color8(240, 168, 79), "value": 5.5, "drops": [{"item": "copper_nugget", "min": 1, "max": 2, "chance": 1.0}]},
	"hardened_resin": {"name": "Hardened Resin", "band": "colossal_ant_chambers", "hardness": 3.8, "breakable": true, "solid": true, "blocks_light": true, "occlusion": 0.35, "color": Color8(143, 95, 34), "highlight": Color8(241, 184, 91), "value": 4.0, "drops": [{"item": "resin_shard", "min": 1, "max": 1, "chance": 0.9}]},
	"royal_jelly": {"name": "Royal Jelly", "band": "colossal_ant_chambers", "hardness": 1.0, "breakable": true, "solid": true, "blocks_light": false, "occlusion": 0.10, "color": Color8(240, 211, 94), "highlight": Color8(255, 238, 154), "value": 10.0, "drops": [{"item": "royal_jelly", "min": 1, "max": 1, "chance": 1.0}]},
	"sandstone_block": {"name": "Buried Sandstone", "band": "buried_pyramids", "hardness": 4.4, "breakable": true, "solid": true, "blocks_light": true, "occlusion": 0.90, "color": Color8(155, 129, 80), "highlight": Color8(210, 179, 106), "value": 4.8, "drops": [{"item": "sandstone_shard", "min": 1, "max": 2, "chance": 1.0}]},
	"pressure_plate": {"name": "Pressure Plate", "band": "buried_pyramids", "hardness": 1.0, "breakable": true, "solid": false, "blocks_light": false, "occlusion": 0.0, "color": Color8(62, 143, 116), "highlight": Color8(112, 206, 177), "value": 1.0, "drops": [{"item": "sandstone_shard", "min": 1, "max": 1, "chance": 0.5}]},
	"cursed_treasure": {"name": "Cursed Treasure", "band": "buried_pyramids", "hardness": 1.8, "breakable": true, "solid": true, "blocks_light": true, "occlusion": 0.25, "color": Color8(88, 66, 40), "highlight": Color8(255, 214, 107), "value": 14.0, "drops": [{"item": "cursed_relic", "min": 1, "max": 1, "chance": 1.0}]},
	"glow_mushroom_loam": {"name": "Glow Loam", "band": "drow_enclaves", "hardness": 5.0, "breakable": true, "solid": true, "blocks_light": true, "occlusion": 0.50, "color": Color8(45, 63, 130), "highlight": Color8(85, 214, 210), "value": 6.0, "drops": [{"item": "glow_spore", "min": 1, "max": 2, "chance": 0.85}]},
	"obsidian_ash": {"name": "Obsidian Ash", "band": "abyssal_lava_slums", "hardness": 7.0, "breakable": true, "solid": true, "blocks_light": true, "occlusion": 0.98, "color": Color8(23, 20, 26), "highlight": Color8(255, 93, 36), "value": 8.0, "drops": [{"item": "obsidian_chip", "min": 1, "max": 1, "chance": 0.9}]},
	"solid_dark_block": {"name": "Solid Dark Block", "band": "solid_dark_blocks", "hardness": 9999.0, "breakable": false, "solid": true, "blocks_light": true, "occlusion": 1.0, "color": Color8(5, 6, 17), "highlight": Color8(34, 39, 70), "value": 0.0, "drops": []}
}

static func get_tile(tile_id: String) -> Dictionary:
	return TILES.get(tile_id, TILES.air)

static func is_solid(tile_id: String) -> bool:
	return bool(get_tile(tile_id).solid)

static func is_breakable(tile_id: String) -> bool:
	return bool(get_tile(tile_id).breakable)

