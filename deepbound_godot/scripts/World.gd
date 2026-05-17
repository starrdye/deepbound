extends Node2D
class_name DeepboundWorld

const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")
const BandCatalog = preload("res://scripts/catalogs/BandCatalog.gd")
const ChunkStore = preload("res://scripts/systems/ChunkStore.gd")
const MiningSystem = preload("res://scripts/systems/MiningSystem.gd")
const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")

const TILE_SIZE := 16
const BREAK_STAGE_COUNT := 5

@export var player_path: NodePath

var store = ChunkStore.new(133742)
var mining = MiningSystem.new()
var player: Node2D
var beacons: Array[Vector2] = []
var flares: Array[Dictionary] = []

func _ready() -> void:
	player = get_node_or_null(player_path)
	z_index = -10

func _process(delta: float) -> void:
	for flare in flares:
		flare.life = float(flare.life) - delta
	flares = flares.filter(func(flare: Dictionary) -> bool: return float(flare.life) > 0.0)
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

func is_solid_tile(tile: Vector2i) -> bool:
	return store.is_solid(tile)

func mine_at(tile: Vector2i, inventory, delta: float, drill_heat := 0.0) -> Dictionary:
	var result := mining.mine_tile(store, tile, inventory, delta, drill_heat)
	if bool(result.broke) or float(result.get("progress", 0.0)) > 0.0:
		queue_redraw()
	return result

func find_mining_target(origin: Vector2, aim: Vector2, reach_tiles := 1.45) -> Vector2i:
	var normal := aim.normalized()
	if normal.length() < 0.001:
		normal = Vector2.RIGHT
	var reach_px := reach_tiles * TILE_SIZE
	var distance := 4.0
	while distance <= reach_px:
		var tile := world_to_tile(origin + normal * distance)
		if is_solid_tile(tile):
			return tile
		distance += 4.0
	return Vector2i(999999, 999999)

func add_beacon(point: Vector2) -> void:
	beacons.append(point)

func add_flare(point: Vector2) -> void:
	flares.append({"position": point, "life": 12.0})

func get_light_sources(player_position: Vector2) -> Array[Dictionary]:
	var sources: Array[Dictionary] = [{"position": player_position + Vector2(0, -18), "radius_tiles": 9.0, "intensity": 0.95}]
	for beacon in beacons:
		sources.append({"position": beacon, "radius_tiles": 12.0, "intensity": 0.75})
	for flare in flares:
		sources.append({"position": flare.position, "radius_tiles": 8.0, "intensity": 0.82})
	return sources

func _draw() -> void:
	var center := Vector2.ZERO
	if player:
		center = player.global_position
	var center_tile := world_to_tile(center)
	var band := BandCatalog.get_band(center_tile.y)
	draw_rect(Rect2(center - Vector2(900, 600), Vector2(1800, 1200)), Color8(9, 11, 18))
	draw_rect(Rect2(center - Vector2(900, -320), Vector2(1800, 160)), Color(band.palette.shadow, 0.35))

	for y in range(center_tile.y - 24, center_tile.y + 25):
		for x in range(center_tile.x - 42, center_tile.x + 43):
			var tile := Vector2i(x, y)
			var tile_id := get_tile(tile)
			if tile_id == "air":
				continue
			var tile_def := TileCatalog.get_tile(tile_id)
			var texture := TextureFactory.make_tile_texture(tile_id, tile_def)
			var rect := Rect2(Vector2(x * TILE_SIZE, y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
			draw_texture_rect(texture, rect, false)
			_draw_autotile_edges(tile, rect, tile_def)
			_draw_tile_break_overlay(tile, rect, tile_def)

	for beacon in beacons:
		draw_circle(beacon, 9.0, Color8(255, 214, 107, 120))
		draw_rect(Rect2(beacon - Vector2(4, 10), Vector2(8, 14)), Color8(192, 139, 62))
	for flare in flares:
		draw_circle(flare.position, 5.0, Color8(255, 138, 31, 170))

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

func _draw_tile_break_overlay(tile: Vector2i, rect: Rect2, tile_def: Dictionary) -> void:
	var damage := store.get_damage(tile)
	if damage <= 0.0 or not bool(tile_def.breakable):
		return
	var progress_ratio: float = clampf(damage / float(tile_def.hardness), 0.0, 0.999)
	var stage_index := clampi(ceili(progress_ratio * BREAK_STAGE_COUNT) - 1, 0, BREAK_STAGE_COUNT - 1)
	var sheet := TextureFactory.make_effect_texture("tile_breaking_%s_sheet" % String(tile_def.get("id", get_tile(tile))))
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
