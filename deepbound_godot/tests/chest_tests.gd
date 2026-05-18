extends SceneTree

const ChestController = preload("res://scripts/controllers/ChestController.gd")
const MainController = preload("res://scripts/Main.gd")
const DeepboundWorld = preload("res://scripts/World.gd")
const BackgroundCatalog = preload("res://scripts/catalogs/BackgroundCatalog.gd")
const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")

var failures: Array[String] = []

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
	_test_chest_open_animation_frames()
	_test_chest_sheet_art_review()
	_test_spawn_area_test_chest()
	_test_chest_mining_spills_physical_drops()
	_test_hotbar_chest_and_block_placement()
	_test_placement_rejections_do_not_consume_item()
	_test_placement_preview_state()
	if failures.is_empty():
		print("Deepbound Godot chest tests passed.")
		quit(0)
	else:
		print("Deepbound Godot chest tests failed: %d" % failures.size())
		quit(1)

func _test_chest_open_animation_frames() -> void:
	var chest := ChestController.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	chest.add_child(sprite)
	get_root().add_child(chest)
	await process_frame
	_assert(chest.frame == 0, "new chest should start closed")
	_assert(sprite.scale == Vector2.ONE * ChestController.VISUAL_SCALE, "chest sprite should render as a single 16x16 cell")
	chest.open()
	chest._process(ChestController.OPEN_SECONDS * 0.5)
	_assert(chest.frame > 0 and chest.frame < ChestController.FRAME_COUNT - 1, "chest should advance through middle open frames")
	chest._process(ChestController.OPEN_SECONDS)
	_assert(chest.frame == ChestController.FRAME_COUNT - 1, "chest should finish on the open frame")
	_assert(sprite.region_rect.position.x == float((ChestController.FRAME_COUNT - 1) * ChestController.FRAME_SIZE.x), "sprite region should point at the final open frame")
	chest.close()
	_assert(chest.frame == 0, "closing should reset to frame zero")
	chest.free()

func _test_chest_sheet_art_review() -> void:
	var image := Image.new()
	_assert(image.load("res://assets/props/chest_open_sheet.png") == OK, "chest art review should load open sheet")
	_assert(image.get_width() == 256 and image.get_height() == 32, "chest open sheet should remain eight 32x32 frames")
	var first := _frame_signature(image, 0)
	var middle := _frame_signature(image, 3)
	var final := _frame_signature(image, 7)
	_assert(first != middle, "middle chest frame should visibly differ from closed frame")
	_assert(middle != final, "middle chest frame should visibly differ from final open frame")
	_assert(first != final, "final open chest should visibly differ from closed frame")

func _frame_signature(image: Image, frame: int) -> int:
	var total := 0
	for y in range(32):
		for x in range(frame * 32, frame * 32 + 32):
			var color := image.get_pixel(x, y)
			total += roundi(color.r * 255.0 + color.g * 765.0 + color.b * 1275.0 + color.a * 1785.0)
	return total

func _test_spawn_area_test_chest() -> void:
	var main := MainController.new()
	var world := DeepboundWorld.new()
	var props := Node2D.new()
	var player := TestPlayer.new()
	player.global_position = Vector2(-128, 208)
	main.world = world
	main.props_node = props
	main.player = player
	main._spawn_test_chest()
	var chest_tile: Vector2i = world.world_to_tile(player.global_position + MainController.TEST_CHEST_OFFSET)
	var chest = props.get_node_or_null("TestSpawnChest")
	_assert(chest != null, "main scene should create a named test chest near initial spawn")
	if chest != null:
		_assert(world.get_tile(chest_tile) == "chest_block", "spawn chest should be backed by a solid chest_block tile")
		_assert(world.get_chest_at_tile(chest_tile) == chest, "spawn chest should be tracked by anchor tile")
		_assert(chest.anchor_tile == chest_tile, "spawn chest should remember its anchor tile")
		_assert(chest.global_position == world.tile_to_world_center(chest_tile), "spawn chest visual should be centered inside one grid cell")
		_assert(chest.inventory.slots.size() == 18 and chest.inventory.hotbar.size() == 0, "chest storage should be 18 slots with no hidden hotbar")
		_assert(chest.inventory.count_item("wooden_sword") == 1, "spawn chest should seed a test wooden sword")
		_assert(chest.inventory.count_item("hammer") == 1, "spawn chest should seed one hammer for background wall mining")
		_assert(chest.inventory.count_item("wooden_background_block") == 10, "spawn chest should seed ten wooden background blocks for wall placement testing")
	main._spawn_test_chest()
	_assert(props.get_child_count() == 1, "test chest setup should be idempotent")
	if chest != null:
		chest.global_position = player.global_position + Vector2(10, 0)
		main._update_test_chest()
		_assert(not bool(chest.is_open), "test chest should not auto-open just because the player walks close")
		_assert(main._try_open_clicked_chest(chest.global_position), "nearby clicked chest should open")
		_assert(bool(chest.is_open), "clicked nearby chest should open")
		chest.close()
		_assert(not main._try_open_clicked_chest(chest.global_position + Vector2(9, 0)), "click outside one-cell chest footprint should miss")
		_assert(not main._try_open_clicked_chest(chest.global_position + Vector2(80, 0)), "nearby miss-click should not open the chest")
		_assert(not bool(chest.is_open), "miss-click should keep the chest closed")
		chest.global_position = player.global_position + Vector2(MainController.TEST_CHEST_OPEN_DISTANCE + 20.0, 0)
		_assert(not main._try_open_clicked_chest(chest.global_position), "far clicked chest should not open")
		_open_for_auto_close(main, chest)
		main._update_test_chest()
		_assert(not bool(chest.is_open), "opened chest should auto-close when the player walks away")
	props.free()
	player.free()
	world.free()
	main.free()

func _open_for_auto_close(main, chest) -> void:
	chest.global_position = main.player.global_position + Vector2(10, 0)
	main._try_open_clicked_chest(chest.global_position)
	chest.global_position = main.player.global_position + Vector2(MainController.TEST_CHEST_OPEN_DISTANCE + 20.0, 0)

func _test_chest_mining_spills_physical_drops() -> void:
	var main := MainController.new()
	var world := DeepboundWorld.new()
	var props := Node2D.new()
	var drops := Node2D.new()
	var player := TestPlayer.new()
	player.global_position = Vector2.ZERO
	world.container_parent = props
	main.world = world
	main.props_node = props
	main.drops_node = drops
	main.player = player
	world.chest_broken.connect(main._on_chest_broken)

	var tile := Vector2i(1, -1)
	_assert(world.place_chest(tile, true), "test setup should place a seeded chest block")
	var chest = world.get_chest_at_tile(tile)
	chest.open()
	main.active_container = chest
	var partial := world.mine_at(tile, player.inventory, 0.25, 0.0)
	_assert(not bool(partial.broke), "first mining tick should damage but not break a chest block")
	_assert(world.store.get_damage(tile) > 0.0, "chest block should accumulate mining damage")
	var broken := world.mine_at(tile, player.inventory, 2.0, 0.0)
	_assert(bool(broken.broke) and bool(broken.get("container_broke", false)), "continued mining should break the container block")
	_assert(world.get_tile(tile) == "air", "broken chest block should become air")
	_assert(world.get_chest_at_tile(tile) == null, "broken chest should be removed from the container store")
	_assert(main.active_container == null, "breaking an open chest should close the active container UI state")
	_assert(player.inventory.count_item("copper_nugget") == 0 and player.inventory.count_item("stone_chunk") == 0 and player.inventory.count_item("wooden_sword") == 0 and player.inventory.count_item("hammer") == 0 and player.inventory.count_item("wooden_background_block") == 0, "spilled chest contents should not enter player inventory automatically")
	_assert(drops.get_child_count() == 6, "broken seeded chest should spawn chest, copper, stone, wooden sword, hammer, and background block drops")
	_assert(_drop_count(drops, "chest") == 1, "broken chest should drop one empty chest item")
	_assert(_drop_count(drops, "copper_nugget") == 6, "broken seeded chest should spill copper stack")
	_assert(_drop_count(drops, "stone_chunk") == 12, "broken seeded chest should spill stone stack")
	_assert(_drop_count(drops, "wooden_sword") == 1, "broken seeded chest should spill wooden sword stack")
	_assert(_drop_count(drops, "hammer") == 1, "broken seeded chest should spill hammer stack")
	_assert(_drop_count(drops, "wooden_background_block") == 10, "broken seeded chest should spill wooden background blocks")
	for child in drops.get_children():
		child.pickup_delay = 0.0
		child._process(0.016)
	_assert(player.inventory.count_item("copper_nugget") == 0 and player.inventory.count_item("stone_chunk") == 0 and player.inventory.count_item("wooden_sword") == 0 and player.inventory.count_item("hammer") == 0 and player.inventory.count_item("wooden_background_block") == 0, "spilled drops should remain manual-click pickups")
	props.free()
	drops.free()
	player.free()
	world.free()
	main.free()

func _test_hotbar_chest_and_block_placement() -> void:
	var main := MainController.new()
	var world := DeepboundWorld.new()
	var props := Node2D.new()
	var player := TestPlayer.new()
	player.global_position = Vector2.ZERO
	world.container_parent = props
	main.world = world
	main.props_node = props
	main.player = player

	player.inventory.set_hotbar_slot(0, "chest", 1)
	main._select_hotbar_index(0)
	var chest_tile := Vector2i(1, -1)
	_assert(main._try_place_selected_hotbar_item(world.tile_to_world_center(chest_tile)), "right-use placement should place a selected chest item")
	_assert(world.get_tile(chest_tile) == "chest_block", "placed chest item should create a chest_block tile")
	_assert(player.inventory.count_item("chest") == 0, "successful chest placement should consume one chest item")
	var chest = world.get_chest_at_tile(chest_tile)
	_assert(chest != null and chest.inventory.count_item("copper_nugget") == 0 and chest.inventory.count_item("stone_chunk") == 0 and chest.inventory.count_item("wooden_sword") == 0, "newly placed chest should be empty")
	_assert(main._try_open_clicked_chest(chest.global_position), "newly placed chest should be reopenable")

	player.inventory.set_hotbar_slot(1, "dirt_clod", 2)
	main._select_hotbar_index(1)
	var dirt_tile := Vector2i(1, -2)
	_assert(main._try_place_selected_hotbar_item(world.tile_to_world_center(dirt_tile)), "mapped terrain resource should place its block")
	_assert(world.get_tile(dirt_tile) == "loose_dirt", "dirt_clod should place loose_dirt")
	_assert(int(player.inventory.get_hotbar_slot(1).count) == 1, "successful terrain placement should consume one resource")

	player.inventory.set_hotbar_slot(1, "stone_chunk", 1)
	var far_reachable_tile := Vector2i(4, -1)
	world.set_tile(far_reachable_tile, "air")
	_assert(main._try_place_selected_hotbar_item(world.tile_to_world_center(far_reachable_tile)), "tripled placement reach should allow farther tiles")
	_assert(world.get_tile(far_reachable_tile) == "soft_stone", "stone_chunk should place soft_stone at the farther reachable tile")

	player.inventory.set_hotbar_slot(2, "copper_nugget", 1)
	main._select_hotbar_index(2)
	var non_placeable_tile := Vector2i(-2, -2)
	_assert(not main._try_place_selected_hotbar_item(world.tile_to_world_center(non_placeable_tile)), "non-placeable selected items should not place blocks")
	_assert(world.get_tile(non_placeable_tile) == "air", "non-placeable item should leave target tile unchanged")
	_assert(player.inventory.count_item("copper_nugget") == 1, "non-placeable item should not be consumed")

	player.inventory.set_hotbar_slot(3, "wooden_background_block", 2)
	main._select_hotbar_index(3)
	var background_tile := Vector2i(2, -1)
	world.set_tile(background_tile, "air")
	world.set_background_tile(background_tile, BackgroundCatalog.EMPTY_ID)
	_assert(main._try_place_selected_hotbar_item(world.tile_to_world_center(background_tile)), "background block item should place a non-solid background wall")
	_assert(world.get_background_tile(background_tile) == "wooden_background_block", "wooden background item should set the background layer")
	_assert(world.get_tile(background_tile) == "air", "background placement should not affect foreground terrain")
	_assert(int(player.inventory.get_hotbar_slot(3).count) == 1, "successful background placement should consume one wall item")

	var behind_solid_tile := Vector2i(3, -1)
	world.set_tile(behind_solid_tile, "soft_stone")
	world.set_background_tile(behind_solid_tile, BackgroundCatalog.EMPTY_ID)
	_assert(main._try_place_selected_hotbar_item(world.tile_to_world_center(behind_solid_tile)), "background block placement should work behind foreground terrain")
	_assert(world.get_background_tile(behind_solid_tile) == "wooden_background_block", "background layer should place behind solid foreground blocks")
	_assert(world.get_tile(behind_solid_tile) == "soft_stone", "placing a background block behind terrain should keep the foreground block")
	props.free()
	player.free()
	world.free()
	main.free()

func _test_placement_rejections_do_not_consume_item() -> void:
	var main := MainController.new()
	var world := DeepboundWorld.new()
	var props := Node2D.new()
	var player := TestPlayer.new()
	player.global_position = Vector2.ZERO
	world.container_parent = props
	main.world = world
	main.props_node = props
	main.player = player
	player.inventory.set_hotbar_slot(0, "chest", 4)
	main._select_hotbar_index(0)

	world.set_tile(Vector2i(1, -1), "soft_stone")
	_assert(not main._try_place_selected_hotbar_item(world.tile_to_world_center(Vector2i(1, -1))), "placement should reject occupied terrain")
	world.set_tile(Vector2i(1, -1), "air")
	_assert(not main._try_place_selected_hotbar_item(world.tile_to_world_center(Vector2i(5, -1))), "placement should reject out-of-reach tiles")
	_assert(not main._try_place_selected_hotbar_item(world.tile_to_world_center(Vector2i(0, -1))), "placement should reject tiles overlapping the player collider")
	_assert(world.place_chest(Vector2i(-2, -2)), "test setup should place an existing chest")
	_assert(not main._try_place_selected_hotbar_item(world.tile_to_world_center(Vector2i(-2, -2))), "placement should reject tiles already occupied by a chest")
	_assert(int(player.inventory.get_hotbar_slot(0).count) == 4, "failed placements should not consume the selected hotbar item")
	props.free()
	player.free()
	world.free()
	main.free()

func _test_placement_preview_state() -> void:
	var world := DeepboundWorld.new()
	var player := TestPlayer.new()
	player.global_position = Vector2.ZERO
	var valid_tile := Vector2i(4, -1)
	var invalid_tile := Vector2i(0, -1)
	world.set_tile(valid_tile, "air")
	_assert(world.is_placeable_tile_clear(valid_tile, player.global_position), "preview validation should accept farther reachable clear tiles")
	_assert(not world.is_placeable_tile_clear(invalid_tile, player.global_position), "preview validation should reject player-overlap tiles")
	world.set_placement_preview(valid_tile, true, true)
	_assert(bool(world.placement_preview_visible), "placement preview should become visible for placeable selected items")
	_assert(world.placement_preview_tile == valid_tile and bool(world.placement_preview_valid), "placement preview should remember a valid target tile")
	world.set_placement_preview(invalid_tile, false, true)
	_assert(world.placement_preview_tile == invalid_tile and not bool(world.placement_preview_valid), "placement preview should mark invalid target tiles for red highlight")
	world.clear_placement_preview()
	_assert(not bool(world.placement_preview_visible), "placement preview should hide when there is no placeable selected item")
	player.free()
	world.free()

func _drop_count(drops: Node, item_id: String) -> int:
	var total := 0
	for child in drops.get_children():
		if String(child.get("item_id")) == item_id:
			total += int(child.get("count"))
	return total
