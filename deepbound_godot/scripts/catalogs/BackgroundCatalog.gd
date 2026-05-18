extends RefCounted
class_name BackgroundCatalog

const EMPTY_ID := "empty"

const BACKGROUNDS := {
	"empty": {"name": "No Background", "band": "shared", "hardness": INF, "breakable": false, "color": Color.TRANSPARENT, "highlight": Color.TRANSPARENT, "item": "", "drops": []},
	"surface_root_background": {"name": "Surface Root Wall", "band": "surface_area", "hardness": 0.75, "breakable": true, "color": Color8(60, 52, 41), "highlight": Color8(132, 101, 61), "item": "dirt_background_block", "drops": [{"item": "dirt_background_block", "min": 1, "max": 1, "chance": 1.0}]},
	"dirt_background_block": {"name": "Dirt Background Block", "band": "standard_caverns", "hardness": 0.65, "breakable": true, "color": Color8(70, 47, 36), "highlight": Color8(118, 77, 48), "item": "dirt_background_block", "drops": [{"item": "dirt_background_block", "min": 1, "max": 1, "chance": 1.0}]},
	"stone_background_block": {"name": "Stone Background Block", "band": "standard_caverns", "hardness": 1.05, "breakable": true, "color": Color8(54, 59, 68), "highlight": Color8(96, 105, 114), "item": "stone_background_block", "drops": [{"item": "stone_background_block", "min": 1, "max": 1, "chance": 1.0}]},
	"wooden_background_block": {"name": "Wooden Background Block", "band": "shared", "hardness": 0.8, "breakable": true, "color": Color8(87, 54, 32), "highlight": Color8(162, 101, 48), "item": "wooden_background_block", "drops": [{"item": "wooden_background_block", "min": 1, "max": 1, "chance": 1.0}]},
	"goblin_timber_background": {"name": "Goblin Timber Backwall", "band": "standard_caverns", "hardness": 0.85, "breakable": true, "color": Color8(69, 45, 31), "highlight": Color8(146, 91, 45), "item": "wooden_background_block", "drops": [{"item": "wooden_background_block", "min": 1, "max": 1, "chance": 1.0}]},
	"goblin_hide_background": {"name": "Goblin Hide Backwall", "band": "standard_caverns", "hardness": 0.7, "breakable": true, "color": Color8(63, 56, 37), "highlight": Color8(139, 126, 69), "item": "wooden_background_block", "drops": [{"item": "wooden_background_block", "min": 1, "max": 1, "chance": 0.65}]},
	"goblin_packed_earth_background": {"name": "Goblin Packed Earth Wall", "band": "standard_caverns", "hardness": 0.75, "breakable": true, "color": Color8(63, 44, 35), "highlight": Color8(130, 86, 50), "item": "dirt_background_block", "drops": [{"item": "dirt_background_block", "min": 1, "max": 1, "chance": 1.0}]},
	"dwarf_granite_background": {"name": "Dwarf Granite Backwall", "band": "colossal_ant_chambers", "hardness": 1.35, "breakable": true, "color": Color8(48, 52, 54), "highlight": Color8(130, 137, 133), "item": "stone_background_block", "drops": [{"item": "stone_background_block", "min": 1, "max": 1, "chance": 1.0}]},
	"dwarf_forge_background": {"name": "Dwarf Forge Backwall", "band": "colossal_ant_chambers", "hardness": 1.45, "breakable": true, "color": Color8(72, 45, 35), "highlight": Color8(230, 143, 63), "item": "stone_background_block", "drops": [{"item": "stone_background_block", "min": 1, "max": 1, "chance": 1.0}]},
	"dwarf_rune_background": {"name": "Dwarf Rune Backwall", "band": "colossal_ant_chambers", "hardness": 1.55, "breakable": true, "color": Color8(45, 48, 57), "highlight": Color8(255, 214, 107), "item": "stone_background_block", "drops": [{"item": "stone_background_block", "min": 1, "max": 1, "chance": 1.0}]},
}

static func get_background(background_id: String) -> Dictionary:
	return BACKGROUNDS.get(background_id, BACKGROUNDS.empty)

static func is_empty(background_id: String) -> bool:
	return background_id == EMPTY_ID or not BACKGROUNDS.has(background_id)

static func is_breakable(background_id: String) -> bool:
	return bool(get_background(background_id).breakable)

static func get_background_ids() -> Array:
	return BACKGROUNDS.keys()
