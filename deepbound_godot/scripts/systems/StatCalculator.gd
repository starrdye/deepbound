extends RefCounted
class_name StatCalculator

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

	return totals

## Returns the utility light radius in tiles from the equipped utility item,
## or 0.0 if the utility slot is empty or has no light_radius_tiles entry.
static func get_utility_light_radius(equipment_system) -> float:
	var item_id: String = equipment_system.get_item("utility")
	if item_id == "":
		return 0.0
	var eq_def: Dictionary = EquipmentCatalog.get_equippable(item_id)
	return float(eq_def.get("light_radius_tiles", 0.0))
