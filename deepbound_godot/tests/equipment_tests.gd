extends SceneTree

## Headless test suite for the Sprint 6 equipment system.
##
## Tests:
##   1. EquipmentCatalog  — catalog queries (slot, stats, is_equippable)
##   2. EquipmentSystem   — slot mutations, signal, validation
##   3. StatCalculator    — stat aggregation and utility light radius
##   4. HudController     — equipment panel geometry and drag-drop integration
##
## Run from project root:
##   godot --headless -s tests/equipment_tests.gd

const EquipmentCatalog  = preload("res://scripts/catalogs/EquipmentCatalog.gd")
const EquipmentSystem   = preload("res://scripts/systems/EquipmentSystem.gd")
const StatCalculator    = preload("res://scripts/systems/StatCalculator.gd")
const InventorySystem   = preload("res://scripts/systems/InventorySystem.gd")
const HudController     = preload("res://scripts/controllers/HudController.gd")

var failures: Array[String] = []

# ── Scaffolding ───────────────────────────────────────────────────────────────

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_equipment_catalog()
	_test_equipment_system()
	_test_stat_calculator()
	await _test_hud_equipment_panel()
	if failures.is_empty():
		print("Deepbound Godot equipment tests passed.")
		quit(0)
	else:
		print("Deepbound Godot equipment tests failed: %d" % failures.size())
		for msg in failures:
			print("  FAIL: " + msg)
		quit(1)

# ── 1. EquipmentCatalog ───────────────────────────────────────────────────────

func _test_equipment_catalog() -> void:
	# get_equippable returns correct entry for known items
	var sword := EquipmentCatalog.get_equippable("wooden_sword")
	_assert(not sword.is_empty(), "get_equippable should return a non-empty dict for wooden_sword")
	_assert(String(sword.get("slot", "")) == "weapon", "wooden_sword should map to the weapon slot")
	_assert(int(sword.get("stats", {}).get("damage", 0)) == 3, "wooden_sword should grant 3 damage")

	var helm := EquipmentCatalog.get_equippable("crystal_helm")
	_assert(int(helm.get("stats", {}).get("defense", 0)) == 4, "crystal_helm should grant 4 defense")
	_assert(int(helm.get("stats", {}).get("health_max", 0)) == 5, "crystal_helm should grant 5 max HP")

	var boots := EquipmentCatalog.get_equippable("leather_boots")
	_assert(absf(float(boots.get("stats", {}).get("speed", 0.0)) - 0.10) < 0.0001,
		"leather_boots should grant 0.10 speed bonus")

	var amulet := EquipmentCatalog.get_equippable("resin_amulet")
	_assert(absf(float(amulet.get("stats", {}).get("drill_cool", 0.0)) - 0.10) < 0.0001,
		"resin_amulet should grant 0.10 drill_cool bonus")

	# Utility items carry light_radius_tiles
	var torch := EquipmentCatalog.get_equippable("torch")
	_assert(absf(float(torch.get("light_radius_tiles", 0.0)) - 10.0) < 0.0001,
		"torch should have light_radius_tiles = 10.0")
	var lantern := EquipmentCatalog.get_equippable("lantern")
	_assert(absf(float(lantern.get("light_radius_tiles", 0.0)) - 17.0) < 0.0001,
		"lantern should have light_radius_tiles = 17.0")

	# get_equippable returns empty dict for non-equipment items
	_assert(EquipmentCatalog.get_equippable("dirt_clod").is_empty(),
		"get_equippable should return empty dict for non-equippable items")
	_assert(EquipmentCatalog.get_equippable("").is_empty(),
		"get_equippable should return empty dict for empty string")

	# is_equippable
	_assert(EquipmentCatalog.is_equippable("iron_helm"), "iron_helm should be equippable")
	_assert(EquipmentCatalog.is_equippable("leather_boots"), "leather_boots should be equippable")
	_assert(not EquipmentCatalog.is_equippable("dirt_clod"), "dirt_clod should not be equippable")
	_assert(not EquipmentCatalog.is_equippable(""), "empty string should not be equippable")
	_assert(not EquipmentCatalog.is_equippable("hammer"), "hammer (tool) should not be equippable")

	# get_slot_for_item
	_assert(EquipmentCatalog.get_slot_for_item("cursed_sword") == "weapon",
		"cursed_sword slot should be weapon")
	_assert(EquipmentCatalog.get_slot_for_item("iron_chestplate") == "body",
		"iron_chestplate slot should be body")
	_assert(EquipmentCatalog.get_slot_for_item("copper_ring") == "accessory",
		"copper_ring slot should be accessory")
	_assert(EquipmentCatalog.get_slot_for_item("lantern") == "utility",
		"lantern slot should be utility")
	_assert(EquipmentCatalog.get_slot_for_item("stone_chunk") == "",
		"non-equippable item should return empty slot string")

# ── 2. EquipmentSystem ────────────────────────────────────────────────────────

func _test_equipment_system() -> void:
	# All 7 slots start empty
	var eq := EquipmentSystem.new()
	for slot_id in EquipmentSystem.SLOT_IDS:
		_assert(eq.get_item(slot_id) == "",
			"slot %s should start empty" % slot_id)
	_assert(eq.all_slots().size() == 7,
		"all_slots should return all 7 slot entries")

	# equip places item and returns "" (slot was empty)
	var displaced := eq.equip("wooden_sword")
	_assert(displaced == "", "equip into empty weapon slot should return empty string")
	_assert(eq.get_item("weapon") == "wooden_sword",
		"weapon slot should contain wooden_sword after equip")
	_assert(not eq.is_slot_empty("weapon"), "weapon slot should not be empty after equip")

	# equip again displaces the previous item
	displaced = eq.equip("crystal_sword")
	_assert(displaced == "wooden_sword",
		"equipping crystal_sword should displace wooden_sword")
	_assert(eq.get_item("weapon") == "crystal_sword",
		"weapon slot should now contain crystal_sword")

	# equip rejects non-equippable items (returns item_id unchanged)
	displaced = eq.equip("dirt_clod")
	_assert(displaced == "dirt_clod",
		"equipping non-equippable item should return the item unchanged")
	_assert(eq.get_item("weapon") == "crystal_sword",
		"weapon slot should not be changed after rejected equip")

	# equip rejects empty string
	displaced = eq.equip("")
	_assert(displaced == "",
		"equipping empty string should return empty string")

	# equipment_changed signal fires on successful equip.
	# Use an Array as a reference-type counter so the lambda can mutate it
	# and the outer scope sees the update (GDScript primitive captures are by value).
	var signal_count := [0]
	eq.equipment_changed.connect(func(): signal_count[0] += 1)
	eq.equip("iron_helm")
	_assert(signal_count[0] == 1, "equip should emit equipment_changed once")
	eq.equip("dirt_clod")  # rejected — should not fire
	_assert(signal_count[0] == 1, "rejected equip should not emit equipment_changed")

	# unequip returns item and clears slot
	var removed := eq.unequip("weapon")
	_assert(removed == "crystal_sword",
		"unequip(weapon) should return the crystal_sword that was there")
	_assert(eq.is_slot_empty("weapon"),
		"weapon slot should be empty after unequip")
	_assert(signal_count[0] == 2, "successful unequip should emit equipment_changed")

	# unequip empty slot returns "" without signal
	removed = eq.unequip("weapon")
	_assert(removed == "", "unequip on already-empty slot should return empty string")
	_assert(signal_count[0] == 2,
		"unequip on empty slot should not emit equipment_changed")

	# unequip_item finds item across all slots
	eq.equip("iron_greaves")   # goes to legs
	eq.equip("copper_ring")    # goes to accessory
	_assert(eq.find_item_slot("iron_greaves") == "legs",
		"find_item_slot should return 'legs' for iron_greaves")
	_assert(eq.find_item_slot("copper_ring") == "accessory",
		"find_item_slot should return 'accessory' for copper_ring")
	_assert(eq.find_item_slot("dirt_clod") == "",
		"find_item_slot should return '' for unequipped item")
	var found := eq.unequip_item("iron_greaves")
	_assert(found, "unequip_item should return true when item was found")
	_assert(eq.is_slot_empty("legs"),
		"legs slot should be empty after unequip_item(iron_greaves)")
	var not_found := eq.unequip_item("leather_boots")
	_assert(not not_found,
		"unequip_item should return false when item is not equipped")

	# swap: valid placement displaces existing item
	eq.equip("wooden_sword")  # put something in weapon slot
	var swapped_out := eq.swap("weapon", "cursed_sword")
	_assert(swapped_out == "wooden_sword",
		"swap should return the previously equipped wooden_sword")
	_assert(eq.get_item("weapon") == "cursed_sword",
		"weapon slot should now contain cursed_sword after swap")

	# swap: wrong-slot item is rejected (boots into weapon slot)
	var rejected := eq.swap("weapon", "leather_boots")
	_assert(rejected == "leather_boots",
		"swap should return incoming item unchanged when it does not belong in the slot")
	_assert(eq.get_item("weapon") == "cursed_sword",
		"weapon slot should not change after a rejected swap")

	# swap with "" just unequips
	var emptied := eq.swap("weapon", "")
	_assert(emptied == "cursed_sword",
		"swap with empty string should unequip and return the current item")
	_assert(eq.is_slot_empty("weapon"),
		"weapon slot should be empty after swap with empty string")

# ── 3. StatCalculator ────────────────────────────────────────────────────────

func _test_stat_calculator() -> void:
	# Empty system → all zeros
	var eq := EquipmentSystem.new()
	var stats := StatCalculator.compute(eq)
	_assert(stats.has("damage"),     "compute result should have 'damage' key")
	_assert(stats.has("defense"),    "compute result should have 'defense' key")
	_assert(stats.has("health_max"), "compute result should have 'health_max' key")
	_assert(stats.has("speed"),      "compute result should have 'speed' key")
	_assert(stats.has("drill_cool"), "compute result should have 'drill_cool' key")
	_assert(int(stats.get("damage"))     == 0,   "empty system damage should be 0")
	_assert(int(stats.get("defense"))    == 0,   "empty system defense should be 0")
	_assert(int(stats.get("health_max"))  == 0,  "empty system health_max should be 0")
	_assert(absf(float(stats.get("speed")))      < 0.0001, "empty system speed should be 0.0")
	_assert(absf(float(stats.get("drill_cool"))) < 0.0001, "empty system drill_cool should be 0.0")

	# Single weapon: wooden_sword gives damage 3
	eq.equip("wooden_sword")
	stats = StatCalculator.compute(eq)
	_assert(int(stats.get("damage")) == 3,
		"wooden_sword should add 3 to damage stat")

	# Swap to crystal_sword: damage 6
	eq.equip("crystal_sword")
	stats = StatCalculator.compute(eq)
	_assert(int(stats.get("damage")) == 6,
		"crystal_sword should give 6 damage (replaces wooden_sword)")

	# crystal_helm: +4 defense, +5 health_max
	eq.equip("crystal_helm")
	stats = StatCalculator.compute(eq)
	_assert(int(stats.get("defense"))   == 4, "crystal_helm should add 4 defense")
	_assert(int(stats.get("health_max")) == 5, "crystal_helm should add 5 health_max")

	# leather_boots: +1 defense, +10% speed
	eq.equip("leather_boots")
	stats = StatCalculator.compute(eq)
	_assert(int(stats.get("defense")) == 5,
		"crystal_helm (4) + leather_boots (1) should give 5 total defense")
	_assert(absf(float(stats.get("speed")) - 0.10) < 0.0001,
		"leather_boots should add 0.10 speed bonus")

	# resin_amulet: +1 defense, -10% drill heat
	eq.equip("resin_amulet")
	stats = StatCalculator.compute(eq)
	_assert(int(stats.get("defense")) == 6,
		"adding resin_amulet should bring total defense to 6")
	_assert(absf(float(stats.get("drill_cool")) - 0.10) < 0.0001,
		"resin_amulet should add 0.10 drill_cool")

	# copper_ring: +5 health_max (stacks with crystal_helm)
	eq.equip("copper_ring")
	stats = StatCalculator.compute(eq)
	_assert(int(stats.get("health_max")) == 10,
		"crystal_helm (5) + copper_ring (5) should total 10 health_max")

	# Full armour loadout on a fresh system to avoid slot-displacement confusion
	var eq2 := EquipmentSystem.new()
	eq2.equip("crystal_helm")    # head:      4 defense
	eq2.equip("iron_chestplate") # body:      4 defense
	eq2.equip("iron_greaves")    # legs:      2 defense
	eq2.equip("leather_boots")   # feet:      1 defense
	eq2.equip("resin_amulet")    # accessory: 1 defense
	# Total: 4 + 4 + 2 + 1 + 1 = 12
	stats = StatCalculator.compute(eq2)
	_assert(int(stats.get("defense")) == 12,
		"full armour (crystal_helm+iron_chestplate+iron_greaves+leather_boots+resin_amulet) should total 12 defense")

	# get_utility_light_radius: no utility → 0.0
	_assert(absf(StatCalculator.get_utility_light_radius(eq)) < 0.0001,
		"utility radius should be 0.0 when utility slot is empty")

	# equip torch → 10.0
	eq.equip("torch")
	_assert(absf(StatCalculator.get_utility_light_radius(eq) - 10.0) < 0.0001,
		"torch should give 10.0 utility light radius")

	# swap to lantern → 17.0
	eq.equip("lantern")
	_assert(absf(StatCalculator.get_utility_light_radius(eq) - 17.0) < 0.0001,
		"lantern should give 17.0 utility light radius")

	# unequip utility → back to 0.0
	eq.unequip("utility")
	_assert(absf(StatCalculator.get_utility_light_radius(eq)) < 0.0001,
		"unequipping utility should return radius to 0.0")

# ── 4. HudController equipment panel ─────────────────────────────────────────

func _test_hud_equipment_panel() -> void:
	var eq := EquipmentSystem.new()
	var player_inventory := InventorySystem.new(24, 99)
	var hud := HudController.new()
	get_root().add_child(hud)
	await process_frame

	# set_equipment_system wires correctly
	hud.set_equipment_system(eq)
	_assert(hud.equipment_system == eq,
		"set_equipment_system should store the EquipmentSystem reference on the HUD")

	# _equip_panel_rect is empty when inventory is closed
	var closed_rect := hud._equip_panel_rect()
	_assert(closed_rect.size == Vector2.ZERO,
		"_equip_panel_rect should return empty Rect2 when inventory is closed")

	# _equip_panel_rect is non-empty when inventory is open
	hud.open_inventory(player_inventory)
	var open_rect := hud._equip_panel_rect()
	_assert(open_rect.size != Vector2.ZERO,
		"_equip_panel_rect should return non-zero Rect2 when inventory is open")
	_assert(open_rect.size.x > 0 and open_rect.size.y > 0,
		"_equip_panel_rect should have positive width and height")

	# _equip_slot_at returns empty dict for point outside the panel
	var outside_hit := hud._equip_slot_at(Vector2(-9999.0, -9999.0))
	_assert(outside_hit.is_empty(),
		"_equip_slot_at should return empty dict for a point outside the panel")

	# _equip_slot_at returns correct slot for point inside a slot
	var weapon_slot_rect := hud._equip_slot_rect_by_idx(0)  # index 0 = weapon
	var inside_hit := hud._equip_slot_at(weapon_slot_rect.get_center())
	_assert(not inside_hit.is_empty(),
		"_equip_slot_at should return non-empty hit for a point inside the panel")
	_assert(String(inside_hit.get("panel", "")) == "equip",
		"_equip_slot_at hit should have panel == 'equip'")
	_assert(String(inside_hit.get("slot_id", "")) == "weapon",
		"_equip_slot_at centre of first slot should identify 'weapon'")

	# Drag from equipment slot: mouse press over a filled slot lifts the item
	eq.equip("wooden_sword")
	var weapon_center := weapon_slot_rect.get_center()
	var pressed := hud._handle_mouse_press(weapon_center)
	_assert(pressed, "pressing over a filled equipment slot should start a drag")
	_assert(String(hud.cursor_stack.get("item", "")) == "wooden_sword",
		"cursor stack should hold wooden_sword after drag from weapon slot")
	# While the drag is active the drag_source should identify the equip panel + slot
	_assert(String(hud.drag_source.get("panel", "")) == "equip",
		"drag_source.panel should be 'equip' while dragging from an equipment slot")
	_assert(String(hud.drag_source.get("slot_id", "")) == "weapon",
		"drag_source.slot_id should be 'weapon' while dragging from the weapon slot")

	# Release over an inventory slot → item should go into inventory cursor path
	# (just release outside the equip panel so the world_drop path is tested)
	hud._handle_mouse_release(weapon_center)  # release at same point puts it back
	# The weapon was taken and then returned via the release — so slot should now be filled again
	_assert(eq.get_item("weapon") == "wooden_sword" or String(hud.cursor_stack.get("item","")) == "wooden_sword",
		"after press+release on same equip slot, item should either remain in slot or stay on cursor")

	# Drop from inventory to equipment slot: place leather_boots into feet slot
	player_inventory.set_slot(0, "leather_boots", 1)
	# Re-open to refresh state
	hud.close_inventory()
	hud.open_inventory(player_inventory)
	hud.set_equipment_system(eq)

	var boots_slot_idx := EquipmentSystem.SLOT_IDS.find("feet")
	var boots_slot_rect := hud._equip_slot_rect_by_idx(boots_slot_idx)

	# Pick boots from player inventory slot 0
	var inv_slot_rect := hud._slot_rect(hud._player_panel_rect(), 0, HudController.PLAYER_COLS)
	_assert(hud._handle_mouse_press(inv_slot_rect.get_center()),
		"pressing player inventory slot with leather_boots should start a drag")
	_assert(String(hud.cursor_stack.get("item","")) == "leather_boots",
		"cursor should hold leather_boots after drag from inventory")

	# Release onto the feet equipment slot
	_assert(hud._handle_mouse_release(boots_slot_rect.get_center()),
		"releasing leather_boots over the feet slot should commit the drag")
	_assert(eq.get_item("feet") == "leather_boots",
		"feet slot should contain leather_boots after drag-drop from inventory")
	_assert(String(hud.cursor_stack.get("item","")) == "",
		"cursor should be empty after committed equipment drop")

	# Wrong-slot rejection: try to drop boots into the weapon slot
	player_inventory.set_slot(1, "leather_boots", 1)
	var inv_slot1_rect := hud._slot_rect(hud._player_panel_rect(), 1, HudController.PLAYER_COLS)
	hud._handle_mouse_press(inv_slot1_rect.get_center())
	hud._handle_mouse_release(weapon_slot_rect.get_center())  # boots → weapon slot: invalid
	_assert(eq.get_item("weapon") == "wooden_sword",
		"weapon slot should not accept leather_boots (wrong slot rejection)")
	# Cursor or inventory should still hold the boots
	var boots_returned := (String(hud.cursor_stack.get("item","")) == "leather_boots"
		or player_inventory.count_item("leather_boots") > 0)
	_assert(boots_returned,
		"rejected wrong-slot drop should return leather_boots to inventory or cursor")

	hud.free()
