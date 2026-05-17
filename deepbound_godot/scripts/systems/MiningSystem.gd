extends RefCounted
class_name MiningSystem

const TileCatalog = preload("res://scripts/catalogs/TileCatalog.gd")

const STARTER_DRILL := {
	"power": 1.0,
	"reach_tiles": 1.45,
	"heat_per_second": 0.16,
	"cool_per_second": 0.34
}
const BREAK_STAGE_COUNT := 5

static func damage_stage(progress_ratio: float) -> int:
	if progress_ratio <= 0.0:
		return 0
	return clampi(ceili(clampf(progress_ratio, 0.0, 0.999) * BREAK_STAGE_COUNT), 1, BREAK_STAGE_COUNT)

func mine_tile(store, tile: Vector2i, inventory, delta: float, drill_heat := 0.0) -> Dictionary:
	var tile_id: String = store.get_tile(tile)
	var tile_def: Dictionary = TileCatalog.get_tile(tile_id)
	if not bool(tile_def.solid):
		return {"target": tile, "tile": tile_id, "broke": false, "progress": 0.0, "stage": 0, "drops": [], "blocked": "empty"}
	if not bool(tile_def.breakable):
		return {"target": tile, "tile": tile_id, "broke": false, "progress": 0.0, "stage": 0, "drops": [], "blocked": "unbreakable"}

	var heat_factor: float = maxf(0.45, 1.0 - drill_heat * 0.35)
	var progress: float = store.get_damage(tile) + float(STARTER_DRILL.power) * heat_factor * delta
	var progress_ratio := progress / float(tile_def.hardness)
	if progress < float(tile_def.hardness):
		store.set_damage(tile, progress)
		return {"target": tile, "tile": tile_id, "broke": false, "progress": progress_ratio, "stage": damage_stage(progress_ratio), "drops": []}

	store.set_tile(tile, "air")
	var drops: Array[Dictionary] = []
	for drop in tile_def.drops:
		var count: int = int(drop.max)
		var remaining: int = inventory.add_item(String(drop.item), count)
		drops.append({"item": String(drop.item), "count": count - remaining})
	return {"target": tile, "tile": tile_id, "broke": true, "progress": 1.0, "stage": BREAK_STAGE_COUNT, "drops": drops}
