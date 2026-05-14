extends RefCounted
class_name BandCatalog

const BAND_HEIGHT_TILES := 384
const SOLID_DARK_START_TILE_Y := 1920

const BANDS := {
	"standard_caverns": {
		"name": "Band 1: Standard Caverns",
		"min_y": 0,
		"max_y": 383,
		"palette": {"shadow": Color8(37, 42, 53), "mid": Color8(122, 75, 46), "highlight": Color8(168, 111, 60), "accent": Color8(255, 214, 107)},
		"hazards": ["loose cave floors", "cave skitters", "light scarcity"],
		"resources": ["dirt_clod", "stone_chunk", "copper_nugget"],
		"ambient_light": 0.18,
		"danger": 1
	},
	"colossal_ant_chambers": {
		"name": "Band 2: Colossal Ant Chambers",
		"min_y": 384,
		"max_y": 767,
		"palette": {"shadow": Color8(58, 36, 22), "mid": Color8(143, 95, 34), "highlight": Color8(241, 184, 91), "accent": Color8(240, 211, 94)},
		"hazards": ["pheromone alarms", "resin choke points", "soldier caste patrols"],
		"resources": ["resin_shard", "royal_jelly"],
		"ambient_light": 0.14,
		"danger": 2
	},
	"buried_pyramids": {
		"name": "Band 3: Buried Pyramids",
		"min_y": 768,
		"max_y": 1151,
		"palette": {"shadow": Color8(58, 51, 40), "mid": Color8(155, 129, 80), "highlight": Color8(210, 179, 106), "accent": Color8(62, 143, 116)},
		"hazards": ["pressure plates", "dart traps", "mummy sentries"],
		"resources": ["sandstone_shard", "cursed_relic"],
		"ambient_light": 0.10,
		"danger": 3
	},
	"drow_enclaves": {
		"name": "Band 4: Drow Enclaves",
		"min_y": 1152,
		"max_y": 1535,
		"palette": {"shadow": Color8(23, 20, 47), "mid": Color8(45, 63, 130), "highlight": Color8(85, 214, 210), "accent": Color8(180, 92, 255)},
		"hazards": ["spore fog", "shadow patrols", "diplomacy traps"],
		"resources": ["glow_spore", "drow_silk"],
		"ambient_light": 0.24,
		"danger": 4
	},
	"abyssal_lava_slums": {
		"name": "Band 5: Abyssal Lava Rivers / Obsidian Slums",
		"min_y": 1536,
		"max_y": 1919,
		"palette": {"shadow": Color8(13, 12, 18), "mid": Color8(43, 32, 38), "highlight": Color8(217, 67, 36), "accent": Color8(255, 138, 31)},
		"hazards": ["magma rivers", "heat pressure", "hostile outcasts"],
		"resources": ["obsidian_chip", "heat_core"],
		"ambient_light": 0.20,
		"danger": 5
	},
	"solid_dark_blocks": {
		"name": "The Solid Dark Blocks",
		"min_y": 1920,
		"max_y": null,
		"palette": {"shadow": Color8(2, 3, 10), "mid": Color8(8, 9, 20), "highlight": Color8(29, 32, 56), "accent": Color8(83, 93, 143)},
		"hazards": ["near-impenetrable mass", "light absorption", "boundary pressure"],
		"resources": ["dark_block_sliver"],
		"ambient_light": 0.02,
		"danger": 6
	}
}

static func resolve_band_id(tile_y: int) -> String:
	if tile_y >= SOLID_DARK_START_TILE_Y:
		return "solid_dark_blocks"
	if tile_y < 384:
		return "standard_caverns"
	if tile_y < 768:
		return "colossal_ant_chambers"
	if tile_y < 1152:
		return "buried_pyramids"
	if tile_y < 1536:
		return "drow_enclaves"
	return "abyssal_lava_slums"

static func get_band(tile_y: int) -> Dictionary:
	return BANDS[resolve_band_id(tile_y)]

static func get_depth_label(tile_y: int) -> String:
	var band := get_band(tile_y)
	if resolve_band_id(tile_y) == "solid_dark_blocks":
		return "%s / %dm" % [band.name, tile_y]
	return "%s / %dm" % [band.name, tile_y - int(band.min_y)]

