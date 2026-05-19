extends Control
class_name MainMenuController

const SaveGameSystem = preload("res://scripts/systems/SaveGameSystem.gd")

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const TEMPLATE_EDITOR_SCENE_PATH := "res://scenes/PrefabDesigner.tscn"

var save_path := SaveGameSystem.SAVE_PATH
var scene_changes_enabled := true
var quit_enabled := true
var last_requested_scene := ""
var quit_was_requested := false

var start_button: Button
var load_button: Button
var template_button: Button
var quit_button: Button
var status_label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_refresh_buttons()

func _build_ui() -> void:
	if start_button != null:
		return
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color8(9, 11, 18)
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	panel.custom_minimum_size = Vector2(320, 300)
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 18
	box.offset_top = 16
	box.offset_right = -18
	box.offset_bottom = -16
	panel.add_child(box)

	var title := Label.new()
	title.text = "Deepbound"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color8(244, 231, 192))
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	start_button = _menu_button("Start World", _on_start_world_pressed)
	load_button = _menu_button("Load Game", _on_load_game_pressed)
	template_button = _menu_button("Template Editor", _on_template_editor_pressed)
	quit_button = _menu_button("Quit", _on_quit_pressed)
	box.add_child(start_button)
	box.add_child(load_button)
	box.add_child(template_button)
	box.add_child(quit_button)

	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color8(178, 190, 182))
	status_label.add_theme_font_size_override("font_size", 12)
	box.add_child(status_label)

	resized.connect(func(): _center_panel(panel))
	_center_panel(panel)

func _panel_style() -> StyleBoxFlat:
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

func _menu_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 38)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(callback)
	return button

func _center_panel(panel: Control) -> void:
	var panel_size := panel.custom_minimum_size
	panel.position = (get_viewport_rect().size - panel_size) * 0.5
	panel.size = panel_size

func _refresh_buttons() -> void:
	if load_button != null:
		load_button.disabled = not SaveGameSystem.has_save(save_path)

func _set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message

func _on_start_world_pressed() -> void:
	SaveGameSystem.clear_pending_save(get_tree().root)
	_request_scene(MAIN_SCENE_PATH)

func _on_load_game_pressed() -> void:
	if not SaveGameSystem.has_save(save_path):
		_set_status("No save found.")
		_refresh_buttons()
		return
	var result := SaveGameSystem.load_game(save_path)
	if not bool(result.get("ok", false)):
		_set_status(String(result.get("error", "Load failed.")))
		_refresh_buttons()
		return
	SaveGameSystem.stash_pending_save(get_tree().root, Dictionary(result.get("data", {})))
	_request_scene(MAIN_SCENE_PATH)

func _on_template_editor_pressed() -> void:
	SaveGameSystem.clear_pending_save(get_tree().root)
	_request_scene(TEMPLATE_EDITOR_SCENE_PATH)

func _on_quit_pressed() -> void:
	quit_was_requested = true
	if quit_enabled:
		get_tree().quit()

func _request_scene(path: String) -> void:
	last_requested_scene = path
	if scene_changes_enabled:
		get_tree().change_scene_to_file(path)
