extends RefCounted
class_name CraftingSystem

const CraftingRecipeBook = preload("res://scripts/catalogs/CraftingRecipeBook.gd")
const ItemCatalog = preload("res://scripts/catalogs/ItemCatalog.gd")

const STATION_RADIUS_TILES := 6
const MODIFIER_CHANCE := 0.75
const WEAPON_MODIFIERS: Array[String] = [
	"Legendary", "Godly", "Ruthless", "Demonic", "Arcane", "Broken", "Damaged", "Weak",
]
const STATION_TILE_MAP := {
	"workbench_block": "Workbench",
	"furnace_block":   "Furnace",
	"anvil_block":     "Anvil",
}

## Scans tiles within STATION_RADIUS_TILES of player_position and returns the
## set of station names that are present (e.g. {"Workbench": true}).
static func detect_active_stations(world, player_position: Vector2) -> Dictionary:
	if world == null or not world.has_method("get_tile") or not world.has_method("world_to_tile"):
		return {}
	var player_tile: Vector2i = world.world_to_tile(player_position)
	var active := {}
	for dy in range(-STATION_RADIUS_TILES, STATION_RADIUS_TILES + 1):
		for dx in range(-STATION_RADIUS_TILES, STATION_RADIUS_TILES + 1):
			var tile_id := String(world.get_tile(player_tile + Vector2i(dx, dy)))
			if STATION_TILE_MAP.has(tile_id):
				active[String(STATION_TILE_MAP[tile_id])] = true
	return active

## Returns every recipe annotated with whether it is currently craftable given
## the player's inventory contents and nearby stations.
static func get_craftable_statuses(inventory, active_stations: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe_id in CraftingRecipeBook.RECIPES:
		var recipe: Dictionary = CraftingRecipeBook.RECIPES[recipe_id]
		result.append({
			"id":       recipe_id,
			"recipe":   recipe,
			"craftable": _can_craft(recipe, inventory, active_stations),
		})
	return result

## Consumes ingredients from inventory and returns the crafted stack, or {} on failure.
static func execute_craft(recipe_id: String, inventory, active_stations: Dictionary) -> Dictionary:
	var recipe: Dictionary = CraftingRecipeBook.RECIPES.get(recipe_id, {})
	if recipe.is_empty() or not _can_craft(recipe, inventory, active_stations):
		return {}
	_consume_ingredients(inventory, recipe.get("ingredients", []))
	var result_id    := String(recipe.get("result", ""))
	var result_count := int(recipe.get("result_count", 1))
	var stack := {"item": result_id, "count": result_count, "stack_cap": 99}
	var def := ItemCatalog.get_item(result_id)
	var category := String(def.get("category", ""))
	if (category == "weapon" or category == "accessory") and randf() < MODIFIER_CHANCE:
		stack["modifier"] = WEAPON_MODIFIERS[randi() % WEAPON_MODIFIERS.size()]
	return stack

static func _can_craft(recipe: Dictionary, inventory, active_stations: Dictionary) -> bool:
	for station in recipe.get("stations", []):
		if not active_stations.get(String(station), false):
			return false
	for ing in recipe.get("ingredients", []):
		if inventory.count_item(String(ing.item)) < int(ing.count):
			return false
	return true

static func _consume_ingredients(inventory, ingredients: Array) -> void:
	for ing in ingredients:
		var item_id    := String(ing.item)
		var to_remove  := int(ing.count)
		for slot in inventory.hotbar:
			if to_remove <= 0:
				break
			if String(slot.item) != item_id:
				continue
			var take := mini(to_remove, int(slot.count))
			slot.count = int(slot.count) - take
			to_remove -= take
			if int(slot.count) <= 0:
				slot.item = ""
		for slot in inventory.slots:
			if to_remove <= 0:
				break
			if String(slot.item) != item_id:
				continue
			var take := mini(to_remove, int(slot.count))
			slot.count = int(slot.count) - take
			to_remove -= take
			if int(slot.count) <= 0:
				slot.item = ""
