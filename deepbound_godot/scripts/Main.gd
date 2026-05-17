extends Node2D

const BandCatalog = preload("res://scripts/catalogs/BandCatalog.gd")
const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")
const LightingSystem = preload("res://scripts/systems/LightingSystem.gd")
const SpawnSystem = preload("res://scripts/systems/SpawnSystem.gd")
const HeartSystem = preload("res://scripts/systems/HeartSystem.gd")
const ChestController = preload("res://scripts/controllers/ChestController.gd")
const DroppedItemController = preload("res://scripts/controllers/DroppedItemController.gd")
const EnemyScene = preload("res://scenes/Enemy.tscn")

const TEST_CHEST_OFFSET := Vector2(64, -16)
const TEST_CHEST_OPEN_DISTANCE := 46.0

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

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_release_transient_input()

func _ready() -> void:
	_configure_input()
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
	world.player = player
	player.world = world
	_spawn_test_chest()
	_spawn_band_encounter(BandCatalog.resolve_band_id(world.world_to_tile(player.global_position).y))

func _process(_delta: float) -> void:
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
	_update_test_chest()
	var band_id := BandCatalog.resolve_band_id(world.world_to_tile(player.global_position).y)
	if band_id != current_encounter_band:
		_spawn_band_encounter(band_id)
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
	_add_key("debug_band_1", KEY_1)
	_add_key("debug_band_2", KEY_2)
	_add_key("debug_band_3", KEY_3)

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

func _spawn_test_chest() -> void:
	if props_node == null or not is_instance_valid(player):
		return
	if props_node.get_node_or_null("TestSpawnChest") != null:
		return
	var chest := ChestController.new()
	chest.name = "TestSpawnChest"
	props_node.add_child(chest)
	chest.global_position = player.global_position + TEST_CHEST_OFFSET

func _update_test_chest() -> void:
	if props_node == null or not is_instance_valid(player):
		return
	var chest = props_node.get_node_or_null("TestSpawnChest")
	if chest == null:
		return
	if chest.global_position.distance_to(player.global_position) <= TEST_CHEST_OPEN_DISTANCE:
		if chest.has_method("open"):
			chest.open()
		if hud != null and hud.has_method("open_container") and chest.get("inventory") != null:
			hud.open_container(player.inventory, chest.inventory, "Test Chest")
	elif chest.has_method("close"):
		chest.close()
		if hud != null and hud.has_method("close_container"):
			hud.close_container()

func _spawn_world_drop(stack: Dictionary) -> void:
	if drops_node == null or not is_instance_valid(player):
		return
	var item_id := String(stack.get("item", ""))
	var count := int(stack.get("count", 0))
	if item_id == "" or count <= 0:
		return
	var direction := Vector2.ZERO
	if is_inside_tree():
		direction = get_global_mouse_position() - player.global_position
	if direction.length_squared() <= 0.001:
		var facing_value = player.get("facing")
		direction = Vector2(float(facing_value) if facing_value != null else 1.0, -0.25)
	direction = direction.normalized()
	var drop := DroppedItemController.new()
	drops_node.add_child(drop)
	drop.global_position = player.global_position + direction * DroppedItemController.SAFE_TOSS_DISTANCE + Vector2(0, -10)
	drop.setup(item_id, count, player, player.inventory, direction * 140.0 + Vector2(0, -40))

func _strike_nearby_enemy() -> void:
	for child in enemies_node.get_children():
		if child.has_method("take_damage") and child.alive and child.global_position.distance_to(player.global_position) < 42.0:
			child.take_damage(12)

func _update_hud() -> void:
	var player_tile: Vector2i = world.world_to_tile(player.global_position)
	var sources: Array[Dictionary] = world.get_light_sources(player.global_position)
	var light: float = LightingSystem.sample_light(world.store, player_tile, sources)
	var band: Dictionary = BandCatalog.get_band(player_tile.y)
	var hostile_nearby := false
	for child in enemies_node.get_children():
		if child.has_method("take_damage") and child.alive and child.global_position.distance_to(player.global_position) < 140.0:
			hostile_nearby = true
	var quick_parts: Array[String] = []
	for slot in player.inventory.quick_slots(8):
		if slot.item != "":
			quick_parts.append("%s:%d" % [slot.item, slot.count])
	var target_def := TileCatalog.get_tile(player.target_tile_id)
	hud.set_hud_state({
		"health_current": player.health,
		"health_max": player.max_health,
		"heart_states": HeartSystem.heart_states(player.health, player.max_health),
		"drill_heat": player.drill_heat,
		"depth_label": BandCatalog.get_depth_label(player_tile.y),
		"target_name": target_def.name,
		"light": light,
		"danger": LightingSystem.danger_pulse(light, float(band.danger) / 6.0, hostile_nearby),
		"quickbar": ", ".join(quick_parts)
	})
