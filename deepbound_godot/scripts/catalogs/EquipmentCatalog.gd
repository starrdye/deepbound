extends RefCounted
class_name EquipmentCatalog

## Defines every equippable item: the slot it occupies and the stat deltas
## it grants while equipped.
##
## Stat keys understood by StatCalculator / Main.gd:
##   damage      — flat bonus added to melee strike damage
##   defense     — flat damage reduction applied in PlayerController.damage()
##   health_max  — bonus max HP (fed into PlayerController.set_equipment_health_delta)
##   speed       — fractional speed multiplier bonus  (0.10 = +10 %)
##   drill_cool  — fractional drill-heat reduction    (0.10 = -10 %)
##
## Utility items also carry "light_radius_tiles" which is broadcast to
## World.set_player_utility_light() when the Utility slot changes.

const EQUIPPABLES := {
	# ── Weapon ───────────────────────────────────────────────────────────────
	"wooden_sword":     {"slot": "weapon",    "stats": {"damage":  3}},
	"crystal_sword":    {"slot": "weapon",    "stats": {"damage":  6}},
	"cursed_sword":     {"slot": "weapon",    "stats": {"damage": 10}},
	# ── Head ─────────────────────────────────────────────────────────────────
	"iron_helm":        {"slot": "head",      "stats": {"defense": 2}},
	"crystal_helm":     {"slot": "head",      "stats": {"defense": 4, "health_max": 5}},
	# ── Body ─────────────────────────────────────────────────────────────────
	"leather_vest":     {"slot": "body",      "stats": {"defense": 1}},
	"iron_chestplate":  {"slot": "body",      "stats": {"defense": 4}},
	# ── Legs ─────────────────────────────────────────────────────────────────
	"leather_pants":    {"slot": "legs",      "stats": {"defense": 1}},
	"iron_greaves":     {"slot": "legs",      "stats": {"defense": 2}},
	# ── Feet ─────────────────────────────────────────────────────────────────
	"leather_boots":    {"slot": "feet",      "stats": {"defense": 1, "speed": 0.10}},
	# ── Accessory ────────────────────────────────────────────────────────────
	"copper_ring":      {"slot": "accessory", "stats": {"health_max": 5}},
	"resin_amulet":     {"slot": "accessory", "stats": {"defense": 1, "drill_cool": 0.10}},
	# ── Utility ──────────────────────────────────────────────────────────────
	"torch":   {"slot": "utility", "stats": {}, "light_radius_tiles": 10.0},
	"lantern": {"slot": "utility", "stats": {}, "light_radius_tiles": 17.0},
}

static func get_equippable(item_id: String) -> Dictionary:
	return EQUIPPABLES.get(item_id, {})

static func is_equippable(item_id: String) -> bool:
	return EQUIPPABLES.has(item_id)

## Returns the slot_id this item belongs in, or "" if not equippable.
static func get_slot_for_item(item_id: String) -> String:
	return String(EQUIPPABLES.get(item_id, {}).get("slot", ""))
