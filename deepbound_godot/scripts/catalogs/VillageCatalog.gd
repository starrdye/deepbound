extends RefCounted
class_name VillageCatalog

const DROW_TILE_IDS := [
	"drow_basalt_brick",
	"drow_carved_floor",
	"drow_mushroom_plank",
	"drow_silk_canopy",
	"drow_arch_inlay",
	"drow_glowglass",
	"glow_mushroom_loam"
]

const DROW_PROP_IDS := [
	"drow_door",
	"drow_lantern",
	"drow_silk_banner",
	"drow_market_crate",
	"drow_moon_shrine",
	"drow_watch_crystal",
	"drow_bridge_post",
	"drow_mushroom_lamp",
	"drow_web_bridge"
]

const DROW_SYMBOLS := {
	".": {"kind": "empty", "id": "air"},
	"#": {"kind": "tile", "id": "drow_basalt_brick"},
	"=": {"kind": "tile", "id": "drow_carved_floor"},
	"P": {"kind": "tile", "id": "drow_mushroom_plank"},
	"^": {"kind": "tile", "id": "drow_silk_canopy"},
	"A": {"kind": "tile", "id": "drow_arch_inlay"},
	"G": {"kind": "tile", "id": "drow_glowglass"},
	"L": {"kind": "prop", "id": "drow_lantern"},
	"D": {"kind": "prop", "id": "drow_door"},
	"B": {"kind": "prop", "id": "drow_silk_banner"},
	"C": {"kind": "prop", "id": "drow_market_crate"},
	"M": {"kind": "prop", "id": "drow_moon_shrine"},
	"W": {"kind": "prop", "id": "drow_watch_crystal"},
	"O": {"kind": "prop", "id": "drow_mushroom_lamp"},
	"|": {"kind": "prop", "id": "drow_bridge_post"},
	"~": {"kind": "prop", "id": "drow_web_bridge"}
}

const DROW_BUILDINGS := {
	"entry_arch": {
		"name": "Silent Gate Arch",
		"role": "Village threshold, encounter pacing marker, and safe-room boundary.",
		"footprint": [13, 7],
		"required_tiles": ["drow_basalt_brick", "drow_arch_inlay", "drow_carved_floor"],
		"required_props": ["drow_lantern", "drow_silk_banner"],
		"layout": [
			"..A#######A..",
			".A##.....##A.",
			"###...L...###",
			"##.........##",
			"#B.........B#",
			"===.......===",
			"============="
		]
	},
	"sporehome": {
		"name": "Sporehome Dwelling",
		"role": "Common home shell with mushroom-plank floor and silk weather canopy.",
		"footprint": [13, 8],
		"required_tiles": ["drow_basalt_brick", "drow_mushroom_plank", "drow_silk_canopy", "drow_glowglass"],
		"required_props": ["drow_door", "drow_mushroom_lamp"],
		"layout": [
			"...^^^^^^^...",
			"..^^#####^^..",
			".^###GGG###^.",
			".###.....###.",
			".##...O...##.",
			".##...D...##.",
			".PPPPPPPPPPP.",
			"============="
		]
	},
	"silk_weaver_house": {
		"name": "Silk Weaver House",
		"role": "Crafting and trade hut for drow silk, rope bridges, and cloth upgrades.",
		"footprint": [15, 8],
		"required_tiles": ["drow_basalt_brick", "drow_mushroom_plank", "drow_silk_canopy"],
		"required_props": ["drow_silk_banner", "drow_market_crate", "drow_door"],
		"layout": [
			"..^^^^^^^^^....",
			".^^#######^^...",
			"###..B.B..###..",
			"##.........##..",
			"##..C...C..##..",
			"##....D....##..",
			"PPPPPPPPPPPPP..",
			"==============="
		]
	},
	"market_stall": {
		"name": "Lowlight Market Stall",
		"role": "Small merchant platform for pickups, tools, and recipe hints.",
		"footprint": [15, 6],
		"required_tiles": ["drow_mushroom_plank", "drow_silk_canopy", "drow_carved_floor"],
		"required_props": ["drow_lantern", "drow_market_crate"],
		"layout": [
			"..^^^^^^^^^^...",
			".^^........^^..",
			"..L..C.C..L....",
			"..PPPPPPPPP....",
			"===============",
			"==============="
		]
	},
	"moon_shrine": {
		"name": "Moonless Shrine",
		"role": "Lore node, checkpoint candidate, and source of cool cyan village lighting.",
		"footprint": [13, 9],
		"required_tiles": ["drow_basalt_brick", "drow_arch_inlay", "drow_glowglass", "drow_carved_floor"],
		"required_props": ["drow_moon_shrine", "drow_lantern", "drow_silk_banner"],
		"layout": [
			".....A.A.....",
			"...A#####A...",
			"..###GGG###..",
			".##...M...##.",
			".##.L...L.##.",
			".#B.......B#.",
			".###.....###.",
			"=============",
			"============="
		]
	},
	"watch_spire": {
		"name": "Crystal Watch Spire",
		"role": "Vertical landmark, archer perch, and route signal in the Drow Enclaves.",
		"footprint": [9, 12],
		"required_tiles": ["drow_basalt_brick", "drow_arch_inlay", "drow_carved_floor"],
		"required_props": ["drow_watch_crystal", "drow_lantern"],
		"layout": [
			"...W.....",
			"..AAA....",
			".#####...",
			"..#L#....",
			"..###....",
			"..#.#....",
			"..###....",
			"..#L#....",
			"..###....",
			".#####...",
			"=========",
			"========="
		]
	},
	"web_bridge_span": {
		"name": "Silk-Web Bridge Span",
		"role": "Connector between cave pockets and stacked village platforms.",
		"footprint": [17, 5],
		"required_tiles": ["drow_mushroom_plank"],
		"required_props": ["drow_bridge_post", "drow_web_bridge", "drow_lantern"],
		"layout": [
			"|~~~|~~~L~~~|~~~|",
			"PPPPPPPPPPPPPPPPP",
			"|~~~|~~~~~~~|~~~|",
			".................",
			"................."
		]
	},
	"central_plaza": {
		"name": "Glowmote Plaza",
		"role": "Village heart, safe landing area, and layout anchor for surrounding buildings.",
		"footprint": [17, 7],
		"required_tiles": ["drow_carved_floor", "drow_glowglass"],
		"required_props": ["drow_mushroom_lamp", "drow_market_crate", "drow_lantern"],
		"layout": [
			".................",
			"...L.........L...",
			".....C..O..C.....",
			"====GGGGGGGGG====",
			"=================",
			"=================",
			"================="
		]
	}
}

const DROW_VILLAGE := {
	"id": "drow_village",
	"name": "Drow Enclave Village",
	"band": "drow_enclaves",
	"tile_y_range": [1152, 1535],
	"preferred_anchor": "wide side pocket attached to the main tunnel",
	"minimum_clearance_tiles": [54, 20],
	"palette": {
		"stone": "#242C56",
		"silk": "#A070DC",
		"cyan_light": "#55D6D2",
		"deep_shadow": "#121023"
	},
	"required_tiles": DROW_TILE_IDS,
	"required_props": DROW_PROP_IDS,
	"symbol_legend": DROW_SYMBOLS,
	"building_order": [
		"central_plaza",
		"entry_arch",
		"sporehome",
		"silk_weaver_house",
		"market_stall",
		"moon_shrine",
		"watch_spire",
		"web_bridge_span"
	],
	"generation_rules": [
		"Place central_plaza first on a widened, mostly flat cavern floor.",
		"Attach entry_arch on the main approach side and web_bridge_span across gaps.",
		"Cluster two to four sporehome variants around plaza edges.",
		"Place silk_weaver_house and market_stall close enough for trading reads.",
		"Place moon_shrine deeper or higher than the plaza to make it feel sacred.",
		"Place watch_spire vertically near a ledge or route transition."
	]
}

static func get_village(village_id: String) -> Dictionary:
	if village_id == "drow_village":
		return DROW_VILLAGE
	return {}

static func get_building(building_id: String) -> Dictionary:
	return DROW_BUILDINGS.get(building_id, {})

static func get_building_ids() -> Array:
	return DROW_VILLAGE.building_order

static func get_symbol(symbol: String) -> Dictionary:
	return DROW_SYMBOLS.get(symbol, {})
