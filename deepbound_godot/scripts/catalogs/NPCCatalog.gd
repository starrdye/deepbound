extends RefCounted
class_name NPCCatalog

## Static registry of all friendly NPC definitions.
## Fields:
##   name           — display name shown in dialogue nameplate
##   sprite_key     — reserved for future sprite atlas lookup
##   dialogue       — ordered list of DialogueCatalog node IDs to play
##   shop           — VendorCatalog shop ID ("" = no shop)
##   interact_radius — world-pixel radius for the [T] Talk prompt

const NPCS := {
	"wandering_merchant": {
		"name": "Wandering Merchant",
		"sprite_key": "merchant",
		"dialogue": ["merchant_greet", "merchant_pitch", "merchant_open_shop"],
		"shop": "wandering_merchant",
		"interact_radius": 52.0,
	},
	"old_miner": {
		"name": "Old Miner",
		"sprite_key": "miner",
		"dialogue": ["miner_greet", "miner_lore_1", "miner_lore_2", "miner_farewell"],
		"shop": "",
		"interact_radius": 52.0,
	},
	"cave_hermit": {
		"name": "Cave Hermit",
		"sprite_key": "hermit",
		"dialogue": ["hermit_greet", "hermit_lore_1", "hermit_warning"],
		"shop": "",
		"interact_radius": 52.0,
	},
}

static func get_npc(npc_id: String) -> Dictionary:
	return NPCS.get(npc_id, {})
