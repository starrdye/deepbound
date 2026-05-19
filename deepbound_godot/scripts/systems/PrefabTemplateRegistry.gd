extends RefCounted
class_name PrefabTemplateRegistry

const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")
const BackgroundCatalog = preload("res://scripts/catalogs/BackgroundCatalog.gd")
const EnemyCatalog = preload("res://scripts/catalogs/EnemyCatalog.gd")
const BandCatalog = preload("res://scripts/catalogs/BandCatalog.gd")

const BUILTIN_TEMPLATE_DIR := "res://data/templates"
const USER_TEMPLATE_DIR := "user://templates"
const SCHEMA_VERSION := 1
const CHUNK_SIZE := 32
const DEFAULT_REGION_SIZE := Vector2i(96, 56)
const DEFAULT_PADDING_TILES := 8
const STARTER_AVOID_RECT := Rect2i(Vector2i(-40, 0), Vector2i(80, 48))
const TEMPLATE_SEARCH_MARGIN := 128

static var cached_templates: Dictionary = {}
static var cache_loaded := false
static var validation_errors_enabled := true
static var structure_region_cache: Dictionary = {}
static var chunk_structure_cache: Dictionary = {}
static var near_query_cache: Dictionary = {}
static var debug_perf_enabled := false
static var debug_perf_counters: Dictionary = {}

static func clear_cache() -> void:
	cached_templates.clear()
	cache_loaded = false
	clear_runtime_structure_cache()

static func set_validation_errors_enabled(enabled: bool) -> void:
	validation_errors_enabled = enabled

static func clear_runtime_structure_cache() -> void:
	structure_region_cache.clear()
	chunk_structure_cache.clear()
	near_query_cache.clear()

static func enable_debug_perf_counters(enabled := true) -> void:
	debug_perf_enabled = enabled
	if enabled:
		debug_perf_counters.clear()

static func reset_debug_perf_counters() -> void:
	debug_perf_enabled = true
	debug_perf_counters.clear()

static func get_debug_perf_counter(counter_name: String) -> int:
	return int(debug_perf_counters.get(counter_name, 0))

static func load_builtin_templates() -> Array[Dictionary]:
	return _load_templates_from_dir(BUILTIN_TEMPLATE_DIR)

static func load_user_templates() -> Array[Dictionary]:
	return _load_templates_from_dir(USER_TEMPLATE_DIR)

static func load_templates(include_user := true) -> Array[Dictionary]:
	var by_id := {}
	for template in load_builtin_templates():
		by_id[String(template.id)] = template
	if include_user:
		for template in load_user_templates():
			by_id[String(template.id)] = template
	var templates: Array[Dictionary] = []
	var ids := by_id.keys()
	ids.sort()
	for template_id in ids:
		templates.append(by_id[template_id])
	return templates

static func loaded_templates() -> Array[Dictionary]:
	if not cache_loaded:
		cached_templates.clear()
		for template in load_templates(true):
			cached_templates[String(template.id)] = template
		cache_loaded = true
	var templates: Array[Dictionary] = []
	var ids := cached_templates.keys()
	ids.sort()
	for template_id in ids:
		templates.append(cached_templates[template_id])
	return templates

static func load_template(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Prefab template file does not exist: %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("Prefab template JSON root must be an object: %s" % path)
		return {}
	var template := validate_template(Dictionary(parsed))
	if template.is_empty():
		push_error("Prefab template failed validation: %s" % path)
		return {}
	template["_path"] = path
	return template

static func save_template(template: Dictionary, path: String) -> bool:
	var normalized := validate_template(template)
	if normalized.is_empty():
		return false
	_ensure_parent_dir(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to open prefab template for write: %s" % path)
		return false
	file.store_string(JSON.stringify(_strip_runtime_keys(normalized), "\t", true))
	file.store_string("\n")
	clear_cache()
	return true

static func validate_template(template: Dictionary) -> Dictionary:
	for key in ["schema_version", "id", "name", "size", "anchor", "metadata", "layers"]:
		if not template.has(key):
			_validation_error("Prefab template missing required field: %s" % key)
			return {}
	if int(template.schema_version) != SCHEMA_VERSION:
		_validation_error("Unsupported prefab template schema version: %s" % str(template.schema_version))
		return {}
	var template_id := String(template.id).strip_edges()
	if template_id == "":
		_validation_error("Prefab template id cannot be empty.")
		return {}
	var size := _parse_vector2i(template.size, Vector2i.ZERO)
	if size.x < 1 or size.y < 1 or size.x > 256 or size.y > 256:
		_validation_error("Prefab template size must be between 1x1 and 256x256: %s" % template_id)
		return {}
	var anchor := _parse_vector2i(template.anchor, Vector2i(-999999, -999999))
	if not _local_tile_in_size(anchor, size):
		_validation_error("Prefab template anchor is outside the canvas: %s" % template_id)
		return {}
	var metadata := _validate_metadata(Dictionary(template.metadata), template_id)
	if metadata.is_empty():
		return {}
	var layers = template.layers
	if not (layers is Dictionary):
		_validation_error("Prefab template layers must be an object: %s" % template_id)
		return {}
	var layer_dict := Dictionary(layers)
	var foreground = _validate_cell_layer(layer_dict.get("foreground", []), size, "foreground", template_id)
	var backgrounds = _validate_cell_layer(layer_dict.get("backgrounds", []), size, "backgrounds", template_id)
	var props = _validate_prop_layer(layer_dict.get("props", []), size, template_id)
	var spawns = _validate_spawn_layer(layer_dict.get("spawns", []), size, template_id)
	if foreground == null or backgrounds == null or props == null or spawns == null:
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"id": template_id,
		"name": String(template.name),
		"size": _vec_to_dict(size),
		"anchor": _vec_to_dict(anchor),
		"metadata": metadata,
		"layers": {
			"foreground": foreground,
			"backgrounds": backgrounds,
			"props": props,
			"spawns": spawns,
		},
	}

static func get_palette_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	entries.append({"kind": "foreground", "id": "air", "name": "Air / Carve", "layer": "foreground"})
	for tile_id in _sorted_keys(TileCatalog.TILES):
		var id := String(tile_id)
		if id == "air":
			continue
		var tile_def: Dictionary = TileCatalog.get_tile(id)
		entries.append({"kind": "foreground", "id": id, "name": String(tile_def.name), "layer": "foreground"})
	entries.append({"kind": "background", "id": BackgroundCatalog.EMPTY_ID, "name": "No Background / Clear", "layer": "backgrounds"})
	for background_id in _sorted_keys(BackgroundCatalog.BACKGROUNDS):
		var id := String(background_id)
		if id == BackgroundCatalog.EMPTY_ID:
			continue
		var background_def: Dictionary = BackgroundCatalog.get_background(id)
		entries.append({"kind": "background", "id": id, "name": String(background_def.name), "layer": "backgrounds"})
	for prop_id in get_prop_ids():
		entries.append({
			"kind": _prop_kind(prop_id),
			"id": prop_id,
			"name": _title_from_id(prop_id),
			"layer": "props",
			"size": _prop_size_tiles(prop_id),
			"draw_layer": _prop_default_draw_layer(prop_id),
			"alpha": _prop_default_alpha(prop_id),
		})
	for enemy_id in _sorted_keys(EnemyCatalog.ENEMIES):
		var enemy_def: Dictionary = EnemyCatalog.get_enemy(String(enemy_id))
		entries.append({"kind": "spawn", "id": String(enemy_id), "name": "%s Spawn" % String(enemy_def.name), "layer": "spawns"})
	return entries

static func get_prop_ids() -> Array[String]:
	var ids: Array[String] = []
	var dir := DirAccess.open("res://assets/props")
	if dir == null:
		return ids
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "png":
			ids.append(file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()
	ids.sort()
	return ids

static func get_structures_overlapping_chunk(seed: int, chunk: Vector2i) -> Array[Dictionary]:
	_record_perf_event("structure_chunk_query")
	var cache_key := _chunk_cache_key(seed, chunk)
	if chunk_structure_cache.has(cache_key):
		_record_perf_event("structure_chunk_cache_hit")
		return chunk_structure_cache[cache_key]
	_record_perf_event("structure_chunk_cache_miss")
	var chunk_rect := Rect2i(Vector2i(chunk.x * CHUNK_SIZE, chunk.y * CHUNK_SIZE), Vector2i(CHUNK_SIZE, CHUNK_SIZE))
	var structures := _get_structures_intersecting_rect(seed, chunk_rect)
	chunk_structure_cache[cache_key] = structures
	return structures

static func has_enabled_template_near_rect(rect: Rect2i) -> bool:
	var query_min_y := rect.position.y
	var query_max_y := rect.position.y + rect.size.y - 1
	for template in loaded_templates():
		if not bool(Dictionary(template.metadata).get("enabled", true)):
			continue
		var bands: Array = Dictionary(template.metadata).get("bands", [])
		if bands.is_empty():
			return true
		var template_size := _template_size(template)
		var y_margin := maxi(TEMPLATE_SEARCH_MARGIN, maxi(template_size.x, template_size.y) + DEFAULT_PADDING_TILES)
		var padded_min_y := query_min_y - y_margin
		var padded_max_y := query_max_y + y_margin
		for band_id in bands:
			if not BandCatalog.BANDS.has(String(band_id)):
				continue
			var band: Dictionary = BandCatalog.BANDS[String(band_id)]
			var band_min_y := int(band.min_y)
			var raw_max_y = band.get("max_y", null)
			var band_max_y := padded_max_y if raw_max_y == null else int(raw_max_y)
			if padded_min_y <= band_max_y and padded_max_y >= band_min_y:
				return true
	return false

static func get_structure_spawns_near(seed: int, center_tile: Vector2i, radius_tiles: int) -> Array[Dictionary]:
	var cache_key := _near_cache_key(seed, "spawns", center_tile, radius_tiles)
	if near_query_cache.has(cache_key):
		_record_perf_event("structure_near_cache_hit")
		return near_query_cache[cache_key]
	_record_perf_event("structure_near_cache_miss")
	var search_rect := Rect2i(center_tile - Vector2i(radius_tiles, radius_tiles), Vector2i(radius_tiles * 2 + 1, radius_tiles * 2 + 1))
	var results: Array[Dictionary] = []
	for structure in _get_structures_intersecting_rect(seed, search_rect):
		for spawn in structure.get("spawns", []):
			var tile: Vector2i = spawn.tile
			if not _rect_contains_tile(search_rect, tile):
				continue
			var record: Dictionary = Dictionary(spawn).duplicate(true)
			record.structure_id = String(structure.id)
			record.structure_type = String(structure.type)
			record.position = Vector2((float(tile.x) + 0.5) * 16.0, float((tile.y + 1) * 16) - 0.5)
			results.append(record)
	near_query_cache[cache_key] = results
	return results

static func get_structure_lights_near(seed: int, center_tile: Vector2i, radius_tiles: int) -> Array[Dictionary]:
	var cache_key := _near_cache_key(seed, "lights", center_tile, radius_tiles)
	if near_query_cache.has(cache_key):
		_record_perf_event("structure_near_cache_hit")
		return near_query_cache[cache_key]
	_record_perf_event("structure_near_cache_miss")
	var search_rect := Rect2i(center_tile - Vector2i(radius_tiles, radius_tiles), Vector2i(radius_tiles * 2 + 1, radius_tiles * 2 + 1))
	var results: Array[Dictionary] = []
	for structure in _get_structures_intersecting_rect(seed, search_rect):
		for light in structure.get("lights", []):
			var tile: Vector2i = light.tile
			if _rect_contains_tile(search_rect, tile):
				results.append(Dictionary(light).duplicate(true))
	near_query_cache[cache_key] = results
	return results

static func get_structure_containers_near(seed: int, center_tile: Vector2i, radius_tiles: int) -> Array[Dictionary]:
	var cache_key := _near_cache_key(seed, "containers", center_tile, radius_tiles)
	if near_query_cache.has(cache_key):
		_record_perf_event("structure_near_cache_hit")
		return near_query_cache[cache_key]
	_record_perf_event("structure_near_cache_miss")
	var search_rect := Rect2i(center_tile - Vector2i(radius_tiles, radius_tiles), Vector2i(radius_tiles * 2 + 1, radius_tiles * 2 + 1))
	var results: Array[Dictionary] = []
	for structure in _get_structures_intersecting_rect(seed, search_rect):
		for container in structure.get("containers", []):
			var tile: Vector2i = container.tile
			if _rect_contains_tile(search_rect, tile):
				results.append(Dictionary(container).duplicate(true))
	near_query_cache[cache_key] = results
	return results

static func instantiate_template(template: Dictionary, world_anchor_tile: Vector2i, transform := {}) -> Dictionary:
	var size := _template_size(template)
	var anchor := _template_anchor(template)
	var transform_dict := Dictionary(transform)
	var transformed_anchor := _transform_point(anchor, size, transform_dict)
	var origin := world_anchor_tile - transformed_anchor
	return _template_to_structure(template, origin, transform_dict, Vector2i(999999, 999999))

static func _get_structures_intersecting_rect(seed: int, rect: Rect2i) -> Array[Dictionary]:
	var structures: Array[Dictionary] = []
	for template in loaded_templates():
		if not bool(Dictionary(template.metadata).get("enabled", true)):
			continue
		var region_size := _spawn_region_size(template)
		var margin := maxi(TEMPLATE_SEARCH_MARGIN, maxi(_template_size(template).x, _template_size(template).y) + DEFAULT_PADDING_TILES)
		var min_region := Vector2i(floori(float(rect.position.x - margin) / float(region_size.x)), floori(float(rect.position.y - margin) / float(region_size.y)))
		var max_region := Vector2i(floori(float(rect.position.x + rect.size.x + margin) / float(region_size.x)), floori(float(rect.position.y + rect.size.y + margin) / float(region_size.y)))
		for ry in range(min_region.y, max_region.y + 1):
			for rx in range(min_region.x, max_region.x + 1):
				var structure := _instantiate_template_for_region(seed, template, Vector2i(rx, ry), region_size)
				if structure.is_empty() or not _rects_intersect(structure.rect, rect):
					continue
				structures.append(structure)
	return structures

static func _instantiate_template_for_region(seed: int, template: Dictionary, region_coord: Vector2i, region_size: Vector2i) -> Dictionary:
	var cache_key := _region_cache_key(seed, String(template.id), region_coord)
	if structure_region_cache.has(cache_key):
		_record_perf_event("template_region_cache_hit")
		return structure_region_cache[cache_key]
	_record_perf_event("template_region_cache_miss")
	var region_origin := Vector2i(region_coord.x * region_size.x, region_coord.y * region_size.y)
	var region_rect := Rect2i(region_origin, region_size)
	if _rects_intersect(region_rect, STARTER_AVOID_RECT):
		structure_region_cache[cache_key] = {}
		return {}
	if not _region_could_match_bands(region_rect, template):
		structure_region_cache[cache_key] = {}
		return {}
	if _roll01(seed, region_coord, 5) > clampf(float(Dictionary(template.metadata).get("rarity", 1.0)), 0.0, 1.0):
		structure_region_cache[cache_key] = {}
		return {}
	var region_center := Vector2i(region_size.x / 2, region_size.y / 2)
	var anchor_offset := _parse_vector2i(Dictionary(template.metadata).get("spawn_anchor_offset", _vec_to_dict(region_center)), region_center)
	var world_anchor := region_origin + anchor_offset
	var transform := _choose_transform(seed, template, region_coord)
	var structure := instantiate_template(template, world_anchor, transform)
	structure.region = region_coord
	if not _structure_matches_bands(structure, template):
		structure_region_cache[cache_key] = {}
		return {}
	if _rects_intersect(structure.rect, STARTER_AVOID_RECT):
		structure_region_cache[cache_key] = {}
		return {}
	structure_region_cache[cache_key] = structure
	return structure

static func _template_to_structure(template: Dictionary, origin: Vector2i, transform: Dictionary, region_coord: Vector2i) -> Dictionary:
	var size := _template_size(template)
	var tiles: Dictionary = {}
	var backgrounds: Dictionary = {}
	var props: Array[Dictionary] = []
	var spawns: Array[Dictionary] = []
	var lights: Array[Dictionary] = []
	var containers: Array[Dictionary] = []
	for entry in Dictionary(template.layers).foreground:
		var local := Vector2i(int(entry.x), int(entry.y))
		tiles[origin + _transform_point(local, size, transform)] = String(entry.id)
	for entry in Dictionary(template.layers).backgrounds:
		var local := Vector2i(int(entry.x), int(entry.y))
		backgrounds[origin + _transform_point(local, size, transform)] = String(entry.id)
	for entry in Dictionary(template.layers).props:
		var local := Vector2i(int(entry.x), int(entry.y))
		var world_tile := origin + _transform_point(local, size, transform)
		var prop := _world_prop_record(Dictionary(entry), world_tile, String(template.id), transform)
		props.append(prop)
		if String(prop.kind) == "container":
			var prop_size := _parse_vector2i(prop.get("size", [1, 1]), Vector2i.ONE)
			var container_tile := world_tile + Vector2i(0, maxi(0, prop_size.y - 1))
			tiles[container_tile] = "chest_block"
			containers.append({"tile": container_tile, "id": String(prop.id), "template_id": String(template.id)})
		if String(prop.kind) == "light" or _is_light_prop(String(prop.id)):
			lights.append({"tile": world_tile, "id": String(prop.id), "radius_tiles": _light_radius(String(prop.id)), "intensity": 0.72, "template_id": String(template.id)})
	for entry in Dictionary(template.layers).spawns:
		var local := Vector2i(int(entry.x), int(entry.y))
		var world_tile := origin + _transform_point(local, size, transform)
		spawns.append({"enemy_id": String(entry.enemy_id), "tile": world_tile, "template_id": String(template.id)})
	var rect := _content_rect(tiles, backgrounds, props, spawns, origin, _transformed_size(size, transform))
	var structure_type := String(Dictionary(template.metadata).get("structure_type", String(template.id)))
	return {
		"id": "template_%s_%d_%d" % [String(template.id), region_coord.x, region_coord.y],
		"type": structure_type,
		"template_id": String(template.id),
		"source_template_id": String(template.id),
		"region": region_coord,
		"rect": rect,
		"tiles": tiles,
		"backgrounds": backgrounds,
		"props": props,
		"spawns": spawns,
		"lights": lights,
		"containers": containers,
	}

static func _validate_metadata(metadata: Dictionary, template_id: String) -> Dictionary:
	for key in ["bands", "rarity", "enabled", "allow_mirror_x", "allow_mirror_y", "allow_rotation", "tags"]:
		if not metadata.has(key):
			_validation_error("Prefab template metadata missing %s: %s" % [key, template_id])
			return {}
	var bands: Array = []
	for band_id in metadata.bands:
		if not BandCatalog.BANDS.has(String(band_id)):
			_validation_error("Prefab template uses unknown band '%s': %s" % [String(band_id), template_id])
			return {}
		bands.append(String(band_id))
	var tags: Array = []
	for tag in metadata.tags:
		tags.append(String(tag))
	var normalized := {
		"bands": bands,
		"rarity": clampf(float(metadata.rarity), 0.0, 1.0),
		"enabled": bool(metadata.enabled),
		"allow_mirror_x": bool(metadata.allow_mirror_x),
		"allow_mirror_y": bool(metadata.allow_mirror_y),
		"allow_rotation": bool(metadata.allow_rotation),
		"tags": tags,
	}
	if metadata.has("spawn_region_size"):
		var region_size := _parse_vector2i(metadata.spawn_region_size, DEFAULT_REGION_SIZE)
		normalized.spawn_region_size = _vec_to_dict(Vector2i(maxi(1, region_size.x), maxi(1, region_size.y)))
	if metadata.has("spawn_anchor_offset"):
		normalized.spawn_anchor_offset = _vec_to_dict(_parse_vector2i(metadata.spawn_anchor_offset, DEFAULT_REGION_SIZE / 2))
	if metadata.has("structure_type"):
		normalized.structure_type = String(metadata.structure_type)
	if metadata.has("source_region"):
		normalized.source_region = _vec_to_dict(_parse_vector2i(metadata.source_region, Vector2i.ZERO))
	return normalized

static func _validate_cell_layer(layer_data, size: Vector2i, layer_name: String, template_id: String):
	if not (layer_data is Array):
		_validation_error("Prefab template layer must be an array: %s / %s" % [template_id, layer_name])
		return null
	var seen := {}
	var entries: Array[Dictionary] = []
	for raw_entry in layer_data:
		if not (raw_entry is Dictionary):
			_validation_error("Prefab template layer entry must be an object: %s / %s" % [template_id, layer_name])
			return null
		var entry := Dictionary(raw_entry)
		var tile := Vector2i(int(entry.get("x", -999999)), int(entry.get("y", -999999)))
		if not _local_tile_in_size(tile, size):
			_validation_error("Prefab template cell is outside bounds: %s / %s" % [template_id, layer_name])
			return null
		if seen.has(tile):
			_validation_error("Prefab template has duplicate cell: %s / %s / %s" % [template_id, layer_name, str(tile)])
			return null
		seen[tile] = true
		var id := String(entry.get("id", ""))
		if layer_name == "foreground" and not TileCatalog.TILES.has(id):
			_validation_error("Prefab template unknown foreground tile '%s': %s" % [id, template_id])
			return null
		if layer_name == "backgrounds" and not BackgroundCatalog.BACKGROUNDS.has(id):
			_validation_error("Prefab template unknown background '%s': %s" % [id, template_id])
			return null
		entries.append({"x": tile.x, "y": tile.y, "id": id})
	_sort_entries_by_tile(entries)
	return entries

static func _validate_prop_layer(layer_data, size: Vector2i, template_id: String):
	if not (layer_data is Array):
		_validation_error("Prefab template props layer must be an array: %s" % template_id)
		return null
	var seen := {}
	var entries: Array[Dictionary] = []
	for raw_entry in layer_data:
		if not (raw_entry is Dictionary):
			_validation_error("Prefab template prop entry must be an object: %s" % template_id)
			return null
		var entry := Dictionary(raw_entry)
		var tile := Vector2i(int(entry.get("x", -999999)), int(entry.get("y", -999999)))
		if not _local_tile_in_size(tile, size):
			_validation_error("Prefab template prop is outside bounds: %s" % template_id)
			return null
		var id := String(entry.get("id", ""))
		if not _prop_exists(id):
			_validation_error("Prefab template unknown prop '%s': %s" % [id, template_id])
			return null
		var duplicate_key := "%d,%d:%s" % [tile.x, tile.y, id]
		if seen.has(duplicate_key):
			_validation_error("Prefab template has duplicate prop: %s / %s" % [template_id, duplicate_key])
			return null
		seen[duplicate_key] = true
		var normalized := {
			"x": tile.x,
			"y": tile.y,
			"id": id,
			"kind": String(entry.get("kind", _prop_kind(id))),
			"size": _vec_to_array(_parse_vector2i(entry.get("size", [1, 1]), Vector2i.ONE)),
			"offset": _vec_to_array(_parse_vector2i(entry.get("offset", [0, 0]), Vector2i.ZERO)),
			"draw_layer": String(entry.get("draw_layer", entry.get("layer", "foreground"))),
			"alpha": float(entry.get("alpha", 1.0)),
		}
		entries.append(normalized)
	_sort_entries_by_tile(entries)
	return entries

static func _validate_spawn_layer(layer_data, size: Vector2i, template_id: String):
	if not (layer_data is Array):
		_validation_error("Prefab template spawns layer must be an array: %s" % template_id)
		return null
	var seen := {}
	var entries: Array[Dictionary] = []
	for raw_entry in layer_data:
		if not (raw_entry is Dictionary):
			_validation_error("Prefab template spawn entry must be an object: %s" % template_id)
			return null
		var entry := Dictionary(raw_entry)
		var tile := Vector2i(int(entry.get("x", -999999)), int(entry.get("y", -999999)))
		if not _local_tile_in_size(tile, size):
			_validation_error("Prefab template spawn is outside bounds: %s" % template_id)
			return null
		var enemy_id := String(entry.get("enemy_id", ""))
		if not EnemyCatalog.ENEMIES.has(enemy_id):
			_validation_error("Prefab template unknown enemy spawn '%s': %s" % [enemy_id, template_id])
			return null
		var duplicate_key := "%d,%d:%s" % [tile.x, tile.y, enemy_id]
		if seen.has(duplicate_key):
			_validation_error("Prefab template has duplicate spawn: %s / %s" % [template_id, duplicate_key])
			return null
		seen[duplicate_key] = true
		entries.append({"x": tile.x, "y": tile.y, "enemy_id": enemy_id})
	_sort_entries_by_tile(entries)
	return entries

static func _load_templates_from_dir(path: String) -> Array[Dictionary]:
	var templates: Array[Dictionary] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return templates
	var names: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "json":
			names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	names.sort()
	for name in names:
		var template := load_template("%s/%s" % [path, name])
		if not template.is_empty():
			templates.append(template)
	return templates

static func _choose_transform(seed: int, template: Dictionary, region_coord: Vector2i) -> Dictionary:
	var metadata: Dictionary = template.metadata
	var h := hash_i(seed ^ _stable_string_hash(String(template.id)) ^ (region_coord.x * 73856093) ^ (region_coord.y * 19349663))
	return {
		"mirror_x": bool(metadata.get("allow_mirror_x", false)) and h % 2 == 0,
		"mirror_y": bool(metadata.get("allow_mirror_y", false)) and (h / 2) % 2 == 0,
		"rotation": int(h % 4) if bool(metadata.get("allow_rotation", false)) else 0,
	}

static func _transform_point(point: Vector2i, size: Vector2i, transform: Dictionary) -> Vector2i:
	var p := point
	var current_size := size
	if bool(transform.get("mirror_x", false)):
		p.x = current_size.x - 1 - p.x
	if bool(transform.get("mirror_y", false)):
		p.y = current_size.y - 1 - p.y
	var steps := posmod(int(transform.get("rotation", 0)), 4)
	for _i in range(steps):
		p = Vector2i(current_size.y - 1 - p.y, p.x)
		current_size = Vector2i(current_size.y, current_size.x)
	return p

static func _transformed_size(size: Vector2i, transform: Dictionary) -> Vector2i:
	return Vector2i(size.y, size.x) if posmod(int(transform.get("rotation", 0)), 2) == 1 else size

static func _content_rect(tiles: Dictionary, backgrounds: Dictionary, props: Array[Dictionary], spawns: Array[Dictionary], origin: Vector2i, fallback_size: Vector2i) -> Rect2i:
	var first := true
	var min_x := origin.x
	var min_y := origin.y
	var max_x := origin.x + fallback_size.x - 1
	var max_y := origin.y + fallback_size.y - 1
	for tile in tiles.keys() + backgrounds.keys():
		var t: Vector2i = tile
		if first:
			min_x = t.x
			max_x = t.x
			min_y = t.y
			max_y = t.y
			first = false
		else:
			min_x = mini(min_x, t.x)
			max_x = maxi(max_x, t.x)
			min_y = mini(min_y, t.y)
			max_y = maxi(max_y, t.y)
	for prop in props:
		var t: Vector2i = prop.tile
		var size := _parse_vector2i(prop.get("size", [1, 1]), Vector2i.ONE)
		min_x = mini(min_x, t.x)
		min_y = mini(min_y, t.y)
		max_x = maxi(max_x, t.x + size.x - 1)
		max_y = maxi(max_y, t.y + size.y - 1)
		first = false
	for spawn in spawns:
		var t: Vector2i = spawn.tile
		min_x = mini(min_x, t.x)
		min_y = mini(min_y, t.y)
		max_x = maxi(max_x, t.x)
		max_y = maxi(max_y, t.y)
		first = false
	if first:
		return Rect2i(origin, fallback_size)
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))

static func _world_prop_record(entry: Dictionary, tile: Vector2i, template_id: String, transform: Dictionary) -> Dictionary:
	var size := _parse_vector2i(entry.get("size", [1, 1]), Vector2i.ONE)
	if posmod(int(transform.get("rotation", 0)), 2) == 1:
		size = Vector2i(size.y, size.x)
	return {
		"id": String(entry.id),
		"kind": String(entry.get("kind", _prop_kind(String(entry.id)))),
		"tile": tile,
		"template_id": template_id,
		"size": _vec_to_array(size),
		"offset": entry.get("offset", [0, 0]),
		"layer": String(entry.get("draw_layer", "foreground")),
		"alpha": float(entry.get("alpha", 1.0)),
	}

static func _structure_matches_bands(structure: Dictionary, template: Dictionary) -> bool:
	var bands: Array = Dictionary(template.metadata).get("bands", [])
	if bands.is_empty():
		return true
	var rect: Rect2i = structure.rect
	for band_id in bands:
		var band: Dictionary = BandCatalog.BANDS[String(band_id)]
		var min_y := int(band.min_y)
		var raw_max_y = band.get("max_y", null)
		var max_y := rect.position.y + rect.size.y - 1 if raw_max_y == null else int(raw_max_y)
		if rect.position.y >= min_y and rect.position.y + rect.size.y - 1 <= max_y:
			return true
	return false

static func _region_could_match_bands(region_rect: Rect2i, template: Dictionary) -> bool:
	var bands: Array = Dictionary(template.metadata).get("bands", [])
	if bands.is_empty():
		return true
	var template_size := _template_size(template)
	var search_rect := Rect2i(region_rect.position - template_size, region_rect.size + template_size * 2)
	for band_id in bands:
		var band: Dictionary = BandCatalog.BANDS[String(band_id)]
		var min_y := int(band.min_y)
		var raw_max_y = band.get("max_y", null)
		var max_y := search_rect.position.y + search_rect.size.y - 1 if raw_max_y == null else int(raw_max_y)
		if search_rect.position.y <= max_y and search_rect.position.y + search_rect.size.y - 1 >= min_y:
			return true
	return false

static func _spawn_region_size(template: Dictionary) -> Vector2i:
	var metadata: Dictionary = template.metadata
	if metadata.has("spawn_region_size"):
		return _parse_vector2i(metadata.spawn_region_size, DEFAULT_REGION_SIZE)
	var size := _template_size(template) + Vector2i(DEFAULT_PADDING_TILES * 2, DEFAULT_PADDING_TILES * 2)
	return Vector2i(maxi(DEFAULT_REGION_SIZE.x, size.x), maxi(DEFAULT_REGION_SIZE.y, size.y))

static func _template_size(template: Dictionary) -> Vector2i:
	return _parse_vector2i(template.size, Vector2i.ONE)

static func _template_anchor(template: Dictionary) -> Vector2i:
	return _parse_vector2i(template.anchor, Vector2i.ZERO)

static func _parse_vector2i(value, fallback: Vector2i) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Dictionary:
		var dict := Dictionary(value)
		return Vector2i(int(dict.get("x", fallback.x)), int(dict.get("y", fallback.y)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback

static func _local_tile_in_size(tile: Vector2i, size: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y

static func _rect_contains_tile(rect: Rect2i, tile: Vector2i) -> bool:
	return tile.x >= rect.position.x and tile.y >= rect.position.y and tile.x < rect.position.x + rect.size.x and tile.y < rect.position.y + rect.size.y

static func _rects_intersect(a: Rect2i, b: Rect2i) -> bool:
	return a.position.x < b.position.x + b.size.x and a.position.x + a.size.x > b.position.x and a.position.y < b.position.y + b.size.y and a.position.y + a.size.y > b.position.y

static func _chunk_cache_key(seed: int, chunk: Vector2i) -> String:
	return "%d:%d,%d" % [seed, chunk.x, chunk.y]

static func _region_cache_key(seed: int, template_id: String, region_coord: Vector2i) -> String:
	return "%d:%s:%d,%d" % [seed, template_id, region_coord.x, region_coord.y]

static func _near_cache_key(seed: int, kind: String, center_tile: Vector2i, radius_tiles: int) -> String:
	return "%d:%s:%d,%d:%d" % [seed, kind, center_tile.x, center_tile.y, radius_tiles]

static func _roll01(seed: int, region_coord: Vector2i, salt: int) -> float:
	return float(hash_i(seed ^ (region_coord.x * 73856093) ^ (region_coord.y * 19349663) ^ (salt * 83492791)) % 10000) / 9999.0

static func hash_i(value: int) -> int:
	var h := value & 0x7fffffff
	h = int((h ^ (h >> 16)) & 0x7fffffff)
	h = int((h * 1103515245 + 12345) & 0x7fffffff)
	h = int((h ^ (h >> 13)) & 0x7fffffff)
	return h

static func _stable_string_hash(value: String) -> int:
	var h := 0
	for i in range(value.length()):
		h = hash_i(h ^ value.unicode_at(i) ^ (i * 131))
	return h

static func _prop_exists(prop_id: String) -> bool:
	return FileAccess.file_exists("res://assets/props/%s.png" % prop_id)

static func _prop_kind(prop_id: String) -> String:
	if prop_id in ["chest_closed", "chest_open", "chest_open_sheet"] or prop_id.find("chest") >= 0:
		return "container"
	if _is_light_prop(prop_id):
		return "light"
	return "decoration"

static func _is_light_prop(prop_id: String) -> bool:
	return prop_id.find("torch") >= 0 or prop_id.find("lantern") >= 0 or prop_id.find("lamp") >= 0 or prop_id.find("forge") >= 0 or prop_id.find("crystal") >= 0 or prop_id in ["flare", "outpost_beacon"]

static func _light_radius(prop_id: String) -> float:
	if prop_id == "outpost_beacon":
		return 12.0
	if prop_id == "flare":
		return 8.0
	if prop_id.find("crystal") >= 0:
		return 7.0
	if prop_id.find("forge") >= 0:
		return 8.0
	return 6.0

static func _prop_size_tiles(prop_id: String) -> Array[int]:
	var path := "res://assets/props/%s.png" % prop_id
	if not FileAccess.file_exists(path):
		return [1, 1]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return [1, 1]
	var image := Image.new()
	if image.load_png_from_buffer(file.get_buffer(file.get_length())) == OK:
		return [maxi(1, ceili(float(image.get_width()) / 16.0)), maxi(1, ceili(float(image.get_height()) / 16.0))]
	return [1, 1]

static func _prop_default_draw_layer(prop_id: String) -> String:
	if prop_id.find("_back_") >= 0 or prop_id.begins_with("dwarf_back_") or prop_id.begins_with("goblin_back_"):
		return "backdrop"
	return "foreground"

static func _prop_default_alpha(prop_id: String) -> float:
	if prop_id.find("_back_") >= 0 or prop_id.begins_with("dwarf_back_") or prop_id.begins_with("goblin_back_"):
		return 0.50 if prop_id.find("dark") >= 0 else 0.62
	return 1.0

static func _title_from_id(id: String) -> String:
	var words := id.split("_", false)
	for i in range(words.size()):
		words[i] = String(words[i]).capitalize()
	return " ".join(words)

static func _vec_to_dict(value: Vector2i) -> Dictionary:
	return {"x": value.x, "y": value.y}

static func _vec_to_array(value: Vector2i) -> Array[int]:
	return [value.x, value.y]

static func _sorted_keys(dict: Dictionary) -> Array:
	var keys := dict.keys()
	keys.sort()
	return keys

static func _sort_entries_by_tile(entries: Array[Dictionary]) -> void:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.y) == int(b.y):
			if int(a.x) == int(b.x):
				return String(a.get("id", a.get("enemy_id", ""))) < String(b.get("id", b.get("enemy_id", "")))
			return int(a.x) < int(b.x)
		return int(a.y) < int(b.y)
	)

static func _strip_runtime_keys(template: Dictionary) -> Dictionary:
	var copy := template.duplicate(true)
	copy.erase("_path")
	return copy

static func _ensure_parent_dir(path: String) -> void:
	var slash_index := path.rfind("/")
	if slash_index < 0:
		return
	var dir_path := path.substr(0, slash_index)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

static func _record_perf_event(counter_name: String) -> void:
	if not debug_perf_enabled:
		return
	debug_perf_counters[counter_name] = int(debug_perf_counters.get(counter_name, 0)) + 1

static func _validation_error(message: String) -> void:
	if validation_errors_enabled:
		push_error(message)
