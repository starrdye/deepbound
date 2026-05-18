extends Node2D
class_name DeepboundWorld

const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")
const BackgroundCatalog = preload("res://scripts/catalogs/BackgroundCatalog.gd")
const BandCatalog = preload("res://scripts/catalogs/BandCatalog.gd")
const ChunkStore = preload("res://scripts/systems/ChunkStore.gd")
const MiningSystem = preload("res://scripts/systems/MiningSystem.gd")
const CollisionSystem = preload("res://scripts/systems/CollisionSystem.gd")
const StructureGenerator = preload("res://scripts/systems/StructureGenerator.gd")
const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")
const ChestController = preload("res://scripts/controllers/ChestController.gd")

const TILE_SIZE := 16
const BREAK_STAGE_COUNT := 5
const VIEW_MARGIN_TILES := 6
const REDRAW_DRIFT_TILES := 3
const MIN_RADIUS_X := 22
const MIN_RADIUS_Y := 14
const PLACEMENT_REACH_TILES := 5.25
const PLAYER_COLLIDER := {"width": 14.0, "height": 28.0}
const CHEST_CLICK_HALF_SIZE := Vector2(8, 8)
const PLACEMENT_PREVIEW_VALID_COLOR := Color(0.34, 0.86, 0.48, 0.32)
const PLACEMENT_PREVIEW_INVALID_COLOR := Color(1.0, 0.16, 0.12, 0.36)
const PLACEMENT_PREVIEW_VALID_BORDER := Color(0.54, 1.0, 0.62, 0.95)
const PLACEMENT_PREVIEW_INVALID_BORDER := Color(1.0, 0.28, 0.22, 0.95)

signal chest_broken(tile, drops)

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

func _ready() -> void:
	player = get_node_or_null(player_path)
	z_index = -10
	last_redraw_center_tile = world_to_tile(_draw_center_position())
	queue_redraw()

func _process(delta: float) -> void:
	var needs_redraw := false
	for index in range(flares.size() - 1, -1, -1):
		flares[index].life = float(flares[index].life) - delta
		if float(flares[index].life) <= 0.0:
			flares.remove_at(index)
			needs_redraw = true
	var center_tile := world_to_tile(_draw_center_position())
	if _redraw_center_moved_enough(center_tile):
		last_redraw_center_tile = center_tile
		needs_redraw = true
	if needs_redraw:
		queue_redraw()

func world_to_tile(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / TILE_SIZE), floori(point.y / TILE_SIZE))

func tile_to_world_center(tile: Vector2i) -> Vector2:
	return Vector2(float(tile.x * TILE_SIZE + TILE_SIZE / 2), float(tile.y * TILE_SIZE + TILE_SIZE / 2))

func get_tile(tile: Vector2i) -> String:
	return store.get_tile(tile)

func set_tile(tile: Vector2i, tile_id: String) -> void:
	store.set_tile(tile, tile_id)
	queue_redraw()

func get_background_tile(tile: Vector2i) -> String:
	return store.get_background_tile(tile)

func set_background_tile(tile: Vector2i, background_id: String) -> void:
	store.set_background_tile(tile, background_id)
	queue_redraw()

func is_solid_tile(tile: Vector2i) -> bool:
	return store.is_solid(tile)

func mine_at(tile: Vector2i, inventory, delta: float, drill_heat := 0.0, layer := "foreground") -> Dictionary:
	if layer == "background":
		var background_result: Dictionary = mining.mine_background(store, tile, inventory, delta, drill_heat)
		if bool(background_result.broke) or float(background_result.get("progress", 0.0)) > 0.0:
			queue_redraw()
		return background_result

	var tile_before := get_tile(tile)
	var result: Dictionary = mining.mine_tile(store, tile, inventory, delta, drill_heat)
	if bool(result.get("broke", false)) and tile_before == "chest_block":
		result.drops = break_chest(tile, true)
		result.container_broke = true
	if bool(result.broke) or float(result.get("progress", 0.0)) > 0.0:
		queue_redraw()
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
	queue_redraw()

func clear_placement_preview() -> void:
	set_placement_preview(Vector2i(999999, 999999), false, false)

func find_mining_target(origin: Vector2, aim: Vector2, reach_tiles := 1.45) -> Vector2i:
	var target_info := find_mining_target_info(origin, aim, reach_tiles)
	if bool(target_info.found):
		return target_info.tile
	return Vector2i(999999, 999999)

func find_mining_target_info(origin: Vector2, aim: Vector2, reach_tiles := 1.45) -> Dictionary:
	var normal := aim.normalized()
	if normal.length() < 0.001:
		normal = Vector2.RIGHT
	var reach_px := reach_tiles * TILE_SIZE
	var distance := 4.0
	var background_tile := Vector2i(999999, 999999)
	var background_id_at_target := BackgroundCatalog.EMPTY_ID
	while distance <= reach_px:
		var tile := world_to_tile(origin + normal * distance)
		if is_solid_tile(tile):
			return {"found": true, "tile": tile, "layer": "foreground", "id": get_tile(tile)}
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
	queue_redraw()

func add_flare(point: Vector2) -> void:
	flares.append({"position": point, "life": 12.0})
	queue_redraw()

func get_light_sources(player_position: Vector2) -> Array[Dictionary]:
	var sources: Array[Dictionary] = [{"position": player_position + Vector2(0, -18), "radius_tiles": 9.0, "intensity": 0.95}]
	for beacon in beacons:
		sources.append({"position": beacon, "radius_tiles": 12.0, "intensity": 0.75})
	for flare in flares:
		sources.append({"position": flare.position, "radius_tiles": 8.0, "intensity": 0.82})
	return sources

func _draw() -> void:
	var center := _draw_center_position()
	var center_tile := world_to_tile(center)
	var band := BandCatalog.get_band(center_tile.y)
	draw_rect(Rect2(center - Vector2(900, 600), Vector2(1800, 1200)), Color8(9, 11, 18))
	draw_rect(Rect2(center - Vector2(900, -320), Vector2(1800, 160)), Color(band.palette.shadow, 0.35))

	var radius := _visible_tile_radius()
	_draw_background_tiles(center_tile, radius)
	var tile_defs := {}
	var tile_textures := {}
	for y in range(center_tile.y - radius.y, center_tile.y + radius.y + 1):
		for x in range(center_tile.x - radius.x, center_tile.x + radius.x + 1):
			var tile := Vector2i(x, y)
			var tile_id := get_tile(tile)
			if tile_id == "air":
				continue
			if not tile_defs.has(tile_id):
				tile_defs[tile_id] = TileCatalog.get_tile(tile_id)
				tile_textures[tile_id] = TextureFactory.make_tile_texture(tile_id, tile_defs[tile_id])
			var tile_def: Dictionary = tile_defs[tile_id]
			var texture: Texture2D = tile_textures[tile_id]
			var rect := Rect2(Vector2(x * TILE_SIZE, y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
			draw_texture_rect(texture, rect, false)
			_draw_autotile_edges(tile, rect, tile_def)
			_draw_tile_break_overlay(tile, tile_id, rect, tile_def)

	_draw_structure_props(center_tile, radius)
	for beacon in beacons:
		draw_circle(beacon, 9.0, Color8(255, 214, 107, 120))
		draw_rect(Rect2(beacon - Vector2(4, 10), Vector2(8, 14)), Color8(192, 139, 62))
	for flare in flares:
		draw_circle(flare.position, 5.0, Color8(255, 138, 31, 170))
	_draw_placement_preview()

func _draw_center_position() -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		return camera.global_position
	if player:
		return player.global_position
	return Vector2.ZERO

func _visible_tile_radius() -> Vector2i:
	var viewport_size := get_viewport_rect().size
	var zoom := Vector2.ONE
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		zoom = camera.zoom
	var safe_zoom := Vector2(maxf(0.1, zoom.x), maxf(0.1, zoom.y))
	var radius_x := ceili((viewport_size.x / safe_zoom.x) / float(TILE_SIZE) * 0.5) + VIEW_MARGIN_TILES
	var radius_y := ceili((viewport_size.y / safe_zoom.y) / float(TILE_SIZE) * 0.5) + VIEW_MARGIN_TILES
	return Vector2i(maxi(MIN_RADIUS_X, radius_x), maxi(MIN_RADIUS_Y, radius_y))

func _redraw_center_moved_enough(center_tile: Vector2i) -> bool:
	if last_redraw_center_tile.x == 999999:
		return true
	return absi(center_tile.x - last_redraw_center_tile.x) >= REDRAW_DRIFT_TILES or absi(center_tile.y - last_redraw_center_tile.y) >= REDRAW_DRIFT_TILES

func _container_parent_node() -> Node2D:
	if container_parent != null and is_instance_valid(container_parent):
		return container_parent
	return self

func _chest_visual_position(tile: Vector2i) -> Vector2:
	return tile_to_world_center(tile)

func _seed_default_chest_contents(chest) -> void:
	if chest == null or chest.get("inventory") == null:
		return
	if chest.inventory.count_item("copper_nugget") == 0 and chest.inventory.count_item("stone_chunk") == 0 and chest.inventory.count_item("wooden_sword") == 0 and chest.inventory.count_item("wooden_background_block") == 0:
		chest.inventory.add_item("copper_nugget", 6)
		chest.inventory.add_item("stone_chunk", 12)
		chest.inventory.add_item("wooden_sword", 1)
		chest.inventory.add_item("wooden_background_block", 10)

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

func _draw_placement_preview() -> void:
	if not placement_preview_visible or placement_preview_tile.x == 999999:
		return
	var rect := Rect2(Vector2(placement_preview_tile.x * TILE_SIZE, placement_preview_tile.y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
	var fill_color := PLACEMENT_PREVIEW_VALID_COLOR if placement_preview_valid else PLACEMENT_PREVIEW_INVALID_COLOR
	var border_color := PLACEMENT_PREVIEW_VALID_BORDER if placement_preview_valid else PLACEMENT_PREVIEW_INVALID_BORDER
	draw_rect(rect, fill_color, true)
	draw_rect(rect.grow(-1.0), border_color, false, 2.0)

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

func _draw_autotile_edges(tile: Vector2i, rect: Rect2, tile_def: Dictionary) -> void:
	var edge_color := Color(tile_def.highlight, 0.32)
	var shadow_color := Color(tile_def.color, 0.48)
	if get_tile(tile + Vector2i(0, -1)) == "air":
		draw_line(rect.position + Vector2(2, 1), rect.position + Vector2(TILE_SIZE - 3, 1), edge_color)
	if get_tile(tile + Vector2i(0, 1)) == "air":
		draw_line(rect.position + Vector2(2, TILE_SIZE - 2), rect.position + Vector2(TILE_SIZE - 3, TILE_SIZE - 2), shadow_color)
	if get_tile(tile + Vector2i(-1, 0)) == "air":
		draw_line(rect.position + Vector2(1, 2), rect.position + Vector2(1, TILE_SIZE - 3), edge_color)
	if get_tile(tile + Vector2i(1, 0)) == "air":
		draw_line(rect.position + Vector2(TILE_SIZE - 2, 2), rect.position + Vector2(TILE_SIZE - 2, TILE_SIZE - 3), shadow_color)

func _draw_tile_break_overlay(tile: Vector2i, tile_id: String, rect: Rect2, tile_def: Dictionary) -> void:
	var damage := store.get_damage(tile)
	if damage <= 0.0 or not bool(tile_def.breakable):
		return
	var progress_ratio: float = clampf(damage / float(tile_def.hardness), 0.0, 0.999)
	var stage_index := clampi(ceili(progress_ratio * BREAK_STAGE_COUNT) - 1, 0, BREAK_STAGE_COUNT - 1)
	var sheet := TextureFactory.make_effect_texture("tile_breaking_%s_sheet" % tile_id)
	if sheet == null:
		sheet = TextureFactory.make_effect_texture("tile_breaking_sheet")
	if sheet != null:
		draw_texture_rect_region(
			sheet,
			rect,
			Rect2(Vector2(stage_index * TILE_SIZE, 0), Vector2(TILE_SIZE, TILE_SIZE))
		)
		return
	draw_line(rect.position + Vector2(4, 3), rect.position + Vector2(11, 13), Color8(255, 224, 161), 1.0)
	if stage_index >= 2:
		draw_line(rect.position + Vector2(11, 7), rect.position + Vector2(3, 12), Color8(214, 176, 113), 1.0)

func _draw_background_break_overlay(tile: Vector2i, background_id: String, rect: Rect2, background_def: Dictionary) -> void:
	var damage := store.get_background_damage(tile)
	if damage <= 0.0 or not bool(background_def.breakable):
		return
	var progress_ratio: float = clampf(damage / float(background_def.hardness), 0.0, 0.999)
	var stage_index := clampi(ceili(progress_ratio * BREAK_STAGE_COUNT) - 1, 0, BREAK_STAGE_COUNT - 1)
	var sheet := TextureFactory.make_effect_texture("tile_breaking_%s_sheet" % background_id)
	if sheet == null:
		sheet = TextureFactory.make_effect_texture("tile_breaking_sheet")
	if sheet != null:
		draw_texture_rect_region(
			sheet,
			rect,
			Rect2(Vector2(stage_index * TILE_SIZE, 0), Vector2(TILE_SIZE, TILE_SIZE))
		)
		return
	draw_line(rect.position + Vector2(4, 3), rect.position + Vector2(11, 13), Color8(255, 224, 161), 1.0)
	if stage_index >= 2:
		draw_line(rect.position + Vector2(11, 7), rect.position + Vector2(3, 12), Color8(214, 176, 113), 1.0)

func _draw_structure_props(center_tile: Vector2i, radius: Vector2i) -> void:
	var visible_rect := Rect2i(center_tile - radius, radius * 2 + Vector2i(1, 1))
	if visible_rect.position.y + visible_rect.size.y - 1 < StructureGenerator.BAND1_MIN_Y or visible_rect.position.y > StructureGenerator.BAND1_MAX_Y:
		return
	var min_chunk := Vector2i(
		floori(float(visible_rect.position.x) / 32.0),
		floori(float(visible_rect.position.y) / 32.0)
	)
	var max_chunk := Vector2i(
		floori(float(visible_rect.position.x + visible_rect.size.x - 1) / 32.0),
		floori(float(visible_rect.position.y + visible_rect.size.y - 1) / 32.0)
	)
	var seen_structures := {}
	var prop_textures := {}
	for chunk_y in range(min_chunk.y, max_chunk.y + 1):
		for chunk_x in range(min_chunk.x, max_chunk.x + 1):
			var chunk := Vector2i(chunk_x, chunk_y)
			for structure in StructureGenerator.get_structures_overlapping_chunk(store.seed, chunk):
				var structure_id := String(structure.id)
				if seen_structures.has(structure_id):
					continue
				seen_structures[structure_id] = true
				for marker in structure.props:
					var prop: Dictionary = marker
					var tile: Vector2i = prop.tile
					if not _rect_contains_tile(visible_rect, tile):
						continue
					var prop_id := String(prop.id)
					if not prop_textures.has(prop_id):
						prop_textures[prop_id] = TextureFactory.make_prop_texture(prop_id)
					var texture: Texture2D = prop_textures[prop_id]
					if texture == null:
						continue
					var rect := Rect2(Vector2(tile.x * TILE_SIZE, tile.y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
					draw_texture_rect(texture, rect, false)

func _rect_contains_tile(rect: Rect2i, tile: Vector2i) -> bool:
	return tile.x >= rect.position.x and tile.y >= rect.position.y and tile.x < rect.position.x + rect.size.x and tile.y < rect.position.y + rect.size.y
