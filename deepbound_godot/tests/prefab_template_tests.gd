extends SceneTree

const PrefabTemplateRegistry = preload("res://scripts/systems/PrefabTemplateRegistry.gd")
const PrefabTemplateImporter = preload("res://scripts/systems/PrefabTemplateImporter.gd")
const PrefabDesignerController = preload("res://scripts/controllers/PrefabDesignerController.gd")
const StructureGenerator = preload("res://scripts/systems/StructureGenerator.gd")
const ChunkStore = preload("res://scripts/systems/ChunkStore.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	PrefabTemplateRegistry.clear_cache()
	_assert(PrefabTemplateImporter.import_current_goblin_village(PrefabTemplateImporter.DEFAULT_GOBLIN_TEMPLATE_PATH, true), "current goblin village should import as a built-in prefab template")
	PrefabTemplateRegistry.clear_cache()
	_test_serialization_round_trip_and_validation()
	_test_import_matches_current_village()
	_test_designer_tool_operations()
	await _test_designer_canvas_navigation()
	_test_designer_undo_redo_operations()
	await _test_designer_scene_loads_palette()
	_test_template_worldgen_replaces_live_goblin_stamping()
	_test_template_band_precheck_covers_multiple_depths()
	if failures.is_empty():
		print("Deepbound Godot prefab template tests passed.")
		quit(0)
	else:
		print("Deepbound Godot prefab template tests failed: %d" % failures.size())
		quit(1)

func _test_serialization_round_trip_and_validation() -> void:
	var template := _small_template()
	var path := "user://templates/round_trip_prefab_test.json"
	_remove_file(path)
	_assert(PrefabTemplateRegistry.save_template(template, path), "valid sparse prefab template should save")
	var first := FileAccess.get_file_as_string(path)
	var loaded := PrefabTemplateRegistry.load_template(path)
	_assert(not loaded.is_empty(), "saved prefab template should load")
	_assert(int(loaded.schema_version) == 1, "loaded prefab template should keep schema version")
	_assert(loaded.layers.foreground.size() == 2, "foreground layer should preserve sparse entries including explicit air")
	_assert(loaded.layers.backgrounds.size() == 2, "background layer should preserve explicit empty clears")
	var direct_structure := PrefabTemplateRegistry.instantiate_template(loaded, Vector2i(20, 20))
	_assert(Dictionary(direct_structure.tiles).values().has("chest_block"), "container props should stamp chest_block tiles when instantiated")
	_assert(Array(direct_structure.containers).size() == 1, "container props should expose container markers")
	_assert(Array(direct_structure.lights).size() == 1, "light props should expose light markers")
	_assert(PrefabTemplateRegistry.save_template(loaded, path), "loaded prefab template should save again")
	var second := FileAccess.get_file_as_string(path)
	_assert(first == second, "prefab template save should be stable and deterministic")

	var duplicate := template.duplicate(true)
	duplicate.layers.foreground.append({"x": 1, "y": 1, "id": "soft_stone"})
	PrefabTemplateRegistry.set_validation_errors_enabled(false)
	_assert(PrefabTemplateRegistry.validate_template(duplicate).is_empty(), "duplicate foreground cells should be rejected")
	var bad_id := template.duplicate(true)
	bad_id.layers.foreground[0].id = "missing_tile"
	_assert(PrefabTemplateRegistry.validate_template(bad_id).is_empty(), "unknown foreground tile ids should be rejected")
	var bad_anchor := template.duplicate(true)
	bad_anchor.anchor = {"x": 99, "y": 0}
	_assert(PrefabTemplateRegistry.validate_template(bad_anchor).is_empty(), "anchor outside canvas should be rejected")
	PrefabTemplateRegistry.set_validation_errors_enabled(true)
	_remove_file(path)
	PrefabTemplateRegistry.clear_cache()

func _test_import_matches_current_village() -> void:
	var region := PrefabTemplateImporter.find_first_goblin_village_region(133742)
	var reference := StructureGenerator.build_goblin_village(133742, region)
	var imported := PrefabTemplateRegistry.load_template(PrefabTemplateImporter.DEFAULT_GOBLIN_TEMPLATE_PATH)
	_assert(not imported.is_empty(), "imported goblin village prefab should load")
	_assert(String(imported.id) == "goblin_village_full", "imported goblin village should use the expected template id")
	_assert(imported.layers.foreground.size() == Dictionary(reference.tiles).size(), "imported foreground count should match the generated reference village")
	_assert(imported.layers.backgrounds.size() == Dictionary(reference.backgrounds).size(), "imported background count should match the generated reference village")
	_assert(imported.layers.props.size() == Array(reference.props).size(), "imported prop count should match the generated reference village")
	_assert(imported.layers.spawns.size() == Array(reference.spawns).size(), "imported spawn count should match the generated reference village")
	var rect: Rect2i = reference.rect
	for source_tile in Dictionary(reference.tiles).keys().slice(0, mini(12, Dictionary(reference.tiles).size())):
		var tile: Vector2i = source_tile
		var local := Vector2i(tile.x - rect.position.x, tile.y - rect.position.y)
		_assert(_template_has_cell(imported.layers.foreground, local, String(reference.tiles[tile])), "imported foreground should preserve generated tile %s" % str(local))

func _test_designer_tool_operations() -> void:
	var designer := PrefabDesignerController.new()
	designer.new_template(6, 5)
	designer.select_palette_asset({"layer": "foreground", "kind": "foreground", "id": "soft_stone", "name": "Soft Stone"})
	designer.apply_pencil(Vector2i(1, 1))
	_assert(String(designer.foreground[Vector2i(1, 1)]) == "soft_stone", "designer pencil should place the selected foreground tile")
	designer.active_tool = PrefabDesignerController.TOOL_BUCKET
	designer.select_palette_asset({"layer": "foreground", "kind": "foreground", "id": "air", "name": "Air"})
	designer.bucket_fill(Vector2i(0, 0))
	_assert(String(designer.foreground[Vector2i(0, 0)]) == "air", "designer bucket should fill matching blank cells with explicit air")
	designer.active_layer = "backgrounds"
	designer.select_palette_asset({"layer": "backgrounds", "kind": "background", "id": "stone_background_block", "name": "Stone Background"})
	designer.apply_pencil(Vector2i(2, 2))
	designer.select_region(Rect2i(Vector2i(1, 1), Vector2i(2, 2)))
	var copied := designer.copy_selection()
	_assert(copied.foreground.size() > 0 and copied.backgrounds.size() > 0, "designer marquee copy should include all authored layers in the region")
	designer.move_selection(Vector2i(2, 0))
	_assert(designer.backgrounds.has(Vector2i(4, 2)), "designer move should shift selected background cells")
	designer.select_palette_asset({"layer": "props", "kind": "decoration", "id": "dwarf_back_house_lit", "name": "Dwarf Back House Lit"})
	designer.apply_pencil(Vector2i(0, 3))
	var prop: Dictionary = designer.props[Vector2i(0, 3)]
	_assert(int(prop.size[0]) == 3 and int(prop.size[1]) == 2, "designer prop pencil should use native prop tile dimensions")
	_assert(String(prop.draw_layer) == "backdrop", "designer prop pencil should use backdrop defaults for decorative back houses")
	_assert(absf(float(prop.alpha) - 0.62) < 0.001, "designer prop pencil should use reduced alpha for lit backdrop houses")
	var template := designer.to_template()
	_assert(not PrefabTemplateRegistry.validate_template(template).is_empty(), "designer-authored template should validate")
	var reloaded_designer := PrefabDesignerController.new()
	_assert(reloaded_designer.load_template_data(template), "designer-authored template should load back into the editor")
	var reloaded_prop: Dictionary = reloaded_designer.props[Vector2i(0, 3)]
	_assert(int(reloaded_prop.size[0]) == 3 and int(reloaded_prop.size[1]) == 2, "designer save/load should preserve native prop size")
	_assert(String(reloaded_prop.draw_layer) == "backdrop", "designer save/load should preserve prop draw layer")
	reloaded_designer.free()
	designer.free()

func _test_designer_canvas_navigation() -> void:
	var designer := PrefabDesignerController.new()
	var canvas := PrefabDesignerController.DesignerCanvasView.new()
	canvas.designer = designer
	canvas.size = Vector2(640, 480)
	designer.canvas_view = canvas
	get_root().add_child(canvas)
	designer.new_template(128, 64)
	designer.set_active_tool(PrefabDesignerController.TOOL_PAN)
	_assert(designer.active_tool == PrefabDesignerController.TOOL_PAN, "designer should expose a selectable pan tool")
	designer.fit_view_to_template()
	_assert(canvas.zoom < 1.0, "fit view should zoom out for fortress-sized templates")
	var content_size := Vector2(designer.canvas_size * PrefabDesignerController.GRID_TILE_SIZE) * canvas.zoom
	_assert(canvas.pan.x >= -0.001 and canvas.pan.y >= -0.001, "fit view should keep the template visible inside the canvas")
	_assert(canvas.pan.x + content_size.x <= canvas.size.x + 0.001 and canvas.pan.y + content_size.y <= canvas.size.y + 0.001, "fit view should frame the full template")
	designer.reset_view_100()
	_assert(absf(canvas.zoom - 1.0) < 0.001, "100% view should reset canvas zoom to one tile pixel scale")
	var undo_count_before_view_controls := designer.undo_stack.size()
	var frame := Control.new()
	frame.size = Vector2(500, 300)
	frame.clip_contents = true
	designer.canvas_frame = frame
	get_root().add_child(frame)
	var scroll_start := canvas.pan
	designer.scroll_view(Vector2.RIGHT)
	var expected_scroll := Vector2(frame.size.x * PrefabDesignerController.VIEW_SCROLL_FRACTION, 0)
	_assert(canvas.pan.distance_to(scroll_start + expected_scroll) < 0.001, "scroll buttons should pan by a viewport-relative step")
	designer.scroll_view(Vector2.UP)
	expected_scroll += Vector2(0, -frame.size.y * PrefabDesignerController.VIEW_SCROLL_FRACTION)
	_assert(canvas.pan.distance_to(scroll_start + expected_scroll) < 0.001, "vertical scroll buttons should pan by a viewport-relative step")
	var zoom_start := canvas.zoom
	var pan_before_zoom := canvas.pan
	var center := frame.size * 0.5
	designer.zoom_view(PrefabDesignerController.VIEW_ZOOM_FACTOR)
	var expected_zoom := zoom_start * PrefabDesignerController.VIEW_ZOOM_FACTOR
	var expected_pan := center - ((center - pan_before_zoom) / zoom_start) * expected_zoom
	_assert(absf(canvas.zoom - expected_zoom) < 0.001, "Zoom + should increase canvas zoom")
	_assert(canvas.pan.distance_to(expected_pan) < 0.001, "Zoom + should zoom around the canvas center")
	designer.zoom_view(1.0 / PrefabDesignerController.VIEW_ZOOM_FACTOR)
	_assert(absf(canvas.zoom - zoom_start) < 0.001, "Zoom - should decrease canvas zoom")
	canvas.zoom = PrefabDesignerController.MAX_CANVAS_ZOOM
	designer.zoom_view(PrefabDesignerController.VIEW_ZOOM_FACTOR)
	_assert(absf(canvas.zoom - PrefabDesignerController.MAX_CANVAS_ZOOM) < 0.001, "Zoom + should clamp to the maximum zoom")
	canvas.zoom = PrefabDesignerController.MIN_CANVAS_ZOOM
	designer.zoom_view(1.0 / PrefabDesignerController.VIEW_ZOOM_FACTOR)
	_assert(absf(canvas.zoom - PrefabDesignerController.MIN_CANVAS_ZOOM) < 0.001, "Zoom - should clamp to the minimum zoom")
	_assert(designer.undo_stack.size() == undo_count_before_view_controls and designer.redo_stack.is_empty(), "scroll and zoom controls should not add undo history")
	designer.canvas_frame = null
	frame.queue_free()
	var before_pan := canvas.pan
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(20, 20)
	canvas._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(54, 47)
	canvas._gui_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(54, 47)
	canvas._gui_input(release)
	_assert(canvas.pan == before_pan + Vector2(34, 27), "left-dragging with the pan tool should move the canvas")
	_assert(designer.foreground.is_empty(), "left-dragging with the pan tool should not paint tiles")
	canvas.queue_free()
	await process_frame
	designer.free()

func _test_designer_undo_redo_operations() -> void:
	var designer := PrefabDesignerController.new()
	designer.new_template(8, 6)
	designer.select_palette_asset({"layer": "foreground", "kind": "foreground", "id": "soft_stone", "name": "Soft Stone"})
	designer.apply_pencil(Vector2i(1, 1))
	_assert(String(designer.foreground[Vector2i(1, 1)]) == "soft_stone", "pencil should create a foreground edit before undo")
	designer.undo()
	_assert(not designer.foreground.has(Vector2i(1, 1)), "undo should revert a pencil edit")
	designer.redo()
	_assert(String(designer.foreground[Vector2i(1, 1)]) == "soft_stone", "redo should restore a pencil edit")

	designer.erase_at(Vector2i(1, 1))
	_assert(not designer.foreground.has(Vector2i(1, 1)), "eraser should remove a tile before undo")
	designer.undo()
	_assert(String(designer.foreground[Vector2i(1, 1)]) == "soft_stone", "undo should restore an erased tile")
	designer.redo()
	_assert(not designer.foreground.has(Vector2i(1, 1)), "redo should reapply an eraser edit")

	designer.select_palette_asset({"layer": "foreground", "kind": "foreground", "id": "air", "name": "Air"})
	designer.bucket_fill(Vector2i(0, 0))
	_assert(String(designer.foreground[Vector2i(0, 0)]) == "air", "bucket should fill blank cells before undo")
	designer.undo()
	_assert(not designer.foreground.has(Vector2i(0, 0)), "undo should revert bucket fill cells")
	designer.redo()
	_assert(String(designer.foreground[Vector2i(0, 0)]) == "air", "redo should restore bucket fill cells")

	designer.new_template(8, 6)
	designer.select_palette_asset({"layer": "foreground", "kind": "foreground", "id": "soft_stone", "name": "Soft Stone"})
	designer.apply_pencil(Vector2i(0, 0))
	designer.select_region(Rect2i(Vector2i(0, 0), Vector2i.ONE))
	designer.copy_selection()
	designer.paste_selection(Vector2i(2, 0))
	_assert(String(designer.foreground[Vector2i(2, 0)]) == "soft_stone", "paste should copy selected foreground cells")
	designer.undo()
	_assert(not designer.foreground.has(Vector2i(2, 0)), "undo should remove pasted cells")
	designer.redo()
	_assert(String(designer.foreground[Vector2i(2, 0)]) == "soft_stone", "redo should restore pasted cells")

	designer.select_region(Rect2i(Vector2i(0, 0), Vector2i.ONE))
	designer.delete_selection()
	_assert(not designer.foreground.has(Vector2i(0, 0)), "delete selection should remove selected cells")
	designer.undo()
	_assert(String(designer.foreground[Vector2i(0, 0)]) == "soft_stone", "undo should restore deleted selected cells")
	designer.redo()
	_assert(not designer.foreground.has(Vector2i(0, 0)), "redo should remove selected cells again")

	designer.active_layer = "backgrounds"
	designer.select_palette_asset({"layer": "backgrounds", "kind": "background", "id": "stone_background_block", "name": "Stone Background"})
	designer.apply_pencil(Vector2i(1, 1))
	designer.select_region(Rect2i(Vector2i(1, 1), Vector2i.ONE))
	designer.move_selection(Vector2i.RIGHT)
	_assert(not designer.backgrounds.has(Vector2i(1, 1)) and String(designer.backgrounds[Vector2i(2, 1)]) == "stone_background_block", "move selection should shift selected cells")
	designer.undo()
	_assert(String(designer.backgrounds[Vector2i(1, 1)]) == "stone_background_block" and not designer.backgrounds.has(Vector2i(2, 1)), "undo should restore moved cells to their source")
	designer.redo()
	_assert(String(designer.backgrounds[Vector2i(2, 1)]) == "stone_background_block", "redo should reapply moved cells")

	var size_before := designer.canvas_size
	designer.resize_canvas(10, 7)
	_assert(designer.canvas_size == Vector2i(10, 7), "resize should update canvas size")
	designer.undo()
	_assert(designer.canvas_size == size_before, "undo should restore previous canvas size")
	designer.redo()
	_assert(designer.canvas_size == Vector2i(10, 7), "redo should restore resized canvas size")

	var anchor_before := designer.anchor_tile
	designer.set_template_anchor(Vector2i(3, 4))
	_assert(designer.anchor_tile == Vector2i(3, 4), "anchor edit should update template anchor")
	designer.undo()
	_assert(designer.anchor_tile == anchor_before, "undo should restore previous anchor")
	designer.redo()
	_assert(designer.anchor_tile == Vector2i(3, 4), "redo should restore anchor edit")

	designer.select_palette_asset({"layer": "props", "kind": "decoration", "id": "dwarf_back_house_lit", "name": "Dwarf Back House Lit"})
	designer.apply_pencil(Vector2i(0, 3))
	designer.select_region(Rect2i(Vector2i(0, 3), Vector2i.ONE))
	designer.prop_kind_edit = LineEdit.new()
	designer.add_child(designer.prop_kind_edit)
	designer.prop_kind_edit.text = "container"
	designer.prop_draw_layer_option = OptionButton.new()
	designer.add_child(designer.prop_draw_layer_option)
	designer.prop_draw_layer_option.add_item("foreground")
	designer.prop_draw_layer_option.add_item("backdrop")
	designer.prop_draw_layer_option.select(0)
	designer.prop_width_spin = SpinBox.new()
	designer.add_child(designer.prop_width_spin)
	designer.prop_width_spin.max_value = PrefabDesignerController.MAX_CANVAS_SIZE
	designer.prop_width_spin.value = 2
	designer.prop_height_spin = SpinBox.new()
	designer.add_child(designer.prop_height_spin)
	designer.prop_height_spin.max_value = PrefabDesignerController.MAX_CANVAS_SIZE
	designer.prop_height_spin.value = 2
	designer.prop_alpha_spin = SpinBox.new()
	designer.add_child(designer.prop_alpha_spin)
	designer.prop_alpha_spin.max_value = 1.0
	designer.prop_alpha_spin.step = 0.01
	designer.prop_alpha_spin.value = 0.5
	designer.apply_prop_metadata_to_selection()
	var edited_prop: Dictionary = designer.props[Vector2i(0, 3)]
	_assert(String(edited_prop.kind) == "container" and int(edited_prop.size[0]) == 2 and absf(float(edited_prop.alpha) - 0.5) < 0.001, "prop metadata edit should update selected props")
	designer.undo()
	var restored_prop: Dictionary = designer.props[Vector2i(0, 3)]
	_assert(String(restored_prop.kind) == "decoration" and int(restored_prop.size[0]) == 3, "undo should restore previous prop metadata")
	designer.redo()
	edited_prop = designer.props[Vector2i(0, 3)]
	_assert(String(edited_prop.kind) == "container", "redo should restore prop metadata edits")

	designer.undo()
	designer.apply_pencil(Vector2i(4, 4))
	_assert(designer.redo_stack.is_empty(), "new edits after undo should clear redo history")
	var metadata_path := "user://templates/metadata_history_test.json"
	_remove_file(metadata_path)
	var previous_id := designer.template_id
	designer.id_edit = LineEdit.new()
	designer.add_child(designer.id_edit)
	designer.id_edit.text = "metadata_history_test"
	_assert(designer.save_to_path(metadata_path), "test setup should save after a metadata control edit")
	_assert(designer.template_id == "metadata_history_test", "saving should pull template metadata controls into saved state")
	designer.undo()
	_assert(designer.template_id == previous_id and designer.id_edit.text == previous_id, "undo should restore template metadata from before save")
	_remove_file(metadata_path)
	_assert(not designer.undo_stack.is_empty(), "test setup should have undo history before load")
	designer.load_template_data(_small_template())
	_assert(designer.undo_stack.is_empty() and designer.redo_stack.is_empty(), "loading a template should clear undo and redo history")
	designer.free()

func _test_designer_scene_loads_palette() -> void:
	var scene: PackedScene = load("res://scenes/PrefabDesigner.tscn")
	var designer = scene.instantiate()
	get_root().add_child(designer)
	await process_frame
	_assert(designer is PrefabDesignerController, "PrefabDesigner scene should instantiate the designer controller")
	_assert(designer.palette_list != null and designer.palette_list.item_count > 0, "PrefabDesigner scene should build a searchable asset palette")
	_assert(designer.canvas_frame != null and bool(designer.canvas_frame.clip_contents), "PrefabDesigner scene should clip the pixel canvas inside a fixed frame")
	_assert(designer.canvas_view != null and designer.canvas_view.get_parent() == designer.canvas_frame, "DesignerCanvasView should be parented inside the clipped canvas frame")
	_assert(designer.canvas_v_scrollbar != null and designer.canvas_h_scrollbar != null, "PrefabDesigner scene should expose visible canvas scrollbars")
	_assert(designer.canvas_v_scrollbar.get_parent().name == "CanvasVerticalScroll" and designer.canvas_h_scrollbar.get_parent().name == "CanvasHorizontalScroll", "canvas scrollbars should live on the canvas sides")
	var canvas_rect: Rect2 = designer.canvas_view.get_rect()
	designer.set_canvas_view(PrefabDesignerController.MAX_CANVAS_ZOOM, Vector2(-3000, -2000))
	_assert(designer.canvas_view.get_rect() == canvas_rect, "large zoom and pan values should not change the fixed canvas control bounds")
	designer.set_canvas_view(2.0, Vector2.ZERO)
	designer._on_canvas_h_scrollbar_changed(64.0)
	designer._on_canvas_v_scrollbar_changed(48.0)
	_assert(absf(designer.canvas_view.pan.x + 64.0) < 0.001 and absf(designer.canvas_view.pan.y + 48.0) < 0.001, "dragging canvas scrollbars should pan the fixed viewport")
	_assert(designer.undo_button != null and designer.redo_button != null, "PrefabDesigner scene should expose undo and redo buttons")
	_assert(designer.prop_kind_edit != null and designer.prop_draw_layer_option != null and designer.prop_alpha_spin != null, "PrefabDesigner scene should expose prop metadata controls")
	designer.queue_free()

func _test_template_worldgen_replaces_live_goblin_stamping() -> void:
	PrefabTemplateRegistry.clear_cache()
	var structure := _find_first_template_structure(133742)
	_assert(not structure.is_empty(), "template registry should spawn at least one goblin village prefab")
	_assert(String(structure.get("source_template_id", "")) == "goblin_village_full", "worldgen goblin village should come from the imported template")
	_assert(not structure.has("buildings"), "template-backed worldgen structures should not expose live procedural building instances")
	_assert(Dictionary(structure.tiles).size() > 0 and Dictionary(structure.backgrounds).size() > 0, "template-backed structure should expose tile and background overlays")
	var center: Vector2i = structure.rect.position + structure.rect.size / 2
	var spawns := StructureGenerator.get_structure_spawns_near(133742, center, 96)
	_assert(spawns.size() >= 3, "template-backed goblin village should expose nearby hostile spawn markers")
	var lights := StructureGenerator.get_structure_lights_near(133742, center, 96)
	_assert(lights.size() > 0, "template-backed goblin village should expose light markers from torch props")
	var sample_tile := _first_non_air_tile(structure)
	_assert(sample_tile != Vector2i(999999, 999999), "template-backed structure should include at least one solid foreground sample")
	var store_a := ChunkStore.new(133742)
	var store_b := ChunkStore.new(133742)
	var chunk := store_a.to_chunk_coord(sample_tile)
	store_b.get_tile(sample_tile + Vector2i(32, 0))
	_assert(store_a.get_tile(sample_tile) == String(structure.tiles[sample_tile]), "template overlay should apply to foreground chunk generation")
	_assert(store_b.get_tile(sample_tile) == store_a.get_tile(sample_tile), "template foreground overlay should be stable regardless of neighboring chunk generation order")

func _test_template_band_precheck_covers_multiple_depths() -> void:
	PrefabTemplateRegistry.clear_cache()
	_assert(PrefabTemplateRegistry.has_enabled_template_near_rect(Rect2i(Vector2i(0, 120), Vector2i(64, 64))), "template precheck should include Band 1 goblin villages")
	_assert(PrefabTemplateRegistry.has_enabled_template_near_rect(Rect2i(Vector2i(0, 520), Vector2i(64, 64))), "template precheck should include Band 2 dwarf fortresses")
	_assert(not PrefabTemplateRegistry.has_enabled_template_near_rect(Rect2i(Vector2i(0, -512), Vector2i(64, 64))), "template precheck should skip far-above-surface camera windows")
	_assert(not PrefabTemplateRegistry.has_enabled_template_near_rect(Rect2i(Vector2i(0, 920), Vector2i(64, 64))), "template precheck should skip bands with no enabled templates")

func _find_first_template_structure(seed: int) -> Dictionary:
	for chunk_y in range(0, 12):
		for chunk_x in range(-18, 19):
			for structure in StructureGenerator.get_structures_overlapping_chunk(seed, Vector2i(chunk_x, chunk_y)):
				if String(structure.get("source_template_id", "")) == "goblin_village_full":
					return structure
	return {}

func _small_template() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "round_trip_prefab_test",
		"name": "Round Trip Prefab Test",
		"size": {"x": 6, "y": 5},
		"anchor": {"x": 3, "y": 4},
		"metadata": {
			"bands": ["standard_caverns"],
			"rarity": 1.0,
			"enabled": true,
			"allow_mirror_x": false,
			"allow_mirror_y": false,
			"allow_rotation": false,
			"tags": ["test"],
			"spawn_region_size": {"x": 96, "y": 56},
			"structure_type": "test_prefab",
		},
		"layers": {
			"foreground": [
				{"x": 1, "y": 1, "id": "soft_stone"},
				{"x": 2, "y": 1, "id": "air"},
			],
			"backgrounds": [
				{"x": 1, "y": 1, "id": "stone_background_block"},
				{"x": 2, "y": 1, "id": "empty"},
			],
			"props": [
				{"x": 3, "y": 2, "id": "chest_closed", "kind": "container", "size": [1, 1], "offset": [0, 0], "draw_layer": "foreground", "alpha": 1.0},
				{"x": 1, "y": 3, "id": "goblin_torch", "kind": "light", "size": [1, 1], "offset": [0, 0], "draw_layer": "foreground", "alpha": 1.0},
			],
			"spawns": [
				{"x": 4, "y": 3, "enemy_id": "goblin_grunt"},
			],
		},
	}

func _template_has_cell(entries: Array, tile: Vector2i, id: String) -> bool:
	for entry in entries:
		if int(entry.x) == tile.x and int(entry.y) == tile.y and String(entry.id) == id:
			return true
	return false

func _remove_file(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)

func _first_non_air_tile(structure: Dictionary) -> Vector2i:
	for tile in Dictionary(structure.tiles).keys():
		var tile_coord: Vector2i = tile
		if String(structure.tiles[tile_coord]) != "air":
			return tile_coord
	return Vector2i(999999, 999999)
