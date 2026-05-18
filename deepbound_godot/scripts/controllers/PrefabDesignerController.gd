extends Control
class_name PrefabDesignerController

const PrefabTemplateRegistry = preload("res://scripts/systems/PrefabTemplateRegistry.gd")
const PrefabTemplateImporter = preload("res://scripts/systems/PrefabTemplateImporter.gd")
const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")
const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")
const BackgroundCatalog = preload("res://scripts/catalogs/BackgroundCatalog.gd")
const BandCatalog = preload("res://scripts/catalogs/BandCatalog.gd")

const GRID_TILE_SIZE := 16
const MAX_CANVAS_SIZE := 256
const LAYERS := ["backgrounds", "foreground", "props", "spawns"]
const TOOL_PENCIL := "pencil"
const TOOL_ERASER := "eraser"
const TOOL_BUCKET := "bucket"
const TOOL_SELECT := "select"

class DesignerCanvasView:
	extends Control

	var designer: PrefabDesignerController
	var zoom := 2.0
	var pan := Vector2(48, 48)
	var panning := false
	var pan_last := Vector2.ZERO
	var selecting := false
	var selection_start := Vector2i.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL

	func _gui_input(event: InputEvent) -> void:
		if designer == null:
			return
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				_zoom_at(event.position, 1.12)
				accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				_zoom_at(event.position, 1.0 / 1.12)
				accept_event()
			elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
				panning = event.pressed
				pan_last = event.position
				accept_event()
			elif event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					var tile := screen_to_tile(event.position)
					if designer.active_tool == TOOL_SELECT:
						selecting = true
						selection_start = tile
						designer.select_region(Rect2i(tile, Vector2i.ONE))
					else:
						designer.apply_tool_at(tile)
					accept_event()
				else:
					selecting = false
					accept_event()
		elif event is InputEventMouseMotion:
			if panning:
				pan += event.position - pan_last
				pan_last = event.position
				queue_redraw()
				accept_event()
			elif selecting:
				var tile := screen_to_tile(event.position)
				var min_tile := Vector2i(mini(selection_start.x, tile.x), mini(selection_start.y, tile.y))
				var max_tile := Vector2i(maxi(selection_start.x, tile.x), maxi(selection_start.y, tile.y))
				designer.select_region(Rect2i(min_tile, max_tile - min_tile + Vector2i.ONE))
				accept_event()

	func screen_to_tile(point: Vector2) -> Vector2i:
		var local := (point - pan) / zoom
		return Vector2i(floori(local.x / GRID_TILE_SIZE), floori(local.y / GRID_TILE_SIZE))

	func tile_rect(tile: Vector2i, size_tiles := Vector2i.ONE) -> Rect2:
		return Rect2(pan + Vector2(tile * GRID_TILE_SIZE) * zoom, Vector2(size_tiles * GRID_TILE_SIZE) * zoom)

	func _zoom_at(point: Vector2, factor: float) -> void:
		var old_zoom := zoom
		zoom = clampf(zoom * factor, 0.35, 8.0)
		var world_point := (point - pan) / old_zoom
		pan = point - world_point * zoom
		queue_redraw()

	func _draw() -> void:
		if designer == null:
			return
		var canvas_rect := Rect2(pan, Vector2(designer.canvas_size * GRID_TILE_SIZE) * zoom)
		draw_rect(canvas_rect, Color8(12, 14, 19), true)
		_draw_layers()
		_draw_grid(canvas_rect)
		_draw_anchor()
		_draw_selection()

	func _draw_layers() -> void:
		if designer.layer_visible.get("backgrounds", true):
			for tile in designer.backgrounds.keys():
				var background_id := String(designer.backgrounds[tile])
				if BackgroundCatalog.is_empty(background_id):
					continue
				var texture := TextureFactory.make_background_texture(background_id, BackgroundCatalog.get_background(background_id))
				if texture != null:
					draw_texture_rect(texture, tile_rect(tile), false, Color(1, 1, 1, 0.78))
		if designer.layer_visible.get("foreground", true):
			for tile in designer.foreground.keys():
				var tile_id := String(designer.foreground[tile])
				if tile_id == "air":
					draw_rect(tile_rect(tile).grow(-1), Color(0.25, 0.5, 0.9, 0.26), true)
					continue
				var texture := TextureFactory.make_tile_texture(tile_id, TileCatalog.get_tile(tile_id))
				if texture != null:
					draw_texture_rect(texture, tile_rect(tile), false)
		if designer.layer_visible.get("props", true):
			for tile in designer.props.keys():
				var prop: Dictionary = designer.props[tile]
				var prop_id := String(prop.id)
				var texture := TextureFactory.make_prop_texture(prop_id)
				var size := designer._entry_size(prop)
				if texture != null:
					draw_texture_rect(texture, tile_rect(tile, size), false, Color(1, 1, 1, float(prop.get("alpha", 1.0))))
				else:
					draw_rect(tile_rect(tile, size).grow(-2), Color8(202, 139, 68, 180), true)
		if designer.layer_visible.get("spawns", true):
			for tile in designer.spawns.keys():
				var rect := tile_rect(tile).grow(-2)
				draw_rect(rect, Color(0.78, 0.14, 0.14, 0.65), true)
				draw_rect(rect, Color8(255, 224, 161), false, maxf(1.0, zoom))

	func _draw_grid(canvas_rect: Rect2) -> void:
		var line_color := Color(0.45, 0.50, 0.56, 0.28)
		var step := GRID_TILE_SIZE * zoom
		for x in range(designer.canvas_size.x + 1):
			var px := pan.x + float(x) * step
			draw_line(Vector2(px, canvas_rect.position.y), Vector2(px, canvas_rect.position.y + canvas_rect.size.y), line_color, 1.0)
		for y in range(designer.canvas_size.y + 1):
			var py := pan.y + float(y) * step
			draw_line(Vector2(canvas_rect.position.x, py), Vector2(canvas_rect.position.x + canvas_rect.size.x, py), line_color, 1.0)
		draw_rect(canvas_rect, Color8(182, 194, 190), false, 2.0)

	func _draw_anchor() -> void:
		var center := tile_rect(designer.anchor_tile).get_center()
		draw_line(center + Vector2(-8, 0) * zoom, center + Vector2(8, 0) * zoom, Color8(85, 214, 210), 2.0)
		draw_line(center + Vector2(0, -8) * zoom, center + Vector2(0, 8) * zoom, Color8(85, 214, 210), 2.0)

	func _draw_selection() -> void:
		if designer.selection_rect.size == Vector2i.ZERO:
			return
		var rect := tile_rect(designer.selection_rect.position, designer.selection_rect.size)
		draw_rect(rect, Color(0.35, 0.78, 1.0, 0.16), true)
		draw_rect(rect, Color8(112, 206, 177), false, 2.0)

var canvas_size := Vector2i(32, 24)
var anchor_tile := Vector2i(16, 23)
var template_id := "new_template"
var template_name := "New Template"
var rarity := 1.0
var enabled := true
var allow_mirror_x := false
var allow_mirror_y := false
var allow_rotation := false
var tags: Array[String] = []
var selected_bands: Array[String] = ["standard_caverns"]
var foreground: Dictionary = {}
var backgrounds: Dictionary = {}
var props: Dictionary = {}
var spawns: Dictionary = {}
var layer_visible := {"backgrounds": true, "foreground": true, "props": true, "spawns": true}
var active_layer := "foreground"
var active_tool := TOOL_PENCIL
var selected_asset := {"layer": "foreground", "kind": "foreground", "id": "loose_dirt", "name": "Loose Dirt"}
var selection_rect := Rect2i(Vector2i.ZERO, Vector2i.ZERO)
var clipboard := {}

var canvas_view: DesignerCanvasView
var palette_search: LineEdit
var palette_list: ItemList
var path_edit: LineEdit
var id_edit: LineEdit
var name_edit: LineEdit
var tags_edit: LineEdit
var width_spin: SpinBox
var height_spin: SpinBox
var anchor_x_spin: SpinBox
var anchor_y_spin: SpinBox
var rarity_spin: SpinBox
var status_label: Label
var band_checks: Dictionary = {}
var mirror_x_check: CheckBox
var mirror_y_check: CheckBox
var rotation_check: CheckBox
var enabled_check: CheckBox

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	PrefabTemplateImporter.ensure_builtin_goblin_template()
	_build_ui()
	_refresh_palette()
	_sync_controls_from_state()

func new_template(width: int, height: int) -> void:
	canvas_size = Vector2i(clampi(width, 1, MAX_CANVAS_SIZE), clampi(height, 1, MAX_CANVAS_SIZE))
	anchor_tile = Vector2i(canvas_size.x / 2, canvas_size.y - 1)
	foreground.clear()
	backgrounds.clear()
	props.clear()
	spawns.clear()
	selection_rect = Rect2i(Vector2i.ZERO, Vector2i.ZERO)
	_sync_controls_from_state()
	_redraw_canvas()

func resize_canvas(width: int, height: int) -> void:
	canvas_size = Vector2i(clampi(width, 1, MAX_CANVAS_SIZE), clampi(height, 1, MAX_CANVAS_SIZE))
	anchor_tile = _clamp_tile(anchor_tile)
	_prune_out_of_bounds()
	_sync_controls_from_state()
	_redraw_canvas()

func set_active_layer(layer_name: String) -> void:
	if layer_name in LAYERS:
		active_layer = layer_name

func set_active_tool(tool_name: String) -> void:
	if tool_name in [TOOL_PENCIL, TOOL_ERASER, TOOL_BUCKET, TOOL_SELECT]:
		active_tool = tool_name

func select_palette_asset(entry: Dictionary) -> void:
	selected_asset = entry.duplicate(true)
	active_layer = String(entry.get("layer", active_layer))

func apply_tool_at(tile: Vector2i) -> void:
	if not _tile_in_canvas(tile):
		return
	if active_tool != TOOL_SELECT and not bool(layer_visible.get(active_layer, true)):
		return
	match active_tool:
		TOOL_PENCIL:
			apply_pencil(tile)
		TOOL_ERASER:
			erase_at(tile)
		TOOL_BUCKET:
			bucket_fill(tile)
	_redraw_canvas()

func apply_pencil(tile: Vector2i) -> void:
	if not _tile_in_canvas(tile):
		return
	match active_layer:
		"foreground":
			foreground[tile] = String(selected_asset.get("id", "air"))
		"backgrounds":
			backgrounds[tile] = String(selected_asset.get("id", BackgroundCatalog.EMPTY_ID))
		"props":
			props[tile] = {
				"x": tile.x,
				"y": tile.y,
				"id": String(selected_asset.get("id", "")),
				"kind": String(selected_asset.get("kind", "decoration")),
				"size": [1, 1],
				"offset": [0, 0],
				"draw_layer": "foreground",
				"alpha": 1.0,
			}
		"spawns":
			spawns[tile] = {"x": tile.x, "y": tile.y, "enemy_id": String(selected_asset.get("id", "cave_skitter"))}

func erase_at(tile: Vector2i) -> void:
	_layer_dict(active_layer).erase(tile)

func bucket_fill(start_tile: Vector2i) -> void:
	if not _tile_in_canvas(start_tile):
		return
	var layer := _layer_dict(active_layer)
	var replacement = _selected_layer_value()
	var target = layer.get(start_tile, null)
	if target == replacement:
		return
	var visited := {}
	var queue: Array[Vector2i] = [start_tile]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if visited.has(current) or not _tile_in_canvas(current):
			continue
		if layer.get(current, null) != target:
			continue
		visited[current] = true
		layer[current] = replacement
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			queue.append(current + offset)

func select_region(rect: Rect2i) -> void:
	var clamped_pos := _clamp_tile(rect.position)
	var end := _clamp_tile(rect.position + rect.size - Vector2i.ONE)
	selection_rect = Rect2i(clamped_pos, end - clamped_pos + Vector2i.ONE)
	_redraw_canvas()

func copy_selection() -> Dictionary:
	if selection_rect.size == Vector2i.ZERO:
		return {}
	var data := {"size": {"x": selection_rect.size.x, "y": selection_rect.size.y}, "foreground": [], "backgrounds": [], "props": [], "spawns": []}
	for tile in foreground.keys():
		if _rect_contains_tile(selection_rect, tile):
			data.foreground.append({"x": tile.x - selection_rect.position.x, "y": tile.y - selection_rect.position.y, "id": String(foreground[tile])})
	for tile in backgrounds.keys():
		if _rect_contains_tile(selection_rect, tile):
			data.backgrounds.append({"x": tile.x - selection_rect.position.x, "y": tile.y - selection_rect.position.y, "id": String(backgrounds[tile])})
	for tile in props.keys():
		if _rect_contains_tile(selection_rect, tile):
			var entry: Dictionary = Dictionary(props[tile]).duplicate(true)
			entry.x = tile.x - selection_rect.position.x
			entry.y = tile.y - selection_rect.position.y
			data.props.append(entry)
	for tile in spawns.keys():
		if _rect_contains_tile(selection_rect, tile):
			var entry: Dictionary = Dictionary(spawns[tile]).duplicate(true)
			entry.x = tile.x - selection_rect.position.x
			entry.y = tile.y - selection_rect.position.y
			data.spawns.append(entry)
	clipboard = data
	return data

func delete_selection() -> void:
	if selection_rect.size == Vector2i.ZERO:
		return
	for layer in [foreground, backgrounds, props, spawns]:
		for tile in layer.keys():
			if _rect_contains_tile(selection_rect, tile):
				layer.erase(tile)
	_redraw_canvas()

func paste_selection(target: Vector2i) -> void:
	if clipboard.is_empty():
		return
	_paste_clipboard(clipboard, target)
	_redraw_canvas()

func move_selection(delta: Vector2i) -> void:
	if selection_rect.size == Vector2i.ZERO:
		return
	var data := copy_selection()
	delete_selection()
	_paste_clipboard(data, selection_rect.position + delta)
	select_region(Rect2i(selection_rect.position + delta, selection_rect.size))

func set_template_anchor(tile: Vector2i) -> void:
	anchor_tile = _clamp_tile(tile)
	_sync_controls_from_state()
	_redraw_canvas()

func to_template() -> Dictionary:
	_pull_metadata_from_controls()
	var foreground_entries: Array[Dictionary] = []
	for tile in foreground.keys():
		foreground_entries.append({"x": tile.x, "y": tile.y, "id": String(foreground[tile])})
	var background_entries: Array[Dictionary] = []
	for tile in backgrounds.keys():
		background_entries.append({"x": tile.x, "y": tile.y, "id": String(backgrounds[tile])})
	var prop_entries: Array[Dictionary] = []
	for tile in props.keys():
		var entry: Dictionary = Dictionary(props[tile]).duplicate(true)
		entry.x = tile.x
		entry.y = tile.y
		prop_entries.append(entry)
	var spawn_entries: Array[Dictionary] = []
	for tile in spawns.keys():
		var entry: Dictionary = Dictionary(spawns[tile]).duplicate(true)
		entry.x = tile.x
		entry.y = tile.y
		spawn_entries.append(entry)
	return {
		"schema_version": PrefabTemplateRegistry.SCHEMA_VERSION,
		"id": template_id,
		"name": template_name,
		"size": {"x": canvas_size.x, "y": canvas_size.y},
		"anchor": {"x": anchor_tile.x, "y": anchor_tile.y},
		"metadata": {
			"bands": selected_bands,
			"rarity": rarity,
			"enabled": enabled,
			"allow_mirror_x": allow_mirror_x,
			"allow_mirror_y": allow_mirror_y,
			"allow_rotation": allow_rotation,
			"tags": tags,
			"spawn_region_size": {"x": maxi(PrefabTemplateRegistry.DEFAULT_REGION_SIZE.x, canvas_size.x + 16), "y": maxi(PrefabTemplateRegistry.DEFAULT_REGION_SIZE.y, canvas_size.y + 16)},
			"structure_type": template_id,
		},
		"layers": {
			"foreground": foreground_entries,
			"backgrounds": background_entries,
			"props": prop_entries,
			"spawns": spawn_entries,
		},
	}

func load_template_data(template: Dictionary) -> bool:
	var normalized := PrefabTemplateRegistry.validate_template(template)
	if normalized.is_empty():
		_set_status("Template failed validation.")
		return false
	template_id = String(normalized.id)
	template_name = String(normalized.name)
	canvas_size = _parse_vec(normalized.size, canvas_size)
	anchor_tile = _parse_vec(normalized.anchor, anchor_tile)
	var metadata: Dictionary = normalized.metadata
	selected_bands.assign(metadata.bands)
	rarity = float(metadata.rarity)
	enabled = bool(metadata.enabled)
	allow_mirror_x = bool(metadata.allow_mirror_x)
	allow_mirror_y = bool(metadata.allow_mirror_y)
	allow_rotation = bool(metadata.allow_rotation)
	tags.assign(metadata.tags)
	foreground.clear()
	backgrounds.clear()
	props.clear()
	spawns.clear()
	for entry in normalized.layers.foreground:
		foreground[Vector2i(int(entry.x), int(entry.y))] = String(entry.id)
	for entry in normalized.layers.backgrounds:
		backgrounds[Vector2i(int(entry.x), int(entry.y))] = String(entry.id)
	for entry in normalized.layers.props:
		props[Vector2i(int(entry.x), int(entry.y))] = Dictionary(entry).duplicate(true)
	for entry in normalized.layers.spawns:
		spawns[Vector2i(int(entry.x), int(entry.y))] = Dictionary(entry).duplicate(true)
	_sync_controls_from_state()
	_redraw_canvas()
	_set_status("Loaded %s." % template_id)
	return true

func save_to_path(path: String) -> bool:
	var ok := PrefabTemplateRegistry.save_template(to_template(), path)
	_set_status("Saved %s." % path if ok else "Save failed.")
	return ok

func load_from_path(path: String) -> bool:
	var template := PrefabTemplateRegistry.load_template(path)
	if template.is_empty():
		_set_status("Load failed.")
		return false
	return load_template_data(template)

func reimport_current_village(overwrite := true) -> bool:
	var ok := PrefabTemplateImporter.import_current_goblin_village(PrefabTemplateImporter.DEFAULT_GOBLIN_TEMPLATE_PATH, overwrite)
	if ok:
		load_from_path(PrefabTemplateImporter.DEFAULT_GOBLIN_TEMPLATE_PATH)
	_set_status("Reimported goblin village." if ok else "Reimport failed.")
	return ok

func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	root.add_child(left)
	_add_label(left, "Assets")
	palette_search = LineEdit.new()
	palette_search.placeholder_text = "Search assets"
	palette_search.text_changed.connect(func(_text): _refresh_palette())
	left.add_child(palette_search)
	palette_list = ItemList.new()
	palette_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_list.item_selected.connect(_on_palette_selected)
	left.add_child(palette_list)

	var tool_row := HBoxContainer.new()
	left.add_child(tool_row)
	for tool_name in [TOOL_PENCIL, TOOL_ERASER, TOOL_BUCKET, TOOL_SELECT]:
		var button := Button.new()
		button.text = tool_name.capitalize()
		button.pressed.connect(func(name: String = tool_name): set_active_tool(name))
		tool_row.add_child(button)
	for layer_name in LAYERS:
		var check := CheckBox.new()
		check.text = layer_name.capitalize()
		check.button_pressed = true
		check.toggled.connect(func(pressed: bool, name: String = layer_name):
			layer_visible[name] = pressed
			_redraw_canvas()
		)
		left.add_child(check)
	var selection_row := HBoxContainer.new()
	left.add_child(selection_row)
	_add_button(selection_row, "Copy", func(): copy_selection())
	_add_button(selection_row, "Paste", func(): paste_selection(selection_rect.position))
	_add_button(selection_row, "Delete", func(): delete_selection())
	var move_row := HBoxContainer.new()
	left.add_child(move_row)
	_add_button(move_row, "Left", func(): move_selection(Vector2i.LEFT))
	_add_button(move_row, "Up", func(): move_selection(Vector2i.UP))
	_add_button(move_row, "Down", func(): move_selection(Vector2i.DOWN))
	_add_button(move_row, "Right", func(): move_selection(Vector2i.RIGHT))

	canvas_view = DesignerCanvasView.new()
	canvas_view.designer = self
	canvas_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(canvas_view)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	root.add_child(right)
	_add_label(right, "Template")
	path_edit = LineEdit.new()
	path_edit.text = "user://templates/new_template.json"
	right.add_child(path_edit)
	var file_row := HBoxContainer.new()
	right.add_child(file_row)
	_add_button(file_row, "Save", func(): save_to_path(path_edit.text))
	_add_button(file_row, "Load", func(): load_from_path(path_edit.text))
	_add_button(file_row, "Reimport", func(): reimport_current_village(true))
	id_edit = _add_line(right, "Id", template_id)
	name_edit = _add_line(right, "Name", template_name)
	tags_edit = _add_line(right, "Tags", ",".join(tags))
	var size_row := HBoxContainer.new()
	right.add_child(size_row)
	width_spin = _add_spin(size_row, "W", canvas_size.x, 1, MAX_CANVAS_SIZE)
	height_spin = _add_spin(size_row, "H", canvas_size.y, 1, MAX_CANVAS_SIZE)
	_add_button(right, "Resize Canvas", func(): resize_canvas(int(width_spin.value), int(height_spin.value)))
	var anchor_row := HBoxContainer.new()
	right.add_child(anchor_row)
	anchor_x_spin = _add_spin(anchor_row, "AX", anchor_tile.x, 0, MAX_CANVAS_SIZE - 1)
	anchor_y_spin = _add_spin(anchor_row, "AY", anchor_tile.y, 0, MAX_CANVAS_SIZE - 1)
	_add_button(right, "Set Anchor", func(): set_template_anchor(Vector2i(int(anchor_x_spin.value), int(anchor_y_spin.value))))
	_add_button(right, "Anchor Bottom Center", func(): set_template_anchor(Vector2i(canvas_size.x / 2, canvas_size.y - 1)))
	_add_button(right, "Anchor Top Left", func(): set_template_anchor(Vector2i.ZERO))
	rarity_spin = _add_spin(right, "Rarity", rarity, 0.0, 1.0, 0.01)
	enabled_check = _add_check(right, "Enabled", enabled)
	mirror_x_check = _add_check(right, "Mirror X", allow_mirror_x)
	mirror_y_check = _add_check(right, "Mirror Y", allow_mirror_y)
	rotation_check = _add_check(right, "Allow Rotation", allow_rotation)
	_add_label(right, "Bands")
	for band_id in BandCatalog.BANDS.keys():
		var check := _add_check(right, String(band_id), selected_bands.has(String(band_id)))
		band_checks[String(band_id)] = check
	status_label = _add_label(right, "")

func _refresh_palette() -> void:
	if palette_list == null:
		return
	var query := palette_search.text.to_lower() if palette_search != null else ""
	palette_list.clear()
	for entry in PrefabTemplateRegistry.get_palette_entries():
		var label := "%s  [%s]" % [String(entry.name), String(entry.layer)]
		if query != "" and label.to_lower().find(query) < 0 and String(entry.id).to_lower().find(query) < 0:
			continue
		var index := palette_list.add_item(label)
		palette_list.set_item_metadata(index, entry)

func _on_palette_selected(index: int) -> void:
	var entry: Dictionary = palette_list.get_item_metadata(index)
	select_palette_asset(entry)
	_set_status("Selected %s." % String(entry.name))

func _pull_metadata_from_controls() -> void:
	if id_edit != null:
		template_id = id_edit.text.strip_edges()
	if name_edit != null:
		template_name = name_edit.text.strip_edges()
	if tags_edit != null:
		tags.clear()
		for raw_tag in tags_edit.text.split(",", false):
			var tag := String(raw_tag).strip_edges()
			if tag != "":
				tags.append(tag)
	if rarity_spin != null:
		rarity = float(rarity_spin.value)
	if enabled_check != null:
		enabled = enabled_check.button_pressed
	if mirror_x_check != null:
		allow_mirror_x = mirror_x_check.button_pressed
	if mirror_y_check != null:
		allow_mirror_y = mirror_y_check.button_pressed
	if rotation_check != null:
		allow_rotation = rotation_check.button_pressed
	selected_bands.clear()
	for band_id in band_checks.keys():
		var check := band_checks[band_id] as CheckBox
		if check != null and check.button_pressed:
			selected_bands.append(String(band_id))
	if selected_bands.is_empty():
		selected_bands.append("standard_caverns")

func _sync_controls_from_state() -> void:
	if id_edit != null:
		id_edit.text = template_id
	if name_edit != null:
		name_edit.text = template_name
	if tags_edit != null:
		tags_edit.text = ",".join(tags)
	if width_spin != null:
		width_spin.value = canvas_size.x
	if height_spin != null:
		height_spin.value = canvas_size.y
	if anchor_x_spin != null:
		anchor_x_spin.max_value = canvas_size.x - 1
		anchor_x_spin.value = anchor_tile.x
	if anchor_y_spin != null:
		anchor_y_spin.max_value = canvas_size.y - 1
		anchor_y_spin.value = anchor_tile.y
	if rarity_spin != null:
		rarity_spin.value = rarity
	if enabled_check != null:
		enabled_check.button_pressed = enabled
	if mirror_x_check != null:
		mirror_x_check.button_pressed = allow_mirror_x
	if mirror_y_check != null:
		mirror_y_check.button_pressed = allow_mirror_y
	if rotation_check != null:
		rotation_check.button_pressed = allow_rotation
	for band_id in band_checks.keys():
		var check := band_checks[band_id] as CheckBox
		if check != null:
			check.button_pressed = selected_bands.has(String(band_id))

func _paste_clipboard(data: Dictionary, target: Vector2i) -> void:
	for entry in data.get("foreground", []):
		var tile := target + Vector2i(int(entry.x), int(entry.y))
		if _tile_in_canvas(tile):
			foreground[tile] = String(entry.id)
	for entry in data.get("backgrounds", []):
		var tile := target + Vector2i(int(entry.x), int(entry.y))
		if _tile_in_canvas(tile):
			backgrounds[tile] = String(entry.id)
	for entry in data.get("props", []):
		var tile := target + Vector2i(int(entry.x), int(entry.y))
		if _tile_in_canvas(tile):
			var prop: Dictionary = Dictionary(entry).duplicate(true)
			prop.x = tile.x
			prop.y = tile.y
			props[tile] = prop
	for entry in data.get("spawns", []):
		var tile := target + Vector2i(int(entry.x), int(entry.y))
		if _tile_in_canvas(tile):
			var spawn: Dictionary = Dictionary(entry).duplicate(true)
			spawn.x = tile.x
			spawn.y = tile.y
			spawns[tile] = spawn

func _selected_layer_value():
	match active_layer:
		"foreground":
			return String(selected_asset.get("id", "air"))
		"backgrounds":
			return String(selected_asset.get("id", BackgroundCatalog.EMPTY_ID))
		"props":
			return {
				"id": String(selected_asset.get("id", "")),
				"kind": String(selected_asset.get("kind", "decoration")),
				"size": [1, 1],
				"offset": [0, 0],
				"draw_layer": "foreground",
				"alpha": 1.0,
			}
		"spawns":
			return {"enemy_id": String(selected_asset.get("id", "cave_skitter"))}
	return null

func _layer_dict(layer_name: String) -> Dictionary:
	match layer_name:
		"backgrounds":
			return backgrounds
		"props":
			return props
		"spawns":
			return spawns
	return foreground

func _prune_out_of_bounds() -> void:
	for layer in [foreground, backgrounds, props, spawns]:
		for tile in layer.keys():
			if not _tile_in_canvas(tile):
				layer.erase(tile)

func _entry_size(entry: Dictionary) -> Vector2i:
	var raw = entry.get("size", [1, 1])
	if raw is Array and raw.size() >= 2:
		return Vector2i(maxi(1, int(raw[0])), maxi(1, int(raw[1])))
	if raw is Dictionary:
		return Vector2i(maxi(1, int(raw.get("x", 1))), maxi(1, int(raw.get("y", 1))))
	return Vector2i.ONE

func _parse_vec(value, fallback: Vector2i) -> Vector2i:
	if value is Dictionary:
		return Vector2i(int(value.get("x", fallback.x)), int(value.get("y", fallback.y)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback

func _tile_in_canvas(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < canvas_size.x and tile.y < canvas_size.y

func _clamp_tile(tile: Vector2i) -> Vector2i:
	return Vector2i(clampi(tile.x, 0, canvas_size.x - 1), clampi(tile.y, 0, canvas_size.y - 1))

func _rect_contains_tile(rect: Rect2i, tile: Vector2i) -> bool:
	return tile.x >= rect.position.x and tile.y >= rect.position.y and tile.x < rect.position.x + rect.size.x and tile.y < rect.position.y + rect.size.y

func _redraw_canvas() -> void:
	if canvas_view != null:
		canvas_view.queue_redraw()

func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text

func _add_label(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	parent.add_child(label)
	return label

func _add_line(parent: Control, label_text: String, value: String) -> LineEdit:
	_add_label(parent, label_text)
	var edit := LineEdit.new()
	edit.text = value
	parent.add_child(edit)
	return edit

func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _add_spin(parent: Control, label_text: String, value: float, min_value: float, max_value: float, step := 1.0) -> SpinBox:
	var box := HBoxContainer.new()
	parent.add_child(box)
	_add_label(box, label_text)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	box.add_child(spin)
	return spin

func _add_check(parent: Control, text: String, checked: bool) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = checked
	parent.add_child(check)
	return check
