extends SceneTree

const MainMenuController = preload("res://scripts/controllers/MainMenuController.gd")
const SaveGameSystem = preload("res://scripts/systems/SaveGameSystem.gd")

const TEST_SAVE_PATH := "user://saves/menu_test_slot.json"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_remove_file(TEST_SAVE_PATH)
	await _test_main_menu_button_handlers()
	_remove_file(TEST_SAVE_PATH)
	SaveGameSystem.clear_pending_save(get_root())
	if failures.is_empty():
		print("Deepbound Godot menu tests passed.")
		quit(0)
	else:
		print("Deepbound Godot menu tests failed: %d" % failures.size())
		quit(1)

func _test_main_menu_button_handlers() -> void:
	var scene: PackedScene = load("res://scenes/MainMenu.tscn")
	var menu = scene.instantiate()
	menu.scene_changes_enabled = false
	menu.quit_enabled = false
	menu.save_path = TEST_SAVE_PATH
	get_root().add_child(menu)
	await process_frame
	_assert(menu is MainMenuController, "MainMenu scene should instantiate the menu controller")
	_assert(menu.start_button != null and menu.load_button != null and menu.template_button != null and menu.quit_button != null, "main menu should build all launch buttons")

	SaveGameSystem.stash_pending_save(get_root(), SaveGameSystem.normalize_save_data({}))
	menu._on_start_world_pressed()
	_assert(menu.last_requested_scene == MainMenuController.MAIN_SCENE_PATH, "Start World should target the main world scene")
	_assert(not get_root().has_meta(SaveGameSystem.PENDING_SAVE_META_KEY), "Start World should clear pending loaded save data")

	menu._on_template_editor_pressed()
	_assert(menu.last_requested_scene == MainMenuController.TEMPLATE_EDITOR_SCENE_PATH, "Template Editor should target the prefab designer scene")

	menu.last_requested_scene = ""
	menu._on_load_game_pressed()
	_assert(menu.last_requested_scene == "", "Load Game should stay on menu when no save exists")
	_assert(String(menu.status_label.text) == "No save found.", "Load Game should report a missing single save slot")

	var write_result := SaveGameSystem.write_save_data(SaveGameSystem.normalize_save_data({}), TEST_SAVE_PATH)
	_assert(bool(write_result.get("ok", false)), "test setup should write a valid menu save slot")
	menu._refresh_buttons()
	_assert(not bool(menu.load_button.disabled), "Load Game button should enable when the configured save exists")
	menu._on_load_game_pressed()
	_assert(menu.last_requested_scene == MainMenuController.MAIN_SCENE_PATH, "Load Game should target the main world scene")
	_assert(get_root().has_meta(SaveGameSystem.PENDING_SAVE_META_KEY), "Load Game should stash pending save data before scene change")

	menu._on_quit_pressed()
	_assert(bool(menu.quit_was_requested), "Quit should record a safe quit request for tests")
	menu.queue_free()
	await process_frame

func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
