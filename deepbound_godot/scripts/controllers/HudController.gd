extends Control
class_name HudController

const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")
const HeartSystem = preload("res://scripts/systems/HeartSystem.gd")
const DebugSystem = preload("res://scripts/systems/DebugSystem.gd")
const TerminalSystem = preload("res://scripts/systems/TerminalSystem.gd")
const ItemCatalog = preload("res://scripts/catalogs/ItemCatalog.gd")

signal world_drop_requested(stack: Dictionary)
signal hotbar_slot_selected(index: int)
signal drag_state_changed(active: bool)
signal terminal_command(cmd: String)

const SLOT_SIZE := 36.0
const SLOT_GAP := 4.0
const GOD_BTN_W := 160.0
const GOD_BTN_H := 26.0
const GOD_BTN_MARGIN_RIGHT := 12.0
const GOD_BTN_TOP := 62.0
const PANEL_PADDING := 12.0
const PANEL_HEADER := 28.0
const PLAYER_COLS := 6
const CONTAINER_COLS := 6
const HOTBAR_SIZE := 6
const HOTBAR_MARGIN_BOTTOM := 14.0

const TERMINAL_H := 32.0  # height of the plain grey input rectangle

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
var inventory_open := false
var container_open := false
var cursor_stack := {"item": "", "count": 0, "stack_cap": 99}
var drag_source := {}
var hud_state_signature := ""

## Terminal console
var _terminal_line_edit: LineEdit = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	health_label = _make_label(Vector2(20, 38))
	depth_label = _make_label(Vector2(20, 74))
	target_label = _make_label(Vector2(20, 96))
	light_label = _make_label(Vector2(1120, 20))
	inventory_label = _make_label(Vector2(20, 650))
	hint_label = _make_label(Vector2(740, 650))
	hint_label.text = ""
	_build_terminal()

func open_inventory(player_inv) -> void:
	player_inventory = player_inv
	container_inventory = null
	container_open = false
	inventory_open = true
	queue_redraw()

func toggle_inventory(player_inv) -> void:
	if inventory_open:
		close_inventory()
	else:
		open_inventory(player_inv)

func open_container(player_inv, chest_inv, title := "Chest") -> void:
	player_inventory = player_inv
	container_inventory = chest_inv
	container_title = title
	inventory_open = true
	container_open = true
	queue_redraw()

func close_container() -> void:
	if not container_open:
		return
	close_inventory()

func close_inventory() -> void:
	if not inventory_open:
		return
	_flush_cursor_stack()
	inventory_open = false
	container_open = false
	container_inventory = null
	queue_redraw()

func _flush_cursor_stack() -> void:
	if _is_empty_stack(cursor_stack):
		return
	if not drag_source.is_empty():
		_clear_drag()
		return
	if player_inventory != null:
		var remaining: int = player_inventory.add_item(String(cursor_stack.item), int(cursor_stack.count))
		if remaining <= 0:
			_clear_drag()
			return
		cursor_stack.count = remaining
	world_drop_requested.emit(cursor_stack.duplicate())
	_clear_drag()

func _make_label(pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_color_override("font_color", Color8(244, 231, 192))
	label.add_theme_font_size_override("font_size", 13)
	add_child(label)
	return label

func set_hud_state(state: Dictionary) -> void:
	var signature := _state_signature(state)
	if signature == hud_state_signature:
		hud_state = state
		return
	hud_state_signature = signature
	hud_state = state
	health_label.text = "HP %d/%d  Drill %d%%" % [state.health_current, state.health_max, roundi(float(state.drill_heat) * 100.0)]
	depth_label.text = String(state.depth_label)
	target_label.text = "Target: %s" % String(state.target_name)
	light_label.text = "Light %d%%" % roundi(float(state.light) * 100.0)
	inventory_label.text = "Active: %s" % String(state.get("active_item", "Empty"))
	queue_redraw()

func _state_signature(state: Dictionary) -> String:
	var hotbar_parts: Array[String] = []
	for slot in state.get("hotbar_slots", []):
		hotbar_parts.append("%s:%d" % [String(slot.get("item", "")), int(slot.get("count", 0))])
	var heart_parts: Array[String] = []
	for heart in state.get("heart_states", []):
		heart_parts.append(String(heart))
	return "%d|%d|%d|%s|%s|%d|%d|%d|%s|%s" % [
		int(state.get("health_current", 0)),
		int(state.get("health_max", 0)),
		roundi(float(state.get("drill_heat", 0.0)) * 100.0),
		String(state.get("depth_label", "")),
		String(state.get("target_name", "")),
		roundi(float(state.get("light", 0.0)) * 100.0),
		roundi(float(state.get("danger", 0.0)) * 100.0),
		int(state.get("selected_hotbar_index", 0)),
		String(state.get("active_item", "")),
		";".join(hotbar_parts) + "|" + ";".join(heart_parts)
	]

func _draw() -> void:
	var size := get_viewport_rect().size
	var danger := float(hud_state.get("danger", 0.0))
	if danger > 0.05:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.1, 0.08, danger * 0.22), false, 14.0)
	_panel(Rect2(12, 10, 260, 58))
	_panel(Rect2(12, 638, 320, 58))
	_panel(Rect2(size.x - 180, 10, 160, 44))
	_draw_god_mode_button()
	_draw_hearts(Vector2(20, 16))
	_draw_hotbar()
	if inventory_open:
		_draw_inventory_panel(_player_panel_rect(), "Inventory", player_inventory, PLAYER_COLS, "player")
	if container_open:
		_draw_inventory_panel(_container_panel_rect(), container_title, container_inventory, CONTAINER_COLS, "container")
	if inventory_open:
		_draw_cursor_stack()
	_draw_tooltip()

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

## ── Terminal console (minimal — plain grey LineEdit rectangle) ───────────────

func _build_terminal() -> void:
	## Create a plain LineEdit that sits just above the hotbar.
	## Godot's default theme renders it as a grey rectangle — exactly what we want.
	_terminal_line_edit = LineEdit.new()
	_terminal_line_edit.visible = false
	_terminal_line_edit.placeholder_text = "command  (help for list, ESC to close)"
	_terminal_line_edit.mouse_filter = MOUSE_FILTER_STOP
	_terminal_line_edit.text_submitted.connect(_on_terminal_submitted)
	add_child(_terminal_line_edit)

func open_terminal() -> void:
	TerminalSystem.is_open = true
	var vsize := get_viewport_rect().size
	var y := vsize.y - SLOT_SIZE - HOTBAR_MARGIN_BOTTOM - TERMINAL_H - 6.0
	_terminal_line_edit.position = Vector2(0.0, y)
	_terminal_line_edit.size    = Vector2(vsize.x, TERMINAL_H)
	_terminal_line_edit.visible = true
	_terminal_line_edit.clear()
	_terminal_line_edit.grab_focus()

func close_terminal() -> void:
	TerminalSystem.is_open = false
	_terminal_line_edit.visible = false
	_terminal_line_edit.release_focus()
	queue_redraw()

func toggle_terminal() -> void:
	if TerminalSystem.is_open:
		close_terminal()
	else:
		open_terminal()

func _on_terminal_submitted(text: String) -> void:
	text = text.strip_edges()
	terminal_command.emit(text)
	close_terminal()

## ─────────────────────────────────────────────────────────────────────────────

func _god_mode_button_rect() -> Rect2:
	var vw := get_viewport_rect().size.x
	return Rect2(vw - GOD_BTN_W - GOD_BTN_MARGIN_RIGHT, GOD_BTN_TOP, GOD_BTN_W, GOD_BTN_H)

func _draw_god_mode_button() -> void:
	var on := DebugSystem.god_mode_enabled
	var rect := _god_mode_button_rect()
	# Background: bright gold when on, dark panel when off.
	var bg := Color8(200, 158, 12, 220) if on else Color(0.05, 0.06, 0.09, 0.82)
	var border := Color8(255, 214, 80) if on else Color8(91, 100, 107)
	var text_col := Color8(18, 14, 4) if on else Color8(244, 231, 192)
	draw_rect(rect, bg, true)
	draw_rect(rect, border, false, 2.0)
	var font := get_theme_default_font()
	if font == null:
		return
	var label := "GOD MODE  ON" if on else "GOD MODE  OFF"
	# pos.x must be the LEFT edge of the centering window; width covers the
	# full button so draw_string centres the text inside the rect correctly.
	draw_string(font, Vector2(rect.position.x, rect.position.y + 18.0),
		label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, text_col)

func _panel(rect: Rect2) -> void:
	draw_rect(rect, Color(0.05, 0.06, 0.09, 0.78), true)
	draw_rect(rect, Color8(91, 100, 107), false, 2.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if inventory_open:
			if event.pressed:
				if _handle_mouse_press(event.position):
					queue_redraw()
					return
			else:
				if _handle_mouse_release(event.position):
					queue_redraw()
					return
		if event.pressed:
			if _god_mode_button_rect().has_point(event.position):
				DebugSystem.toggle_god_mode()
				queue_redraw()
				accept_event()
				return
			var hotbar_index := _hotbar_slot_at(event.position)
			if hotbar_index >= 0:
				hotbar_slot_selected.emit(hotbar_index)
				accept_event()
	elif event is InputEventMouseMotion:
		queue_redraw()

func _handle_mouse_press(point: Vector2) -> bool:
	var hit := _slot_at(point)
	if hit.is_empty() or not _is_empty_stack(cursor_stack):
		return false
	var stack: Dictionary = _get_hit_stack(hit)
	if _is_empty_stack(stack):
		return false
	_begin_drag(hit)
	cursor_stack = stack.duplicate()
	accept_event()
	return true

func _handle_mouse_release(point: Vector2) -> bool:
	if _is_empty_stack(cursor_stack):
		return false
	var hit := _slot_at(point)
	if hit.is_empty():
		var dropped_stack := _take_hit_stack(drag_source) if not drag_source.is_empty() else cursor_stack.duplicate()
		if not _is_empty_stack(dropped_stack):
			world_drop_requested.emit(dropped_stack)
		_clear_drag()
		accept_event()
		return true
	if not drag_source.is_empty() and _is_same_hit(hit, drag_source):
		_clear_drag()
		accept_event()
		return true
	var moving_stack := _take_hit_stack(drag_source) if not drag_source.is_empty() else cursor_stack.duplicate()
	var remainder := _place_hit_stack(hit, moving_stack)
	if not _is_empty_stack(remainder) and not drag_source.is_empty():
		var unplaced := _place_hit_stack(drag_source, remainder)
		if not _is_empty_stack(unplaced):
			world_drop_requested.emit(unplaced)
	elif not _is_empty_stack(remainder):
		world_drop_requested.emit(remainder)
	_clear_drag()
	accept_event()
	return true

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

func _draw_inventory_panel(rect: Rect2, title: String, inventory, cols: int, panel_id: String) -> void:
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
		_draw_stack(_display_stack_for_slot(panel_id, index, inventory.get_slot(index)), slot_rect)

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
	if inventory_open and player_inventory != null:
		var hit := _slot_at_panel(point, _player_panel_rect(), player_inventory, PLAYER_COLS, "player")
		if not hit.is_empty():
			return hit
		var hotbar_index := _hotbar_slot_at(point)
		if hotbar_index >= 0:
			return {"panel": "hotbar", "index": hotbar_index, "inventory": player_inventory, "rect": _hotbar_slot_rect(hotbar_index)}
	if container_open and container_inventory != null:
		var hit := _slot_at_panel(point, _container_panel_rect(), container_inventory, CONTAINER_COLS, "container")
		if not hit.is_empty():
			return hit
	return {}

func _get_hit_stack(hit: Dictionary) -> Dictionary:
	var inventory = hit.inventory
	var index := int(hit.index)
	if String(hit.get("panel", "")) == "hotbar":
		return inventory.get_hotbar_slot(index)
	return inventory.get_slot(index)

func _take_hit_stack(hit: Dictionary) -> Dictionary:
	var inventory = hit.inventory
	var index := int(hit.index)
	if String(hit.get("panel", "")) == "hotbar":
		return inventory.take_hotbar_slot(index)
	return inventory.take_slot(index)

func _place_hit_stack(hit: Dictionary, stack: Dictionary) -> Dictionary:
	var inventory = hit.inventory
	var index := int(hit.index)
	if String(hit.get("panel", "")) == "hotbar":
		return inventory.place_hotbar_stack(index, stack)
	return inventory.place_stack(index, stack)

func _is_same_hit(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	return String(a.get("panel", "")) == String(b.get("panel", "")) and int(a.get("index", -1)) == int(b.get("index", -2)) and a.get("inventory") == b.get("inventory")

func _display_stack_for_slot(panel_id: String, index: int, stack: Dictionary) -> Dictionary:
	if not _is_empty_stack(cursor_stack) and not drag_source.is_empty():
		if String(drag_source.get("panel", "")) == panel_id and int(drag_source.get("index", -1)) == index:
			return _empty_stack()
	return stack

func _clear_drag() -> void:
	var was_dragging := not drag_source.is_empty() or not _is_empty_stack(cursor_stack)
	cursor_stack = _empty_stack()
	drag_source = {}
	if was_dragging:
		drag_state_changed.emit(false)

func _begin_drag(source_hit: Dictionary) -> void:
	drag_source = source_hit
	drag_state_changed.emit(true)

func is_dragging_stack() -> bool:
	return not _is_empty_stack(cursor_stack)

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

func _draw_hotbar() -> void:
	var slots: Array = hud_state.get("hotbar_slots", [])
	var selected := int(hud_state.get("selected_hotbar_index", 0))
	var rect := _hotbar_rect()
	for index in range(HOTBAR_SIZE):
		var slot_rect := _hotbar_slot_rect(index)
		draw_rect(slot_rect, Color(0.055, 0.052, 0.065, 0.92), true)
		draw_rect(slot_rect, Color8(91, 100, 107), false, 1.0)
		if index == selected:
			_draw_selected_hotbar_brackets(slot_rect)
		if player_inventory != null and player_inventory.has_method("get_hotbar_slot"):
			_draw_stack(_display_stack_for_slot("hotbar", index, player_inventory.get_hotbar_slot(index)), slot_rect)
		elif index < slots.size():
			_draw_stack(_display_stack_for_slot("hotbar", index, slots[index]), slot_rect)
		var font := get_theme_default_font()
		if font != null:
			draw_string(font, slot_rect.position + Vector2(4, 10), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color8(190, 176, 137))
	draw_rect(rect.grow(3.0), Color(0.02, 0.022, 0.03, 0.4), false, 1.0)

func _draw_selected_hotbar_brackets(slot_rect: Rect2) -> void:
	var color := Color8(240, 168, 79)
	var length := 9.0
	var width := 2.0
	draw_line(slot_rect.position, slot_rect.position + Vector2(length, 0), color, width)
	draw_line(slot_rect.position, slot_rect.position + Vector2(0, length), color, width)
	draw_line(slot_rect.position + Vector2(slot_rect.size.x, 0), slot_rect.position + Vector2(slot_rect.size.x - length, 0), color, width)
	draw_line(slot_rect.position + Vector2(slot_rect.size.x, 0), slot_rect.position + Vector2(slot_rect.size.x, length), color, width)
	draw_line(slot_rect.position + Vector2(0, slot_rect.size.y), slot_rect.position + Vector2(length, slot_rect.size.y), color, width)
	draw_line(slot_rect.position + Vector2(0, slot_rect.size.y), slot_rect.position + Vector2(0, slot_rect.size.y - length), color, width)
	draw_line(slot_rect.position + slot_rect.size, slot_rect.position + slot_rect.size - Vector2(length, 0), color, width)
	draw_line(slot_rect.position + slot_rect.size, slot_rect.position + slot_rect.size - Vector2(0, length), color, width)

func _hotbar_rect() -> Rect2:
	var width := HOTBAR_SIZE * SLOT_SIZE + (HOTBAR_SIZE - 1) * SLOT_GAP
	var origin := Vector2(
		(get_viewport_rect().size.x - width) * 0.5,
		get_viewport_rect().size.y - SLOT_SIZE - HOTBAR_MARGIN_BOTTOM
	)
	return Rect2(origin, Vector2(width, SLOT_SIZE))

func _hotbar_slot_rect(index: int) -> Rect2:
	var rect := _hotbar_rect()
	return Rect2(rect.position + Vector2(index * (SLOT_SIZE + SLOT_GAP), 0), Vector2(SLOT_SIZE, SLOT_SIZE))

func _hotbar_slot_at(point: Vector2) -> int:
	if not _hotbar_rect().has_point(point):
		return -1
	for index in range(HOTBAR_SIZE):
		if _hotbar_slot_rect(index).has_point(point):
			return index
	return -1

func _draw_cursor_stack() -> void:
	if _is_empty_stack(cursor_stack):
		return
	_draw_stack(cursor_stack, Rect2(get_local_mouse_position() - Vector2(18, 18), Vector2(SLOT_SIZE, SLOT_SIZE)))

func _empty_stack() -> Dictionary:
	return {"item": "", "count": 0, "stack_cap": 99}

func _is_empty_stack(stack: Dictionary) -> bool:
	return String(stack.get("item", "")) == "" or int(stack.get("count", 0)) <= 0

## ── Item tooltip ─────────────────────────────────────────────────────────────

func _item_id_at(point: Vector2) -> String:
	var hotbar_idx := _hotbar_slot_at(point)
	if hotbar_idx >= 0:
		if player_inventory != null and player_inventory.has_method("get_hotbar_slot"):
			return String(player_inventory.get_hotbar_slot(hotbar_idx).get("item", ""))
		var slots: Array = hud_state.get("hotbar_slots", [])
		if hotbar_idx < slots.size():
			return String(slots[hotbar_idx].get("item", ""))
		return ""
	if inventory_open:
		var hit := _slot_at(point)
		if not hit.is_empty():
			return String(_get_hit_stack(hit).get("item", ""))
	return ""

func _draw_tooltip() -> void:
	if TerminalSystem.is_open or not _is_empty_stack(cursor_stack):
		return
	var mouse_pos := get_local_mouse_position()
	var item_id := _item_id_at(mouse_pos)
	if item_id == "":
		return

	var def := ItemCatalog.get_item(item_id)
	var item_name := String(def.get("name", item_id.replace("_", " ").capitalize()))
	var rarity := String(def.get("rarity", "common"))
	var category := String(def.get("category", ""))
	var desc := String(def.get("desc", ""))

	var font := get_theme_default_font()
	if font == null:
		return

	const PAD := 10.0
	const NAME_SZ := 14
	const BODY_SZ := 11
	const LINE_GAP := 3.0

	# Build lines: [{text, color, size}]
	var lines: Array[Dictionary] = []
	lines.append({"text": item_name, "color": ItemCatalog.rarity_color(rarity), "size": NAME_SZ})
	if rarity != "common":
		var dim := ItemCatalog.rarity_color(rarity).lerp(Color8(140, 140, 140), 0.5)
		lines.append({"text": rarity.capitalize(), "color": dim, "size": BODY_SZ})
	if category != "":
		lines.append({"text": category.replace("_", " ").capitalize(), "color": Color8(160, 160, 160), "size": BODY_SZ})
	if desc != "":
		lines.append({"text": "", "color": Color.WHITE, "size": 5})
		for line in desc.split("\n"):
			lines.append({"text": line, "color": Color8(210, 210, 210), "size": BODY_SZ})

	# Measure required width
	var max_w := 0.0
	for ld in lines:
		if String(ld.text) == "":
			continue
		var w := font.get_string_size(String(ld.text), HORIZONTAL_ALIGNMENT_LEFT, -1, int(ld.size)).x
		if w > max_w:
			max_w = w
	var panel_w := max_w + PAD * 2.0
	var panel_h := PAD * 2.0
	for ld in lines:
		panel_h += float(int(ld.size)) + LINE_GAP

	# Position: right of cursor, above; clamped to viewport
	var vsize := get_viewport_rect().size
	var px := mouse_pos.x + 18.0
	var py := mouse_pos.y - panel_h - 12.0
	px = clampf(px, 4.0, vsize.x - panel_w - 4.0)
	py = clampf(py, 4.0, vsize.y - panel_h - 4.0)

	var panel_rect := Rect2(Vector2(px, py), Vector2(panel_w, panel_h))

	# Shadow
	draw_rect(Rect2(panel_rect.position + Vector2(3.0, 3.0), panel_rect.size), Color(0, 0, 0, 0.4), true)
	# Background
	draw_rect(panel_rect, Color(0.04, 0.04, 0.09, 0.96), true)
	# Border (tinted by rarity)
	var border := ItemCatalog.rarity_color(rarity)
	border.a = 0.80
	draw_rect(panel_rect, border, false, 1.5)

	# Draw text lines
	var cy := py + PAD
	for ld in lines:
		var sz := int(ld.size)
		if String(ld.text) == "":
			cy += float(sz) + LINE_GAP
			continue
		draw_string(font, Vector2(px + PAD, cy + sz), String(ld.text),
			HORIZONTAL_ALIGNMENT_LEFT, -1, sz, ld.color)
		cy += float(sz) + LINE_GAP
