extends RefCounted
class_name ItemCatalog

const ITEMS := {
	"dirt_clod": {
		"name": "Dirt Clod",
		"desc": "Loose earth. Can be placed to fill gaps.",
		"rarity": "common",
		"category": "placeable",
	},
	"stone_chunk": {
		"name": "Stone Chunk",
		"desc": "A rough piece of stone. Solid when placed.",
		"rarity": "common",
		"category": "placeable",
	},
	"copper_nugget": {
		"name": "Copper Nugget",
		"desc": "A small nugget of copper ore.\nUsed in crafting and trade.",
		"rarity": "common",
		"category": "material",
	},
	"wooden_sword": {
		"name": "Wooden Sword",
		"desc": "A crude blade carved from hardwood.\n3 damage  |  Melee",
		"rarity": "common",
		"category": "weapon",
	},
	"hammer": {
		"name": "Hammer",
		"desc": "Breaks background walls.\nEssential for clearing hidden passages.",
		"rarity": "common",
		"category": "tool",
	},
	"chest": {
		"name": "Chest",
		"desc": "A wooden chest for storing items.\nPlace it to open.",
		"rarity": "common",
		"category": "placeable",
	},
	"dirt_background_block": {
		"name": "Dirt Wall",
		"desc": "Packed earth for building background walls.",
		"rarity": "common",
		"category": "placeable",
	},
	"stone_background_block": {
		"name": "Stone Wall",
		"desc": "A solid stone background block.",
		"rarity": "common",
		"category": "placeable",
	},
	"wooden_background_block": {
		"name": "Wooden Wall",
		"desc": "Planks of wood for building walls.",
		"rarity": "common",
		"category": "placeable",
	},
	"resin_shard": {
		"name": "Resin Shard",
		"desc": "Hardened tree sap found deep in ant chambers.\nSticky and durable.",
		"rarity": "uncommon",
		"category": "material",
	},
	"royal_jelly": {
		"name": "Royal Jelly",
		"desc": "Produced by the ant queen.\nHighly prized by alchemists.",
		"rarity": "rare",
		"category": "material",
	},
	"sandstone_shard": {
		"name": "Sandstone Shard",
		"desc": "Compressed desert stone from buried pyramids.",
		"rarity": "uncommon",
		"category": "placeable",
	},
	"cursed_relic": {
		"name": "Cursed Relic",
		"desc": "An artefact radiating dark energy.\nHandle with extreme care.",
		"rarity": "epic",
		"category": "material",
	},
	"glow_spore": {
		"name": "Glow Spore",
		"desc": "A bioluminescent spore from cave fungi.\nEmits a faint, eerie glow.",
		"rarity": "uncommon",
		"category": "material",
	},
	"drow_silk": {
		"name": "Drow Silk",
		"desc": "Woven from spider webs by drow artisans.\nLighter than air, stronger than steel.",
		"rarity": "rare",
		"category": "material",
	},
	"obsidian_chip": {
		"name": "Obsidian Chip",
		"desc": "Volcanic glass, razor-sharp and extremely hard.\nFound near deep heat vents.",
		"rarity": "rare",
		"category": "material",
	},
	"crystal_drill": {
		"name": "Crystal Drill",
		"desc": "A drill tipped with cave crystal.\nMines faster and reaches deeper.",
		"rarity": "rare",
		"category": "tool",
	},
	"cursed_drill": {
		"name": "Cursed Drill",
		"desc": "Imbued with dark energy.\nCuts through nearly any material.",
		"rarity": "epic",
		"category": "tool",
	},
	"crystal_sword": {
		"name": "Crystal Sword",
		"desc": "Forged from cave crystals.\n6 damage  |  Melee",
		"rarity": "rare",
		"category": "weapon",
	},
	"cursed_sword": {
		"name": "Cursed Sword",
		"desc": "Pulsing with malevolent energy.\n10 damage  |  Melee",
		"rarity": "epic",
		"category": "weapon",
	},
	"workbench": {
		"name": "Workbench",
		"desc": "Unlocks basic crafting recipes.\nPlace it nearby to use.",
		"rarity": "common",
		"category": "placeable",
	},
	"furnace": {
		"name": "Furnace",
		"desc": "Smelts ores and processes materials.\nNeeded for advanced recipes.",
		"rarity": "common",
		"category": "placeable",
	},
	"anvil": {
		"name": "Anvil",
		"desc": "Forges powerful weapons and tools.\nRequires a Workbench and Furnace.",
		"rarity": "uncommon",
		"category": "placeable",
	},
}

	# ── Equipment — Head ─────────────────────────────────────────────────────
	"iron_helm": {
		"name": "Iron Helm",
		"desc": "A sturdy iron helmet.\n+2 Defense",
		"rarity": "common",
		"category": "head",
	},
	"crystal_helm": {
		"name": "Crystal Helm",
		"desc": "A helm of cave crystal.\n+4 Defense  |  +5 Max HP",
		"rarity": "rare",
		"category": "head",
	},
	# ── Equipment — Body ─────────────────────────────────────────────────────
	"leather_vest": {
		"name": "Leather Vest",
		"desc": "Tanned hide stitched into a vest.\n+1 Defense",
		"rarity": "common",
		"category": "body",
	},
	"iron_chestplate": {
		"name": "Iron Chestplate",
		"desc": "Heavy iron plate for the chest.\n+4 Defense",
		"rarity": "uncommon",
		"category": "body",
	},
	# ── Equipment — Legs ─────────────────────────────────────────────────────
	"leather_pants": {
		"name": "Leather Pants",
		"desc": "Simple hardened leather legwear.\n+1 Defense",
		"rarity": "common",
		"category": "legs",
	},
	"iron_greaves": {
		"name": "Iron Greaves",
		"desc": "Leg armor hammered from iron.\n+2 Defense",
		"rarity": "uncommon",
		"category": "legs",
	},
	# ── Equipment — Feet ─────────────────────────────────────────────────────
	"leather_boots": {
		"name": "Leather Boots",
		"desc": "Sturdy boots for cave exploration.\n+1 Defense  |  +10% Speed",
		"rarity": "common",
		"category": "feet",
	},
	# ── Equipment — Accessory ────────────────────────────────────────────────
	"copper_ring": {
		"name": "Copper Ring",
		"desc": "A simple copper band.\n+5 Max HP",
		"rarity": "common",
		"category": "accessory",
	},
	"resin_amulet": {
		"name": "Resin Amulet",
		"desc": "Hardened resin pendant.\n+1 Defense  |  -10% Drill Heat",
		"rarity": "uncommon",
		"category": "accessory",
	},
	# ── Equipment — Utility ──────────────────────────────────────────────────
	"torch": {
		"name": "Torch",
		"desc": "A burning torch.\nIlluminates a wide area when equipped.",
		"rarity": "common",
		"category": "utility",
	},
	"lantern": {
		"name": "Lantern",
		"desc": "An oil lantern with a bright steady flame.\nIlluminates a very wide area when equipped.",
		"rarity": "uncommon",
		"category": "utility",
	},
}

static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})

static func rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon": return Color8(85, 255, 85)
		"rare":     return Color8(85, 170, 255)
		"epic":     return Color8(200, 100, 255)
		"legendary": return Color8(255, 170, 0)
	return Color8(255, 255, 255)
