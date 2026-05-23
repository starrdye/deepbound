extends SceneTree

## Headless test suite for the Item Modifier / Prefix system.
##
## Tests:
##   1. ModifierCatalog — data integrity, roll_for_item, modifier_color
##   2. ModifierSystem  — get_modified_damage, get_display_name, build_tooltip_stat_lines
##   3. InventorySystem — modifier preservation in place_stack, add_stack, restore_slot
##   4. EquipmentSystem — equip_stack, get_slot_modifier, get_slot_stack,
##                        unequip_as_stack, swap_stack
##
## Run from project root:
##   godot --headless -s tests/modifier_tests.gd

const ModifierCatalog  = preload("res://scripts/catalogs/ModifierCatalog.gd")
const ModifierSystem   = preload("res://scripts/systems/ModifierSystem.gd")
const InventorySystem  = preload("res://scripts/systems/InventorySystem.gd")
const EquipmentSystem  = preload("res://scripts/systems/EquipmentSystem.gd")

var failures: Array[String] = []

# ── Scaffolding ─────────────��────────────────────────���────────────────────────

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_modifier_catalog()
	_test_modifier_system()
	_test_inventory_modifier()
	_test_equipment_modifier()
	if failures.is_empty():
		print("Deepbound Godot modifier tests passed.")
		quit(0)
	else:
		for f in failures:
			push_error("FAIL: " + f)
		quit(1)

# ── 1. ModifierCatalog ─────────────────���──────────────────────��───────────────

func _test_modifier_catalog() -> void:
	print("  [mod] ModifierCatalog...")

	# All required keys present in every modifier entry.
	for mod_id in ModifierCatalog.MODIFIERS:
		var m : Dictionary = ModifierCatalog.MODIFIERS[mod_id]
		_assert(m.has("name"),           "modifier '%s' missing 'name'" % mod_id)
		_assert(m.has("damage_mult"),    "modifier '%s' missing 'damage_mult'" % mod_id)
		_assert(m.has("speed_mult"),     "modifier '%s' missing 'speed_mult'" % mod_id)
		_assert(m.has("knockback_mult"), "modifier '%s' missing 'knockback_mult'" % mod_id)
		_assert(m.has("crit_bonus"),     "modifier '%s' missing 'crit_bonus'" % mod_id)
		_assert(m.has("value_mult"),     "modifier '%s' missing 'value_mult'" % mod_id)
		_assert(m.has("tier"),           "modifier '%s' missing 'tier'" % mod_id)

	# is_valid
	_assert(ModifierCatalog.is_valid("legendary"),    "legendary should be valid")
	_assert(ModifierCatalog.is_valid("broken"),       "broken should be valid")
	_assert(not ModifierCatalog.is_valid(""),         "empty string should not be valid")
	_assert(not ModifierCatalog.is_valid("nonexistent_xyz"), "unknown id should not be valid")

	# get_modifier returns correct data
	var leg := ModifierCatalog.get_modifier("legendary")
	_assert(float(leg.get("damage_mult", 0.0)) > 1.0, "legendary damage_mult should exceed 1.0")
	_assert(String(leg.get("tier", "")) == "legendary", "legendary tier should be 'legendary'")
	var brk := ModifierCatalog.get_modifier("broken")
	_assert(float(brk.get("damage_mult", 1.0)) < 1.0, "broken damage_mult should be < 1.0")

	# modifier_color returns distinct colours per tier
	var col_leg := ModifierCatalog.modifier_color("legendary")
	var col_brk := ModifierCatalog.modifier_color("broken")
	var col_com := ModifierCatalog.modifier_color("")   # unknown → common grey
	_assert(col_leg != col_brk,  "legendary and broken should have different colors")
	_assert(col_leg != col_com,  "legendary and unknown should have different colors")

	# roll_for_item pool logic
	# weapon pool is non-empty
	var got_weapon_mod := false
	for _i in range(200):
		var result := ModifierCatalog.roll_for_item("weapon")
		if result != "":
			_assert(ModifierCatalog.is_valid(result), "rolled weapon mod '%s' should be valid" % result)
			_assert(ModifierCatalog.MELEE_POOL.has(result), "rolled weapon mod should be in MELEE_POOL")
			got_weapon_mod = true
			break
	_assert(got_weapon_mod, "roll_for_item('weapon') should return a modifier in some of 200 rolls")

	# accessory pool
	var got_acc_mod := false
	for _i in range(200):
		var result := ModifierCatalog.roll_for_item("accessory")
		if result != "":
			_assert(ModifierCatalog.ACCESSORY_POOL.has(result), "rolled accessory mod should be in ACCESSORY_POOL")
			got_acc_mod = true
			break
	_assert(got_acc_mod, "roll_for_item('accessory') should return a modifier in some of 200 rolls")

	# unknown category → always ""
	for _i in range(20):
		_assert(ModifierCatalog.roll_for_item("material") == "", "non-equipment category should never return modifier")
		_assert(ModifierCatalog.roll_for_item("") == "",         "empty category should never return modifier")

# ── 2. ModifierSystem ─────────────��───────────────────────────────────────────

func _test_modifier_system() -> void:
	print("  [mod] ModifierSystem...")

	# get_modified_damage — crystal_sword base = 6 (high enough to show modifier diff)
	var base_dmg := ModifierSystem.get_modified_damage("crystal_sword", "")
	_assert(base_dmg == 6, "crystal_sword base damage should be 6, got %d" % base_dmg)

	var sharp_dmg := ModifierSystem.get_modified_damage("crystal_sword", "sharp")
	_assert(sharp_dmg > base_dmg, "sharp crystal_sword should have more damage than base (%d vs %d)" % [sharp_dmg, base_dmg])

	var broken_dmg := ModifierSystem.get_modified_damage("crystal_sword", "broken")
	_assert(broken_dmg < base_dmg, "broken crystal_sword should have less damage than base (%d vs %d)" % [broken_dmg, base_dmg])

	# Non-weapon item (no damage stat) → 0 regardless of modifier
	_assert(ModifierSystem.get_modified_damage("copper_ring", "legendary") == 0,
		"copper_ring has no damage stat — should return 0 with modifier")

	# get_display_name
	var plain_name := ModifierSystem.get_display_name("wooden_sword", "")
	_assert(plain_name == "Wooden Sword", "plain name should be 'Wooden Sword', got '%s'" % plain_name)

	var sharp_name := ModifierSystem.get_display_name("wooden_sword", "sharp")
	_assert(sharp_name.begins_with("Sharp"), "modified name should start with 'Sharp', got '%s'" % sharp_name)
	_assert(sharp_name.ends_with("Sword"),   "modified name should end with 'Sword', got '%s'" % sharp_name)

	# get_display_name with invalid modifier → base name only
	var invalid_name := ModifierSystem.get_display_name("wooden_sword", "nonexistent_xyz")
	_assert(invalid_name == "Wooden Sword", "invalid modifier should yield base name")

	# build_tooltip_stat_lines — sharp on crystal_sword (6 dmg) → 6→7 diff > 0
	var sharp_lines := ModifierSystem.build_tooltip_stat_lines("sharp", "crystal_sword", 11)
	_assert(sharp_lines.size() > 0, "sharp crystal_sword should produce stat lines")
	var found_damage_line := false
	for line in sharp_lines:
		if String(line.get("text", "")).begins_with("Damage"):
			found_damage_line = true
			_assert(line.get("color") == Color8(100, 220, 100), "positive damage diff should be green")
	_assert(found_damage_line, "sharp should produce a Damage stat line for crystal_sword")

	# broken — damage_mult < 1.0 → red
	var brk_lines := ModifierSystem.build_tooltip_stat_lines("broken", "crystal_sword", 11)
	var found_red := false
	for line in brk_lines:
		if String(line.get("text", "")).begins_with("Damage"):
			found_red = (line.get("color") == Color8(220, 80, 80))
	_assert(found_red, "broken damage diff line should be red")

	# No modifier → empty lines
	var no_lines := ModifierSystem.build_tooltip_stat_lines("", "wooden_sword", 11)
	_assert(no_lines.is_empty(), "empty modifier_id should yield no stat lines")

	# Warding (defense_bonus) on accessory — should include a Defense line
	var ward_lines := ModifierSystem.build_tooltip_stat_lines("warding", "copper_ring", 11)
	var found_def := false
	for line in ward_lines:
		if String(line.get("text", "")).begins_with("Defense"):
			found_def = true
	_assert(found_def, "warding should include a Defense stat line")

# ── 3. InventorySystem modifier handling ─────────────────────────────────────

func _test_inventory_modifier() -> void:
	print("  [mod] InventorySystem modifier handling...")

	var inv := InventorySystem.new(24, 99, 6)

	# add_stack with modifier — places in first empty hotbar slot
	var sharp_sword := {"item": "wooden_sword", "count": 1, "stack_cap": 1, "modifier": "sharp"}
	var remaining := inv.add_stack(sharp_sword)
	_assert(remaining == 0, "add_stack should place the stack (remaining = 0)")
	var hb0 := inv.get_hotbar_slot(0)
	_assert(String(hb0.get("item", "")) == "wooden_sword", "hotbar[0] should have wooden_sword")
	_assert(String(hb0.get("modifier", "")) == "sharp",    "hotbar[0] modifier should be 'sharp'")

	# add_stack without modifier — delegates to add_item
	var plain_rem := inv.add_stack({"item": "copper_nugget", "count": 5})
	_assert(plain_rem == 0, "plain add_stack should place copper_nugget")

	# _place_stack_in_array via place_hotbar_stack:
	# Swap sharp sword to slot 1 — modifier should be preserved in displaced result.
	var leg_sword := {"item": "wooden_sword", "count": 1, "stack_cap": 1, "modifier": "legendary"}
	var displaced := inv.place_hotbar_stack(0, leg_sword)
	# hb[0] should now hold legendary
	var hb0_after := inv.get_hotbar_slot(0)
	_assert(String(hb0_after.get("modifier", "")) == "legendary", "slot should hold legendary after place")
	# displaced should be the old sharp sword stack
	_assert(String(displaced.get("modifier", "")) == "sharp", "displaced stack should carry sharp modifier")

	# Modifier stacks with SAME modifier DO merge if same item
	inv.clear_hotbar_slot(0)
	inv.clear_hotbar_slot(1)
	# Clear all slots first by fresh inventory
	var inv2 := InventorySystem.new(4, 99, 2)
	var stack_a := {"item": "copper_nugget", "count": 3, "stack_cap": 99}
	var stack_b := {"item": "copper_nugget", "count": 2, "stack_cap": 99}
	inv2.place_hotbar_stack(0, stack_a)
	var leftover := inv2.place_hotbar_stack(0, stack_b)
	_assert(leftover.is_empty() or int(leftover.get("count", -1)) == 0, "same item without modifier should merge")
	_assert(int(inv2.get_hotbar_slot(0).get("count", 0)) == 5, "merged count should be 5")

	# restore_slot preserves modifier
	var inv3 := InventorySystem.new(4, 99, 2)
	inv3.restore_slot(0, {"item": "crystal_sword", "count": 1, "stack_cap": 1, "modifier": "godly"})
	var restored := inv3.get_slot(0)
	_assert(String(restored.get("item", "")) == "crystal_sword", "restored slot should hold crystal_sword")
	_assert(String(restored.get("modifier", "")) == "godly",     "restored slot should carry godly modifier")

	# restore_hotbar_slot
	inv3.restore_hotbar_slot(0, {"item": "wooden_sword", "count": 1, "stack_cap": 1, "modifier": "broken"})
	var rhb := inv3.get_hotbar_slot(0)
	_assert(String(rhb.get("modifier", "")) == "broken", "restored hotbar slot should carry broken modifier")

	# Empty restore clears slot
	inv3.restore_slot(0, {})
	_assert(inv3.is_empty_stack(inv3.get_slot(0)), "restoring empty dict should clear the slot")

# ── 4. EquipmentSystem modifier handling ─────────────────────────────────────

func _test_equipment_modifier() -> void:
	print("  [mod] EquipmentSystem modifier handling...")

	var eq := EquipmentSystem.new()

	# get_slot_modifier — initially all empty
	for slot_id in EquipmentSystem.SLOT_IDS:
		_assert(eq.get_slot_modifier(slot_id) == "", "slot '%s' modifier should be empty at start" % slot_id)

	# equip_stack — weapon slot gets item + modifier
	var sharp_stack := {"item": "wooden_sword", "count": 1, "stack_cap": 1, "modifier": "sharp"}
	var displaced := eq.equip_stack(sharp_stack)
	_assert(eq.get_item("weapon") == "wooden_sword",     "weapon slot should be wooden_sword")
	_assert(eq.get_slot_modifier("weapon") == "sharp",   "weapon modifier should be sharp")
	_assert(String(displaced.get("item", "")) == "",     "displaced from empty slot should be empty item")

	# equip_stack — replace with legendary; displaced should carry sharp
	var leg_stack := {"item": "wooden_sword", "count": 1, "stack_cap": 1, "modifier": "legendary"}
	var displaced2 := eq.equip_stack(leg_stack)
	_assert(eq.get_slot_modifier("weapon") == "legendary", "weapon modifier should update to legendary")
	_assert(String(displaced2.get("modifier", "")) == "sharp", "displaced should carry previous sharp modifier")

	# get_slot_stack — returns full dict
	var ws := eq.get_slot_stack("weapon")
	_assert(String(ws.get("item", "")) == "wooden_sword", "get_slot_stack item should be wooden_sword")
	_assert(String(ws.get("modifier", "")) == "legendary","get_slot_stack modifier should be legendary")
	_assert(int(ws.get("count", 0)) == 1,                "get_slot_stack count should be 1")

	# unequip_as_stack — removes item and returns full stack
	var taken := eq.unequip_as_stack("weapon")
	_assert(String(taken.get("item", "")) == "wooden_sword", "unequip_as_stack should return wooden_sword")
	_assert(String(taken.get("modifier", "")) == "legendary","unequip_as_stack should carry legendary modifier")
	_assert(eq.get_item("weapon") == "",              "weapon slot should be empty after unequip")
	_assert(eq.get_slot_modifier("weapon") == "",     "weapon modifier should be cleared after unequip")

	# swap_stack — equip via swap into empty slot
	var brk_stack := {"item": "wooden_sword", "count": 1, "stack_cap": 1, "modifier": "broken"}
	var sw1 := eq.swap_stack("weapon", brk_stack)
	_assert(eq.get_slot_modifier("weapon") == "broken", "swap_stack should set broken modifier")
	_assert(String(sw1.get("item", "")) == "",          "swap into empty slot returns empty displaced")

	# swap_stack — replace broken with sharp; displaced should be broken
	var sw2 := eq.swap_stack("weapon", sharp_stack)
	_assert(eq.get_slot_modifier("weapon") == "sharp",  "swap_stack should update to sharp")
	_assert(String(sw2.get("modifier", "")) == "broken","displaced from swap should have broken modifier")

	# swap_stack rejection — wrong slot type returns incoming unchanged
	var chest_stack := {"item": "iron_chestplate", "count": 1, "stack_cap": 1, "modifier": "warding"}
	var rejected := eq.swap_stack("weapon", chest_stack)   # chestplate doesn't go in weapon slot
	_assert(String(rejected.get("item", "")) == "iron_chestplate", "rejected swap should return incoming item")
	_assert(String(rejected.get("modifier", "")) == "warding",     "rejected swap should return incoming modifier")
	_assert(eq.get_item("weapon") == "wooden_sword",               "weapon slot unchanged after rejected swap")

	# plain equip() clears any existing modifier
	eq.equip("wooden_sword")   # plain string equip
	_assert(eq.get_slot_modifier("weapon") == "", "plain equip() should clear modifier")

	# accessory slot — swap warding ring
	var ward_ring := {"item": "copper_ring", "count": 1, "stack_cap": 1, "modifier": "warding"}
	eq.swap_stack("accessory", ward_ring)
	_assert(eq.get_slot_modifier("accessory") == "warding", "accessory modifier should be warding")
	# unequip_as_stack on accessory
	var acc_taken := eq.unequip_as_stack("accessory")
	_assert(String(acc_taken.get("modifier", "")) == "warding", "accessory unequip should carry warding")
