extends SceneTree

const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")
const DroppedItemController = preload("res://scripts/controllers/DroppedItemController.gd")
const MainController = preload("res://scripts/Main.gd")
const HudController = preload("res://scripts/controllers/HudController.gd")

var failures: Array[String] = []
var dropped_stack := {}

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
	await _test_hud_drag_merge_and_world_drop()
	_test_safe_world_drop_distance()
	_test_auto_pickup_into_inventory()
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
	player_inventory.set_slot(1, "copper_nugget", 4)
	var second_slot := hud._slot_rect(hud._player_panel_rect(), 1, HudController.PLAYER_COLS)
	hud._handle_mouse_press(second_slot.get_center())
	hud._handle_mouse_release(Vector2(640, 650))
	_assert(String(dropped_stack.get("item", "")) == "copper_nugget" and int(dropped_stack.get("count", 0)) == 4, "releasing cursor stack outside panels should request a world drop")
	_assert(String(player_inventory.get_slot(1).item) == "", "world-dropped stack should leave the source slot")
	hud.free()

func _on_world_drop_requested(stack: Dictionary) -> void:
	dropped_stack = stack

func _test_safe_world_drop_distance() -> void:
	var main := MainController.new()
	var drops := Node2D.new()
	var player := TestPlayer.new()
	player.global_position = Vector2(100, 100)
	main.drops_node = drops
	main.player = player
	main._spawn_world_drop({"item": "stone_chunk", "count": 3, "stack_cap": 99})
	_assert(drops.get_child_count() == 1, "world drop should create one dropped item entity")
	var drop := drops.get_child(0)
	_assert(drop.global_position.distance_to(player.global_position) >= DroppedItemController.AUTO_PICKUP_RADIUS, "world drop should spawn outside auto-pickup radius")
	drops.free()
	player.free()
	main.free()

func _test_auto_pickup_into_inventory() -> void:
	var inventory := InventorySystem.new(2, 99)
	var player := Node2D.new()
	player.global_position = Vector2.ZERO
	var drop := DroppedItemController.new()
	get_root().add_child(drop)
	drop.global_position = Vector2(0, -12)
	drop.pickup_delay = 0.0
	drop.setup("copper_nugget", 4, player, inventory, Vector2.ZERO)
	drop._process(0.016)
	_assert(inventory.count_item("copper_nugget") == 4, "nearby dropped item should auto-pick up into available inventory")
	drop.free()
	player.free()
