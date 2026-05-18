extends RefCounted
class_name BackgroundCatalog

const EMPTY_ID := "empty"

const BACKGROUNDS := {
	"empty": {"name": "No Background", "band": "shared", "hardness": INF, "breakable": false, "color": Color.TRANSPARENT, "highlight": Color.TRANSPARENT, "item": "", "drops": []},
	"dirt_background_block": {"name": "Dirt Background Block", "band": "standard_caverns", "hardness": 0.65, "breakable": true, "color": Color8(70, 47, 36), "highlight": Color8(118, 77, 48), "item": "dirt_background_block", "drops": [{"item": "dirt_background_block", "min": 1, "max": 1, "chance": 1.0}]},
	"stone_background_block": {"name": "Stone Background Block", "band": "standard_caverns", "hardness": 1.05, "breakable": true, "color": Color8(54, 59, 68), "highlight": Color8(96, 105, 114), "item": "stone_background_block", "drops": [{"item": "stone_background_block", "min": 1, "max": 1, "chance": 1.0}]},
	"wooden_background_block": {"name": "Wooden Background Block", "band": "shared", "hardness": 0.8, "breakable": true, "color": Color8(87, 54, 32), "highlight": Color8(162, 101, 48), "item": "wooden_background_block", "drops": [{"item": "wooden_background_block", "min": 1, "max": 1, "chance": 1.0}]},
}

static func get_background(background_id: String) -> Dictionary:
	return BACKGROUNDS.get(background_id, BACKGROUNDS.empty)

static func is_empty(background_id: String) -> bool:
	return background_id == EMPTY_ID or not BACKGROUNDS.has(background_id)

static func is_breakable(background_id: String) -> bool:
	return bool(get_background(background_id).breakable)

static func get_background_ids() -> Array:
	return BACKGROUNDS.keys()
