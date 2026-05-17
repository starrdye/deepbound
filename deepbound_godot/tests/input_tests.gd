extends SceneTree

const MainController = preload("res://scripts/Main.gd")
const PlayerController = preload("res://scripts/controllers/PlayerController.gd")

var failures: Array[String] = []

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
	await process_frame
	_test_focus_loss_releases_stale_actions()
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

func _release_test_actions() -> void:
	for action_name in ["move_up", "move_down", "move_left", "move_right", "jump", "drill", "strike", "use_flare", "place_beacon"]:
		if InputMap.has_action(action_name):
			Input.action_release(action_name)

func _action_has_key(action_name: String, keycode: Key) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.keycode == keycode:
			return true
	return false
