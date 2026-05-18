extends SceneTree

const VillageCatalog = preload("res://scripts/catalogs/VillageCatalog.gd")
const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_drow_village_metadata()
	_test_goblin_village_metadata()
	_test_drow_assets_exist()
	_test_goblin_assets_exist()
	_test_building_templates_are_valid()
	if failures.is_empty():
		print("Deepbound Godot village template tests passed.")
		quit(0)
	else:
		print("Deepbound Godot village template tests failed: %d" % failures.size())
		quit(1)

func _test_drow_village_metadata() -> void:
	var village := VillageCatalog.get_village("drow_village")
	_assert(not village.is_empty(), "drow village template should exist")
	_assert(String(village.band) == "drow_enclaves", "drow village should belong to Band 4 Drow Enclaves")
	_assert(int(village.tile_y_range[0]) == 1152 and int(village.tile_y_range[1]) == 1535, "drow village should stay inside Band 4 tile range")
	_assert(village.building_order.size() >= 6, "drow village should define a full settlement building roster")
	_assert(village.required_tiles.has("glow_mushroom_loam"), "drow village should use native Band 4 ground material")

func _test_goblin_village_metadata() -> void:
	var village := VillageCatalog.get_village("goblin_village")
	_assert(not village.is_empty(), "goblin village template should exist")
	_assert(String(village.band) == "standard_caverns", "goblin village should belong to Band 1 Standard Caverns")
	_assert(int(village.tile_y_range[0]) == 48 and int(village.tile_y_range[1]) == 340, "goblin villages should stay inside the safe Band 1 generation range")
	_assert(village.required_buildings.has("goblin_hub"), "goblin village should require an empty hub")
	_assert(village.required_buildings.has("goblin_village_chamber"), "goblin village should require a main chamber")
	_assert(village.optional_buildings.size() >= 5, "goblin village should define a varied hostile building roster")

func _test_drow_assets_exist() -> void:
	var village := VillageCatalog.get_village("drow_village")
	for tile_id in village.required_tiles:
		var tile_def := TileCatalog.get_tile(String(tile_id))
		_assert(String(tile_def.name) != "Air", "required drow tile should be in TileCatalog: %s" % tile_id)
		_assert(FileAccess.file_exists("res://assets/tiles/%s.png" % tile_id), "required drow tile PNG should exist: %s" % tile_id)
	for prop_id in village.required_props:
		_assert(FileAccess.file_exists("res://assets/props/%s.png" % prop_id), "required drow prop PNG should exist: %s" % prop_id)
	_assert(FileAccess.file_exists("res://assets/previews/drow_village_kit_preview.png"), "drow village preview atlas should exist")

func _test_goblin_assets_exist() -> void:
	var village := VillageCatalog.get_village("goblin_village")
	for tile_id in village.required_tiles:
		var tile_def := TileCatalog.get_tile(String(tile_id))
		_assert(String(tile_def.name) != "Air", "required goblin tile should be in TileCatalog: %s" % tile_id)
		_assert(FileAccess.file_exists("res://assets/tiles/%s.png" % tile_id), "required goblin tile PNG should exist: %s" % tile_id)
	for prop_id in village.required_props:
		_assert(FileAccess.file_exists("res://assets/props/%s.png" % prop_id), "required goblin prop PNG should exist: %s" % prop_id)
	_assert(FileAccess.file_exists("res://assets/previews/goblin_village_kit_preview.png"), "goblin village preview atlas should exist")

func _test_building_templates_are_valid() -> void:
	for village_id in ["drow_village", "goblin_village"]:
		var village := VillageCatalog.get_village(village_id)
		var legend: Dictionary = village.symbol_legend
		for building_id in village.building_order:
			var building := VillageCatalog.get_building(String(building_id))
			_assert(not building.is_empty(), "building template should exist: %s" % building_id)
			var footprint: Array = building.footprint
			var layout: Array = building.layout
			_assert(layout.size() == int(footprint[1]), "%s layout row count should match footprint height" % building_id)
			for row in layout:
				var row_text := String(row)
				_assert(row_text.length() == int(footprint[0]), "%s row width should match footprint width: %s" % [building_id, row_text])
				for index in range(row_text.length()):
					var symbol := row_text.substr(index, 1)
					_assert(legend.has(symbol), "%s uses undefined symbol '%s'" % [building_id, symbol])
			for tile_id in building.required_tiles:
				_assert(village.required_tiles.has(tile_id), "%s required tile should be listed by village: %s" % [building_id, tile_id])
			for prop_id in building.required_props:
				_assert(village.required_props.has(prop_id), "%s required prop should be listed by village: %s" % [building_id, prop_id])
