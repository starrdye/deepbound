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

const DROW_SETTLEMENT_BACKGROUND_IDS := [
	"drow_carved_background",
	"drow_webbed_background",
	"drow_scriptuarium_background",
]

const DROW_SETTLEMENT_PROP_IDS := [
	"drow_spider_totem",
	"drow_spectral_torch",
	"drow_silk_curtain",
	"drow_bookshelf",
	"drow_rift_crystal",
	"drow_wall_map",
	"drow_weapon_rack",
	"drow_iron_railing",
	"drow_chain_ladder",
	"drow_cocoon",
	"drow_web_cluster",
	"drow_back_house_lit",
	"drow_back_house_dark",
]

const GOBLIN_TILE_IDS := [
	"goblin_timber_wall",
	"goblin_packed_floor",
	"goblin_hide_canopy",
	"goblin_mossy_brick",
	"goblin_plank_platform"
]

const GOBLIN_BACKGROUND_IDS := [
	"goblin_timber_background",
	"goblin_hide_background",
	"goblin_packed_earth_background"
]

const GOBLIN_PROP_IDS := [
	"goblin_bone_altar",
	"goblin_crate",
	"goblin_cage",
	"goblin_torch",
	"goblin_banner",
	"goblin_door_flap",
	"goblin_palisade_post",
	"goblin_rope_ladder",
	"goblin_rope_bridge",
	"goblin_scaffold_post",
	"goblin_diagonal_brace",
	"goblin_central_hut",
	"goblin_back_hut_lit",
	"goblin_back_hut_dark",
	"goblin_work_shelf",
	"goblin_wall_torch"
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

const GOBLIN_SYMBOLS := {
	"_": {"kind": "ignore", "id": ""},
	".": {"kind": "empty", "id": "air"},
	"#": {"kind": "tile", "id": "goblin_timber_wall"},
	"=": {"kind": "tile", "id": "goblin_packed_floor"},
	"^": {"kind": "tile", "id": "goblin_hide_canopy"},
	"M": {"kind": "tile", "id": "goblin_mossy_brick"},
	"-": {"kind": "tile", "id": "goblin_plank_platform"},
	"P": {"kind": "prop", "id": "goblin_palisade_post"},
	"A": {"kind": "prop", "id": "goblin_bone_altar"},
	"C": {"kind": "prop", "id": "goblin_crate"},
	"X": {"kind": "prop", "id": "goblin_cage"},
	"T": {"kind": "prop", "id": "goblin_torch"},
	"B": {"kind": "prop", "id": "goblin_banner"},
	"D": {"kind": "prop", "id": "goblin_door_flap"},
	"L": {"kind": "prop", "id": "goblin_rope_ladder", "size": [1, 3]},
	"~": {"kind": "prop", "id": "goblin_rope_bridge", "size": [3, 1]},
	"|": {"kind": "prop", "id": "goblin_scaffold_post", "size": [1, 3]},
	"/": {"kind": "prop", "id": "goblin_diagonal_brace", "size": [2, 2]},
	"H": {"kind": "prop", "id": "goblin_central_hut", "size": [4, 3]},
	"h": {"kind": "prop", "id": "goblin_back_hut_lit", "size": [3, 2], "layer": "backdrop", "alpha": 0.55},
	"j": {"kind": "prop", "id": "goblin_back_hut_dark", "size": [3, 2], "layer": "backdrop", "alpha": 0.48},
	"W": {"kind": "prop", "id": "goblin_work_shelf", "size": [3, 2]},
	"F": {"kind": "prop", "id": "goblin_wall_torch", "size": [1, 2]},
	"g": {"kind": "spawn", "id": "goblin_grunt"},
	"s": {"kind": "spawn", "id": "goblin_slinger"},
	"m": {"kind": "spawn", "id": "goblin_shaman"}
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

const GOBLIN_BUILDINGS := {
	"goblin_hub": {
		"name": "Empty Goblin Hub",
		"role": "Empty landing room and village approach chamber.",
		"footprint": [19, 11],
		"floor_row": 9,
		"entrances": {"left": [0, 8], "right": [18, 8]},
		"required_tiles": ["goblin_timber_wall", "goblin_packed_floor", "goblin_hide_canopy"],
		"required_props": ["goblin_torch"],
		"layout": [
			"___^^^^^^^^^^^^^___",
			"__###.........###__",
			"_###...........###_",
			"###.............###",
			"##...............##",
			"##...............##",
			"##...............##",
			"###.............###",
			"_###...........###_",
			"===================",
			"==================="
		]
	},
	"goblin_village_chamber": {
		"name": "Goblin Village Chamber",
		"role": "Main hostile village room, central hut facade, and connection anchor.",
		"footprint": [29, 13],
		"floor_row": 11,
		"entrances": {"left": [0, 10], "right": [28, 10]},
		"required_tiles": ["goblin_timber_wall", "goblin_packed_floor", "goblin_hide_canopy", "goblin_mossy_brick", "goblin_plank_platform"],
		"required_props": ["goblin_torch", "goblin_banner", "goblin_central_hut", "goblin_back_hut_lit", "goblin_back_hut_dark", "goblin_work_shelf", "goblin_wall_torch"],
		"layout": [
			"____^^^^^^^^^^^^^^^^^^^^^____",
			"____#####...........#####____",
			"__#####...............#####__",
			"_#####.................#####_",
			"####........h...j........####",
			"###........g..H..s........###",
			"##.........................##",
			"##.............F...........##",
			"##.........W...............##",
			"###.......................###",
			"_#####.................#####_",
			"MMMMM===================MMMMM",
			"MMMMM=======---=========MMMMM"
		]
	},
	"goblin_altar": {
		"name": "Goblin Bone Altar",
		"role": "Hostile ritual room and shaman spawn point.",
		"footprint": [15, 10],
		"floor_row": 8,
		"entrances": {"left": [0, 7], "right": [14, 7]},
		"required_tiles": ["goblin_timber_wall", "goblin_packed_floor", "goblin_hide_canopy"],
		"required_props": ["goblin_bone_altar", "goblin_torch", "goblin_banner"],
		"layout": [
			"__^^^^^^^^^^^__",
			"_####.....####_",
			"####.......####",
			"##.....A.....##",
			"##...........##",
			"##....m......##",
			"###.........###",
			"_###.......###_",
			"===============",
			"==============="
		]
	},
	"goblin_barracks": {
		"name": "Goblin Barracks",
		"role": "Dense hostile room with several grunts.",
		"footprint": [17, 10],
		"floor_row": 8,
		"entrances": {"left": [0, 7], "right": [16, 7]},
		"required_tiles": ["goblin_timber_wall", "goblin_packed_floor", "goblin_hide_canopy"],
		"required_props": ["goblin_crate", "goblin_door_flap"],
		"layout": [
			"__^^^^^^^^^^^^^__",
			"_####.......####_",
			"####.........####",
			"##..g...g...g..##",
			"##.............##",
			"##..C.......C..##",
			"###...........###",
			"_###....D....###_",
			"=================",
			"================="
		]
	},
	"goblin_storehouse": {
		"name": "Goblin Storehouse",
		"role": "Crate room with a slinger guard.",
		"footprint": [15, 9],
		"floor_row": 7,
		"entrances": {"left": [0, 6], "right": [14, 6]},
		"required_tiles": ["goblin_timber_wall", "goblin_packed_floor", "goblin_hide_canopy"],
		"required_props": ["goblin_crate", "goblin_door_flap"],
		"layout": [
			"__^^^^^^^^^^^__",
			"_####.....####_",
			"####.......####",
			"##..C.C.C....##",
			"##...........##",
			"##....s......##",
			"_###...D...###_",
			"===============",
			"==============="
		]
	},
	"goblin_watch_post": {
		"name": "Goblin Watch Post",
		"role": "Small vertical lookout tied back to the same village baseline.",
		"footprint": [11, 13],
		"floor_row": 11,
		"entrances": {"left": [0, 10], "right": [10, 10]},
		"required_tiles": ["goblin_timber_wall", "goblin_packed_floor", "goblin_plank_platform"],
		"required_props": ["goblin_palisade_post", "goblin_torch", "goblin_rope_ladder"],
		"layout": [
			"____P______",
			"___PPP_____",
			"__#####____",
			"___#T#_____",
			"___###_____",
			"___#s#_____",
			"___#L#_____",
			"__#---#____",
			"_###...###_",
			"###.....###",
			"##.......##",
			"===========",
			"==========="
		]
	},
	"goblin_cage": {
		"name": "Goblin Cage Room",
		"role": "Cage landmark with one goblin guard.",
		"footprint": [13, 9],
		"floor_row": 7,
		"entrances": {"left": [0, 6], "right": [12, 6]},
		"required_tiles": ["goblin_timber_wall", "goblin_packed_floor", "goblin_hide_canopy"],
		"required_props": ["goblin_cage", "goblin_door_flap"],
		"layout": [
			"__^^^^^^^^^__",
			"_###.....###_",
			"###.......###",
			"##...X.....##",
			"##....g....##",
			"##.........##",
			"_###..D..###_",
			"=============",
			"============="
		]
	},
	"goblin_ladder_shaft": {
		"name": "Goblin Ladder Shaft",
		"role": "Vertical traversal read with rope ladders, scaffold posts, and small platform perches.",
		"footprint": [13, 16],
		"floor_row": 14,
		"entrances": {"left": [0, 13], "right": [12, 13]},
		"required_tiles": ["goblin_mossy_brick", "goblin_plank_platform", "goblin_packed_floor"],
		"required_props": ["goblin_rope_ladder", "goblin_rope_bridge", "goblin_scaffold_post", "goblin_diagonal_brace", "goblin_wall_torch"],
		"layout": [
			"__M###M###M__",
			"_M#.......#M_",
			"M#...|.....#M",
			"M#...L..F..#M",
			"M#...L.....#M",
			"M#---L---s-#M",
			"M#...L.....#M",
			"M#...L..~..#M",
			"M#---L-----#M",
			"M#...L.....#M",
			"M#...L..F..#M",
			"M#.../.....#M",
			"_M#.......#M_",
			"===-----=====",
			"=============",
			"MMMMMMMMMMMMM"
		]
	},
	"goblin_raised_hut": {
		"name": "Raised Hide Hut",
		"role": "Foreground hut facade on planks with distant background huts tucked into the cave wall.",
		"footprint": [23, 14],
		"floor_row": 12,
		"entrances": {"left": [0, 11], "right": [22, 11]},
		"required_tiles": ["goblin_mossy_brick", "goblin_plank_platform", "goblin_hide_canopy", "goblin_packed_floor"],
		"required_props": ["goblin_central_hut", "goblin_back_hut_lit", "goblin_back_hut_dark", "goblin_crate", "goblin_door_flap", "goblin_wall_torch"],
		"layout": [
			"_____^^^^^^^^^^^^^_____",
			"___MM###.......###MM___",
			"__M##.............##M__",
			"_M##.....h...j.....##M_",
			"M##.................##M",
			"M##......H..........##M",
			"M##.................##M",
			"M##....C.....C......##M",
			"M##........g........##M",
			"M##.................##M",
			"_M##.....D.....F...##M_",
			"---=======---=======---",
			"MMMMM=============MMMMM",
			"MMMMMMMMMMMMMMMMMMMMMMM"
		]
	},
	"goblin_scaffold_market": {
		"name": "Scaffold Market Shelf",
		"role": "Workbench and shelf room with rope bridge reads and rough scaffold floor pieces.",
		"footprint": [19, 11],
		"floor_row": 9,
		"entrances": {"left": [0, 8], "right": [18, 8]},
		"required_tiles": ["goblin_mossy_brick", "goblin_plank_platform", "goblin_hide_canopy", "goblin_packed_floor"],
		"required_props": ["goblin_work_shelf", "goblin_rope_bridge", "goblin_crate", "goblin_wall_torch"],
		"layout": [
			"__^^^^^^^^^^^^^^^__",
			"_M##...........##M_",
			"M##......W......##M",
			"M##.............##M",
			"M##..C..F..C....##M",
			"M##.............##M",
			"M##..~.....~....##M",
			"_M##....s......##M_",
			"===-----===-----===",
			"MMMMM=========MMMMM",
			"MMMMMMMMMMMMMMMMMMM"
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

const DROW_VILLAGE_FULL := {
	"id": "drow_village_full",
	"name": "Drow Village Full",
	"band": "drow_enclaves",
	"tile_y_range": [1152, 1535],
	"template_path": "res://data/templates/drow_village_full.json",
	"required_tiles": DROW_TILE_IDS,
	"required_backgrounds": DROW_SETTLEMENT_BACKGROUND_IDS,
	"required_props": DROW_SETTLEMENT_PROP_IDS,
	"rooms": ["spider_court", "shadow_respite", "scriptuarium_tower", "arena_pit", "trap_shaft"],
	"primary_spawn": "drow_matriarch",
}

const GOBLIN_VILLAGE := {
	"id": "goblin_village",
	"name": "Goblin Timber Village",
	"band": "standard_caverns",
	"tile_y_range": [48, 340],
	"preferred_anchor": "wide Band 1 cave pocket or carved horizontal structure pocket",
	"minimum_clearance_tiles": [76, 24],
	"baseline_jitter_tiles": 2,
	"required_tiles": GOBLIN_TILE_IDS,
	"required_backgrounds": GOBLIN_BACKGROUND_IDS,
	"required_props": GOBLIN_PROP_IDS,
	"symbol_legend": GOBLIN_SYMBOLS,
	"required_buildings": ["goblin_hub", "goblin_village_chamber"],
	"optional_buildings": ["goblin_altar", "goblin_barracks", "goblin_storehouse", "goblin_watch_post", "goblin_cage", "goblin_ladder_shaft", "goblin_raised_hut", "goblin_scaffold_market"],
	"building_order": [
		"goblin_hub",
		"goblin_village_chamber",
		"goblin_altar",
		"goblin_barracks",
		"goblin_storehouse",
		"goblin_watch_post",
		"goblin_cage",
		"goblin_ladder_shaft",
		"goblin_raised_hut",
		"goblin_scaffold_market"
	],
	"generation_rules": [
		"Place the empty hub first as the approach room.",
		"Place the larger village chamber next to the hub on the same baseline, using the hut facade as the visual focal point.",
		"Attach two to four optional rooms to the chamber and keep entrances within two tiles of the chamber baseline.",
		"Use ladder shafts, plank platforms, rope bridge props, and scaffold posts to imply stacked settlement routes inside a mostly horizontal pocket.",
		"Place backdrop-only hut facades behind foreground floors and walls for distant decorative dwellings.",
		"Reject padded building rectangles that overlap.",
		"Connect every room with a three-tile-high corridor and a solid packed-floor or plank row.",
		"Fill passable room interiors with timber backwalls, hide patch accents, and packed-earth connector walls.",
		"Spawn goblins from marker symbols only when the player approaches the village."
	]
}

static func get_village(village_id: String) -> Dictionary:
	if village_id == "drow_village":
		return DROW_VILLAGE
	if village_id == "goblin_village":
		return GOBLIN_VILLAGE
	return {}

static func get_building(building_id: String) -> Dictionary:
	if DROW_BUILDINGS.has(building_id):
		return DROW_BUILDINGS[building_id]
	return GOBLIN_BUILDINGS.get(building_id, {})

static func get_building_ids(village_id := "drow_village") -> Array:
	var village := get_village(village_id)
	return [] if village.is_empty() else village.building_order

static func get_symbol(symbol: String) -> Dictionary:
	return DROW_SYMBOLS.get(symbol, {})

static func get_symbol_for_village(village_id: String, symbol: String) -> Dictionary:
	var village := get_village(village_id)
	if village.is_empty():
		return {}
	return Dictionary(village.symbol_legend).get(symbol, {})
