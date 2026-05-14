extends RefCounted
class_name LightingSystem

const BandCatalog = preload("res://scripts/catalogs/BandCatalog.gd")
const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")

static func trace_line_of_sight(store, origin: Vector2i, target: Vector2i) -> float:
	var delta := target - origin
	var steps := maxi(abs(delta.x), abs(delta.y))
	if steps == 0:
		return 1.0
	var visibility := 1.0
	for i in range(1, steps + 1):
		var tile := Vector2i(roundi(float(origin.x) + float(delta.x) * float(i) / float(steps)), roundi(float(origin.y) + float(delta.y) * float(i) / float(steps)))
		var tile_def := TileCatalog.get_tile(store.get_tile(tile))
		visibility -= float(tile_def.occlusion) * 0.36
		if visibility <= 0.0:
			return 0.0
	return maxf(0.0, visibility)

static func sample_light(store, tile: Vector2i, sources: Array[Dictionary]) -> float:
	var intensity := float(BandCatalog.get_band(tile.y).ambient_light)
	for source in sources:
		var origin := Vector2i(floori(float(source.position.x) / 16.0), floori(float(source.position.y) / 16.0))
		var distance := Vector2(origin).distance_to(Vector2(tile))
		var radius := float(source.radius_tiles)
		if distance > radius:
			continue
		var visibility := trace_line_of_sight(store, origin, tile)
		intensity += float(source.intensity) * (1.0 - distance / radius) * visibility
	return clampf(intensity, 0.0, 1.0)

static func danger_pulse(local_light: float, depth_danger: float, hostile_nearby: bool) -> float:
	var darkness := 0.0
	if local_light < 0.35:
		darkness = (0.35 - local_light) / 0.35
	return clampf(darkness * 0.55 + depth_danger * 0.25 + (0.35 if hostile_nearby else 0.0), 0.0, 1.0)
