extends SceneTree

const MainController = preload("res://scripts/Main.gd")
const PlayerController = preload("res://scripts/controllers/PlayerController.gd")

var failures: Array[String] = []

class NoTargetWorld:
	extends Node2D
	func find_mining_target(_origin: Vector2, _aim: Vector2) -> Vector2i:
		return Vector2i(999999, 999999)
	func get_tile(_tile: Vector2i) -> String:
		return "air"

class RecordingMineWorld:
	extends Node2D
	var mine_calls := 0
	var last_drill_heat := -1.0
	func find_mining_target(_origin: Vector2, _aim: Vector2) -> Vector2i:
		return Vector2i(1, 1)
	func get_tile(_tile: Vector2i) -> String:
		return "loose_dirt"
	func mine_at(_tile: Vector2i, _inventory, _delta: float, drill_heat := 0.0) -> Dictionary:
		mine_calls += 1
		last_drill_heat = drill_heat
		return {"broke": false, "progress": 0.1, "stage": 1, "drops": []}

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_keyboard_action_split()
	await process_frame
	_test_jump_request_edges()
	_test_jump_height_is_four_tiles()
	await process_frame
	_test_focus_loss_releases_stale_actions()
	_test_inventory_key_is_configured()
	_test_hotbar_key_actions_are_configured()
	_test_mouse_wheel_cycles_hotbar_selection()
	_test_drag_lock_blocks_player_actions()
	await _test_non_drill_selection_uses_constant_mining_speed()
	await _test_held_drill_does_not_auto_cycle_at_full_heat()
	if failures.is_empty():
		print("Deepbound Godot input tests passed.")
		quit(0)
	else:
		print("Deepbound Godot input tests failed: %d" % failures.size())
		quit(1)

func _test_keyboard_action_split() -> void:
	var main := MainController.new()
	main._configure_input()
	_assert(_action_has_key("jump", KEY_SPACE), "space should be the dedicated jump key")
	_assert(not _action_has_key("jump", KEY_UP), "up should not share the jump action with space")
	_assert(not _action_has_key("jump", KEY_W), "W should not share the jump action with space")
	_assert(_action_has_key("move_up", KEY_UP), "up should be available as vertical intent")
	_assert(_action_has_key("move_up", KEY_W), "W should be available as vertical intent")
	_assert(_action_has_key("move_left", KEY_LEFT), "left arrow should remain horizontal movement")
	_assert(_action_has_key("move_right", KEY_RIGHT), "right arrow should remain horizontal movement")
	main.free()

func _test_jump_request_edges() -> void:
	_release_test_actions()
	var player := PlayerController.new()

	Input.action_press("move_up")
	_assert(player._is_jump_requested(), "pressing up should still be accepted as an up-jump request")
	Input.action_press("move_left")
	Input.action_press("jump")
	_assert(player._is_jump_requested(), "holding up and left should not swallow a separate space jump")

	_release_test_actions()
	player.free()

func _test_jump_height_is_four_tiles() -> void:
	var target_height: float = float(PlayerController.JUMP_HEIGHT_TILES * PlayerController.TILE_SIZE)
	var simulated_height: float = _simulate_player_jump_height()
	_assert(absf(simulated_height - target_height) <= 2.0, "player jump should reach about four tiles; expected %.2f got %.2f" % [target_height, simulated_height])

func _test_focus_loss_releases_stale_actions() -> void:
	_release_test_actions()
	var main := MainController.new()
	main._configure_input()
	var player := PlayerController.new()
	main.player = player
	player.velocity.x = 74.0

	Input.action_press("move_right")
	Input.action_press("drill")
	Input.action_press("jump")
	_assert(Input.is_action_pressed("move_right"), "test setup should have a stuck right action")
	main._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_assert(not Input.is_action_pressed("move_right"), "focus loss should release stale right input")
	_assert(not Input.is_action_pressed("drill"), "focus loss should release stale drill input")
	_assert(not Input.is_action_pressed("jump"), "focus loss should release stale jump input")
	_assert(is_zero_approx(player.velocity.x), "focus loss should cancel stale horizontal player velocity")

	_release_test_actions()
	player.free()
	main.free()

func _test_inventory_key_is_configured() -> void:
	var main := MainController.new()
	main._configure_input()
	_assert(InputMap.has_action("toggle_inventory"), "I inventory key should create a toggle_inventory action")
	var found_i := false
	for event in InputMap.action_get_events("toggle_inventory"):
		if event is InputEventKey and event.keycode == KEY_I:
			found_i = true
	_assert(found_i, "toggle_inventory should be bound to the I key")
	main.free()

func _test_hotbar_key_actions_are_configured() -> void:
	var main := MainController.new()
	main._configure_input()
	for index in range(MainController.HOTBAR_SIZE):
		var action_name := "hotbar_slot_%d" % [index + 1]
		_assert(InputMap.has_action(action_name), "hotbar number action should exist: %s" % action_name)
		_assert(_action_has_key(action_name, KEY_1 + index), "hotbar action should be bound to its matching number key")
	_assert(not _action_has_key("debug_band_1", KEY_1), "debug band jump should not steal number key 1 from the hotbar")
	_assert(_action_has_key("debug_band_1", KEY_F1), "debug band jump 1 should move to F1")
	_assert(_action_has_key("debug_band_2", KEY_F2), "debug band jump 2 should move to F2")
	_assert(_action_has_key("debug_band_3", KEY_F3), "debug band jump 3 should move to F3")
	main.free()

func _test_mouse_wheel_cycles_hotbar_selection() -> void:
	var main := MainController.new()
	main.selected_hotbar_index = 0
	main._cycle_hotbar(1)
	_assert(main.selected_hotbar_index == 1, "mouse wheel down should advance active hotbar slot")
	main._cycle_hotbar(-1)
	_assert(main.selected_hotbar_index == 0, "mouse wheel up should move back one hotbar slot")
	main._cycle_hotbar(-1)
	_assert(main.selected_hotbar_index == MainController.HOTBAR_SIZE - 1, "mouse wheel should wrap from first to last hotbar slot")
	main.free()

func _test_drag_lock_blocks_player_actions() -> void:
	_release_test_actions()
	var main := MainController.new()
	main._configure_input()
	var player := PlayerController.new()
	Input.action_press("drill")
	Input.action_press("move_up")
	_assert(player._is_drill_active(), "test setup should make the drill action active")
	_assert(player._is_jump_requested(), "test setup should make up-jump active")
	player.start_weapon_swing(Vector2.RIGHT)
	_assert(player._is_weapon_swinging(), "test setup should allow weapon swing before drag lock")
	player.set_controls_locked(true)
	_assert(not player._is_drill_active(), "drag lock should prevent mouse-held drilling")
	_assert(not player._is_jump_requested(), "drag lock should prevent movement/jump actions")
	_assert(not player._is_weapon_swinging(), "drag lock should suppress weapon animation/action state")
	_release_test_actions()
	player.free()
	main.free()

func _test_held_drill_does_not_auto_cycle_at_full_heat() -> void:
	_release_test_actions()
	var main := MainController.new()
	main._configure_input()
	var world := NoTargetWorld.new()
	var player := PlayerController.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	player.add_child(sprite)
	get_root().add_child(world)
	get_root().add_child(player)
	await process_frame

	player.world = world
	player.on_ground = true
	player.velocity = Vector2.ZERO
	player.set_selected_hotbar_item("starter_drill")
	Input.action_press("drill")
	player._update_mining(10.0)
	_assert(is_equal_approx(player.drill_heat, 1.0), "test setup should bring the drill to full heat")
	_assert(player._is_drill_active(), "held drill should stay active at full heat instead of cycling off")
	player._update_animation(0.1, 0.0)
	_assert(sprite.region_rect.position.y in [96.0, 128.0, 160.0], "full-heat held drill should keep a drill animation active")

	_release_test_actions()
	player.queue_free()
	world.queue_free()
	main.free()

func _test_non_drill_selection_uses_constant_mining_speed() -> void:
	_release_test_actions()
	var main := MainController.new()
	main._configure_input()
	var world := RecordingMineWorld.new()
	var player := PlayerController.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	player.add_child(sprite)
	get_root().add_child(world)
	get_root().add_child(player)
	await process_frame
	player.world = world
	Input.action_press("drill")

	player.set_selected_hotbar_item("")
	player._update_mining(10.0)
	_assert(world.mine_calls == 1, "empty-hand mining should still call into the mining system")
	_assert(is_zero_approx(player.drill_heat), "empty-hand mining should not build drill heat")
	_assert(is_zero_approx(world.last_drill_heat), "empty-hand mining should use constant baseline speed")

	player.set_selected_hotbar_item("dirt_clod")
	player._update_mining(10.0)
	_assert(world.mine_calls == 2, "block-held mining should still call into the mining system")
	_assert(is_zero_approx(player.drill_heat), "holding a block should not build drill heat")
	_assert(is_zero_approx(world.last_drill_heat), "holding a block should keep mining speed constant")

	player.set_selected_hotbar_item("starter_drill")
	player._update_mining(1.0)
	_assert(player.drill_heat > 0.0, "holding a drill should build drill heat")
	_assert(world.last_drill_heat > 0.0, "holding a drill should pass drill heat into mining speed")

	_release_test_actions()
	player.queue_free()
	world.queue_free()
	main.free()

func _release_test_actions() -> void:
	for action_name in ["move_up", "move_down", "move_left", "move_right", "jump", "drill", "strike", "use_flare", "place_beacon", "toggle_inventory", "hotbar_slot_1", "hotbar_slot_2", "hotbar_slot_3", "hotbar_slot_4", "hotbar_slot_5", "hotbar_slot_6"]:
		if InputMap.has_action(action_name):
			Input.action_release(action_name)

func _simulate_player_jump_height() -> float:
	var dt := 1.0 / 60.0
	var y := 0.0
	var min_y := 0.0
	var velocity_y := PlayerController.JUMP_VELOCITY
	for _step in range(180):
		velocity_y = minf(PlayerController.MAX_FALL, velocity_y + PlayerController.GRAVITY * dt)
		y += velocity_y * dt
		min_y = minf(min_y, y)
		if velocity_y >= 0.0:
			break
	return -min_y

func _action_has_key(action_name: String, keycode: Key) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.keycode == keycode:
			return true
	return false
