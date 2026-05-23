extends RefCounted
class_name DialogueCatalog

## Static registry of all dialogue nodes.
## Fields:
##   text    — the line of dialogue shown in the text area
##   speaker — name shown in the nameplate
##   event   — optional trigger fired when the player advances past this node:
##               ""         — no event
##               "open_shop" — close dialogue and open the NPC's vendor shop

const NODES := {
	# ── Wandering Merchant ────────────────────────────────────────────────────
	"merchant_greet": {
		"text": "Well met, traveller! These tunnels are no place for the unprepared.",
		"speaker": "Wandering Merchant",
		"event": "",
	},
	"merchant_pitch": {
		"text": "Fortunately for you, I've been hauling wares through these caves for years. I know exactly what keeps a digger alive.",
		"speaker": "Wandering Merchant",
		"event": "",
	},
	"merchant_open_shop": {
		"text": "Take a look at my stock. Fair prices — I swear on my pickaxe.",
		"speaker": "Wandering Merchant",
		"event": "open_shop",
	},
	# ── Old Miner ─────────────────────────────────────────────────────────────
	"miner_greet": {
		"text": "You there! Watch your step in these caverns.",
		"speaker": "Old Miner",
		"event": "",
	},
	"miner_lore_1": {
		"text": "I've been down here forty years. These ants — they're not natural. They started building deeper about a decade back. Something called them down.",
		"speaker": "Old Miner",
		"event": "",
	},
	"miner_lore_2": {
		"text": "The drow used to trade with us at the border stones. Now they seal their gates and shoot anyone who wanders past the third cavern. Something changed.",
		"speaker": "Old Miner",
		"event": "",
	},
	"miner_farewell": {
		"text": "Stay close to the walls. The open spaces are where things live.",
		"speaker": "Old Miner",
		"event": "",
	},
	# ── Cave Hermit ───────────────────────────────────────────────────────────
	"hermit_greet": {
		"text": "*startled* Oh — a living face. I've been alone so long I'd almost forgotten what one looks like.",
		"speaker": "Cave Hermit",
		"event": "",
	},
	"hermit_lore_1": {
		"text": "The resin veins are expanding. I mapped them three years ago — they've doubled since. The ants are feeding something enormous down below.",
		"speaker": "Cave Hermit",
		"event": "",
	},
	"hermit_warning": {
		"text": "Do NOT bring a cursed relic to the deep pyramid. I saw what happened to the last group who tried. I was the only one who ran.",
		"speaker": "Cave Hermit",
		"event": "",
	},
}

static func get_node(node_id: String) -> Dictionary:
	return NODES.get(node_id, {})
