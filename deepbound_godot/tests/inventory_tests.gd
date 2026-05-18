extends SceneTree

const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")
const DroppedItemController = preload("res://scripts/controllers/DroppedItemController.gd")
const MainController = preload("res://scripts/Main.gd")
const HudController = preload("res://scripts/controllers/HudController.gd")

var failures: Array[String] = []
var dropped_stack := {}
var selected_hotbar_slot := -1

class TestPlayer:
	extends Node2D
	var inventory := InventorySystem.new()
	var facing := 1

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_stack_merge_and_remainder()
	_test_stack_swap()
	_test_hotbar_is_extra_storage()
	_test_pickup_intake_fills_hotbar_first()
	await _test_main_inventory_toggle()
	await _test_main_hotbar_selection_helpers()
	await _test_hud_player_inventory_only_page()
	await _test_hud_hotbar_click_selects_slot()
	await _test_hud_hotbar_drag_waits_for_release()
	await _test_hud_drag_swap_returns_target_to_source()
	await _test_hud_drag_merge_overflow_returns_to_source()
	await _test_hud_drag_merge_and_world_drop()
	_test_manual_world_drop_at_player()
	_test_manual_drop_requires_click()
	_test_world_drop_click_collects_on_release()
	_test_world_drop_drag_moves_without_collecting()
	_test_special_drop_auto_pickup_into_inventory()
	if failures.is_empty():
		print("Deepbound Godot inventory tests passed.")
		quit(0)
	else:
		print("Deepbound Godot inventory tests failed: %d" % failures.size())
		quit(1)

func _test_stack_merge_and_remainder() -> void:
	var inventory := InventorySystem.new(4, 99)
	inventory.set_slot(0, "stone_chunk", 75)
	var cursor := {"item": "stone_chunk", "count": 40, "stack_cap": 99}
	var remaining := inventory.place_stack(0, cursor)
	_assert(int(inventory.get_slot(0).count) == 99, "matching stacks should merge up to stack cap")
	_assert(String(remaining.item) == "stone_chunk" and int(remaining.count) == 16, "merge should leave the cursor with overflow")

func _test_stack_swap() -> void:
	var inventory := InventorySystem.new(4, 99)
	inventory.set_slot(0, "stone_chunk", 12)
	var cursor := {"item": "copper_nugget", "count": 5, "stack_cap": 99}
	var swapped := inventory.place_stack(0, cursor)
	_assert(String(inventory.get_slot(0).item) == "copper_nugget" and int(inventory.get_slot(0).count) == 5, "different item drop should place cursor stack in slot")
	_assert(String(swapped.item) == "stone_chunk" and int(swapped.count) == 12, "different item drop should return the old slot as cursor stack")

func _test_hotbar_is_extra_storage() -> void:
	var inventory := InventorySystem.new(24, 99)
	inventory.set_slot(18, "copper_nugget", 4)
	inventory.set_hotbar_slot(0, "dirt_clod", 3)
	inventory.set_hotbar_slot(5, "stone_chunk", 2)
	var hotbar := inventory.hotbar_slots(6)
	_assert(inventory.slots.size() == 24, "player inventory should keep its full 24 slots")
	_assert(hotbar.size() == 6, "hotbar should expose six extra slots")
	_assert(String(hotbar[0].item) == "dirt_clod", "hotbar slot 1 should be independent extra storage")
	_assert(String(hotbar[5].item) == "stone_chunk", "hotbar slot 6 should be independent extra storage")
	_assert(String(inventory.get_slot(18).item) == "copper_nugget", "inventory slot 18 should not be consumed by the hotbar")
	_assert(inventory.count_item("dirt_clod") == 3, "item counts should include hotbar stacks")

func _test_pickup_intake_fills_hotbar_first() -> void:
	var inventory := InventorySystem.new(2, 99, 2)
	inventory.set_hotbar_slot(0, "stone_chunk", 98)
	inventory.set_slot(0, "stone_chunk", 90)
	var remaining := inventory.add_item("stone_chunk", 7)
	_assert(remaining == 0, "hotbar-first pickup intake should accept the full stack when space exists")
	_assert(int(inventory.get_hotbar_slot(0).count) == 99, "pickup intake should fill existing hotbar stacks first")
	_assert(String(inventory.get_hotbar_slot(1).item) == "stone_chunk" and int(inventory.get_hotbar_slot(1).count) == 6, "pickup intake should fill empty hotbar slots left to right before inventory")
	_assert(int(inventory.get_slot(0).count) == 90, "pickup intake should not top off inventory stacks until the hotbar is full")

	var full_hotbar := InventorySystem.new(2, 99, 2)
	full_hotbar.set_hotbar_slot(0, "stone_chunk", 99)
	full_hotbar.set_hotbar_slot(1, "dirt_clod", 99)
	full_hotbar.set_slot(0, "stone_chunk", 90)
	full_hotbar.add_item("stone_chunk", 15)
	_assert(int(full_hotbar.get_slot(0).count) == 99, "pickup intake should top off inventory stacks after hotbar is full")
	_assert(String(full_hotbar.get_slot(1).item) == "stone_chunk" and int(full_hotbar.get_slot(1).count) == 6, "pickup intake should use empty inventory slots after matching inventory stacks")

func _test_main_inventory_toggle() -> void:
	var main := MainController.new()
	var player := TestPlayer.new()
	var hud := HudController.new()
	get_root().add_child(hud)
	await process_frame
	main.player = player
	main.hud = hud
	main._toggle_player_inventory()
	_assert(bool(hud.inventory_open), "Main should open the player inventory when the I action is handled")
	_assert(not bool(hud.container_open), "Main I toggle should not open a container by itself")
	main._toggle_player_inventory()
	_assert(not bool(hud.inventory_open), "Main should close the player inventory when I is toggled again")
	hud.free()
	player.free()
	main.free()

func _test_main_hotbar_selection_helpers() -> void:
	var main := MainController.new()
	var player := TestPlayer.new()
	var hud := HudController.new()
	get_root().add_child(hud)
	await process_frame
	main.player = player
	main.hud = hud
	player.inventory.set_hotbar_slot(2, "stone_chunk", 2)
	main._select_hotbar_index(2)
	_assert(main.selected_hotbar_index == 2, "number-key selection should choose a hotbar index")
	_assert(String(main._selected_hotbar_stack().item) == "stone_chunk", "selected hotbar item should read from extra hotbar storage")
	_assert(main._format_stack_label(main._selected_hotbar_stack()) == "stone_chunk x2", "active item label should include stack count")
	main._cycle_hotbar(1)
	_assert(main.selected_hotbar_index == 3, "mouse wheel down should advance the hotbar selection")
	main._cycle_hotbar(-4)
	_assert(main.selected_hotbar_index == 5, "mouse wheel up should wrap around the hotbar selection")
	hud.free()
	player.free()
	main.free()

func _test_hud_player_inventory_only_page() -> void:
	var player_inventory := InventorySystem.new(24, 99)
	player_inventory.set_slot(0, "dirt_clod", 3)
	var hud := HudController.new()
	get_root().add_child(hud)
	await process_frame
	hud.open_inventory(player_inventory)
	_assert(bool(hud.inventory_open), "I inventory page should be able to open the player inventory by itself")
	_assert(not bool(hud.container_open), "player inventory page should not imply a container panel")
	var player_slot := hud._slot_rect(hud._player_panel_rect(), 0, HudController.PLAYER_COLS)
	hud._handle_mouse_press(player_slot.get_center())
	_assert(String(hud.cursor_stack.item) == "dirt_clod", "player-only inventory page should support picking up stacks")
	hud.close_inventory()
	_assert(not bool(hud.inventory_open), "player inventory page should close cleanly")
	_assert(player_inventory.count_item("dirt_clod") == 3, "closing player inventory should return a held cursor stack to inventory")
	hud.free()

func _test_hud_hotbar_click_selects_slot() -> void:
	selected_hotbar_slot = -1
	var hud := HudController.new()
	get_root().add_child(hud)
	await process_frame
	hud.hotbar_slot_selected.connect(_on_hotbar_slot_selected)
	hud.set_hud_state({
		"health_current": 10,
		"health_max": 10,
		"drill_heat": 0.0,
		"depth_label": "Band 1",
		"target_name": "Air",
		"light": 1.0,
		"danger": 0.0,
		"hotbar_slots": [],
		"selected_hotbar_index": 0,
		"active_item": "Empty",
	})
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = hud._hotbar_slot_rect(4).get_center()
	hud._gui_input(click)
	_assert(selected_hotbar_slot == 4, "clicking a visible hotbar slot should request selection")
	hud.free()

func _on_hotbar_slot_selected(index: int) -> void:
	selected_hotbar_slot = index

func _test_hud_hotbar_drag_waits_for_release() -> void:
	var player_inventory := InventorySystem.new(24, 99)
	player_inventory.set_hotbar_slot(0, "stone_chunk", 5)
	var hud := HudController.new()
	get_root().add_child(hud)
	await process_frame
	hud.open_inventory(player_inventory)
	var hotbar_slot := hud._hotbar_slot_rect(0)
	var inventory_slot := hud._slot_rect(hud._player_panel_rect(), 4, HudController.PLAYER_COLS)
	_assert(hud._handle_mouse_press(hotbar_slot.get_center()), "pressing a filled hotbar slot should start a drag")
	_assert(String(hud.cursor_stack.item) == "stone_chunk" and int(hud.cursor_stack.count) == 5, "drag cursor should preview the hotbar stack")
	_assert(String(player_inventory.get_slot(4).item) == "", "target inventory slot should stay empty before mouse release")
	_assert(String(player_inventory.get_hotbar_slot(0).item) == "stone_chunk", "source hotbar data should not mutate before mouse release")
	_assert(String(hud._display_stack_for_slot("hotbar", 0, player_inventory.get_hotbar_slot(0)).item) == "", "drag source should be visually hidden while held")
	_assert(hud._handle_mouse_release(inventory_slot.get_center()), "releasing over an inventory slot should commit the drag")
	_assert(String(player_inventory.get_slot(4).item) == "stone_chunk" and int(player_inventory.get_slot(4).count) == 5, "hotbar stack should move to inventory only after release")
	_assert(String(player_inventory.get_hotbar_slot(0).item) == "", "source hotbar slot should empty after committed drag")
	_assert(String(hud.cursor_stack.item) == "", "cursor should clear after committed drag")
	hud.free()

func _test_hud_drag_swap_returns_target_to_source() -> void:
	var player_inventory := InventorySystem.new(24, 99)
	player_inventory.set_hotbar_slot(0, "stone_chunk", 5)
	player_inventory.set_slot(0, "copper_nugget", 2)
	var hud := HudController.new()
	get_root().add_child(hud)
	await process_frame
	hud.open_inventory(player_inventory)
	var hotbar_slot := hud._hotbar_slot_rect(0)
	var inventory_slot := hud._slot_rect(hud._player_panel_rect(), 0, HudController.PLAYER_COLS)
	hud._handle_mouse_press(hotbar_slot.get_center())
	hud._handle_mouse_release(inventory_slot.get_center())
	_assert(String(player_inventory.get_slot(0).item) == "stone_chunk" and int(player_inventory.get_slot(0).count) == 5, "different-item drag should move source stack to target")
	_assert(String(player_inventory.get_hotbar_slot(0).item) == "copper_nugget" and int(player_inventory.get_hotbar_slot(0).count) == 2, "different-item drag should return target stack to source slot")
	_assert(String(hud.cursor_stack.item) == "", "swap drag should not leave a released item stuck on the cursor")
	hud.free()

func _test_hud_drag_merge_overflow_returns_to_source() -> void:
	var player_inventory := InventorySystem.new(24, 99)
	var chest_inventory := InventorySystem.new(18, 99)
	player_inventory.set_slot(0, "stone_chunk", 10)
	chest_inventory.set_slot(0, "stone_chunk", 95)
	var hud := HudController.new()
	get_root().add_child(hud)
	await process_frame
	hud.open_container(player_inventory, chest_inventory, "Test Chest")
	var player_slot := hud._slot_rect(hud._player_panel_rect(), 0, HudController.PLAYER_COLS)
	var chest_slot := hud._slot_rect(hud._container_panel_rect(), 0, HudController.CONTAINER_COLS)
	hud._handle_mouse_press(player_slot.get_center())
	hud._handle_mouse_release(chest_slot.get_center())
	_assert(int(chest_inventory.get_slot(0).count) == 99, "matching-stack drag should fill the target to cap")
	_assert(String(player_inventory.get_slot(0).item) == "stone_chunk" and int(player_inventory.get_slot(0).count) == 6, "merge overflow should return to the source slot after release")
	_assert(String(hud.cursor_stack.item) == "", "merge overflow should not remain stuck on the cursor after release")
	hud.free()

func _test_hud_drag_merge_and_world_drop() -> void:
	dropped_stack = {}
	var player_inventory := InventorySystem.new(24, 99)
	var chest_inventory := InventorySystem.new(18, 99)
	player_inventory.set_slot(0, "stone_chunk", 12)
	chest_inventory.set_slot(0, "stone_chunk", 80)
	var hud := HudController.new()
	get_root().add_child(hud)
	hud.world_drop_requested.connect(_on_world_drop_requested)
	await process_frame
	hud.open_container(player_inventory, chest_inventory, "Test Chest")
	var player_slot := hud._slot_rect(hud._player_panel_rect(), 0, HudController.PLAYER_COLS)
	var chest_slot := hud._slot_rect(hud._container_panel_rect(), 0, HudController.CONTAINER_COLS)
	hud._handle_mouse_press(player_slot.get_center())
	hud._handle_mouse_release(chest_slot.get_center())
	_assert(int(chest_inventory.get_slot(0).count) == 92, "dragging matching stack into chest should merge")
	_assert(String(player_inventory.get_slot(0).item) == "", "source slot should be empty after drag merge")
	player_inventory.set_slot(2, "dirt_clod", 5)
	var third_slot := hud._slot_rect(hud._player_panel_rect(), 2, HudController.PLAYER_COLS)
	hud._handle_mouse_press(third_slot.get_center())
	hud._handle_mouse_release(hud._hotbar_slot_rect(3).get_center())
	_assert(String(player_inventory.get_hotbar_slot(3).item) == "dirt_clod" and int(player_inventory.get_hotbar_slot(3).count) == 5, "dragging from inventory to visible hotbar should place the stack in extra hotbar storage")
	_assert(String(player_inventory.get_slot(2).item) == "", "dragging to hotbar should empty the source inventory slot")
	player_inventory.set_slot(1, "copper_nugget", 4)
	var second_slot := hud._slot_rect(hud._player_panel_rect(), 1, HudController.PLAYER_COLS)
	hud._handle_mouse_press(second_slot.get_center())
	hud._handle_mouse_release(Vector2(640, 650))
	_assert(String(dropped_stack.get("item", "")) == "copper_nugget" and int(dropped_stack.get("count", 0)) == 4, "releasing cursor stack outside panels should request a world drop")
	_assert(String(player_inventory.get_slot(1).item) == "", "world-dropped stack should leave the source slot")
	hud.free()

func _on_world_drop_requested(stack: Dictionary) -> void:
	dropped_stack = stack

func _test_manual_world_drop_at_player() -> void:
	var main := MainController.new()
	var drops := Node2D.new()
	var player := TestPlayer.new()
	player.global_position = Vector2(100, 100)
	main.drops_node = drops
	main.player = player
	main._spawn_world_drop({"item": "stone_chunk", "count": 3, "stack_cap": 99})
	_assert(drops.get_child_count() == 1, "world drop should create one dropped item entity")
	var drop := drops.get_child(0)
	var expected_position := player.global_position - DroppedItemController.ITEM_COLLIDER.bottom_offset
	_assert(drop.global_position.distance_to(expected_position) <= 0.01, "manual world drop should spawn at the player's current location")
	_assert(not bool(drop.auto_pickup_enabled), "manual world drop should not enable automatic pickup")
	_assert(main._try_collect_clicked_drop(drop.global_position), "clicking a manual world drop should collect it")
	_assert(player.inventory.count_item("stone_chunk") == 3, "clicked manual world drop should enter the player inventory")
	_assert(String(player.inventory.get_hotbar_slot(0).item) == "stone_chunk" and int(player.inventory.get_hotbar_slot(0).count) == 3, "clicked manual world drop should fill the hotbar before inventory slots")
	drops.free()
	player.free()
	main.free()

func _test_manual_drop_requires_click() -> void:
	var inventory := InventorySystem.new(2, 99)
	var player := Node2D.new()
	player.global_position = Vector2.ZERO
	var drop := DroppedItemController.new()
	get_root().add_child(drop)
	drop.global_position = Vector2(0, -12)
	drop.pickup_delay = 0.0
	drop.setup("copper_nugget", 4, player, inventory, Vector2.ZERO)
	drop._process(0.016)
	_assert(inventory.count_item("copper_nugget") == 0, "normal dropped item should not auto-pick up when the player is nearby")
	_assert(drop.try_collect(inventory), "normal dropped item should collect when clicked")
	_assert(inventory.count_item("copper_nugget") == 4, "clicked normal drop should enter available inventory")
	_assert(String(inventory.get_hotbar_slot(0).item) == "copper_nugget" and int(inventory.get_hotbar_slot(0).count) == 4, "clicked normal drop should fill hotbar slot 1 first")
	drop.free()
	player.free()

func _test_world_drop_click_collects_on_release() -> void:
	var main := MainController.new()
	var drops := Node2D.new()
	var player := TestPlayer.new()
	player.global_position = Vector2(100, 100)
	main.drops_node = drops
	main.player = player
	main._spawn_world_drop({"item": "stone_chunk", "count": 2, "stack_cap": 99})
	var drop := drops.get_child(0)
	var click_point: Vector2 = drop.global_position
	_assert(main._begin_world_drop_interaction(click_point), "pressing a world drop should start a click/drag interaction")
	_assert(player.inventory.count_item("stone_chunk") == 0, "world drop should not collect on mouse press")
	_assert(main._finish_world_drop_interaction(click_point), "releasing without dragging should collect the world drop")
	_assert(player.inventory.count_item("stone_chunk") == 2, "simple world-drop click should collect on release")
	_assert(String(player.inventory.get_hotbar_slot(0).item) == "stone_chunk" and int(player.inventory.get_hotbar_slot(0).count) == 2, "simple world-drop click should fill hotbar slot 1 first")
	drops.free()
	player.free()
	main.free()

func _test_world_drop_drag_moves_without_collecting() -> void:
	var main := MainController.new()
	var drops := Node2D.new()
	var player := TestPlayer.new()
	player.global_position = Vector2(100, 100)
	main.drops_node = drops
	main.player = player
	main._spawn_world_drop({"item": "copper_nugget", "count": 4, "stack_cap": 99})
	var drop := drops.get_child(0)
	var start_point: Vector2 = drop.global_position
	var drag_point := start_point + Vector2(24, -8)
	_assert(main._begin_world_drop_interaction(start_point), "pressing a world drop should start a drag candidate")
	_assert(bool(drop.manual_dragging), "world drop should pause physics while held")
	main._update_world_drop_drag(drag_point)
	_assert(drop.global_position.distance_to(drag_point) <= 0.01, "dragging should move the world drop to the cursor")
	main._finish_world_drop_interaction(drag_point)
	_assert(player.inventory.count_item("copper_nugget") == 0, "dragging a world drop should not collect it")
	_assert(drop.global_position.distance_to(drag_point) <= 0.01, "released world drop should remain at the dragged position")
	_assert(not bool(drop.manual_dragging), "released world drop should resume normal physics")
	drops.free()
	player.free()
	main.free()

func _test_special_drop_auto_pickup_into_inventory() -> void:
	var inventory := InventorySystem.new(2, 99)
	var player := Node2D.new()
	player.global_position = Vector2.ZERO
	var drop := DroppedItemController.new()
	get_root().add_child(drop)
	drop.global_position = Vector2(0, -12)
	drop.pickup_delay = 0.0
	drop.setup("royal_jelly", 1, player, inventory, Vector2.ZERO, null, true)
	drop._process(0.016)
	_assert(inventory.count_item("royal_jelly") == 1, "special boss-style drops should support explicit auto-pickup")
	_assert(String(inventory.get_hotbar_slot(0).item) == "royal_jelly" and int(inventory.get_hotbar_slot(0).count) == 1, "special auto-pickup should fill the hotbar before inventory slots")
	drop.free()
	player.free()
