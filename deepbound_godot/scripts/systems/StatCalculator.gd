extends RefCounted
class_name StatCalculator

const EquipmentSystem  = preload("res://scripts/systems/EquipmentSystem.gd")
const EquipmentCatalog = preload("res://scripts/catalogs/EquipmentCatalog.gd")
const ModifierCatalog  = preload("res://scripts/catalogs/ModifierCatalog.gd")

## Derives all equipment-based stat bonuses from an EquipmentSystem snapshot.
##
## Stat keys consumed:
##   damage      — flat bonus added to melee strike damage
##   defense     — flat damage reduction in PlayerController.damage()
##   health_max  — bonus max HP
##   speed       — fractional speed multiplier bonus  (0.10 = +10 %)
##   drill_cool  — fractional drill-heat reduction    (0.10 = -10 %)
##
## Utility items additionally carry light_radius_tiles which is exposed via
## get_utility_light_radius() for World.set_player_utility_light().

## Compute and return all summed stat bonuses from the given EquipmentSystem.
## Returns a Dictionary with integer/float values for every stat key.
static func compute(equipment_system) -> Dictionary:
	var totals := {
		"damage":     0,
		"defense":    0,
		"health_max": 0,
		"speed":      0.0,
		"drill_cool": 0.0,
	}

	for slot_id in EquipmentSystem.SLOT_IDS:
		var item_id: String = equipment_system.get_item(slot_id)
		if item_id == "":
			continue
		var eq_def: Dictionary = EquipmentCatalog.get_equippable(item_id)
		if eq_def.is_empty():
			continue
		var stats: Dictionary = eq_def.get("stats", {})
		for key in stats:
			if totals.has(key):
				totals[key] = totals[key] + stats[key]

	# Apply weapon modifier's damage_mult — replaces the raw base damage with
	# the modified value so the net change is (modified - base).
	if equipment_system.has_method("get_slot_modifier"):
		var weapon_id: String = equipment_system.get_item("weapon")
		if weapon_id != "":
			var modifier_id: String = equipment_system.get_slot_modifier("weapon")
			if ModifierCatalog.is_valid(modifier_id):
				var base_dmg := int(EquipmentCatalog.get_equippable(weapon_id).get("stats", {}).get("damage", 0))
				var mod      := ModifierCatalog.get_modifier(modifier_id)
				var mod_dmg  := roundi(float(base_dmg) * float(mod.get("damage_mult", 1.0)))
				totals["damage"] = int(totals["damage"]) - base_dmg + mod_dmg

	return totals

## Compute equipment stats then layer status-effect stats on top.
## Math order: Base Stats → Equipment Stats → Status Effect Stats.
## Accepts an optional status_manager (StatusManager node); if null the result
## is identical to compute().
static func compute_with_status(equipment_system, status_manager) -> Dictionary:
	var totals := compute(equipment_system)
	if status_manager == null or not status_manager.has_method("get_stat_totals"):
		return totals
	var status_stats: Dictionary = status_manager.get_stat_totals()
	for key in status_stats:
		if totals.has(key):
			totals[key] = totals[key] + status_stats[key]
	return totals

## Returns the utility light radius in tiles from the equipped utility item,
## or 0.0 if the utility slot is empty or has no light_radius_tiles entry.
static func get_utility_light_radius(equipment_system) -> float:
	var item_id: String = equipment_system.get_item("utility")
	if item_id == "":
		return 0.0
	var eq_def: Dictionary = EquipmentCatalog.get_equippable(item_id)
	return float(eq_def.get("light_radius_tiles", 0.0))
