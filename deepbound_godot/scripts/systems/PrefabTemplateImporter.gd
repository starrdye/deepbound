extends RefCounted
class_name PrefabTemplateImporter

const StructureGenerator = preload("res://scripts/systems/StructureGenerator.gd")
const PrefabTemplateRegistry = preload("res://scripts/systems/PrefabTemplateRegistry.gd")

const DEFAULT_GOBLIN_TEMPLATE_PATH := "res://data/templates/goblin_village_full.json"
const DEFAULT_IMPORT_SEED := 133742

static func ensure_builtin_goblin_template(path := DEFAULT_GOBLIN_TEMPLATE_PATH) -> bool:
	if FileAccess.file_exists(path):
		return true
	return import_current_goblin_village(path, true)

static func import_current_goblin_village(path := DEFAULT_GOBLIN_TEMPLATE_PATH, overwrite := false) -> bool:
	if FileAccess.file_exists(path) and not overwrite:
		return true
	var region := find_first_goblin_village_region(DEFAULT_IMPORT_SEED)
	if region == Vector2i(999999, 999999):
		push_error("Unable to import goblin village template; no village generated for seed %d." % DEFAULT_IMPORT_SEED)
		return false
	var structure := StructureGenerator.build_goblin_village(DEFAULT_IMPORT_SEED, region)
	if structure.is_empty():
		push_error("Unable to import goblin village template; generated village was empty.")
		return false
	var template := build_template_from_structure(structure, region)
	return PrefabTemplateRegistry.save_template(template, path)

static func build_template_from_structure(structure: Dictionary, region: Vector2i) -> Dictionary:
	var rect: Rect2i = structure.rect
	var anchor := Vector2i(rect.size.x / 2, rect.size.y - 1)
	var region_origin := Vector2i(region.x * StructureGenerator.REGION_SIZE.x, region.y * StructureGenerator.REGION_SIZE.y)
	var world_anchor := rect.position + anchor
	var foreground: Array[Dictionary] = []
	for tile in Dictionary(structure.tiles).keys():
		var tile_coord: Vector2i = tile
		foreground.append({"x": tile_coord.x - rect.position.x, "y": tile_coord.y - rect.position.y, "id": String(structure.tiles[tile_coord])})
	var backgrounds: Array[Dictionary] = []
	for tile in Dictionary(structure.get("backgrounds", {})).keys():
		var tile_coord: Vector2i = tile
		backgrounds.append({"x": tile_coord.x - rect.position.x, "y": tile_coord.y - rect.position.y, "id": String(structure.backgrounds[tile_coord])})
	var props: Array[Dictionary] = []
	for marker in structure.get("props", []):
		var prop: Dictionary = Dictionary(marker)
		var tile: Vector2i = prop.tile
		var entry := {
			"x": tile.x - rect.position.x,
			"y": tile.y - rect.position.y,
			"id": String(prop.id),
			"kind": _prop_kind(String(prop.id)),
			"size": _array_from_value(prop.get("size", [1, 1])),
			"offset": _array_from_value(prop.get("offset", [0, 0])),
			"draw_layer": String(prop.get("layer", "foreground")),
			"alpha": float(prop.get("alpha", 1.0)),
		}
		props.append(entry)
	var spawns: Array[Dictionary] = []
	for marker in structure.get("spawns", []):
		var spawn: Dictionary = Dictionary(marker)
		var tile: Vector2i = spawn.tile
		spawns.append({"x": tile.x - rect.position.x, "y": tile.y - rect.position.y, "enemy_id": String(spawn.enemy_id)})
	foreground.sort_custom(_sort_tile_entries)
	backgrounds.sort_custom(_sort_tile_entries)
	props.sort_custom(_sort_tile_entries)
	spawns.sort_custom(_sort_tile_entries)
	return {
		"schema_version": PrefabTemplateRegistry.SCHEMA_VERSION,
		"id": "goblin_village_full",
		"name": "Goblin Village Full",
		"size": {"x": rect.size.x, "y": rect.size.y},
		"anchor": {"x": anchor.x, "y": anchor.y},
		"metadata": {
			"bands": ["standard_caverns"],
			"rarity": StructureGenerator.VILLAGE_CHANCE,
			"enabled": true,
			"allow_mirror_x": true,
			"allow_mirror_y": false,
			"allow_rotation": false,
			"tags": ["goblin", "village"],
			"spawn_region_size": {"x": StructureGenerator.REGION_SIZE.x, "y": StructureGenerator.REGION_SIZE.y},
			"spawn_anchor_offset": {"x": world_anchor.x - region_origin.x, "y": world_anchor.y - region_origin.y},
			"source_region": {"x": region.x, "y": region.y},
			"structure_type": "goblin_village",
		},
		"layers": {
			"foreground": foreground,
			"backgrounds": backgrounds,
			"props": props,
			"spawns": spawns,
		},
	}

static func find_first_goblin_village_region(seed: int) -> Vector2i:
	for ry in range(1, 7):
		for rx in range(-8, 9):
			var region := Vector2i(rx, ry)
			if not StructureGenerator.build_goblin_village(seed, region).is_empty():
				return region
	return Vector2i(999999, 999999)

static func _prop_kind(prop_id: String) -> String:
	if prop_id in ["chest_closed", "chest_open", "chest_open_sheet"]:
		return "container"
	if prop_id.find("torch") >= 0 or prop_id.find("lantern") >= 0 or prop_id.find("lamp") >= 0 or prop_id in ["flare", "outpost_beacon"]:
		return "light"
	return "decoration"

static func _array_from_value(value) -> Array[int]:
	if value is Vector2i:
		return [value.x, value.y]
	if value is Array and value.size() >= 2:
		return [int(value[0]), int(value[1])]
	if value is Dictionary:
		return [int(value.get("x", 0)), int(value.get("y", 0))]
	return [0, 0]

static func _sort_tile_entries(a: Dictionary, b: Dictionary) -> bool:
	if int(a.y) == int(b.y):
		if int(a.x) == int(b.x):
			return String(a.get("id", a.get("enemy_id", ""))) < String(b.get("id", b.get("enemy_id", "")))
		return int(a.x) < int(b.x)
	return int(a.y) < int(b.y)
