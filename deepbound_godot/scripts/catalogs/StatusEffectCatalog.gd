extends RefCounted
class_name StatusEffectCatalog

## Predefined status-effect definitions used by the terminal buff/debuff commands
## and any in-game systems that want to apply named effects.
##
## Each entry mirrors the fields of StatusEffectData:
##   display_name  — human-readable name
##   duration      — seconds; <= 0 means permanent
##   stat_modifiers — same keys as StatCalculator totals
##   is_debuff     — true for harmful effects

const StatusEffectData = preload("res://scripts/components/StatusEffectData.gd")

const EFFECTS: Dictionary = {
	# ── Buffs ─────────────────────────────────────────────────────────────────
	"swiftness": {
		"display_name":  "Swiftness",
		"duration":      30.0,
		"stat_modifiers": {"speed": 0.15},
		"is_debuff":     false,
	},
	"endurance": {
		"display_name":  "Endurance",
		"duration":      25.0,
		"stat_modifiers": {"defense": 3},
		"is_debuff":     false,
	},
	"fervor": {
		"display_name":  "Fervor",
		"duration":      20.0,
		"stat_modifiers": {"damage": 3},
		"is_debuff":     false,
	},
	"fortitude": {
		"display_name":  "Fortitude",
		"duration":      30.0,
		"stat_modifiers": {"health_max": 20},
		"is_debuff":     false,
	},
	"vigor": {
		"display_name":  "Vigor",
		"duration":      20.0,
		"stat_modifiers": {"damage": 2, "speed": 0.10},
		"is_debuff":     false,
	},
	# ── Debuffs ───────────────────────────────────────────────────────────────
	"slow": {
		"display_name":  "Slow",
		"duration":      10.0,
		"stat_modifiers": {"speed": -0.20},
		"is_debuff":     true,
	},
	"vulnerable": {
		"display_name":  "Vulnerable",
		"duration":      10.0,
		"stat_modifiers": {"defense": -2},
		"is_debuff":     true,
	},
	"weakness": {
		"display_name":  "Weakness",
		"duration":      10.0,
		"stat_modifiers": {"damage": -2},
		"is_debuff":     true,
	},
	"curse": {
		"display_name":  "Curse",
		"duration":      -1.0,   # permanent until cleared
		"stat_modifiers": {"damage": -2, "speed": -0.10},
		"is_debuff":     true,
	},
	"frail": {
		"display_name":  "Frail",
		"duration":      12.0,
		"stat_modifiers": {"defense": -3, "health_max": -10},
		"is_debuff":     true,
	},
}

## Returns true if effect_id is a known effect.
static func is_valid(effect_id: String) -> bool:
	return effect_id != "" and EFFECTS.has(effect_id)

## Returns a new StatusEffectData resource populated from the catalog entry.
## Returns null if effect_id is unknown.
static func make(effect_id: String) -> StatusEffectData:
	if not EFFECTS.has(effect_id):
		return null
	var def: Dictionary = EFFECTS[effect_id]
	var eff := StatusEffectData.new()
	eff.effect_id      = effect_id
	eff.display_name   = String(def.get("display_name", effect_id))
	eff.duration       = float(def.get("duration", -1.0))
	eff.stat_modifiers = def.get("stat_modifiers", {}).duplicate()
	eff.is_debuff      = bool(def.get("is_debuff", false))
	return eff

## Returns a sorted list of all known effect IDs (buffs first, then debuffs).
static func all_ids() -> Array:
	var buffs:   Array = []
	var debuffs: Array = []
	for id in EFFECTS:
		if bool(EFFECTS[id].get("is_debuff", false)):
			debuffs.append(id)
		else:
			buffs.append(id)
	buffs.sort()
	debuffs.sort()
	return buffs + debuffs
