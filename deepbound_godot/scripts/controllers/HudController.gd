extends Control
class_name HudController

const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")
const HeartSystem = preload("res://scripts/systems/HeartSystem.gd")

signal world_drop_requested(stack: Dictionary)

const SLOT_SIZE := 36.0
const SLOT_GAP := 4.0
const PANEL_PADDING := 12.0
const PANEL_HEADER := 28.0
const PLAYER_COLS := 6
const CONTAINER_COLS := 6

var health_label: Label
var inventory_label: Label
var depth_label: Label
var target_label: Label
var light_label: Label
var hint_label: Label
var hud_state := {}
var player_inventory
var container_inventory
var container_title := "Chest"
var container_open := false
var cursor_stack := {"item": "", "count": 0, "stack_cap": 99}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	health_label = _make_label(Vector2(20, 38))
	depth_label = _make_label(Vector2(20, 74))
	target_label = _make_label(Vector2(20, 96))
	light_label = _make_label(Vector2(1120, 20))
	inventory_label = _make_label(Vector2(20, 650))
	hint_label = _make_label(Vector2(740, 650))
	hint_label.text = "Mouse/F: drill  E: strike  Q: flare  R: beacon  1/2/3: sprint bands"

func open_container(player_inv, chest_inv, title := "Chest") -> void:
	player_inventory = player_inv
	container_inventory = chest_inv
	container_title = title
	container_open = true
	queue_redraw()

func close_container() -> void:
	if not container_open:
		return
	_flush_cursor_stack()
	container_open = false
	container_inventory = null
	queue_redraw()

func _flush_cursor_stack() -> void:
	if _is_empty_stack(cursor_stack):
		return
	if player_inventory != null:
		var remaining: int = player_inventory.add_item(String(cursor_stack.item), int(cursor_stack.count))
		if remaining <= 0:
			cursor_stack = _empty_stack()
			return
		cursor_stack.count = remaining
	world_drop_requested.emit(cursor_stack.duplicate())
	cursor_stack = _empty_stack()

func _make_label(pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_color_override("font_color", Color8(244, 231, 192))
	label.add_theme_font_size_override("font_size", 13)
	add_child(label)
	return label

func set_hud_state(state: Dictionary) -> void:
	hud_state = state
	health_label.text = "HP %d/%d  Drill %d%%" % [state.health_current, state.health_max, roundi(float(state.drill_heat) * 100.0)]
	depth_label.text = String(state.depth_label)
	target_label.text = "Target: %s" % String(state.target_name)
	light_label.text = "Light %d%%" % roundi(float(state.light) * 100.0)
	inventory_label.text = "Quick: %s" % String(state.quickbar)
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	var danger := float(hud_state.get("danger", 0.0))
	if danger > 0.05:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.1, 0.08, danger * 0.22), false, 14.0)
	_panel(Rect2(12, 10, 260, 58))
	_panel(Rect2(12, 638, 520, 58))
	_panel(Rect2(size.x - 180, 10, 160, 44))
	_draw_hearts(Vector2(20, 16))
	if container_open:
		_draw_inventory_panel(_player_panel_rect(), "Inventory", player_inventory, PLAYER_COLS)
		_draw_inventory_panel(_container_panel_rect(), container_title, container_inventory, CONTAINER_COLS)
		_draw_cursor_stack()

func _draw_hearts(origin: Vector2) -> void:
	var states: Array = hud_state.get(
		"heart_states",
		HeartSystem.heart_states(int(hud_state.get("health_current", 0)), int(hud_state.get("health_max", HeartSystem.DEFAULT_MAX_HP)))
	)
	var sheet := TextureFactory.make_ui_texture("heart_sheet")
	for index in range(states.size()):
		var frame := HeartSystem.sprite_frame_for_state(String(states[index]))
		var target := Rect2(origin + Vector2(index * 18, 0), Vector2(16, 16))
		if sheet != null:
			draw_texture_rect_region(sheet, target, Rect2(frame * 16, 0, 16, 16))
		else:
			var fallback_color := Color8(201, 78, 78) if frame == 0 else Color8(82, 36, 46)
			draw_rect(target, fallback_color, true)

func _panel(rect: Rect2) -> void:
	draw_rect(rect, Color(0.05, 0.06, 0.09, 0.78), true)
	draw_rect(rect, Color8(91, 100, 107), false, 2.0)

func _gui_input(event: InputEvent) -> void:
	if not container_open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_mouse_press(event.position)
		else:
			_handle_mouse_release(event.position)
		queue_redraw()
	elif event is InputEventMouseMotion and not _is_empty_stack(cursor_stack):
		queue_redraw()

func _handle_mouse_press(point: Vector2) -> void:
	var hit := _slot_at(point)
	if hit.is_empty() or not _is_empty_stack(cursor_stack):
		return
	var inventory = hit.inventory
	var stack: Dictionary = inventory.get_slot(int(hit.index))
	if _is_empty_stack(stack):
		return
	cursor_stack = inventory.take_slot(int(hit.index))
	accept_event()

func _handle_mouse_release(point: Vector2) -> void:
	if _is_empty_stack(cursor_stack):
		return
	var hit := _slot_at(point)
	if hit.is_empty():
		world_drop_requested.emit(cursor_stack.duplicate())
		cursor_stack = _empty_stack()
		accept_event()
		return
	var inventory = hit.inventory
	cursor_stack = inventory.place_stack(int(hit.index), cursor_stack)
	accept_event()

func _player_panel_rect() -> Rect2:
	var rows := ceili(float(player_inventory.slots.size() if player_inventory != null else 24) / float(PLAYER_COLS))
	return _panel_rect(Vector2(64, 132), PLAYER_COLS, rows)

func _container_panel_rect() -> Rect2:
	var rows := ceili(float(container_inventory.slots.size() if container_inventory != null else 18) / float(CONTAINER_COLS))
	var width := PANEL_PADDING * 2.0 + CONTAINER_COLS * SLOT_SIZE + (CONTAINER_COLS - 1) * SLOT_GAP
	return _panel_rect(Vector2(get_viewport_rect().size.x - width - 64.0, 132), CONTAINER_COLS, rows)

func _panel_rect(origin: Vector2, cols: int, rows: int) -> Rect2:
	return Rect2(
		origin,
		Vector2(
			PANEL_PADDING * 2.0 + cols * SLOT_SIZE + (cols - 1) * SLOT_GAP,
			PANEL_PADDING * 2.0 + PANEL_HEADER + rows * SLOT_SIZE + (rows - 1) * SLOT_GAP
		)
	)

func _draw_inventory_panel(rect: Rect2, title: String, inventory, cols: int) -> void:
	if inventory == null:
		return
	_panel(rect)
	var font := get_theme_default_font()
	if font != null:
		draw_string(font, rect.position + Vector2(PANEL_PADDING, 19), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color8(244, 231, 192))
	for index in range(inventory.slots.size()):
		var slot_rect := _slot_rect(rect, index, cols)
		draw_rect(slot_rect, Color(0.08, 0.075, 0.085, 0.92), true)
		draw_rect(slot_rect, Color8(91, 100, 107), false, 1.0)
		_draw_stack(inventory.get_slot(index), slot_rect)

func _slot_rect(panel_rect: Rect2, index: int, cols: int) -> Rect2:
	var col := index % cols
	var row := index / cols
	return Rect2(
		panel_rect.position + Vector2(
			PANEL_PADDING + col * (SLOT_SIZE + SLOT_GAP),
			PANEL_PADDING + PANEL_HEADER + row * (SLOT_SIZE + SLOT_GAP)
		),
		Vector2(SLOT_SIZE, SLOT_SIZE)
	)

func _slot_at(point: Vector2) -> Dictionary:
	if player_inventory != null:
		var hit := _slot_at_panel(point, _player_panel_rect(), player_inventory, PLAYER_COLS, "player")
		if not hit.is_empty():
			return hit
	if container_inventory != null:
		var hit := _slot_at_panel(point, _container_panel_rect(), container_inventory, CONTAINER_COLS, "container")
		if not hit.is_empty():
			return hit
	return {}

func _slot_at_panel(point: Vector2, panel_rect: Rect2, inventory, cols: int, panel_id: String) -> Dictionary:
	if not panel_rect.has_point(point):
		return {}
	for index in range(inventory.slots.size()):
		var slot_rect := _slot_rect(panel_rect, index, cols)
		if slot_rect.has_point(point):
			return {"panel": panel_id, "index": index, "inventory": inventory, "rect": slot_rect}
	return {}

func _draw_stack(stack: Dictionary, slot_rect: Rect2) -> void:
	if _is_empty_stack(stack):
		return
	var texture := TextureFactory.make_item_texture(String(stack.item))
	var item_rect := Rect2(slot_rect.position + Vector2(6, 5), Vector2(24, 24))
	if texture != null:
		draw_texture_rect(texture, item_rect, false)
	else:
		draw_rect(item_rect.grow(-5), Color8(255, 214, 107), true)
	if int(stack.count) > 1:
		var font := get_theme_default_font()
		if font != null:
			draw_string(font, slot_rect.position + Vector2(18, 31), str(stack.count), HORIZONTAL_ALIGNMENT_RIGHT, 15.0, 11, Color8(255, 238, 154))

func _draw_cursor_stack() -> void:
	if _is_empty_stack(cursor_stack):
		return
	_draw_stack(cursor_stack, Rect2(get_local_mouse_position() - Vector2(18, 18), Vector2(SLOT_SIZE, SLOT_SIZE)))

func _empty_stack() -> Dictionary:
	return {"item": "", "count": 0, "stack_cap": 99}

func _is_empty_stack(stack: Dictionary) -> bool:
	return String(stack.get("item", "")) == "" or int(stack.get("count", 0)) <= 0
