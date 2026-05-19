extends Node2D

const BandCatalog = preload("res://scripts/catalogs/BandCatalog.gd")
const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")
const BackgroundCatalog = preload("res://scripts/catalogs/BackgroundCatalog.gd")
const LightingSystem = preload("res://scripts/systems/LightingSystem.gd")
const SpawnSystem = preload("res://scripts/systems/SpawnSystem.gd")
const StructureGenerator = preload("res://scripts/systems/StructureGenerator.gd")
const HeartSystem = preload("res://scripts/systems/HeartSystem.gd")
const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")
const PlaceableCatalog = preload("res://scripts/catalogs/PlaceableCatalog.gd")
const ChestController = preload("res://scripts/controllers/ChestController.gd")
const DroppedItemController = preload("res://scripts/controllers/DroppedItemController.gd")
const SaveGameSystem = preload("res://scripts/systems/SaveGameSystem.gd")
const EnemyScene = preload("res://scenes/Enemy.tscn")

const TEST_CHEST_OFFSET := Vector2(64, -16)
const TEST_CHEST_OPEN_DISTANCE := 46.0
const TEST_CHEST_CLICK_HALF_SIZE := Vector2(8, 8)
const HOTBAR_SIZE := 6
const WORLD_DROP_DRAG_THRESHOLD := 5.0
const STRUCTURE_SPAWN_RADIUS_TILES := 28
const STRUCTURE_SPAWN_CHECK_STEP_TILES := 16
const STRUCTURE_SPAWN_CHECK_INTERVAL_SECONDS := 0.20
const HUD_LIGHT_REFRESH_INTERVAL_SECONDS := 0.12
const MAIN_MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"
const PREFAB_DESIGNER_SCENE_PATH := "res://scenes/PrefabDesigner.tscn"

const TRANSIENT_INPUT_ACTIONS := [
	"move_left",
	"move_right",
	"move_up",
	"move_down",
	"jump",
	"drill",
	"strike",
	"use_flare",
	"place_beacon",
]

@onready var world = $World
@onready var player = $Player
@onready var props_node: Node2D = get_node_or_null("Props")
@onready var drops_node: Node2D = get_node_or_null("Drops")
@onready var hud = $HudLayer/Hud
@onready var enemies_node: Node2D = $Enemies

var current_encounter_band := ""
var active_container
var selected_hotbar_index := 0
var hud_drag_active := false
var held_world_drop
var held_world_drop_press_position := Vector2.ZERO
var held_world_drop_dragging := false
var spawned_structure_encounters: Dictionary = {}
var last_structure_spawn_check_tile := Vector2i(999999, 999999)
var structure_spawn_check_elapsed := STRUCTURE_SPAWN_CHECK_INTERVAL_SECONDS
var hud_light_refresh_elapsed := HUD_LIGHT_REFRESH_INTERVAL_SECONDS
var cached_hud_light := 1.0
var cached_hud_light_tile := Vector2i(999999, 999999)
var pause_menu_layer: CanvasLayer
var pause_status_label: Label
var pause_load_button: Button
var pause_menu_open := false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_release_transient_input()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_input()
	_configure_pause_processing()
	TextureFactory.warm_runtime_cache()
	if props_node == null:
		props_node = Node2D.new()
		props_node.name = "Props"
		add_child(props_node)
	if drops_node == null:
		drops_node = Node2D.new()
		drops_node.name = "Drops"
		add_child(drops_node)
	if hud.has_signal("world_drop_requested") and not hud.world_drop_requested.is_connected(_spawn_world_drop):
		hud.world_drop_requested.connect(_spawn_world_drop)
	if hud.has_signal("hotbar_slot_selected") and not hud.hotbar_slot_selected.is_connected(_select_hotbar_index):
		hud.hotbar_slot_selected.connect(_select_hotbar_index)
	if hud.has_signal("drag_state_changed") and not hud.drag_state_changed.is_connected(_set_hud_drag_active):
		hud.drag_state_changed.connect(_set_hud_drag_active)
	world.player = player
	world.container_parent = props_node
	if world.has_signal("chest_broken") and not world.chest_broken.is_connected(_on_chest_broken):
		world.chest_broken.connect(_on_chest_broken)
	player.world = world
	_ensure_pause_menu()
	_sync_selected_hotbar_item()
	_spawn_test_chest()
	var pending_save := SaveGameSystem.consume_pending_save(get_tree().root)
	if pending_save.is_empty():
		_spawn_band_encounter(BandCatalog.resolve_band_id(world.world_to_tile(player.global_position).y))
		_maybe_spawn_nearby_structure_encounters(true)
	else:
		var result := SaveGameSystem.apply_game_state(self, pending_save)
		if not bool(result.get("ok", false)):
			push_warning("Unable to apply pending save: %s" % String(result.get("error", "unknown error")))
			_spawn_band_encounter(BandCatalog.resolve_band_id(world.world_to_tile(player.global_position).y))
			_maybe_spawn_nearby_structure_encounters(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		_toggle_pause_menu()
		get_viewport().set_input_as_handled()
		return
	if pause_menu_open:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_hotbar(-1)
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_hotbar(1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var click_point := get_global_mouse_position()
			if event.pressed:
				if _begin_world_drop_interaction(click_point):
					get_viewport().set_input_as_handled()
			elif held_world_drop != null:
				_finish_world_drop_interaction(click_point)
				get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if not _is_item_drag_active() and _try_use_selected_hotbar_item(get_global_mouse_position()):
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and held_world_drop != null:
		_update_world_drop_drag(get_global_mouse_position())
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if pause_menu_open:
		return
	structure_spawn_check_elapsed += delta
	hud_light_refresh_elapsed += delta
	_set_player_drag_lock(_is_item_drag_active())
	if not _is_item_drag_active():
		if Input.is_action_just_pressed("debug_band_1"):
			_teleport_to_band(0)
		if Input.is_action_just_pressed("debug_band_2"):
			_teleport_to_band(390)
		if Input.is_action_just_pressed("debug_band_3"):
			_teleport_to_band(780)
		if Input.is_action_just_pressed("use_flare"):
			player.use_flare()
		if Input.is_action_just_pressed("place_beacon"):
			player.place_beacon()
		if Input.is_action_just_pressed("strike"):
			player.start_weapon_swing(get_global_mouse_position() - player.global_position)
			_strike_nearby_enemy()
		if Input.is_action_just_pressed("toggle_inventory"):
			_toggle_player_inventory()
		_handle_hotbar_number_input()
	_update_test_chest()
	_update_placement_preview()
	var band_id := BandCatalog.resolve_band_id(world.world_to_tile(player.global_position).y)
	if band_id != current_encounter_band:
		_spawn_band_encounter(band_id)
		_maybe_spawn_nearby_structure_encounters(true)
	else:
		_maybe_spawn_nearby_structure_encounters()
	_update_hud()

func _configure_input() -> void:
	_add_key("move_left", KEY_A)
	_add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_D)
	_add_key("move_right", KEY_RIGHT)
	_add_key("move_up", KEY_W)
	_add_key("move_up", KEY_UP)
	_add_key("move_down", KEY_S)
	_add_key("move_down", KEY_DOWN)
	_remove_key("jump", KEY_W)
	_remove_key("jump", KEY_UP)
	_add_key("jump", KEY_SPACE)
	_add_key("drill", KEY_F)
	_add_mouse("drill", MOUSE_BUTTON_LEFT)
	_add_key("strike", KEY_E)
	_add_key("use_flare", KEY_Q)
	_add_key("place_beacon", KEY_R)
	_add_key("toggle_inventory", KEY_I)
	_add_key("pause_menu", KEY_ESCAPE)
	for index in range(HOTBAR_SIZE):
		_add_key("hotbar_slot_%d" % [index + 1], KEY_1 + index)
	_remove_key("debug_band_1", KEY_1)
	_remove_key("debug_band_2", KEY_2)
	_remove_key("debug_band_3", KEY_3)
	_add_key("debug_band_1", KEY_F1)
	_add_key("debug_band_2", KEY_F2)
	_add_key("debug_band_3", KEY_F3)

func _add_key(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.keycode == keycode:
			return
	var input := InputEventKey.new()
	input.keycode = keycode
	InputMap.action_add_event(action_name, input)

func _remove_key(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		return
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.keycode == keycode:
			InputMap.action_erase_event(action_name, event)

func _configure_pause_processing() -> void:
	for node in [world, player, props_node, drops_node, enemies_node]:
		if node != null:
			node.process_mode = Node.PROCESS_MODE_PAUSABLE
	if hud != null:
		hud.process_mode = Node.PROCESS_MODE_ALWAYS

func _release_transient_input() -> void:
	for action_name in TRANSIENT_INPUT_ACTIONS:
		if InputMap.has_action(action_name):
			Input.action_release(action_name)
	if is_instance_valid(player) and player.has_method("cancel_transient_input"):
		player.cancel_transient_input()

func _add_mouse(action_name: String, button: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var input := InputEventMouseButton.new()
	input.button_index = button
	InputMap.action_add_event(action_name, input)

func _teleport_to_band(tile_y: int) -> void:
	player.global_position = Vector2(-8 * 16, tile_y * 16 + 13 * 16)
	player.velocity = Vector2.ZERO
	player.place_beacon()

func _spawn_band_encounter(band_id: String) -> void:
	current_encounter_band = band_id
	for child in enemies_node.get_children():
		child.queue_free()
	match band_id:
		"standard_caverns":
			_spawn_enemy("cave_skitter", player.global_position + Vector2(220, 0))
		"colossal_ant_chambers":
			_spawn_enemy("worker_ant", player.global_position + Vector2(190, 0))
			_spawn_enemy("soldier_ant", player.global_position + Vector2(260, 0))
		"buried_pyramids":
			_spawn_enemy("mummy_sentry", player.global_position + Vector2(210, 0))

func _spawn_enemy(enemy_id: String, pos: Vector2) -> void:
	var spawn := SpawnSystem.find_enemy_spawn(enemy_id, pos, player.global_position, world)
	if not bool(spawn.found):
		push_warning("Skipped %s spawn because no clear nearby space was found." % enemy_id)
		return
	var enemy = EnemyScene.instantiate()
	enemies_node.add_child(enemy)
	enemy.global_position = spawn.position
	enemy.setup(enemy_id, player, world)

func _maybe_spawn_nearby_structure_encounters(force := false) -> void:
	if world == null or player == null or enemies_node == null:
		return
	if not force and structure_spawn_check_elapsed < STRUCTURE_SPAWN_CHECK_INTERVAL_SECONDS:
		return
	var player_tile: Vector2i = world.world_to_tile(player.global_position)
	if not force and abs(player_tile.x - last_structure_spawn_check_tile.x) < STRUCTURE_SPAWN_CHECK_STEP_TILES and abs(player_tile.y - last_structure_spawn_check_tile.y) < STRUCTURE_SPAWN_CHECK_STEP_TILES:
		return
	structure_spawn_check_elapsed = 0.0
	last_structure_spawn_check_tile = player_tile
	_spawn_nearby_structure_encounters(player_tile)

func _spawn_nearby_structure_encounters(player_tile: Vector2i) -> void:
	if player_tile.y + STRUCTURE_SPAWN_RADIUS_TILES < StructureGenerator.BAND1_MIN_Y or player_tile.y - STRUCTURE_SPAWN_RADIUS_TILES > StructureGenerator.BAND1_MAX_Y:
		return
	var spawns: Array[Dictionary] = world.get_structure_spawns_near(player_tile, STRUCTURE_SPAWN_RADIUS_TILES) if world.has_method("get_structure_spawns_near") else StructureGenerator.get_structure_spawns_near(world.store.seed, player_tile, STRUCTURE_SPAWN_RADIUS_TILES)
	var structure_ids := {}
	for spawn in spawns:
		structure_ids[String(spawn.structure_id)] = true
	for structure_id in structure_ids.keys():
		if spawned_structure_encounters.has(structure_id):
			continue
		for spawn in spawns:
			if String(spawn.structure_id) != String(structure_id):
				continue
			_spawn_enemy(String(spawn.enemy_id), spawn.position)
		spawned_structure_encounters[structure_id] = true

func _spawn_test_chest() -> void:
	if props_node == null or not is_instance_valid(player):
		return
	if props_node.get_node_or_null("TestSpawnChest") != null:
		return
	if world != null and world.has_method("place_chest"):
		world.container_parent = props_node
		var tile: Vector2i = world.world_to_tile(player.global_position + TEST_CHEST_OFFSET)
		var chest = world.get_chest_at_tile(tile) if world.has_method("get_chest_at_tile") else null
		if chest == null and world.place_chest(tile, true):
			chest = world.get_chest_at_tile(tile)
		if chest != null:
			chest.name = "TestSpawnChest"
		return
	var chest := ChestController.new()
	chest.name = "TestSpawnChest"
	chest.seed_default_contents = true
	props_node.add_child(chest)
	chest.global_position = player.global_position + TEST_CHEST_OFFSET

func _update_test_chest() -> void:
	if props_node == null or not is_instance_valid(player):
		return
	if active_container == null:
		return
	if not is_instance_valid(active_container):
		_close_active_container()
		return
	if active_container.global_position.distance_to(player.global_position) > TEST_CHEST_OPEN_DISTANCE:
		_close_active_container()

func _try_open_clicked_chest(world_point: Vector2) -> bool:
	if props_node == null or not is_instance_valid(player):
		return false
	var chest = null
	if world != null and world.has_method("get_chest_at_world_point"):
		chest = world.get_chest_at_world_point(world_point)
	if chest == null:
		chest = props_node.get_node_or_null("TestSpawnChest")
	if chest == null:
		return false
	if chest.global_position.distance_to(player.global_position) > TEST_CHEST_OPEN_DISTANCE:
		return false
	var chest_rect := Rect2(chest.global_position - TEST_CHEST_CLICK_HALF_SIZE, TEST_CHEST_CLICK_HALF_SIZE * 2.0)
	if not chest_rect.has_point(world_point):
		return false
	if active_container == chest and bool(chest.get("is_open")):
		_close_active_container()
	else:
		_open_chest_container(chest)
	return true

func _try_use_selected_hotbar_item(world_point: Vector2) -> bool:
	if _try_open_clicked_chest(world_point):
		return true
	return _try_place_selected_hotbar_item(world_point)

func _try_place_selected_hotbar_item(world_point: Vector2) -> bool:
	if world == null or player == null or player.get("inventory") == null:
		return false
	var stack := _selected_hotbar_stack()
	var item_id := String(stack.get("item", ""))
	if item_id == "" or int(stack.get("count", 0)) <= 0:
		return false
	var placeable := PlaceableCatalog.get_placeable(item_id)
	if placeable.is_empty():
		return false
	var target_tile: Vector2i = world.world_to_tile(world_point)
	var placed := false
	match String(placeable.get("kind", "")):
		"container":
			if world.has_method("is_placeable_tile_clear") and not world.is_placeable_tile_clear(target_tile, player.global_position):
				return false
			placed = world.place_chest(target_tile)
		"tile":
			if world.has_method("is_placeable_tile_clear") and not world.is_placeable_tile_clear(target_tile, player.global_position):
				return false
			if world.get_tile(target_tile) == "air":
				world.set_tile(target_tile, String(placeable.get("tile", "air")))
				placed = true
		"background":
			if not world.has_method("set_background_tile"):
				return false
			if world.has_method("is_background_placeable_tile_clear") and not world.is_background_placeable_tile_clear(target_tile, player.global_position):
				return false
			world.set_background_tile(target_tile, String(placeable.get("background", "empty")))
			placed = true
	if not placed:
		return false
	player.inventory.decrement_hotbar_slot(selected_hotbar_index, int(placeable.get("count", 1)))
	_sync_selected_hotbar_item()
	if hud != null:
		hud.queue_redraw()
	return true

func _update_placement_preview() -> void:
	if world == null or not world.has_method("set_placement_preview"):
		return
	if not _should_show_placement_preview():
		world.clear_placement_preview()
		return
	var target_tile: Vector2i = world.world_to_tile(get_global_mouse_position())
	var placeable := PlaceableCatalog.get_placeable(String(_selected_hotbar_stack().get("item", "")))
	var valid := _is_placeable_target_valid(placeable, target_tile)
	world.set_placement_preview(target_tile, valid, true)

func _should_show_placement_preview() -> bool:
	if world == null or player == null or player.get("inventory") == null:
		return false
	if _is_item_drag_active():
		return false
	if hud != null and bool(hud.get("inventory_open")):
		return false
	var stack := _selected_hotbar_stack()
	var item_id := String(stack.get("item", ""))
	if item_id == "" or int(stack.get("count", 0)) <= 0:
		return false
	return PlaceableCatalog.is_placeable(item_id)

func _is_placeable_target_valid(placeable: Dictionary, target_tile: Vector2i) -> bool:
	match String(placeable.get("kind", "")):
		"background":
			return not world.has_method("is_background_placeable_tile_clear") or bool(world.is_background_placeable_tile_clear(target_tile, player.global_position))
		_:
			return not world.has_method("is_placeable_tile_clear") or bool(world.is_placeable_tile_clear(target_tile, player.global_position))

func _open_chest_container(chest) -> void:
	if chest == null:
		return
	if active_container != null and active_container != chest:
		_close_active_container()
	active_container = chest
	if chest.has_method("open"):
		chest.open()
	if hud != null and hud.has_method("open_container") and chest.get("inventory") != null:
		hud.open_container(player.inventory, chest.inventory, "Test Chest")

func _close_active_container() -> void:
	if active_container != null and is_instance_valid(active_container) and active_container.has_method("close"):
		active_container.close()
	active_container = null
	if hud != null and hud.has_method("close_container"):
		hud.close_container()

func _toggle_player_inventory() -> void:
	if active_container != null:
		_close_active_container()
		return
	if hud == null:
		return
	if hud.has_method("toggle_inventory"):
		hud.toggle_inventory(player.inventory)

func _handle_hotbar_number_input() -> void:
	for index in range(HOTBAR_SIZE):
		if Input.is_action_just_pressed("hotbar_slot_%d" % [index + 1]):
			_select_hotbar_index(index)

func _select_hotbar_index(index: int) -> void:
	selected_hotbar_index = clampi(index, 0, HOTBAR_SIZE - 1)
	_sync_selected_hotbar_item()
	if hud != null:
		hud.queue_redraw()

func _cycle_hotbar(direction: int) -> void:
	selected_hotbar_index = posmod(selected_hotbar_index + direction, HOTBAR_SIZE)
	_sync_selected_hotbar_item()
	if hud != null:
		hud.queue_redraw()

func _selected_hotbar_stack() -> Dictionary:
	if player == null or player.get("inventory") == null:
		return {"item": "", "count": 0, "stack_cap": 99}
	return player.inventory.get_hotbar_slot(selected_hotbar_index)

func _sync_selected_hotbar_item() -> void:
	if player == null or not is_instance_valid(player) or not player.has_method("set_selected_hotbar_item"):
		return
	var stack := _selected_hotbar_stack()
	var item_id := String(stack.get("item", ""))
	if int(stack.get("count", 0)) <= 0:
		item_id = ""
	player.set_selected_hotbar_item(item_id)

func _format_stack_label(stack: Dictionary) -> String:
	if String(stack.get("item", "")) == "" or int(stack.get("count", 0)) <= 0:
		return "Empty"
	if int(stack.get("count", 0)) > 1:
		return "%s x%d" % [String(stack.get("item", "")), int(stack.get("count", 0))]
	return String(stack.get("item", ""))

func _spawn_world_drop(stack: Dictionary) -> void:
	if not is_instance_valid(player):
		return
	_spawn_world_drop_at(stack, player.global_position - DroppedItemController.ITEM_COLLIDER.bottom_offset, false)

func _spawn_world_drop_at(stack: Dictionary, position: Vector2, auto_pickup_enabled := false, toss_velocity := Vector2.ZERO) -> void:
	if drops_node == null or not is_instance_valid(player):
		return
	var item_id := String(stack.get("item", ""))
	var count := int(stack.get("count", 0))
	if item_id == "" or count <= 0:
		return
	var drop := DroppedItemController.new()
	drops_node.add_child(drop)
	drop.global_position = position
	drop.setup(item_id, count, player, player.inventory, toss_velocity, world, auto_pickup_enabled)

func _spawn_auto_pickup_drop(stack: Dictionary, position: Vector2) -> void:
	_spawn_world_drop_at(stack, position, true)

func _on_chest_broken(tile: Vector2i, drops: Array) -> void:
	if active_container != null:
		var should_close := not is_instance_valid(active_container)
		if not should_close and active_container.get("anchor_tile") != null:
			should_close = active_container.anchor_tile == tile
		if should_close:
			_close_active_container()
	if world == null:
		return
	var base_position: Vector2 = world.tile_to_world_center(tile)
	for index in range(drops.size()):
		var stack: Dictionary = drops[index]
		var offset := Vector2(float((index % 3) - 1) * 5.0, -8.0 - float(index / 3) * 3.0)
		var toss := Vector2(float((index % 3) - 1) * 28.0, -42.0)
		_spawn_world_drop_at(stack, base_position + offset, false, toss)

func _try_collect_clicked_drop(world_point: Vector2) -> bool:
	var drop = _drop_at_point(world_point)
	if drop == null or not is_instance_valid(player):
		return false
	return drop.try_collect(player.inventory)

func _drop_at_point(world_point: Vector2):
	if drops_node == null:
		return null
	var children := drops_node.get_children()
	children.reverse()
	for child in children:
		if child is DroppedItemController and child.contains_world_point(world_point):
			return child
	return null

func _begin_world_drop_interaction(world_point: Vector2) -> bool:
	var drop = _drop_at_point(world_point)
	if drop == null:
		return false
	held_world_drop = drop
	held_world_drop_press_position = world_point
	held_world_drop_dragging = false
	if held_world_drop.has_method("begin_manual_drag"):
		held_world_drop.begin_manual_drag()
	_set_player_drag_lock(true)
	_release_transient_input()
	return true

func _update_world_drop_drag(world_point: Vector2) -> void:
	if held_world_drop == null or not is_instance_valid(held_world_drop):
		_clear_world_drop_interaction()
		return
	if not held_world_drop_dragging and world_point.distance_to(held_world_drop_press_position) >= WORLD_DROP_DRAG_THRESHOLD:
		held_world_drop_dragging = true
	if held_world_drop_dragging and held_world_drop.has_method("drag_to_world"):
		held_world_drop.drag_to_world(world_point)

func _finish_world_drop_interaction(world_point: Vector2) -> bool:
	if held_world_drop == null or not is_instance_valid(held_world_drop):
		_clear_world_drop_interaction()
		return false
	var drop = held_world_drop
	var should_collect := not held_world_drop_dragging
	if held_world_drop_dragging and drop.has_method("drag_to_world"):
		drop.drag_to_world(world_point)
	if drop.has_method("end_manual_drag"):
		drop.end_manual_drag()
	_clear_world_drop_interaction()
	if should_collect and is_instance_valid(player):
		return drop.try_collect(player.inventory)
	return true

func _clear_world_drop_interaction() -> void:
	held_world_drop = null
	held_world_drop_dragging = false
	held_world_drop_press_position = Vector2.ZERO
	_set_player_drag_lock(_is_item_drag_active())

func _set_hud_drag_active(active: bool) -> void:
	hud_drag_active = active
	if active:
		_release_transient_input()
	_set_player_drag_lock(_is_item_drag_active())

func _is_item_drag_active() -> bool:
	return hud_drag_active or held_world_drop != null

func _set_player_drag_lock(locked: bool) -> void:
	if is_instance_valid(player) and player.has_method("set_controls_locked"):
		player.set_controls_locked(locked)

func save_game() -> Dictionary:
	return SaveGameSystem.save_game(self)

func load_game() -> Dictionary:
	var result := SaveGameSystem.load_game()
	if not bool(result.get("ok", false)):
		return result
	var apply_result := SaveGameSystem.apply_game_state(self, Dictionary(result.get("data", {})))
	if not bool(apply_result.get("ok", false)):
		return {
			"ok": false,
			"path": result.get("path", SaveGameSystem.SAVE_PATH),
			"error": String(apply_result.get("error", "Unable to apply save.")),
			"data": {},
		}
	return result

func _refresh_encounters_after_load() -> void:
	for child in enemies_node.get_children():
		child.queue_free()
	current_encounter_band = ""
	spawned_structure_encounters.clear()
	last_structure_spawn_check_tile = Vector2i(999999, 999999)
	structure_spawn_check_elapsed = STRUCTURE_SPAWN_CHECK_INTERVAL_SECONDS
	cached_hud_light_tile = Vector2i(999999, 999999)
	_spawn_band_encounter(BandCatalog.resolve_band_id(world.world_to_tile(player.global_position).y))
	_maybe_spawn_nearby_structure_encounters(true)

func _ensure_pause_menu() -> void:
	if pause_menu_layer != null and is_instance_valid(pause_menu_layer):
		return
	pause_menu_layer = CanvasLayer.new()
	pause_menu_layer.name = "PauseMenuLayer"
	pause_menu_layer.layer = 40
	pause_menu_layer.visible = false
	pause_menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_menu_layer)

	var root := Control.new()
	root.name = "PauseMenuRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu_layer.add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.48)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(280, 322)
	panel.add_theme_stylebox_override("panel", _pause_panel_style())
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_top = 14
	box.offset_right = -16
	box.offset_bottom = -14
	panel.add_child(box)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color8(244, 231, 192))
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	box.add_child(_pause_button("Resume", _resume_game))
	box.add_child(_pause_button("Save", _on_pause_save_pressed))
	pause_load_button = _pause_button("Load", _on_pause_load_pressed)
	box.add_child(pause_load_button)
	box.add_child(_pause_button("Template Editor", _on_pause_template_editor_pressed))
	box.add_child(_pause_button("Main Menu", _on_pause_main_menu_pressed))
	box.add_child(_pause_button("Quit", _on_pause_quit_pressed))

	pause_status_label = Label.new()
	pause_status_label.text = ""
	pause_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_status_label.add_theme_color_override("font_color", Color8(178, 190, 182))
	pause_status_label.add_theme_font_size_override("font_size", 12)
	box.add_child(pause_status_label)

	root.resized.connect(func(): _center_pause_panel(panel))
	_center_pause_panel(panel)

func _pause_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.94)
	style.border_color = Color8(91, 100, 107)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _pause_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 34)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(callback)
	return button

func _center_pause_panel(panel: Control) -> void:
	if panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var panel_size := panel.custom_minimum_size
	panel.position = (viewport_size - panel_size) * 0.5
	panel.size = panel_size

func _toggle_pause_menu() -> void:
	if pause_menu_open:
		_resume_game()
	else:
		_open_pause_menu()

func _open_pause_menu() -> void:
	_ensure_pause_menu()
	pause_menu_open = true
	pause_menu_layer.visible = true
	_set_pause_status("")
	_refresh_pause_buttons()
	_set_player_drag_lock(true)
	_release_transient_input()
	get_tree().paused = true

func _resume_game() -> void:
	if not pause_menu_open:
		return
	get_tree().paused = false
	pause_menu_open = false
	if pause_menu_layer != null:
		pause_menu_layer.visible = false
	_set_player_drag_lock(_is_item_drag_active())

func _refresh_pause_buttons() -> void:
	if pause_load_button != null:
		pause_load_button.disabled = not SaveGameSystem.has_save()

func _set_pause_status(message: String) -> void:
	if pause_status_label != null:
		pause_status_label.text = message

func _on_pause_save_pressed() -> void:
	var result := save_game()
	if bool(result.get("ok", false)):
		_set_pause_status("Saved.")
	else:
		_set_pause_status(String(result.get("error", "Save failed.")))
	_refresh_pause_buttons()

func _on_pause_load_pressed() -> void:
	if not SaveGameSystem.has_save():
		_set_pause_status("No save found.")
		_refresh_pause_buttons()
		return
	var result := load_game()
	if bool(result.get("ok", false)):
		_set_pause_status("Loaded.")
	else:
		_set_pause_status(String(result.get("error", "Load failed.")))
	_refresh_pause_buttons()

func _on_pause_template_editor_pressed() -> void:
	_change_scene_from_pause(PREFAB_DESIGNER_SCENE_PATH)

func _on_pause_main_menu_pressed() -> void:
	_change_scene_from_pause(MAIN_MENU_SCENE_PATH)

func _on_pause_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()

func _change_scene_from_pause(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)

func _strike_nearby_enemy() -> void:
	for child in enemies_node.get_children():
		if child.has_method("take_damage") and child.alive and child.global_position.distance_to(player.global_position) < 42.0:
			child.take_damage(12)

func _update_hud() -> void:
	var player_tile: Vector2i = world.world_to_tile(player.global_position)
	var light := _hud_light_for_tile(player_tile)
	var band: Dictionary = BandCatalog.get_band(player_tile.y)
	var hostile_nearby := false
	for child in enemies_node.get_children():
		if child.has_method("take_damage") and child.alive and child.global_position.distance_to(player.global_position) < 140.0:
			hostile_nearby = true
	var hotbar_slots: Array = player.inventory.hotbar_slots(HOTBAR_SIZE)
	var active_stack := _selected_hotbar_stack()
	_sync_selected_hotbar_item()
	var target_def := BackgroundCatalog.get_background(player.target_tile_id) if String(player.get("target_layer")) == "background" else TileCatalog.get_tile(player.target_tile_id)
	hud.set_hud_state({
		"health_current": player.health,
		"health_max": player.max_health,
		"heart_states": HeartSystem.heart_states(player.health, player.max_health),
		"drill_heat": player.drill_heat,
		"depth_label": BandCatalog.get_depth_label(player_tile.y),
		"target_name": target_def.name,
		"light": light,
		"danger": LightingSystem.danger_pulse(light, float(band.danger) / 6.0, hostile_nearby),
		"hotbar_slots": hotbar_slots,
		"selected_hotbar_index": selected_hotbar_index,
		"active_item": _format_stack_label(active_stack)
	})

func _hud_light_for_tile(player_tile: Vector2i) -> float:
	var tile_changed := player_tile != cached_hud_light_tile
	var cache_empty := cached_hud_light_tile.x == 999999
	var has_world_light_sources: bool = world.beacons.size() > 0 or world.flares.size() > 0
	var interval_elapsed: bool = hud_light_refresh_elapsed >= HUD_LIGHT_REFRESH_INTERVAL_SECONDS
	if cache_empty or (tile_changed and interval_elapsed) or (has_world_light_sources and interval_elapsed):
		var sources: Array[Dictionary] = world.get_light_sources(player.global_position)
		cached_hud_light = LightingSystem.sample_light(world.store, player_tile, sources)
		cached_hud_light_tile = player_tile
		hud_light_refresh_elapsed = 0.0
	return cached_hud_light
