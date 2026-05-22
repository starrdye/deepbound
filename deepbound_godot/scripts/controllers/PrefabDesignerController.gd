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
const MIN_CANVAS_ZOOM := 0.05
const MAX_CANVAS_ZOOM := 8.0
const FIT_VIEW_PADDING := 32.0
const VIEW_SCROLL_FRACTION := 0.25
const VIEW_ZOOM_FACTOR := 1.12
const UNDO_HISTORY_LIMIT := 50
const BUILTIN_TEMPLATE_PATHS := {
	"Goblin Village": "res://data/templates/goblin_village_full.json",
	"Dwarf Fortress": "res://data/templates/dwarf_fortress_full.json",
	"Dwarf Settlement": "res://data/templates/dwarf_settlement_full.json",
	"Drow Village": "res://data/templates/drow_village_full.json",
}
const LAYERS := ["backgrounds", "foreground", "props", "spawns"]
const TOOL_PENCIL := "pencil"
const TOOL_ERASER := "eraser"
const TOOL_BUCKET := "bucket"
const TOOL_PAN := "pan"
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
				if designer.active_tool == TOOL_PAN:
					panning = event.pressed
					selecting = false
					pan_last = event.position
					accept_event()
					return
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
				designer.pan_canvas(event.position - pan_last)
				pan_last = event.position
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
		var next_zoom := clampf(zoom * factor, MIN_CANVAS_ZOOM, MAX_CANVAS_ZOOM)
		var world_point := (point - pan) / old_zoom
		designer.set_canvas_view(next_zoom, point - world_point * next_zoom)

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
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var restoring_history := false

var canvas_frame: Control
var canvas_view: DesignerCanvasView
var canvas_v_scrollbar: VScrollBar
var canvas_h_scrollbar: HScrollBar
var updating_canvas_scrollbars := false
var undo_button: Button
var redo_button: Button
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
var prop_kind_edit: LineEdit
var prop_draw_layer_option: OptionButton
var prop_width_spin: SpinBox
var prop_height_spin: SpinBox
var prop_alpha_spin: SpinBox

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	PrefabTemplateImporter.ensure_builtin_goblin_template()
	_build_ui()
	_refresh_palette()
	_sync_controls_from_state()
	_clear_history()

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
	_clear_history()

func resize_canvas(width: int, height: int) -> void:
	var next_size := Vector2i(clampi(width, 1, MAX_CANVAS_SIZE), clampi(height, 1, MAX_CANVAS_SIZE))
	if next_size == canvas_size:
		return
	_push_undo_state()
	canvas_size = next_size
	anchor_tile = _clamp_tile(anchor_tile)
	_prune_out_of_bounds()
	_sync_controls_from_state()
	_redraw_canvas()

func set_active_layer(layer_name: String) -> void:
	if layer_name in LAYERS:
		active_layer = layer_name

func set_active_tool(tool_name: String) -> void:
	if tool_name in [TOOL_PENCIL, TOOL_ERASER, TOOL_BUCKET, TOOL_PAN, TOOL_SELECT]:
		active_tool = tool_name
		if canvas_view != null:
			canvas_view.mouse_default_cursor_shape = Control.CURSOR_MOVE if active_tool == TOOL_PAN else Control.CURSOR_ARROW

func select_palette_asset(entry: Dictionary) -> void:
	selected_asset = entry.duplicate(true)
	active_layer = String(entry.get("layer", active_layer))
	_sync_prop_controls_from_selection()

func fit_view_to_template() -> void:
	if canvas_view == null:
		return
	var view_size := _canvas_view_size()
	var content_size := Vector2(canvas_size * GRID_TILE_SIZE)
	var available := Vector2(maxf(1.0, view_size.x - FIT_VIEW_PADDING * 2.0), maxf(1.0, view_size.y - FIT_VIEW_PADDING * 2.0))
	var next_zoom := clampf(minf(available.x / content_size.x, available.y / content_size.y), MIN_CANVAS_ZOOM, MAX_CANVAS_ZOOM)
	var next_pan := (view_size - content_size * next_zoom) * 0.5
	set_canvas_view(next_zoom, next_pan)

func reset_view_100() -> void:
	set_canvas_view(1.0, Vector2(FIT_VIEW_PADDING, FIT_VIEW_PADDING))

func scroll_view(direction: Vector2) -> void:
	if canvas_view == null:
		return
	var view_size := _canvas_view_size()
	pan_canvas(Vector2(direction.x * view_size.x, direction.y * view_size.y) * VIEW_SCROLL_FRACTION)

func zoom_view(factor: float) -> void:
	if canvas_view == null:
		return
	var center := _canvas_view_center()
	var old_zoom := canvas_view.zoom
	var next_zoom := clampf(canvas_view.zoom * factor, MIN_CANVAS_ZOOM, MAX_CANVAS_ZOOM)
	var world_point := (center - canvas_view.pan) / old_zoom
	set_canvas_view(next_zoom, center - world_point * next_zoom)

func pan_canvas(delta: Vector2) -> void:
	if canvas_view == null:
		return
	set_canvas_view(canvas_view.zoom, canvas_view.pan + delta)

func set_canvas_view(next_zoom: float, next_pan: Vector2) -> void:
	if canvas_view == null:
		return
	canvas_view.zoom = clampf(next_zoom, MIN_CANVAS_ZOOM, MAX_CANVAS_ZOOM)
	canvas_view.pan = next_pan
	canvas_view.queue_redraw()
	_refresh_canvas_scrollbars()

func _canvas_view_size() -> Vector2:
	if canvas_frame != null and is_instance_valid(canvas_frame):
		var frame_size := canvas_frame.size
		if frame_size.x > 1.0 and frame_size.y > 1.0:
			return frame_size
	if canvas_view == null:
		return Vector2(640, 480)
	var view_size := canvas_view.size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = canvas_view.get_rect().size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = Vector2(640, 480)
	return view_size

func _canvas_view_center() -> Vector2:
	return _canvas_view_size() * 0.5

func _canvas_content_size() -> Vector2:
	if canvas_view == null:
		return Vector2(canvas_size * GRID_TILE_SIZE)
	return Vector2(canvas_size * GRID_TILE_SIZE) * canvas_view.zoom

func _canvas_scroll_offset() -> Vector2:
	if canvas_view == null:
		return Vector2.ZERO
	var view_size := _canvas_view_size()
	var content_size := _canvas_content_size()
	return Vector2(
		clampf(-canvas_view.pan.x, 0.0, maxf(0.0, content_size.x - view_size.x)),
		clampf(-canvas_view.pan.y, 0.0, maxf(0.0, content_size.y - view_size.y))
	)

func _refresh_canvas_scrollbars() -> void:
	if canvas_view == null or canvas_h_scrollbar == null or canvas_v_scrollbar == null:
		return
	var view_size := _canvas_view_size()
	var content_size := _canvas_content_size()
	var offset := _canvas_scroll_offset()
	updating_canvas_scrollbars = true
	_configure_canvas_scrollbar(canvas_h_scrollbar, content_size.x, view_size.x, offset.x)
	_configure_canvas_scrollbar(canvas_v_scrollbar, content_size.y, view_size.y, offset.y)
	updating_canvas_scrollbars = false

func _configure_canvas_scrollbar(scrollbar: ScrollBar, content_length: float, view_length: float, offset: float) -> void:
	var track_length := maxf(content_length, view_length)
	var max_offset := maxf(0.0, content_length - view_length)
	scrollbar.min_value = 0.0
	scrollbar.max_value = track_length
	scrollbar.page = minf(view_length, track_length)
	scrollbar.step = maxf(1.0, view_length * 0.05)
	scrollbar.value = clampf(offset, 0.0, max_offset)
	scrollbar.modulate = Color(1, 1, 1, 1.0 if max_offset > 0.5 else 0.58)

func _on_canvas_h_scrollbar_changed(value: float) -> void:
	if updating_canvas_scrollbars or canvas_view == null:
		return
	var view_size := _canvas_view_size()
	var content_size := _canvas_content_size()
	var offset_x := clampf(value, 0.0, maxf(0.0, content_size.x - view_size.x))
	set_canvas_view(canvas_view.zoom, Vector2(-offset_x, canvas_view.pan.y))

func _on_canvas_v_scrollbar_changed(value: float) -> void:
	if updating_canvas_scrollbars or canvas_view == null:
		return
	var view_size := _canvas_view_size()
	var content_size := _canvas_content_size()
	var offset_y := clampf(value, 0.0, maxf(0.0, content_size.y - view_size.y))
	set_canvas_view(canvas_view.zoom, Vector2(canvas_view.pan.x, -offset_y))

func apply_tool_at(tile: Vector2i) -> void:
	if not _tile_in_canvas(tile):
		return
	if active_tool != TOOL_SELECT and active_tool != TOOL_PAN and not bool(layer_visible.get(active_layer, true)):
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
	_push_undo_state()
	match active_layer:
		"foreground":
			foreground[tile] = String(selected_asset.get("id", "air"))
		"backgrounds":
			backgrounds[tile] = String(selected_asset.get("id", BackgroundCatalog.EMPTY_ID))
		"props":
			props[tile] = _new_prop_entry(tile)
		"spawns":
			spawns[tile] = {"x": tile.x, "y": tile.y, "enemy_id": String(selected_asset.get("id", "cave_skitter"))}

func erase_at(tile: Vector2i) -> void:
	if not _layer_dict(active_layer).has(tile):
		return
	_push_undo_state()
	_layer_dict(active_layer).erase(tile)

func bucket_fill(start_tile: Vector2i) -> void:
	if not _tile_in_canvas(start_tile):
		return
	var layer := _layer_dict(active_layer)
	var replacement = _selected_layer_value()
	var target = layer.get(start_tile, null)
	if target == replacement:
		return
	_push_undo_state()
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
	_sync_prop_controls_from_selection()
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
	if not _selection_has_content():
		return
	_push_undo_state()
	_delete_selection_cells()
	_redraw_canvas()

func paste_selection(target: Vector2i) -> void:
	if clipboard.is_empty():
		return
	_push_undo_state()
	_paste_clipboard(clipboard, target)
	_redraw_canvas()

func move_selection(delta: Vector2i) -> void:
	if selection_rect.size == Vector2i.ZERO:
		return
	if not _selection_has_content():
		return
	_push_undo_state()
	var original_selection := selection_rect
	var data := copy_selection()
	_delete_selection_cells()
	_paste_clipboard(data, original_selection.position + delta)
	select_region(Rect2i(original_selection.position + delta, original_selection.size))

func set_template_anchor(tile: Vector2i) -> void:
	var next_anchor := _clamp_tile(tile)
	if next_anchor == anchor_tile:
		return
	_push_undo_state()
	anchor_tile = next_anchor
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
	_clear_history()
	fit_view_to_template()
	_set_status("Loaded %s." % template_id)
	return true

func save_to_path(path: String) -> bool:
	if _metadata_controls_differ_from_state():
		_push_undo_state(false)
	var ok := PrefabTemplateRegistry.save_template(to_template(), path)
	_set_status("Saved %s." % path if ok else "Save failed.")
	return ok

func load_from_path(path: String) -> bool:
	var template := PrefabTemplateRegistry.load_template(path)
	if template.is_empty():
		_set_status("Load failed.")
		return false
	if path_edit != null:
		path_edit.text = path
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
	for tool_name in [TOOL_PENCIL, TOOL_ERASER, TOOL_BUCKET, TOOL_PAN, TOOL_SELECT]:
		var button := Button.new()
		button.text = tool_name.capitalize()
		button.pressed.connect(func(name: String = tool_name): set_active_tool(name))
		tool_row.add_child(button)
	var history_row := HBoxContainer.new()
	left.add_child(history_row)
	undo_button = _add_button(history_row, "Undo", func(): undo())
	redo_button = _add_button(history_row, "Redo", func(): redo())
	_add_button(history_row, "Fit View", fit_view_to_template)
	_add_button(history_row, "100%", reset_view_100)
	_refresh_history_buttons()
	var zoom_row := HBoxContainer.new()
	left.add_child(zoom_row)
	_add_button(zoom_row, "Zoom -", func(): zoom_view(1.0 / VIEW_ZOOM_FACTOR))
	_add_button(zoom_row, "Zoom +", func(): zoom_view(VIEW_ZOOM_FACTOR))
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

	var center := VBoxContainer.new()
	center.name = "CanvasWorkspace"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var canvas_row := HBoxContainer.new()
	canvas_row.name = "CanvasRow"
	canvas_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(canvas_row)

	canvas_frame = Control.new()
	canvas_frame.name = "CanvasFrame"
	canvas_frame.clip_contents = true
	canvas_frame.custom_minimum_size = Vector2(360, 260)
	canvas_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_row.add_child(canvas_frame)

	canvas_view = DesignerCanvasView.new()
	canvas_view.name = "DesignerCanvasView"
	canvas_view.designer = self
	canvas_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_frame.add_child(canvas_view)

	var vertical_scroll := VBoxContainer.new()
	vertical_scroll.name = "CanvasVerticalScroll"
	vertical_scroll.custom_minimum_size = Vector2(58, 0)
	canvas_row.add_child(vertical_scroll)
	_add_button(vertical_scroll, "Up", func(): scroll_view(Vector2.UP))
	canvas_v_scrollbar = VScrollBar.new()
	canvas_v_scrollbar.name = "CanvasVScrollBar"
	canvas_v_scrollbar.custom_minimum_size = Vector2(22, 0)
	canvas_v_scrollbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_v_scrollbar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_canvas_scrollbar(canvas_v_scrollbar)
	canvas_v_scrollbar.value_changed.connect(_on_canvas_v_scrollbar_changed)
	vertical_scroll.add_child(canvas_v_scrollbar)
	_add_button(vertical_scroll, "Down", func(): scroll_view(Vector2.DOWN))

	var horizontal_scroll := HBoxContainer.new()
	horizontal_scroll.name = "CanvasHorizontalScroll"
	horizontal_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(horizontal_scroll)
	_add_button(horizontal_scroll, "Left", func(): scroll_view(Vector2.LEFT))
	canvas_h_scrollbar = HScrollBar.new()
	canvas_h_scrollbar.name = "CanvasHScrollBar"
	canvas_h_scrollbar.custom_minimum_size = Vector2(0, 22)
	canvas_h_scrollbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_h_scrollbar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_canvas_scrollbar(canvas_h_scrollbar)
	canvas_h_scrollbar.value_changed.connect(_on_canvas_h_scrollbar_changed)
	horizontal_scroll.add_child(canvas_h_scrollbar)
	_add_button(horizontal_scroll, "Right", func(): scroll_view(Vector2.RIGHT))
	_refresh_canvas_scrollbars()

	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(320, 0)
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(right_scroll)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right)
	_add_label(right, "Template")
	path_edit = LineEdit.new()
	path_edit.text = "user://templates/new_template.json"
	right.add_child(path_edit)
	var file_row := HBoxContainer.new()
	right.add_child(file_row)
	_add_button(file_row, "Save", func(): save_to_path(path_edit.text))
	_add_button(file_row, "Load", func(): load_from_path(path_edit.text))
	_add_button(file_row, "Reimport", func(): reimport_current_village(true))
	var builtin_row := VBoxContainer.new()
	builtin_row.add_theme_constant_override("separation", 4)
	right.add_child(builtin_row)
	for template_label in BUILTIN_TEMPLATE_PATHS.keys():
		_add_button(builtin_row, template_label, func(label: String = template_label): load_from_path(String(BUILTIN_TEMPLATE_PATHS[label])))
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
	_add_label(right, "Prop Metadata")
	prop_kind_edit = _add_line(right, "Kind", "decoration")
	var prop_layer_row := HBoxContainer.new()
	right.add_child(prop_layer_row)
	_add_label(prop_layer_row, "Draw Layer")
	prop_draw_layer_option = OptionButton.new()
	prop_draw_layer_option.add_item("foreground")
	prop_draw_layer_option.add_item("backdrop")
	prop_layer_row.add_child(prop_draw_layer_option)
	var prop_size_row := HBoxContainer.new()
	right.add_child(prop_size_row)
	prop_width_spin = _add_spin(prop_size_row, "PW", 1, 1, MAX_CANVAS_SIZE)
	prop_height_spin = _add_spin(prop_size_row, "PH", 1, 1, MAX_CANVAS_SIZE)
	prop_alpha_spin = _add_spin(right, "Alpha", 1.0, 0.0, 1.0, 0.01)
	_add_button(right, "Apply Prop Metadata", func(): apply_prop_metadata_to_selection())
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

func undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(_snapshot_editor_state())
	var snapshot: Dictionary = undo_stack.pop_back()
	_restore_editor_state(snapshot)
	_set_status("Undo.")
	_refresh_history_buttons()

func redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(_snapshot_editor_state())
	var snapshot: Dictionary = redo_stack.pop_back()
	_restore_editor_state(snapshot)
	_set_status("Redo.")
	_refresh_history_buttons()

func _clear_history() -> void:
	undo_stack.clear()
	redo_stack.clear()
	_refresh_history_buttons()

func _push_undo_state(use_controls := true) -> void:
	if restoring_history:
		return
	undo_stack.append(_snapshot_editor_state(use_controls))
	while undo_stack.size() > UNDO_HISTORY_LIMIT:
		undo_stack.pop_front()
	redo_stack.clear()
	_refresh_history_buttons()

func _refresh_history_buttons() -> void:
	if undo_button != null:
		undo_button.disabled = undo_stack.is_empty()
	if redo_button != null:
		redo_button.disabled = redo_stack.is_empty()

func _snapshot_editor_state(use_controls := true) -> Dictionary:
	return {
		"canvas_size": canvas_size,
		"anchor_tile": anchor_tile,
		"template_id": id_edit.text.strip_edges() if use_controls and id_edit != null else template_id,
		"template_name": name_edit.text if use_controls and name_edit != null else template_name,
		"rarity": float(rarity_spin.value) if use_controls and rarity_spin != null else rarity,
		"enabled": enabled_check.button_pressed if use_controls and enabled_check != null else enabled,
		"allow_mirror_x": mirror_x_check.button_pressed if use_controls and mirror_x_check != null else allow_mirror_x,
		"allow_mirror_y": mirror_y_check.button_pressed if use_controls and mirror_y_check != null else allow_mirror_y,
		"allow_rotation": rotation_check.button_pressed if use_controls and rotation_check != null else allow_rotation,
		"tags": _tags_from_controls() if use_controls else tags.duplicate(),
		"selected_bands": _selected_bands_from_controls() if use_controls else selected_bands.duplicate(),
		"foreground": foreground.duplicate(true),
		"backgrounds": backgrounds.duplicate(true),
		"props": props.duplicate(true),
		"spawns": spawns.duplicate(true),
		"selection_position": selection_rect.position,
		"selection_size": selection_rect.size,
		"clipboard": clipboard.duplicate(true),
	}

func _restore_editor_state(snapshot: Dictionary) -> void:
	restoring_history = true
	canvas_size = snapshot.get("canvas_size", canvas_size)
	anchor_tile = snapshot.get("anchor_tile", anchor_tile)
	template_id = String(snapshot.get("template_id", template_id))
	template_name = String(snapshot.get("template_name", template_name))
	rarity = float(snapshot.get("rarity", rarity))
	enabled = bool(snapshot.get("enabled", enabled))
	allow_mirror_x = bool(snapshot.get("allow_mirror_x", allow_mirror_x))
	allow_mirror_y = bool(snapshot.get("allow_mirror_y", allow_mirror_y))
	allow_rotation = bool(snapshot.get("allow_rotation", allow_rotation))
	tags.assign(snapshot.get("tags", tags))
	selected_bands.assign(snapshot.get("selected_bands", selected_bands))
	foreground = Dictionary(snapshot.get("foreground", {})).duplicate(true)
	backgrounds = Dictionary(snapshot.get("backgrounds", {})).duplicate(true)
	props = Dictionary(snapshot.get("props", {})).duplicate(true)
	spawns = Dictionary(snapshot.get("spawns", {})).duplicate(true)
	selection_rect = Rect2i(snapshot.get("selection_position", Vector2i.ZERO), snapshot.get("selection_size", Vector2i.ZERO))
	clipboard = Dictionary(snapshot.get("clipboard", {})).duplicate(true)
	_sync_controls_from_state()
	_redraw_canvas()
	restoring_history = false

func _metadata_controls_differ_from_state() -> bool:
	if id_edit != null and id_edit.text.strip_edges() != template_id:
		return true
	if name_edit != null and name_edit.text != template_name:
		return true
	if rarity_spin != null and not is_equal_approx(float(rarity_spin.value), rarity):
		return true
	if enabled_check != null and enabled_check.button_pressed != enabled:
		return true
	if mirror_x_check != null and mirror_x_check.button_pressed != allow_mirror_x:
		return true
	if mirror_y_check != null and mirror_y_check.button_pressed != allow_mirror_y:
		return true
	if rotation_check != null and rotation_check.button_pressed != allow_rotation:
		return true
	if _tags_from_controls() != tags:
		return true
	return _selected_bands_from_controls() != selected_bands

func _tags_from_controls() -> Array[String]:
	if tags_edit == null:
		return tags.duplicate()
	var result: Array[String] = []
	for raw_tag in tags_edit.text.split(",", false):
		var tag := String(raw_tag).strip_edges()
		if tag != "":
			result.append(tag)
	return result

func _selected_bands_from_controls() -> Array[String]:
	if band_checks.is_empty():
		return selected_bands.duplicate()
	var result: Array[String] = []
	for band_id in BandCatalog.BANDS.keys():
		var check := band_checks.get(String(band_id), null) as CheckBox
		if check != null and check.button_pressed:
			result.append(String(band_id))
	if result.is_empty():
		result.append("standard_caverns")
	return result

func _pull_metadata_from_controls() -> void:
	if id_edit != null:
		template_id = id_edit.text.strip_edges()
	if name_edit != null:
		template_name = name_edit.text.strip_edges()
	if tags_edit != null:
		tags.assign(_tags_from_controls())
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
	selected_bands.assign(_selected_bands_from_controls())

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
	_sync_prop_controls_from_selection()

func _selection_has_content() -> bool:
	for layer in [foreground, backgrounds, props, spawns]:
		for tile in layer.keys():
			if _rect_contains_tile(selection_rect, tile):
				return true
	return false

func _delete_selection_cells() -> void:
	for layer in [foreground, backgrounds, props, spawns]:
		for tile in layer.keys():
			if _rect_contains_tile(selection_rect, tile):
				layer.erase(tile)

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

func apply_prop_metadata_to_selection() -> void:
	var prop_tiles := _selected_prop_tiles()
	if prop_tiles.is_empty():
		_set_status("Select one or more props first.")
		return
	_push_undo_state()
	var kind := prop_kind_edit.text.strip_edges() if prop_kind_edit != null else "decoration"
	if kind == "":
		kind = "decoration"
	var draw_layer := "foreground"
	if prop_draw_layer_option != null:
		draw_layer = prop_draw_layer_option.get_item_text(maxi(0, prop_draw_layer_option.selected))
	var size := [1, 1]
	if prop_width_spin != null and prop_height_spin != null:
		size = [maxi(1, int(prop_width_spin.value)), maxi(1, int(prop_height_spin.value))]
	var alpha := 1.0
	if prop_alpha_spin != null:
		alpha = clampf(float(prop_alpha_spin.value), 0.0, 1.0)
	for tile in prop_tiles:
		var prop: Dictionary = Dictionary(props[tile]).duplicate(true)
		prop.kind = kind
		prop.draw_layer = draw_layer
		prop.size = size
		prop.alpha = alpha
		props[tile] = prop
	_set_status("Updated %d prop metadata entries." % prop_tiles.size())
	_redraw_canvas()

func _selected_prop_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if selection_rect.size == Vector2i.ZERO:
		return tiles
	for tile in props.keys():
		if _rect_contains_tile(selection_rect, tile):
			tiles.append(tile)
	return tiles

func _sync_prop_controls_from_selection() -> void:
	if prop_kind_edit == null:
		return
	var sample := {}
	for tile in _selected_prop_tiles():
		sample = Dictionary(props[tile])
		break
	if sample.is_empty() and String(selected_asset.get("layer", "")) == "props":
		sample = _new_prop_entry(Vector2i.ZERO)
	if sample.is_empty():
		return
	prop_kind_edit.text = String(sample.get("kind", "decoration"))
	_set_prop_draw_layer_control(String(sample.get("draw_layer", "foreground")))
	var size := _entry_size(sample)
	if prop_width_spin != null:
		prop_width_spin.value = size.x
	if prop_height_spin != null:
		prop_height_spin.value = size.y
	if prop_alpha_spin != null:
		prop_alpha_spin.value = float(sample.get("alpha", 1.0))

func _set_prop_draw_layer_control(draw_layer: String) -> void:
	if prop_draw_layer_option == null:
		return
	for index in range(prop_draw_layer_option.item_count):
		if prop_draw_layer_option.get_item_text(index) == draw_layer:
			prop_draw_layer_option.select(index)
			return
	prop_draw_layer_option.select(0)

func _new_prop_entry(tile: Vector2i) -> Dictionary:
	var prop_id := String(selected_asset.get("id", ""))
	var size := _entry_size({"size": selected_asset.get("size", _prop_size_for_id(prop_id))})
	return {
		"x": tile.x,
		"y": tile.y,
		"id": prop_id,
		"kind": String(selected_asset.get("kind", "decoration")),
		"size": [size.x, size.y],
		"offset": selected_asset.get("offset", [0, 0]),
		"draw_layer": String(selected_asset.get("draw_layer", _default_prop_draw_layer(prop_id))),
		"alpha": float(selected_asset.get("alpha", _default_prop_alpha(prop_id))),
	}

func _prop_size_for_id(prop_id: String) -> Array[int]:
	if prop_id == "":
		return [1, 1]
	var texture := TextureFactory.make_prop_texture(prop_id)
	if texture == null:
		return [1, 1]
	return [maxi(1, ceili(float(texture.get_width()) / float(GRID_TILE_SIZE))), maxi(1, ceili(float(texture.get_height()) / float(GRID_TILE_SIZE)))]

func _default_prop_draw_layer(prop_id: String) -> String:
	if prop_id.find("_back_") >= 0 or prop_id.begins_with("dwarf_back_") or prop_id.begins_with("goblin_back_"):
		return "backdrop"
	return "foreground"

func _default_prop_alpha(prop_id: String) -> float:
	if prop_id.find("_back_") >= 0 or prop_id.begins_with("dwarf_back_") or prop_id.begins_with("goblin_back_"):
		return 0.50 if prop_id.find("dark") >= 0 else 0.62
	return 1.0

func _selected_layer_value():
	match active_layer:
		"foreground":
			return String(selected_asset.get("id", "air"))
		"backgrounds":
			return String(selected_asset.get("id", BackgroundCatalog.EMPTY_ID))
		"props":
			var entry := _new_prop_entry(Vector2i.ZERO)
			entry.erase("x")
			entry.erase("y")
			return entry
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

func _style_canvas_scrollbar(scrollbar: ScrollBar) -> void:
	scrollbar.add_theme_stylebox_override("scroll", _canvas_scrollbar_track_style())
	scrollbar.add_theme_stylebox_override("scroll_focus", _canvas_scrollbar_track_style())
	scrollbar.add_theme_stylebox_override("grabber", _canvas_scrollbar_grabber_style(Color8(151, 160, 166)))
	scrollbar.add_theme_stylebox_override("grabber_highlight", _canvas_scrollbar_grabber_style(Color8(190, 200, 202)))
	scrollbar.add_theme_stylebox_override("grabber_pressed", _canvas_scrollbar_grabber_style(Color8(226, 213, 161)))

func _canvas_scrollbar_track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color8(38, 39, 42)
	style.border_color = Color8(83, 87, 92)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style

func _canvas_scrollbar_grabber_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

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
