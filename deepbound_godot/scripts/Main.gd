extends Node2D

const BandCatalog = preload("res://scripts/catalogs/BandCatalog.gd")
const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")
const LightingSystem = preload("res://scripts/systems/LightingSystem.gd")
const EnemyScene = preload("res://scenes/Enemy.tscn")

@onready var world = $World
@onready var player = $Player
@onready var hud = $HudLayer/Hud
@onready var enemies_node: Node2D = $Enemies

var current_encounter_band := ""

func _ready() -> void:
	_configure_input()
	world.player = player
	player.world = world
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
		_strike_nearby_enemy()
	var band_id := BandCatalog.resolve_band_id(world.world_to_tile(player.global_position).y)
	if band_id != current_encounter_band:
		_spawn_band_encounter(band_id)
	_update_hud()

func _configure_input() -> void:
	_add_key("move_left", KEY_A)
	_add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_D)
	_add_key("move_right", KEY_RIGHT)
	_add_key("jump", KEY_W)
	_add_key("jump", KEY_UP)
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
	var enemy = EnemyScene.instantiate()
	enemies_node.add_child(enemy)
	enemy.global_position = pos
	enemy.setup(enemy_id, player, world)

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
		"drill_heat": player.drill_heat,
		"depth_label": BandCatalog.get_depth_label(player_tile.y),
		"target_name": target_def.name,
		"light": light,
		"danger": LightingSystem.danger_pulse(light, float(band.danger) / 6.0, hostile_nearby),
		"quickbar": ", ".join(quick_parts)
	})
