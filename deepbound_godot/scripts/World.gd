extends Node2D
class_name DeepboundWorld

const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")
const BackgroundCatalog = preload("res://scripts/catalogs/BackgroundCatalog.gd")
const BandCatalog = preload("res://scripts/catalogs/BandCatalog.gd")
const ChunkStore = preload("res://scripts/systems/ChunkStore.gd")
const MiningSystem = preload("res://scripts/systems/MiningSystem.gd")
const CollisionSystem = preload("res://scripts/systems/CollisionSystem.gd")
const StructureGenerator = preload("res://scripts/systems/StructureGenerator.gd")
const WorldGenerator = preload("res://scripts/systems/WorldGenerator.gd")
const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")
const ChestController = preload("res://scripts/controllers/ChestController.gd")

const TILE_SIZE := 16
const BREAK_STAGE_COUNT := 5
const BLOCK_INTERACTION_REACH_TILES := 4.35
const VIEW_MARGIN_TILES := 6
const REDRAW_DRIFT_TILES := VIEW_MARGIN_TILES
const CHUNK_WARM_AHEAD_CHUNKS_Y := 3
const CHUNK_WARM_PER_FRAME := 2
const CHUNK_SIZE := 32
const MIN_RADIUS_X := 22
const MIN_RADIUS_Y := 14
const PLACEMENT_REACH_TILES := 5.25
const PLAYER_COLLIDER := {"width": 14.0, "height": 28.0}
const CHEST_CLICK_HALF_SIZE := Vector2(8, 8)
const STRUCTURE_LIGHT_RADIUS_TILES := 48
const STRUCTURE_LIGHT_CACHE_MARGIN_TILES := 16

signal chest_broken(tile, drops)

class PlacementPreviewOverlay:
	extends Node2D

	const TILE_SIZE := 16
	const VALID_COLOR := Color(0.34, 0.86, 0.48, 0.32)
	const INVALID_COLOR := Color(1.0, 0.16, 0.12, 0.36)
	const VALID_BORDER := Color(0.54, 1.0, 0.62, 0.95)
	const INVALID_BORDER := Color(1.0, 0.28, 0.22, 0.95)

	var preview_visible := false
	var preview_tile := Vector2i(999999, 999999)
	var preview_valid := false
	var draw_count := 0

	func set_preview(tile: Vector2i, valid: bool, visible := true) -> void:
		if preview_visible == visible and preview_tile == tile and preview_valid == valid:
			return
		preview_visible = visible
		preview_tile = tile
		preview_valid = valid
		queue_redraw()

	func _draw() -> void:
		draw_count += 1
		if not preview_visible or preview_tile.x == 999999:
			return
		var rect := Rect2(Vector2(preview_tile.x * TILE_SIZE, preview_tile.y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
		var fill_color := VALID_COLOR if preview_valid else INVALID_COLOR
		var border_color := VALID_BORDER if preview_valid else INVALID_BORDER
		draw_rect(rect, fill_color, true)
		draw_rect(rect.grow(-1.0), border_color, false, 2.0)

class ChunkRenderLayer:
	extends Node2D

	var world
	var chunk := Vector2i.ZERO
	var layer := "foreground"
	var draw_count := 0

	func setup(world_ref, chunk_coord: Vector2i, layer_name: String) -> void:
		world = world_ref
		chunk = chunk_coord
		layer = layer_name
		name = "Chunk%s_%d_%d" % [layer_name.capitalize(), chunk.x, chunk.y]
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		z_index = 0 if layer == "background" else 2

	func _draw() -> void:
		draw_count += 1
		if world == null:
			return
		world._record_perf_event("chunk_%s_draw" % layer)
		if layer == "background":
			world._draw_background_chunk_on(self, chunk)
		else:
			world._draw_foreground_chunk_on(self, chunk)

class PropOverlay:
	extends Node2D

	var world
	var prop_layer := "foreground"
	var include_surface_props := false
	var draw_count := 0

	func setup(world_ref, layer_name: String, include_surface := false) -> void:
		world = world_ref
		prop_layer = layer_name
		include_surface_props = include_surface
		name = "%sPropOverlay" % layer_name.capitalize()
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		z_index = 1 if prop_layer == "backdrop" else 3

	func _draw() -> void:
		draw_count += 1
		if world == null:
			return
		world._record_perf_event("prop_overlay_%s_draw" % prop_layer)
		var visible_rect: Rect2i = world._current_visible_tile_rect()
		world._draw_structure_props_on(self, visible_rect, world._cached_visible_structures(), prop_layer)
		if include_surface_props:
			world._draw_surface_props_on(self, visible_rect)

class DynamicWorldOverlay:
	extends Node2D

	var world
	var draw_count := 0

	func setup(world_ref) -> void:
		world = world_ref
		name = "DynamicWorldOverlay"
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		z_index = 5

	func _draw() -> void:
		draw_count += 1
		if world == null:
			return
		world._record_perf_event("dynamic_overlay_draw")
		for beacon in world.beacons:
			draw_circle(beacon, 9.0, Color8(255, 214, 107, 120))
			draw_rect(Rect2(beacon - Vector2(4, 10), Vector2(8, 14)), Color8(192, 139, 62))
		for flare in world.flares:
			draw_circle(flare.position, 5.0, Color8(255, 138, 31, 170))

@export var player_path: NodePath

var store = ChunkStore.new(133742)
var mining = MiningSystem.new()
var player: Node2D
var container_parent: Node2D
var container_blocks: Dictionary = {}
var beacons: Array[Vector2] = []
var flares: Array[Dictionary] = []
var last_redraw_center_tile := Vector2i(999999, 999999)
var placement_preview_visible := false
var placement_preview_tile := Vector2i(999999, 999999)
var placement_preview_valid := false
var placement_preview_overlay: Node2D
var backdrop_prop_overlay: Node2D
var foreground_prop_overlay: Node2D
var dynamic_overlay: Node2D
var chunk_render_nodes: Dictionary = {}
var visible_chunk_window := Rect2i(Vector2i(999999, 999999), Vector2i.ZERO)
var visible_tile_rect := Rect2i(Vector2i.ZERO, Vector2i.ZERO)
var visible_structures_cache: Array[Dictionary] = []
var structure_light_cache: Array[Dictionary] = []
var structure_light_cache_center := Vector2i(999999, 999999)
var solid_tile_cache: Dictionary = {}
var solid_tile_cache_physics_frame := -1
var debug_perf_enabled := false
var debug_perf_logging := false
var debug_perf_counters: Dictionary = {}
var chunk_warm_queue: Array[Vector2i] = []
var queued_chunk_warmups: Dictionary = {}
var last_chunk_warm_center_tile := Vector2i(999999, 999999)
var frozen_structures_by_id: Dictionary = {}
var frozen_structure_chunk_index: Dictionary = {}
var frozen_chunk_keys: Dictionary = {}

func _ready() -> void:
	player = get_node_or_null(player_path)
	z_index = -10
	_ensure_placement_preview_overlay()
	_ensure_prop_overlays()
	_ensure_dynamic_overlay()
	last_redraw_center_tile = world_to_tile(_draw_center_position())
	refresh_visible_chunk_window(true)
	_queue_dynamic_overlay_redraw()

func _process(delta: float) -> void:
	var dynamic_changed := false
	for index in range(flares.size() - 1, -1, -1):
		flares[index].life = float(flares[index].life) - delta
		if float(flares[index].life) <= 0.0:
			flares.remove_at(index)
			dynamic_changed = true
	if dynamic_changed:
		_record_perf_event("dynamic_overlay_flare_expiry")
		_queue_dynamic_overlay_redraw()
	refresh_visible_chunk_window()
	_process_chunk_warm_queue(CHUNK_WARM_PER_FRAME)

func reset_for_loaded_state(world_seed: int) -> void:
	store = ChunkStore.new(world_seed)
	mining = MiningSystem.new()
	container_blocks.clear()
	beacons.clear()
	flares.clear()
	_clear_frozen_world_state()
	clear_placement_preview()
	_clear_runtime_render_state()

func refresh_after_loaded_state() -> void:
	_clear_solid_tile_cache()
	structure_light_cache.clear()
	structure_light_cache_center = Vector2i(999999, 999999)
	last_redraw_center_tile = Vector2i(999999, 999999)
	refresh_visible_chunk_window(true)
	_queue_dynamic_overlay_redraw()
	_queue_prop_overlay_redraw()
	_queue_world_redraw("load")

func set_frozen_world_state(structures: Array, chunks: Array[Vector2i]) -> void:
	frozen_chunk_keys.clear()
	for chunk in chunks:
		frozen_chunk_keys[_structure_chunk_key(chunk)] = true
	_set_frozen_structures(structures)

func snapshot_structures_for_generated_chunks() -> Array[Dictionary]:
	var seen := {}
	var structures: Array[Dictionary] = []
	for chunk in store.get_generated_chunk_coords(true):
		for structure in get_structures_overlapping_chunk(chunk):
			var structure_id := String(structure.get("id", ""))
			if structure_id == "" or seen.has(structure_id):
				continue
			seen[structure_id] = true
			structures.append(structure)
	structures.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.get("id", "")) < String(b.get("id", "")))
	return structures

func get_structures_overlapping_chunk(chunk: Vector2i) -> Array[Dictionary]:
	var chunk_rect := Rect2i(chunk * CHUNK_SIZE, Vector2i(CHUNK_SIZE, CHUNK_SIZE))
	var results: Array[Dictionary] = []
	var seen := {}
	for structure in _frozen_structures_intersecting_rect(chunk_rect):
		var structure_id := String(structure.get("id", ""))
		if structure_id == "" or seen.has(structure_id):
			continue
		seen[structure_id] = true
		results.append(structure)
	if _is_frozen_chunk(chunk):
		return results
	for structure in StructureGenerator.get_structures_overlapping_chunk(store.seed, chunk):
		var structure_id := String(structure.get("id", ""))
		if structure_id == "" or seen.has(structure_id) or frozen_structures_by_id.has(structure_id):
			continue
		seen[structure_id] = true
		results.append(structure)
	return results

func get_structures_intersecting_rect(rect: Rect2i) -> Array[Dictionary]:
	var min_chunk := store.to_chunk_coord(rect.position)
	var max_chunk := store.to_chunk_coord(rect.position + rect.size - Vector2i.ONE)
	var seen := {}
	var structures: Array[Dictionary] = []
	for chunk_y in range(min_chunk.y, max_chunk.y + 1):
		for chunk_x in range(min_chunk.x, max_chunk.x + 1):
			for structure in get_structures_overlapping_chunk(Vector2i(chunk_x, chunk_y)):
				var structure_id := String(structure.get("id", ""))
				if structure_id == "" or seen.has(structure_id):
					continue
				seen[structure_id] = true
				structures.append(structure)
	return structures

func get_structure_spawns_near(center_tile: Vector2i, radius_tiles: int) -> Array[Dictionary]:
	var search_rect := Rect2i(center_tile - Vector2i(radius_tiles, radius_tiles), Vector2i(radius_tiles * 2 + 1, radius_tiles * 2 + 1))
	var results: Array[Dictionary] = []
	for structure in get_structures_intersecting_rect(search_rect):
		for raw_spawn in structure.get("spawns", []):
			var spawn: Dictionary = Dictionary(raw_spawn)
			var tile: Vector2i = spawn.get("tile", Vector2i.ZERO)
			if not _rect_contains_tile(search_rect, tile):
				continue
			var record := spawn.duplicate(true)
			record.structure_id = String(structure.get("id", ""))
			record.structure_type = String(structure.get("type", ""))
			record.position = Vector2((float(tile.x) + 0.5) * TILE_SIZE, float((tile.y + 1) * TILE_SIZE) - 0.5)
			results.append(record)
	return results

func get_structure_lights_near(center_tile: Vector2i, radius_tiles: int) -> Array[Dictionary]:
	var search_rect := Rect2i(center_tile - Vector2i(radius_tiles, radius_tiles), Vector2i(radius_tiles * 2 + 1, radius_tiles * 2 + 1))
	var results: Array[Dictionary] = []
	for structure in get_structures_intersecting_rect(search_rect):
		for raw_light in structure.get("lights", []):
			var light: Dictionary = Dictionary(raw_light)
			var tile: Vector2i = light.get("tile", Vector2i.ZERO)
			if _rect_contains_tile(search_rect, tile):
				results.append(light.duplicate(true))
	return results

func get_structure_containers_near(center_tile: Vector2i, radius_tiles: int) -> Array[Dictionary]:
	var search_rect := Rect2i(center_tile - Vector2i(radius_tiles, radius_tiles), Vector2i(radius_tiles * 2 + 1, radius_tiles * 2 + 1))
	var results: Array[Dictionary] = []
	for structure in get_structures_intersecting_rect(search_rect):
		for raw_container in structure.get("containers", []):
			var container: Dictionary = Dictionary(raw_container)
			var tile: Vector2i = container.get("tile", Vector2i.ZERO)
			if _rect_contains_tile(search_rect, tile):
				results.append(container.duplicate(true))
	return results

func world_to_tile(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / TILE_SIZE), floori(point.y / TILE_SIZE))

func tile_to_world_center(tile: Vector2i) -> Vector2:
	return Vector2(float(tile.x * TILE_SIZE + TILE_SIZE / 2), float(tile.y * TILE_SIZE + TILE_SIZE / 2))

func get_tile(tile: Vector2i) -> String:
	return store.get_tile(tile)

func set_tile(tile: Vector2i, tile_id: String) -> void:
	store.set_tile(tile, tile_id)
	_clear_solid_tile_cache()
	_record_perf_event("tile_mutation")
	invalidate_tile_chunk(tile, true)

func get_background_tile(tile: Vector2i) -> String:
	return store.get_background_tile(tile)

func set_background_tile(tile: Vector2i, background_id: String) -> void:
	store.set_background_tile(tile, background_id)
	_record_perf_event("background_mutation")
	_invalidate_chunk_render_layer("background", store.to_chunk_coord(tile))

func is_solid_tile(tile: Vector2i) -> bool:
	_record_perf_event("solid_tile_probe")
	var physics_frame := Engine.get_physics_frames()
	if solid_tile_cache_physics_frame != physics_frame:
		solid_tile_cache.clear()
		solid_tile_cache_physics_frame = physics_frame
	if solid_tile_cache.has(tile):
		_record_perf_event("solid_tile_cache_hit")
		return bool(solid_tile_cache[tile])
	_record_perf_event("solid_tile_cache_miss")
	var solid := store.is_solid(tile)
	solid_tile_cache[tile] = solid
	return solid

func mine_at(tile: Vector2i, inventory, delta: float, drill_heat := 0.0, layer := "foreground", tool_item_id := "") -> Dictionary:
	if layer == "background":
		var background_before := get_background_tile(tile)
		var previous_background_stage := _background_damage_stage(tile, background_before)
		var background_result: Dictionary = mining.mine_background(store, tile, inventory, delta, drill_heat, tool_item_id)
		if _mining_result_needs_redraw(background_result, previous_background_stage):
			_record_perf_event("mining_stage")
			_invalidate_chunk_render_layer("background", store.to_chunk_coord(tile))
		return background_result

	var tile_before := get_tile(tile)
	var previous_stage := _foreground_damage_stage(tile, tile_before)
	var result: Dictionary = mining.mine_tile(store, tile, inventory, delta, drill_heat)
	if bool(result.get("broke", false)) and tile_before == "chest_block":
		result.drops = break_chest(tile, true)
		result.container_broke = true
	if _mining_result_needs_redraw(result, previous_stage):
		_record_perf_event("mining_stage")
		invalidate_tile_chunk(tile, bool(result.get("broke", false)))
	return result

func place_chest(tile: Vector2i, seed_default_contents := false) -> bool:
	if get_tile(tile) != "air" or container_blocks.has(tile):
		return false
	set_tile(tile, "chest_block")
	var chest := ChestController.new()
	chest.name = "Chest_%d_%d" % [tile.x, tile.y]
	chest.anchor_tile = tile
	chest.seed_default_contents = seed_default_contents
	if seed_default_contents:
		_seed_default_chest_contents(chest)
	container_blocks[tile] = chest
	_container_parent_node().add_child(chest)
	chest.global_position = _chest_visual_position(tile)
	return true

func break_chest(tile: Vector2i, force_chest_drop := false) -> Array[Dictionary]:
	var chest = get_chest_at_tile(tile)
	var was_chest_tile := force_chest_drop or get_tile(tile) == "chest_block"
	if chest == null and not was_chest_tile:
		return []
	var drops: Array[Dictionary] = [{"item": "chest", "count": 1, "stack_cap": 99}]
	if chest != null:
		_append_inventory_drops(chest.inventory, drops)
		if chest.has_method("close"):
			chest.close()
		container_blocks.erase(tile)
		chest.queue_free()
	if was_chest_tile:
		set_tile(tile, "air")
	else:
		store.clear_damage(tile)
	chest_broken.emit(tile, drops)
	return drops

func get_chest_at_tile(tile: Vector2i):
	if not container_blocks.has(tile):
		_ensure_generated_container_at_tile(tile)
	return container_blocks.get(tile, null)

func get_chest_at_world_point(point: Vector2):
	for chest in container_blocks.values():
		if chest == null or not is_instance_valid(chest):
			continue
		var rect := Rect2(chest.global_position - CHEST_CLICK_HALF_SIZE, CHEST_CLICK_HALF_SIZE * 2.0)
		if rect.has_point(point):
			return chest
	return get_chest_at_tile(world_to_tile(point))

func is_placeable_tile_clear(tile: Vector2i, player_position: Vector2) -> bool:
	if get_tile(tile) != "air":
		return false
	if container_blocks.has(tile):
		return false
	var player_origin := player_position + Vector2(0, -14)
	if tile_to_world_center(tile).distance_to(player_origin) > PLACEMENT_REACH_TILES * TILE_SIZE:
		return false
	var tile_rect := Rect2(Vector2(tile.x * TILE_SIZE, tile.y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
	var player_rect := CollisionSystem.aabb(player_position, PLAYER_COLLIDER)
	return not tile_rect.intersects(player_rect, true)

func is_background_placeable_tile_clear(tile: Vector2i, player_position: Vector2) -> bool:
	if not BackgroundCatalog.is_empty(get_background_tile(tile)):
		return false
	var player_origin := player_position + Vector2(0, -14)
	return tile_to_world_center(tile).distance_to(player_origin) <= PLACEMENT_REACH_TILES * TILE_SIZE

func set_placement_preview(tile: Vector2i, valid: bool, visible := true) -> void:
	if placement_preview_visible == visible and placement_preview_tile == tile and placement_preview_valid == valid:
		return
	placement_preview_visible = visible
	placement_preview_tile = tile
	placement_preview_valid = valid
	_record_perf_event("placement_preview_update")
	var overlay := _ensure_placement_preview_overlay()
	if overlay != null and overlay.has_method("set_preview"):
		overlay.set_preview(tile, valid, visible)

func clear_placement_preview() -> void:
	set_placement_preview(Vector2i(999999, 999999), false, false)

func find_mining_target(origin: Vector2, aim: Vector2, reach_tiles := BLOCK_INTERACTION_REACH_TILES) -> Vector2i:
	var target_info := find_mining_target_info(origin, aim, reach_tiles, false)
	if bool(target_info.found):
		return target_info.tile
	return Vector2i(999999, 999999)

func find_mining_target_info(origin: Vector2, aim: Vector2, reach_tiles := BLOCK_INTERACTION_REACH_TILES, can_target_background := false) -> Dictionary:
	var normal := aim.normalized()
	if normal.length() < 0.001:
		normal = Vector2.RIGHT
	var reach_px := reach_tiles * TILE_SIZE
	var distance := 4.0
	var background_tile := Vector2i(999999, 999999)
	var background_id_at_target := BackgroundCatalog.EMPTY_ID
	var previous_tile := Vector2i(999999, 999999)
	while distance <= reach_px:
		var tile := world_to_tile(origin + normal * distance)
		if tile == previous_tile:
			distance += 4.0
			continue
		previous_tile = tile
		if is_solid_tile(tile):
			return {"found": true, "tile": tile, "layer": "foreground", "id": get_tile(tile)}
		if can_target_background:
			var background_id := get_background_tile(tile)
			if not BackgroundCatalog.is_empty(background_id):
				background_tile = tile
				background_id_at_target = background_id
		distance += 4.0
	if background_tile.x != 999999:
		return {"found": true, "tile": background_tile, "layer": "background", "id": background_id_at_target}
	return {"found": false, "tile": Vector2i(999999, 999999), "layer": "foreground", "id": "air"}

func add_beacon(point: Vector2) -> void:
	beacons.append(point)
	_queue_dynamic_overlay_redraw()

func add_flare(point: Vector2) -> void:
	flares.append({"position": point, "life": 12.0})
	_queue_dynamic_overlay_redraw()

func get_light_sources(player_position: Vector2) -> Array[Dictionary]:
	var sources: Array[Dictionary] = [{"position": player_position + Vector2(0, -18), "radius_tiles": 9.0, "intensity": 0.95}]
	for beacon in beacons:
		sources.append({"position": beacon, "radius_tiles": 12.0, "intensity": 0.75})
	for flare in flares:
		sources.append({"position": flare.position, "radius_tiles": 8.0, "intensity": 0.82})
	var player_tile := world_to_tile(player_position)
	for light in _structure_lights_for_player_tile(player_tile):
		var light_tile: Vector2i = light.tile
		sources.append({
			"position": tile_to_world_center(light_tile),
			"radius_tiles": float(light.get("radius_tiles", 6.0)),
			"intensity": float(light.get("intensity", 0.72)),
		})
	return sources

func _structure_lights_for_player_tile(player_tile: Vector2i) -> Array[Dictionary]:
	var cache_empty := structure_light_cache_center.x == 999999
	var cache_delta := player_tile - structure_light_cache_center
	if cache_empty or maxi(absi(cache_delta.x), absi(cache_delta.y)) > STRUCTURE_LIGHT_CACHE_MARGIN_TILES / 2:
		structure_light_cache_center = player_tile
		structure_light_cache = get_structure_lights_near(player_tile, STRUCTURE_LIGHT_RADIUS_TILES + STRUCTURE_LIGHT_CACHE_MARGIN_TILES)
		_record_perf_event("structure_light_cache_refresh")
	else:
		_record_perf_event("structure_light_cache_hit")
	var results: Array[Dictionary] = []
	var max_distance_sq := STRUCTURE_LIGHT_RADIUS_TILES * STRUCTURE_LIGHT_RADIUS_TILES
	for light in structure_light_cache:
		var tile: Vector2i = light.tile
		var delta := tile - player_tile
		if delta.x * delta.x + delta.y * delta.y <= max_distance_sq:
			results.append(light)
	return results

func _draw() -> void:
	_record_perf_event("world_draw")
	var center := _draw_center_position()
	var center_tile := world_to_tile(center)
	var band := BandCatalog.get_band(center_tile.y)
	var tile_rect := _current_visible_tile_rect()
	var view_rect := Rect2(
		Vector2(tile_rect.position.x * TILE_SIZE, tile_rect.position.y * TILE_SIZE),
		Vector2(tile_rect.size.x * TILE_SIZE, tile_rect.size.y * TILE_SIZE)
	).grow(TILE_SIZE * 4.0)
	draw_rect(view_rect, Color8(9, 11, 18))
	if _visible_rect_includes_surface_rect(tile_rect):
		_draw_surface_backdrop(view_rect)
	else:
		draw_rect(Rect2(center - Vector2(900, -320), Vector2(1800, 160)), Color(band.palette.shadow, 0.35))

func _draw_center_position() -> Vector2:
	var viewport := get_viewport()
	if viewport != null:
		var camera := viewport.get_camera_2d()
		if camera != null:
			return camera.global_position
	if player:
		return player.global_position
	return Vector2.ZERO

func _visible_tile_radius() -> Vector2i:
	var viewport_size := get_viewport_rect().size
	var zoom := Vector2.ONE
	var viewport := get_viewport()
	if viewport != null:
		var camera := viewport.get_camera_2d()
		if camera != null:
			zoom = camera.zoom
	var safe_zoom := Vector2(maxf(0.1, zoom.x), maxf(0.1, zoom.y))
	var radius_x := ceili((viewport_size.x / safe_zoom.x) / float(TILE_SIZE) * 0.5) + VIEW_MARGIN_TILES
	var radius_y := ceili((viewport_size.y / safe_zoom.y) / float(TILE_SIZE) * 0.5) + VIEW_MARGIN_TILES
	return Vector2i(maxi(MIN_RADIUS_X, radius_x), maxi(MIN_RADIUS_Y, radius_y))

func refresh_visible_chunk_window(force := false) -> bool:
	var center_tile := world_to_tile(_draw_center_position())
	var radius := _visible_tile_radius()
	var exact_visible_rect := Rect2i(center_tile - radius, radius * 2 + Vector2i(1, 1))
	var min_chunk := store.to_chunk_coord(exact_visible_rect.position)
	var max_chunk := store.to_chunk_coord(exact_visible_rect.position + exact_visible_rect.size - Vector2i(1, 1))
	var next_window := Rect2i(min_chunk, max_chunk - min_chunk + Vector2i.ONE)
	if not force and next_window == visible_chunk_window:
		return false
	var direction_y := 0
	if visible_chunk_window.position.x != 999999:
		if next_window.position.y > visible_chunk_window.position.y:
			direction_y = 1
		elif next_window.position.y < visible_chunk_window.position.y:
			direction_y = -1
	visible_chunk_window = next_window
	visible_tile_rect = _chunk_window_to_tile_rect(next_window)
	last_redraw_center_tile = center_tile
	_record_perf_event("visible_chunk_window_refresh")
	_sync_chunk_render_nodes(next_window)
	_refresh_visible_structure_cache()
	_queue_chunk_warmup_for_window(next_window, direction_y)
	_queue_world_redraw("camera_chunk_window")
	_queue_prop_overlay_redraw()
	return true

func get_visible_chunk_window() -> Rect2i:
	return visible_chunk_window

func invalidate_tile_chunk(tile: Vector2i, include_neighbors := false) -> void:
	var chunk := store.to_chunk_coord(tile)
	_invalidate_chunk_render_layer("foreground", chunk)
	if include_neighbors:
		_invalidate_neighbor_edge_chunks(tile, chunk)

func _redraw_center_moved_enough(center_tile: Vector2i) -> bool:
	if last_redraw_center_tile.x == 999999:
		return true
	return absi(center_tile.x - last_redraw_center_tile.x) >= REDRAW_DRIFT_TILES or absi(center_tile.y - last_redraw_center_tile.y) >= REDRAW_DRIFT_TILES

func enable_debug_perf_counters(enabled := true, logging := false) -> void:
	debug_perf_enabled = enabled
	debug_perf_logging = logging
	if enabled:
		debug_perf_counters.clear()

func reset_debug_perf_counters() -> void:
	debug_perf_counters.clear()

func get_debug_perf_counter(counter_name: String) -> int:
	return int(debug_perf_counters.get(counter_name, 0))

func get_placement_preview_draw_count() -> int:
	var overlay := _ensure_placement_preview_overlay()
	return 0 if overlay == null else int(overlay.get("draw_count"))

func _queue_chunk_warmup_for_window(window: Rect2i, direction_y: int) -> void:
	last_chunk_warm_center_tile = world_to_tile(_draw_center_position())
	for chunk_y in range(window.position.y, window.position.y + window.size.y):
		for chunk_x in range(window.position.x, window.position.x + window.size.x):
			_enqueue_chunk_warmup(Vector2i(chunk_x, chunk_y))

	if direction_y > 0:
		var start_y := window.position.y + window.size.y
		for chunk_y in range(start_y, start_y + CHUNK_WARM_AHEAD_CHUNKS_Y):
			for chunk_x in range(window.position.x, window.position.x + window.size.x):
				_enqueue_chunk_warmup(Vector2i(chunk_x, chunk_y))
	elif direction_y < 0:
		for chunk_y in range(window.position.y - CHUNK_WARM_AHEAD_CHUNKS_Y, window.position.y):
			for chunk_x in range(window.position.x, window.position.x + window.size.x):
				_enqueue_chunk_warmup(Vector2i(chunk_x, chunk_y))

func _enqueue_chunk_warmup(chunk: Vector2i) -> void:
	if queued_chunk_warmups.has(chunk) or store.is_chunk_warmed(chunk, true):
		return
	queued_chunk_warmups[chunk] = true
	chunk_warm_queue.append(chunk)

func _process_chunk_warm_queue(limit: int) -> void:
	var processed := 0
	while processed < limit and not chunk_warm_queue.is_empty():
		var chunk: Vector2i = chunk_warm_queue.pop_front()
		queued_chunk_warmups.erase(chunk)
		_record_perf_event("chunk_warm_checked")
		var generated := store.warm_chunk(chunk, true)
		if generated > 0:
			_record_perf_event_count("chunk_warm_generated", generated)
		processed += 1

func _sync_chunk_render_nodes(window: Rect2i) -> void:
	var wanted := {}
	for chunk_y in range(window.position.y, window.position.y + window.size.y):
		for chunk_x in range(window.position.x, window.position.x + window.size.x):
			var chunk := Vector2i(chunk_x, chunk_y)
			for layer_name in ["background", "foreground"]:
				var key := _chunk_render_key(layer_name, chunk)
				wanted[key] = true
				if chunk_render_nodes.has(key):
					continue
				var node := ChunkRenderLayer.new()
				node.setup(self, chunk, layer_name)
				chunk_render_nodes[key] = node
				add_child(node)
				_record_perf_event("chunk_%s_node_created" % layer_name)
	for key in chunk_render_nodes.keys():
		if wanted.has(key):
			continue
		var node: Node = chunk_render_nodes[key]
		chunk_render_nodes.erase(key)
		if node != null and is_instance_valid(node):
			node.queue_free()
			_record_perf_event("chunk_node_removed")

func _invalidate_chunk_render_layer(layer_name: String, chunk: Vector2i) -> void:
	var key := _chunk_render_key(layer_name, chunk)
	if not chunk_render_nodes.has(key):
		return
	var node: Node = chunk_render_nodes[key]
	if node != null and is_instance_valid(node):
		node.queue_redraw()
		_record_perf_event("chunk_%s_invalidated" % layer_name)

func _invalidate_neighbor_edge_chunks(tile: Vector2i, chunk: Vector2i) -> void:
	var local := store.to_local_tile(tile)
	if local.x == 0:
		_invalidate_chunk_render_layer("foreground", chunk + Vector2i(-1, 0))
	elif local.x == CHUNK_SIZE - 1:
		_invalidate_chunk_render_layer("foreground", chunk + Vector2i(1, 0))
	if local.y == 0:
		_invalidate_chunk_render_layer("foreground", chunk + Vector2i(0, -1))
	elif local.y == CHUNK_SIZE - 1:
		_invalidate_chunk_render_layer("foreground", chunk + Vector2i(0, 1))

func _clear_solid_tile_cache() -> void:
	solid_tile_cache.clear()
	solid_tile_cache_physics_frame = -1

func _clear_runtime_render_state() -> void:
	for node in chunk_render_nodes.values():
		if node != null and is_instance_valid(node):
			node.queue_free()
	chunk_render_nodes.clear()
	visible_chunk_window = Rect2i(Vector2i(999999, 999999), Vector2i.ZERO)
	visible_tile_rect = Rect2i(Vector2i.ZERO, Vector2i.ZERO)
	visible_structures_cache.clear()
	structure_light_cache.clear()
	structure_light_cache_center = Vector2i(999999, 999999)
	solid_tile_cache.clear()
	solid_tile_cache_physics_frame = -1
	chunk_warm_queue.clear()
	queued_chunk_warmups.clear()
	last_chunk_warm_center_tile = Vector2i(999999, 999999)

func _clear_frozen_world_state() -> void:
	frozen_structures_by_id.clear()
	frozen_structure_chunk_index.clear()
	frozen_chunk_keys.clear()
	structure_light_cache.clear()
	structure_light_cache_center = Vector2i(999999, 999999)

func _set_frozen_structures(structures: Array) -> void:
	frozen_structures_by_id.clear()
	frozen_structure_chunk_index.clear()
	for raw_structure in structures:
		if not (raw_structure is Dictionary):
			continue
		var structure: Dictionary = Dictionary(raw_structure)
		var structure_id := String(structure.get("id", ""))
		if structure_id == "":
			continue
		frozen_structures_by_id[structure_id] = structure
		var rect: Rect2i = structure.get("rect", Rect2i(Vector2i.ZERO, Vector2i.ZERO))
		var min_chunk := store.to_chunk_coord(rect.position)
		var max_chunk := store.to_chunk_coord(rect.position + rect.size - Vector2i.ONE)
		for chunk_y in range(min_chunk.y, max_chunk.y + 1):
			for chunk_x in range(min_chunk.x, max_chunk.x + 1):
				var key := _structure_chunk_key(Vector2i(chunk_x, chunk_y))
				if not frozen_structure_chunk_index.has(key):
					frozen_structure_chunk_index[key] = []
				frozen_structure_chunk_index[key].append(structure_id)
	structure_light_cache.clear()
	structure_light_cache_center = Vector2i(999999, 999999)

func _frozen_structures_intersecting_rect(rect: Rect2i) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var seen := {}
	var min_chunk := store.to_chunk_coord(rect.position)
	var max_chunk := store.to_chunk_coord(rect.position + rect.size - Vector2i.ONE)
	for chunk_y in range(min_chunk.y, max_chunk.y + 1):
		for chunk_x in range(min_chunk.x, max_chunk.x + 1):
			var key := _structure_chunk_key(Vector2i(chunk_x, chunk_y))
			for structure_id in frozen_structure_chunk_index.get(key, []):
				var id := String(structure_id)
				if seen.has(id) or not frozen_structures_by_id.has(id):
					continue
				var structure: Dictionary = frozen_structures_by_id[id]
				var structure_rect: Rect2i = structure.get("rect", Rect2i(Vector2i.ZERO, Vector2i.ZERO))
				if not _rects_intersect(structure_rect, rect):
					continue
				seen[id] = true
				results.append(structure)
	return results

func _has_frozen_structure_near_rect(rect: Rect2i) -> bool:
	return not _frozen_structures_intersecting_rect(rect).is_empty()

func _is_frozen_chunk(chunk: Vector2i) -> bool:
	return frozen_chunk_keys.has(_structure_chunk_key(chunk))

func _structure_chunk_key(chunk: Vector2i) -> String:
	return "%d,%d" % [chunk.x, chunk.y]

func _chunk_render_key(layer_name: String, chunk: Vector2i) -> String:
	return "%s:%d,%d" % [layer_name, chunk.x, chunk.y]

func _chunk_window_to_tile_rect(window: Rect2i) -> Rect2i:
	return Rect2i(window.position * CHUNK_SIZE, window.size * CHUNK_SIZE)

func _current_visible_tile_rect() -> Rect2i:
	if visible_chunk_window.position.x == 999999:
		refresh_visible_chunk_window(true)
	return visible_tile_rect

func _refresh_visible_structure_cache() -> void:
	visible_structures_cache = _collect_visible_structures(_current_visible_tile_rect())
	_record_perf_event_count("visible_structure_count", visible_structures_cache.size())

func _cached_visible_structures() -> Array[Dictionary]:
	return visible_structures_cache

func _queue_prop_overlay_redraw() -> void:
	var backdrop := _ensure_backdrop_prop_overlay()
	var foreground := _ensure_foreground_prop_overlay()
	if backdrop != null:
		backdrop.queue_redraw()
	if foreground != null:
		foreground.queue_redraw()

func _queue_dynamic_overlay_redraw() -> void:
	var overlay := _ensure_dynamic_overlay()
	if overlay != null:
		overlay.queue_redraw()

func _queue_world_redraw(reason: String) -> void:
	var normalized_reason := reason if reason != "" else "unspecified"
	last_redraw_center_tile = world_to_tile(_draw_center_position())
	_record_perf_event("world_redraw_%s" % normalized_reason)
	queue_redraw()

func _record_perf_event(counter_name: String) -> void:
	if not debug_perf_enabled:
		return
	debug_perf_counters[counter_name] = int(debug_perf_counters.get(counter_name, 0)) + 1
	if debug_perf_logging:
		print("world-perf:%s=%d" % [counter_name, int(debug_perf_counters[counter_name])])

func _record_perf_event_count(counter_name: String, amount: int) -> void:
	if not debug_perf_enabled or amount <= 0:
		return
	debug_perf_counters[counter_name] = int(debug_perf_counters.get(counter_name, 0)) + amount
	if debug_perf_logging:
		print("world-perf:%s=%d" % [counter_name, int(debug_perf_counters[counter_name])])

func _ensure_placement_preview_overlay() -> Node2D:
	if placement_preview_overlay != null and is_instance_valid(placement_preview_overlay):
		return placement_preview_overlay
	var existing := get_node_or_null("PlacementPreviewOverlay") as Node2D
	if existing != null:
		placement_preview_overlay = existing
		return placement_preview_overlay
	placement_preview_overlay = PlacementPreviewOverlay.new()
	placement_preview_overlay.name = "PlacementPreviewOverlay"
	placement_preview_overlay.z_index = 4
	placement_preview_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(placement_preview_overlay)
	return placement_preview_overlay

func _ensure_prop_overlays() -> void:
	_ensure_backdrop_prop_overlay()
	_ensure_foreground_prop_overlay()

func _ensure_backdrop_prop_overlay() -> Node2D:
	if backdrop_prop_overlay != null and is_instance_valid(backdrop_prop_overlay):
		return backdrop_prop_overlay
	var existing := get_node_or_null("BackdropPropOverlay") as Node2D
	if existing != null:
		backdrop_prop_overlay = existing
		return backdrop_prop_overlay
	backdrop_prop_overlay = PropOverlay.new()
	backdrop_prop_overlay.setup(self, "backdrop", false)
	add_child(backdrop_prop_overlay)
	return backdrop_prop_overlay

func _ensure_foreground_prop_overlay() -> Node2D:
	if foreground_prop_overlay != null and is_instance_valid(foreground_prop_overlay):
		return foreground_prop_overlay
	var existing := get_node_or_null("ForegroundPropOverlay") as Node2D
	if existing != null:
		foreground_prop_overlay = existing
		return foreground_prop_overlay
	foreground_prop_overlay = PropOverlay.new()
	foreground_prop_overlay.setup(self, "foreground", true)
	add_child(foreground_prop_overlay)
	return foreground_prop_overlay

func _ensure_dynamic_overlay() -> Node2D:
	if dynamic_overlay != null and is_instance_valid(dynamic_overlay):
		return dynamic_overlay
	var existing := get_node_or_null("DynamicWorldOverlay") as Node2D
	if existing != null:
		dynamic_overlay = existing
		return dynamic_overlay
	dynamic_overlay = DynamicWorldOverlay.new()
	dynamic_overlay.setup(self)
	add_child(dynamic_overlay)
	return dynamic_overlay

func _container_parent_node() -> Node2D:
	if container_parent != null and is_instance_valid(container_parent):
		return container_parent
	return self

func _ensure_generated_container_at_tile(tile: Vector2i) -> void:
	if get_tile(tile) != "chest_block":
		return
	for container in get_structure_containers_near(tile, 1):
		var container_tile: Vector2i = container.tile
		if container_tile != tile:
			continue
		var chest := ChestController.new()
		chest.name = "GeneratedChest_%d_%d" % [tile.x, tile.y]
		chest.anchor_tile = tile
		chest.seed_default_contents = false
		container_blocks[tile] = chest
		_container_parent_node().add_child(chest)
		chest.global_position = _chest_visual_position(tile)
		return

func _chest_visual_position(tile: Vector2i) -> Vector2:
	return tile_to_world_center(tile)

func _seed_default_chest_contents(chest) -> void:
	if chest == null or chest.get("inventory") == null:
		return
	if chest.inventory.count_item("copper_nugget") == 0 and chest.inventory.count_item("stone_chunk") == 0 and chest.inventory.count_item("wooden_sword") == 0 and chest.inventory.count_item("wooden_background_block") == 0 and chest.inventory.count_item("hammer") == 0:
		chest.inventory.add_item("copper_nugget", 6)
		chest.inventory.add_item("stone_chunk", 12)
		chest.inventory.add_item("wooden_sword", 1)
		chest.inventory.add_item("wooden_background_block", 10)
		chest.inventory.add_item("hammer", 1)

func _append_inventory_drops(inventory, drops: Array[Dictionary]) -> void:
	if inventory == null:
		return
	for slot in inventory.slots:
		if String(slot.get("item", "")) == "" or int(slot.get("count", 0)) <= 0:
			continue
		drops.append({
			"item": String(slot.item),
			"count": int(slot.count),
			"stack_cap": int(slot.get("stack_cap", 99)),
		})

func _draw_background_chunk_on(target, chunk: Vector2i) -> void:
	var background_defs := {}
	var background_textures := {}
	var origin := chunk * CHUNK_SIZE
	_record_perf_event_count("background_cell_scanned", CHUNK_SIZE * CHUNK_SIZE)
	for local_y in range(CHUNK_SIZE):
		for local_x in range(CHUNK_SIZE):
			var tile := origin + Vector2i(local_x, local_y)
			var background_id := get_background_tile(tile)
			if BackgroundCatalog.is_empty(background_id):
				continue
			if not background_defs.has(background_id):
				background_defs[background_id] = BackgroundCatalog.get_background(background_id)
				background_textures[background_id] = TextureFactory.make_background_texture(background_id, background_defs[background_id])
			var texture: Texture2D = background_textures[background_id]
			if texture == null:
				continue
			var rect := Rect2(Vector2(tile.x * TILE_SIZE, tile.y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
			target.draw_texture_rect(texture, rect, false)
			_draw_background_break_overlay_on(target, tile, background_id, rect, background_defs[background_id])

func _draw_foreground_chunk_on(target, chunk: Vector2i) -> void:
	var tile_defs := {}
	var tile_textures := {}
	var origin := chunk * CHUNK_SIZE
	_record_perf_event_count("foreground_cell_scanned", CHUNK_SIZE * CHUNK_SIZE)
	for local_y in range(CHUNK_SIZE):
		for local_x in range(CHUNK_SIZE):
			var tile := origin + Vector2i(local_x, local_y)
			var tile_id := get_tile(tile)
			if tile_id == "air":
				continue
			if not tile_defs.has(tile_id):
				tile_defs[tile_id] = TileCatalog.get_tile(tile_id)
				tile_textures[tile_id] = TextureFactory.make_tile_texture(tile_id, tile_defs[tile_id])
			var tile_def: Dictionary = tile_defs[tile_id]
			var texture: Texture2D = tile_textures[tile_id]
			var rect := Rect2(Vector2(tile.x * TILE_SIZE, tile.y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
			target.draw_texture_rect(texture, rect, false)
			_draw_autotile_edges_on(target, tile, rect, tile_def)
			_draw_tile_break_overlay_on(target, tile, tile_id, rect, tile_def)

func _draw_background_tiles(center_tile: Vector2i, radius: Vector2i) -> void:
	var background_defs := {}
	var background_textures := {}
	for y in range(center_tile.y - radius.y, center_tile.y + radius.y + 1):
		for x in range(center_tile.x - radius.x, center_tile.x + radius.x + 1):
			var tile := Vector2i(x, y)
			var background_id := get_background_tile(tile)
			if BackgroundCatalog.is_empty(background_id):
				continue
			if not background_defs.has(background_id):
				background_defs[background_id] = BackgroundCatalog.get_background(background_id)
				background_textures[background_id] = TextureFactory.make_background_texture(background_id, background_defs[background_id])
			var texture: Texture2D = background_textures[background_id]
			if texture == null:
				continue
			var rect := Rect2(Vector2(x * TILE_SIZE, y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
			draw_texture_rect(texture, rect, false)
			_draw_background_break_overlay(tile, background_id, rect, background_defs[background_id])

func _visible_rect_includes_surface(center_tile: Vector2i, radius: Vector2i) -> bool:
	var min_y := center_tile.y - radius.y
	var max_y := center_tile.y + radius.y
	return min_y <= 1 and max_y >= BandCatalog.SURFACE_MIN_TILE_Y

func _visible_rect_includes_surface_rect(rect: Rect2i) -> bool:
	var min_y := rect.position.y
	var max_y := rect.position.y + rect.size.y - 1
	return min_y <= 1 and max_y >= BandCatalog.SURFACE_MIN_TILE_Y

func _draw_surface_backdrop(view_rect: Rect2) -> void:
	var surface_bottom := float(TILE_SIZE * 2)
	var surface_top := maxf(view_rect.position.y, float(BandCatalog.SURFACE_MIN_TILE_Y * TILE_SIZE))
	var surface_height := minf(view_rect.position.y + view_rect.size.y, surface_bottom) - surface_top
	if surface_height <= 0.0:
		return
	var surface_rect := Rect2(Vector2(view_rect.position.x, surface_top), Vector2(view_rect.size.x, surface_height))
	draw_rect(surface_rect, Color8(72, 117, 135))
	draw_rect(Rect2(Vector2(surface_rect.position.x, surface_rect.position.y + surface_rect.size.y * 0.58), Vector2(surface_rect.size.x, surface_rect.size.y * 0.42)), Color8(41, 67, 59, 150))
	_draw_repeating_surface_texture("tree_backdrop", view_rect, -15.0 * TILE_SIZE, 0.45)
	_draw_repeating_surface_texture("rocks_backdrop", view_rect, -6.0 * TILE_SIZE, 0.34)

func _draw_repeating_surface_texture(asset_id: String, view_rect: Rect2, baseline_y: float, alpha: float) -> void:
	var texture := TextureFactory.make_surface_texture(asset_id)
	if texture == null:
		return
	var size := Vector2(texture.get_width(), texture.get_height())
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var start_x := floori(view_rect.position.x / size.x) * int(size.x)
	var end_x := ceili((view_rect.position.x + view_rect.size.x) / size.x) * int(size.x)
	var y := baseline_y - size.y
	for x in range(start_x, end_x + int(size.x), int(size.x)):
		draw_texture_rect(texture, Rect2(Vector2(float(x), y), size), false, Color(1, 1, 1, alpha))

func _draw_autotile_edges(tile: Vector2i, rect: Rect2, tile_def: Dictionary) -> void:
	_draw_autotile_edges_on(self, tile, rect, tile_def)

func _draw_autotile_edges_on(target, tile: Vector2i, rect: Rect2, tile_def: Dictionary) -> void:
	var edge_color := Color(tile_def.highlight, 0.32)
	var shadow_color := Color(tile_def.color, 0.48)
	if get_tile(tile + Vector2i(0, -1)) == "air":
		target.draw_line(rect.position + Vector2(2, 1), rect.position + Vector2(TILE_SIZE - 3, 1), edge_color)
	if get_tile(tile + Vector2i(0, 1)) == "air":
		target.draw_line(rect.position + Vector2(2, TILE_SIZE - 2), rect.position + Vector2(TILE_SIZE - 3, TILE_SIZE - 2), shadow_color)
	if get_tile(tile + Vector2i(-1, 0)) == "air":
		target.draw_line(rect.position + Vector2(1, 2), rect.position + Vector2(1, TILE_SIZE - 3), edge_color)
	if get_tile(tile + Vector2i(1, 0)) == "air":
		target.draw_line(rect.position + Vector2(TILE_SIZE - 2, 2), rect.position + Vector2(TILE_SIZE - 2, TILE_SIZE - 3), shadow_color)

func _draw_tile_break_overlay(tile: Vector2i, tile_id: String, rect: Rect2, tile_def: Dictionary) -> void:
	_draw_tile_break_overlay_on(self, tile, tile_id, rect, tile_def)

func _draw_tile_break_overlay_on(target, tile: Vector2i, tile_id: String, rect: Rect2, tile_def: Dictionary) -> void:
	var damage := store.get_damage(tile)
	if damage <= 0.0 or not bool(tile_def.breakable):
		return
	var progress_ratio: float = clampf(damage / float(tile_def.hardness), 0.0, 0.999)
	var stage_index := clampi(ceili(progress_ratio * BREAK_STAGE_COUNT) - 1, 0, BREAK_STAGE_COUNT - 1)
	var sheet := TextureFactory.make_effect_texture("tile_breaking_%s_sheet" % tile_id)
	if sheet == null:
		sheet = TextureFactory.make_effect_texture("tile_breaking_sheet")
	if sheet != null:
		target.draw_texture_rect_region(
			sheet,
			rect,
			Rect2(Vector2(stage_index * TILE_SIZE, 0), Vector2(TILE_SIZE, TILE_SIZE))
		)
		return
	target.draw_line(rect.position + Vector2(4, 3), rect.position + Vector2(11, 13), Color8(255, 224, 161), 1.0)
	if stage_index >= 2:
		target.draw_line(rect.position + Vector2(11, 7), rect.position + Vector2(3, 12), Color8(214, 176, 113), 1.0)

func _draw_background_break_overlay(tile: Vector2i, background_id: String, rect: Rect2, background_def: Dictionary) -> void:
	_draw_background_break_overlay_on(self, tile, background_id, rect, background_def)

func _draw_background_break_overlay_on(target, tile: Vector2i, background_id: String, rect: Rect2, background_def: Dictionary) -> void:
	var damage := store.get_background_damage(tile)
	if damage <= 0.0 or not bool(background_def.breakable):
		return
	var progress_ratio: float = clampf(damage / float(background_def.hardness), 0.0, 0.999)
	var stage_index := clampi(ceili(progress_ratio * BREAK_STAGE_COUNT) - 1, 0, BREAK_STAGE_COUNT - 1)
	var sheet := TextureFactory.make_effect_texture("tile_breaking_%s_sheet" % background_id)
	if sheet == null:
		sheet = TextureFactory.make_effect_texture("tile_breaking_sheet")
	if sheet != null:
		target.draw_texture_rect_region(
			sheet,
			rect,
			Rect2(Vector2(stage_index * TILE_SIZE, 0), Vector2(TILE_SIZE, TILE_SIZE))
		)
		return
	target.draw_line(rect.position + Vector2(4, 3), rect.position + Vector2(11, 13), Color8(255, 224, 161), 1.0)
	if stage_index >= 2:
		target.draw_line(rect.position + Vector2(11, 7), rect.position + Vector2(3, 12), Color8(214, 176, 113), 1.0)

func _collect_visible_structures(visible_rect: Rect2i) -> Array[Dictionary]:
	if not _has_frozen_structure_near_rect(visible_rect) and not StructureGenerator.has_enabled_template_near_rect(visible_rect):
		_record_perf_event("visible_structure_band_skip")
		return []
	var min_chunk := Vector2i(
		floori(float(visible_rect.position.x) / 32.0),
		floori(float(visible_rect.position.y) / 32.0)
	)
	var max_chunk := Vector2i(
		floori(float(visible_rect.position.x + visible_rect.size.x - 1) / 32.0),
		floori(float(visible_rect.position.y + visible_rect.size.y - 1) / 32.0)
	)
	_record_perf_event_count("visible_structure_chunk_query", (max_chunk.x - min_chunk.x + 1) * (max_chunk.y - min_chunk.y + 1))
	var seen_structures := {}
	var structures: Array[Dictionary] = []
	for chunk_y in range(min_chunk.y, max_chunk.y + 1):
		for chunk_x in range(min_chunk.x, max_chunk.x + 1):
			var chunk := Vector2i(chunk_x, chunk_y)
			for structure in get_structures_overlapping_chunk(chunk):
				var structure_id := String(structure.id)
				if seen_structures.has(structure_id):
					continue
				seen_structures[structure_id] = true
				structures.append(structure)
	return structures

func _draw_structure_props(visible_rect: Rect2i, visible_structures: Array[Dictionary], prop_layer := "foreground") -> void:
	_draw_structure_props_on(self, visible_rect, visible_structures, prop_layer)

func _draw_structure_props_on(target, visible_rect: Rect2i, visible_structures: Array[Dictionary], prop_layer := "foreground") -> void:
	var prop_textures := {}
	for structure in visible_structures:
		for marker in structure.props:
			var prop: Dictionary = marker
			var tile: Vector2i = prop.tile
			var layer := String(prop.get("layer", "foreground"))
			if layer != prop_layer:
				continue
			var size_tiles := _prop_size_tiles(prop)
			var origin_tile := tile + _prop_offset_tiles(prop)
			var prop_rect := Rect2i(origin_tile, size_tiles)
			if not _rects_intersect(prop_rect, visible_rect):
				continue
			var prop_id := String(prop.id)
			if not prop_textures.has(prop_id):
				prop_textures[prop_id] = TextureFactory.make_prop_texture(prop_id)
			var texture: Texture2D = prop_textures[prop_id]
			if texture == null:
				continue
			var rect := Rect2(Vector2(origin_tile.x * TILE_SIZE, origin_tile.y * TILE_SIZE), Vector2(size_tiles.x * TILE_SIZE, size_tiles.y * TILE_SIZE))
			target.draw_texture_rect(texture, rect, false, Color(1, 1, 1, float(prop.get("alpha", 1.0))))
			_record_perf_event("structure_prop_drawn")

func _draw_surface_props(center_tile: Vector2i, radius: Vector2i) -> void:
	var visible_rect := Rect2i(center_tile - radius, radius * 2 + Vector2i(1, 1))
	_draw_surface_props_on(self, visible_rect)

func _draw_surface_props_on(target, visible_rect: Rect2i) -> void:
	if visible_rect.position.y > 1 or visible_rect.position.y + visible_rect.size.y - 1 < BandCatalog.SURFACE_MIN_TILE_Y:
		return
	var prop_textures := {}
	for x in range(visible_rect.position.x, visible_rect.position.x + visible_rect.size.x):
		if abs(x) <= 3:
			continue
		var floor_y := WorldGenerator.surface_floor_y(store.seed, x)
		var prop_tile := Vector2i(x, floor_y - 1)
		if not _rect_contains_tile(visible_rect, prop_tile):
			continue
		var roll := WorldGenerator.noise01(store.seed + 7701, x, floor_y)
		var prop_id := ""
		if roll > 0.986:
			prop_id = "surface_root_arch"
		elif roll > 0.948:
			prop_id = "surface_mushroom"
		elif roll > 0.850:
			prop_id = "surface_flower_clump"
		elif roll > 0.620:
			prop_id = "surface_grass_clump"
		else:
			continue
		if not prop_textures.has(prop_id):
			prop_textures[prop_id] = TextureFactory.make_prop_texture(prop_id)
		var texture: Texture2D = prop_textures[prop_id]
		if texture == null:
			continue
		var rect := Rect2(Vector2(prop_tile.x * TILE_SIZE, prop_tile.y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
		target.draw_texture_rect(texture, rect, false)
		_record_perf_event("surface_prop_drawn")

func _rect_contains_tile(rect: Rect2i, tile: Vector2i) -> bool:
	return tile.x >= rect.position.x and tile.y >= rect.position.y and tile.x < rect.position.x + rect.size.x and tile.y < rect.position.y + rect.size.y

func _foreground_damage_stage(tile: Vector2i, tile_id: String) -> int:
	var tile_def := TileCatalog.get_tile(tile_id)
	if not bool(tile_def.breakable):
		return 0
	return MiningSystem.damage_stage(store.get_damage(tile) / float(tile_def.hardness))

func _background_damage_stage(tile: Vector2i, background_id: String) -> int:
	var background_def := BackgroundCatalog.get_background(background_id)
	if BackgroundCatalog.is_empty(background_id) or not bool(background_def.breakable):
		return 0
	return MiningSystem.damage_stage(store.get_background_damage(tile) / float(background_def.hardness))

func _mining_result_needs_redraw(result: Dictionary, previous_stage: int) -> bool:
	if bool(result.get("broke", false)):
		return true
	var current_stage := int(result.get("stage", 0))
	return current_stage > 0 and current_stage != previous_stage

func _prop_size_tiles(prop: Dictionary) -> Vector2i:
	var raw_size = prop.get("size", [1, 1])
	if raw_size is Vector2i:
		return raw_size
	if raw_size is Array and raw_size.size() >= 2:
		return Vector2i(maxi(1, int(raw_size[0])), maxi(1, int(raw_size[1])))
	return Vector2i.ONE

func _prop_offset_tiles(prop: Dictionary) -> Vector2i:
	var raw_offset = prop.get("offset", [0, 0])
	if raw_offset is Vector2i:
		return raw_offset
	if raw_offset is Array and raw_offset.size() >= 2:
		return Vector2i(int(raw_offset[0]), int(raw_offset[1]))
	return Vector2i.ZERO

func _rects_intersect(a: Rect2i, b: Rect2i) -> bool:
	return a.position.x < b.position.x + b.size.x and a.position.x + a.size.x > b.position.x and a.position.y < b.position.y + b.size.y and a.position.y + a.size.y > b.position.y
