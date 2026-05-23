extends RefCounted
class_name ModifierSystem

## Stat-calculation and tooltip helpers for the item modifier / prefix system.
##
## All methods are static — instantiation is never required.

const ModifierCatalog  = preload("res://scripts/catalogs/ModifierCatalog.gd")
const EquipmentCatalog = preload("res://scripts/catalogs/EquipmentCatalog.gd")
const ItemCatalog      = preload("res://scripts/catalogs/ItemCatalog.gd")

# ── Stat getters ──────────────────────────────────────────────────────────────

## Return the modified damage for item_id + modifier_id.
## Base damage comes from EquipmentCatalog.  Returns the base unchanged if
## item has no damage stat, or modifier_id is invalid / empty.
static func get_modified_damage(item_id: String, modifier_id: String) -> int:
	var eq_def  := EquipmentCatalog.get_equippable(item_id)
	var base_dmg := int(eq_def.get("stats", {}).get("damage", 0))
	if base_dmg == 0 or not ModifierCatalog.is_valid(modifier_id):
		return base_dmg
	var mod := ModifierCatalog.get_modifier(modifier_id)
	return roundi(float(base_dmg) * float(mod.get("damage_mult", 1.0)))

# ── Display helpers ───────────────────────────────────────────────────────────

## Return the display name for a stack, prefixing the modifier name when set.
##   get_display_name("wooden_sword", "sharp") → "Sharp Wooden Sword"
##   get_display_name("wooden_sword", "")      → "Wooden Sword"
static func get_display_name(item_id: String, modifier_id: String) -> String:
	var item_def  := ItemCatalog.get_item(item_id)
	var base_name := String(item_def.get("name", item_id.replace("_", " ").capitalize()))
	if not ModifierCatalog.is_valid(modifier_id):
		return base_name
	var mod := ModifierCatalog.get_modifier(modifier_id)
	return String(mod.get("name", "")) + " " + base_name

# ── Tooltip ───────────────────────────────────────────────────────────────────

## Build modifier stat-delta lines suitable for the HUD tooltip.
## Returns an Array[Dictionary] each with keys: text (String), color (Color),
## size (int).  Only includes stats that differ from neutral.
##
## Parameters:
##   modifier_id  — the modifier to describe
##   item_id      — the host item (needed for base damage comparison)
##   font_size    — text size in points (usually TOOLTIP_BODY_SZ from HudController)
static func build_tooltip_stat_lines(modifier_id: String, item_id: String, font_size: int) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if not ModifierCatalog.is_valid(modifier_id):
		return lines
	var mod      := ModifierCatalog.get_modifier(modifier_id)
	var eq_def   := EquipmentCatalog.get_equippable(item_id)
	var base_dmg := int(eq_def.get("stats", {}).get("damage", 0))

	# Damage — only shown for weapons that have a damage stat
	var dmg_mult := float(mod.get("damage_mult", 1.0))
	if dmg_mult != 1.0 and base_dmg > 0:
		var new_dmg := roundi(float(base_dmg) * dmg_mult)
		var diff    := new_dmg - base_dmg
		var sign    := "+" if diff > 0 else ""
		var col     := Color8(100, 220, 100) if diff > 0 else Color8(220, 80, 80)
		lines.append({"text": "Damage  %d → %d  (%s%d)" % [base_dmg, new_dmg, sign, diff], "color": col, "size": font_size})

	# Speed
	var spd_mult := float(mod.get("speed_mult", 1.0))
	if spd_mult != 1.0:
		var pct  := roundi((spd_mult - 1.0) * 100.0)
		var sign := "+" if pct > 0 else ""
		var col  := Color8(100, 220, 100) if pct > 0 else Color8(220, 80, 80)
		lines.append({"text": "Speed  %s%d%%" % [sign, pct], "color": col, "size": font_size})

	# Knockback
	var kb_mult := float(mod.get("knockback_mult", 1.0))
	if kb_mult != 1.0:
		var pct  := roundi((kb_mult - 1.0) * 100.0)
		var sign := "+" if pct > 0 else ""
		var col  := Color8(100, 220, 100) if pct > 0 else Color8(220, 80, 80)
		lines.append({"text": "Knockback  %s%d%%" % [sign, pct], "color": col, "size": font_size})

	# Crit bonus
	var crit := float(mod.get("crit_bonus", 0.0))
	if crit != 0.0:
		var pct  := roundi(crit * 100.0)
		var sign := "+" if pct > 0 else ""
		var col  := Color8(100, 220, 100) if pct > 0 else Color8(220, 80, 80)
		lines.append({"text": "Crit  %s%d%%" % [sign, pct], "color": col, "size": font_size})

	# Defense bonus (accessories only)
	var def_bonus := int(mod.get("defense_bonus", 0))
	if def_bonus != 0:
		var sign := "+" if def_bonus > 0 else ""
		var col  := Color8(100, 220, 100) if def_bonus > 0 else Color8(220, 80, 80)
		lines.append({"text": "Defense  %s%d" % [sign, def_bonus], "color": col, "size": font_size})

	return lines
