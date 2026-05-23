extends RefCounted
class_name ModifierCatalog

## Modifier / Prefix catalog — Terraria-style item prefixes.
##
## Modifiers apply to weapons and accessories only.  Each entry contains:
##   name           — display name prepended to the item name in the tooltip
##   damage_mult    — multiplier applied to weapon base damage (1.0 = neutral)
##   speed_mult     — use/swing speed multiplier              (1.0 = neutral)
##   knockback_mult — knockback multiplier                    (1.0 = neutral)
##   crit_bonus     — additive crit-chance bonus  (0.05 = +5 %; 0.0 = none)
##   value_mult     — drop/sell value multiplier  (informational only)
##   tier           — display tier: legendary | rare | uncommon | common | broken
##   defense_bonus  — (optional) flat defense bonus for accessories
##
## Stacks store the modifier_id as a plain String in their "modifier" key:
##   {"item": "wooden_sword", "count": 1, "stack_cap": 1, "modifier": "sharp"}

const MODIFIERS := {
	# ── Legendary ────────────────────────────────────────────────────────────────
	"legendary": {
		"name": "Legendary", "tier": "legendary",
		"damage_mult": 1.15, "speed_mult": 1.05, "knockback_mult": 1.15,
		"crit_bonus": 0.05,  "value_mult": 2.5,
	},
	"godly": {
		"name": "Godly", "tier": "legendary",
		"damage_mult": 1.15, "speed_mult": 1.10, "knockback_mult": 1.15,
		"crit_bonus": 0.07,  "value_mult": 3.0,
	},
	# ── Rare ─────────────────────────────────────────────────────────────────────
	"demonic": {
		"name": "Demonic", "tier": "rare",
		"damage_mult": 1.15, "speed_mult": 1.0,  "knockback_mult": 1.0,
		"crit_bonus": 0.10,  "value_mult": 1.8,
	},
	"keen": {
		"name": "Keen", "tier": "rare",
		"damage_mult": 1.05, "speed_mult": 1.0,  "knockback_mult": 1.0,
		"crit_bonus": 0.04,  "value_mult": 1.4,
	},
	# ── Uncommon ─────────────────────────────────────────────────────────────────
	"sharp": {
		"name": "Sharp", "tier": "uncommon",
		"damage_mult": 1.10, "speed_mult": 1.0,  "knockback_mult": 1.0,
		"crit_bonus": 0.0,   "value_mult": 1.3,
	},
	"heavy": {
		"name": "Heavy", "tier": "uncommon",
		"damage_mult": 1.0,  "speed_mult": 0.90, "knockback_mult": 1.25,
		"crit_bonus": 0.0,   "value_mult": 1.1,
	},
	"swift": {
		"name": "Swift", "tier": "uncommon",
		"damage_mult": 1.0,  "speed_mult": 1.15, "knockback_mult": 1.0,
		"crit_bonus": 0.0,   "value_mult": 1.1,
	},
	"lucky": {
		"name": "Lucky", "tier": "uncommon",
		"damage_mult": 1.0,  "speed_mult": 1.0,  "knockback_mult": 1.0,
		"crit_bonus": 0.08,  "value_mult": 1.2,
	},
	"menacing": {
		"name": "Menacing", "tier": "uncommon",
		"damage_mult": 1.04, "speed_mult": 1.0,  "knockback_mult": 1.0,
		"crit_bonus": 0.0,   "value_mult": 1.2,
	},
	"violent": {
		"name": "Violent", "tier": "uncommon",
		"damage_mult": 1.0,  "speed_mult": 1.0,  "knockback_mult": 1.0,
		"crit_bonus": 0.06,  "value_mult": 1.3,
	},
	"warding": {
		"name": "Warding", "tier": "uncommon",
		"damage_mult": 1.0,  "speed_mult": 1.0,  "knockback_mult": 1.0,
		"crit_bonus": 0.0,   "value_mult": 1.1,  "defense_bonus": 2,
	},
	"quick": {
		"name": "Quick", "tier": "uncommon",
		"damage_mult": 1.0,  "speed_mult": 1.08, "knockback_mult": 1.0,
		"crit_bonus": 0.0,   "value_mult": 1.1,
	},
	# ── Broken (negative) ────────────────────────────────────────────────────────
	"broken": {
		"name": "Broken", "tier": "broken",
		"damage_mult": 0.75, "speed_mult": 0.90, "knockback_mult": 0.75,
		"crit_bonus": 0.0,   "value_mult": 0.5,
	},
	"blunt": {
		"name": "Blunt", "tier": "broken",
		"damage_mult": 0.85, "speed_mult": 1.0,  "knockback_mult": 0.85,
		"crit_bonus": 0.0,   "value_mult": 0.7,
	},
}

## Modifier pools by item slot / category.
const MELEE_POOL     := ["legendary", "godly", "demonic", "keen", "sharp", "heavy", "swift", "lucky", "broken", "blunt"]
const ACCESSORY_POOL := ["menacing", "warding", "violent", "quick", "lucky"]

## Probability (0–1) that a droppable weapon / accessory receives a modifier.
const ROLL_CHANCE := 0.30

# ── Lookups ───────────────────────────────────────────────────────────────────

## Return the modifier entry for modifier_id, or {} if unknown.
static func get_modifier(modifier_id: String) -> Dictionary:
	return MODIFIERS.get(modifier_id, {})

## Returns true when modifier_id names a known modifier.
static func is_valid(modifier_id: String) -> bool:
	return modifier_id != "" and MODIFIERS.has(modifier_id)

# ── Rolling ───────────────────────────────────────────────────────────────────

## Roll a modifier_id for an item in the given category ("weapon", "accessory").
## Returns "" (no modifier) when the roll fails or the category has no pool.
static func roll_for_item(item_category: String) -> String:
	if randf() > ROLL_CHANCE:
		return ""
	var pool: Array = []
	match item_category:
		"weapon":    pool = MELEE_POOL
		"accessory": pool = ACCESSORY_POOL
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]

# ── Visual ────────────────────────────────────────────────────────────────────

## Display colour for a modifier, matched to ItemCatalog.rarity_color palette.
static func modifier_color(modifier_id: String) -> Color:
	var mod := get_modifier(modifier_id)
	match String(mod.get("tier", "")):
		"legendary": return Color8(255, 170,   0)
		"rare":      return Color8( 85, 170, 255)
		"uncommon":  return Color8( 85, 255,  85)
		"broken":    return Color8(180,  60,  60)
	return Color8(210, 210, 210)
