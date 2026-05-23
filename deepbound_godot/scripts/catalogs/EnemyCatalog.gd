extends RefCounted
class_name EnemyCatalog

const ENEMIES := {
	"cave_skitter": {"name": "Cave Skitter", "band": "standard_caverns", "health": 24, "damage": 8, "speed": 34.0, "aggro_tiles": 8, "color": Color8(139, 70, 80)},
	"goblin_grunt": {"name": "Goblin Grunt", "band": "standard_caverns", "health": 34, "damage": 10, "speed": 42.0, "aggro_tiles": 10, "color": Color8(91, 126, 48)},
	"goblin_slinger": {"name": "Goblin Slinger", "band": "standard_caverns", "health": 26, "damage": 8, "speed": 46.0, "aggro_tiles": 12, "color": Color8(124, 142, 61)},
	"goblin_shaman": {"name": "Goblin Shaman", "band": "standard_caverns", "health": 42, "damage": 13, "speed": 30.0, "aggro_tiles": 11, "color": Color8(97, 119, 52)},
	"worker_ant": {"name": "Worker Ant", "band": "colossal_ant_chambers", "health": 34, "damage": 10, "speed": 42.0, "aggro_tiles": 9, "color": Color8(198, 134, 51)},
	"soldier_ant": {"name": "Soldier Ant", "band": "colossal_ant_chambers", "health": 58, "damage": 16, "speed": 36.0, "aggro_tiles": 10, "color": Color8(143, 95, 34)},
	"dwarf_guard": {"name": "Dwarf Guard", "band": "colossal_ant_chambers", "health": 62, "damage": 16, "speed": 31.0, "aggro_tiles": 9, "color": Color8(138, 111, 72)},
	"dwarf_crossbowman": {"name": "Dwarf Crossbowman", "band": "colossal_ant_chambers", "health": 46, "damage": 14, "speed": 34.0, "aggro_tiles": 13, "color": Color8(118, 100, 82)},
	"dwarf_smith": {"name": "Dwarf Smith", "band": "colossal_ant_chambers", "health": 70, "damage": 18, "speed": 27.0, "aggro_tiles": 9, "color": Color8(152, 93, 54)},
	"mummy_sentry": {"name": "Mummy Sentry", "band": "buried_pyramids", "health": 72, "damage": 18, "speed": 25.0, "aggro_tiles": 7, "color": Color8(210, 179, 106)},
	"drow_warrior": {"name": "Drow Warrior", "band": "drow_enclaves", "health": 95, "damage": 24, "speed": 32.0, "aggro_tiles": 11, "color": Color8(62, 55, 119)},
	"drow_acolyte": {"name": "Drow Acolyte", "band": "drow_enclaves", "health": 65, "damage": 28, "speed": 36.0, "aggro_tiles": 13, "color": Color8(112, 206, 177)}
}

const COLLIDERS := {
	"cave_skitter": {"width": 14.0, "height": 10.0},
	"goblin_grunt": {"width": 14.0, "height": 25.0},
	"goblin_slinger": {"width": 14.0, "height": 24.0},
	"goblin_shaman": {"width": 15.0, "height": 27.0},
	"worker_ant": {"width": 18.0, "height": 10.0},
	"soldier_ant": {"width": 22.0, "height": 12.0},
	"dwarf_guard": {"width": 16.0, "height": 24.0},
	"dwarf_crossbowman": {"width": 16.0, "height": 23.0},
	"dwarf_smith": {"width": 18.0, "height": 25.0},
	"mummy_sentry": {"width": 14.0, "height": 28.0},
	"tunneling_worm_head": {"width": 26.0, "height": 18.0},
	"tunneling_worm_segment": {"width": 12.0, "height": 12.0},
	"drow_warrior": {"width": 16.0, "height": 26.0},
	"drow_acolyte": {"width": 14.0, "height": 26.0}
}

const BOSSES := {
	"rootbound_foreman": {"band": "standard_caverns", "health": 420, "damage": 18, "unlock": "copper_brace"},
	"amber_queen": {"band": "colossal_ant_chambers", "health": 760, "damage": 26, "unlock": "royal_jelly"},
	"pharaoh_of_buried_sun": {"band": "buried_pyramids", "health": 920, "damage": 32, "unlock": "cursed_relic"},
	"drow_matriarch": {"band": "drow_enclaves", "health": 1100, "damage": 38, "unlock": "drow_silk"},
	"obsidian_baron": {"band": "abyssal_lava_slums", "health": 1360, "damage": 44, "unlock": "heat_core"}
}

## Drop tables: each entry is an Array of { item, count_min, count_max, chance }.
## `chance` is 0.0–1.0.  All matching entries are rolled independently each kill.
const DROPS := {
	"cave_skitter": [
		{"item": "dirt_clod",    "count_min": 1, "count_max": 2, "chance": 0.60},
		{"item": "copper_nugget","count_min": 1, "count_max": 1, "chance": 0.25},
	],
	"goblin_grunt": [
		{"item": "stone_chunk",  "count_min": 1, "count_max": 3, "chance": 0.65},
		{"item": "copper_nugget","count_min": 1, "count_max": 2, "chance": 0.40},
	],
	"goblin_slinger": [
		{"item": "stone_chunk",  "count_min": 1, "count_max": 2, "chance": 0.55},
		{"item": "copper_nugget","count_min": 1, "count_max": 2, "chance": 0.35},
	],
	"goblin_shaman": [
		{"item": "copper_nugget","count_min": 2, "count_max": 4, "chance": 0.70},
		{"item": "resin_shard",  "count_min": 1, "count_max": 1, "chance": 0.20},
	],
	"worker_ant": [
		{"item": "stone_chunk",  "count_min": 1, "count_max": 2, "chance": 0.60},
		{"item": "copper_nugget","count_min": 1, "count_max": 2, "chance": 0.30},
	],
	"soldier_ant": [
		{"item": "copper_nugget","count_min": 2, "count_max": 3, "chance": 0.65},
		{"item": "resin_shard",  "count_min": 1, "count_max": 2, "chance": 0.35},
	],
	"dwarf_guard": [
		{"item": "copper_nugget","count_min": 2, "count_max": 4, "chance": 0.75},
		{"item": "stone_chunk",  "count_min": 1, "count_max": 3, "chance": 0.50},
	],
	"dwarf_crossbowman": [
		{"item": "copper_nugget","count_min": 2, "count_max": 3, "chance": 0.70},
		{"item": "resin_shard",  "count_min": 1, "count_max": 1, "chance": 0.25},
	],
	"dwarf_smith": [
		{"item": "copper_nugget","count_min": 3, "count_max": 5, "chance": 0.80},
		{"item": "resin_shard",  "count_min": 1, "count_max": 2, "chance": 0.40},
	],
	"mummy_sentry": [
		{"item": "sandstone_shard","count_min": 1, "count_max": 3, "chance": 0.70},
		{"item": "copper_nugget",  "count_min": 2, "count_max": 4, "chance": 0.55},
		{"item": "cursed_relic",   "count_min": 1, "count_max": 1, "chance": 0.05},
	],
	"drow_warrior": [
		{"item": "copper_nugget","count_min": 3, "count_max": 5, "chance": 0.75},
		{"item": "drow_silk",    "count_min": 1, "count_max": 1, "chance": 0.15},
	],
	"drow_acolyte": [
		{"item": "copper_nugget","count_min": 2, "count_max": 4, "chance": 0.70},
		{"item": "drow_silk",    "count_min": 1, "count_max": 1, "chance": 0.20},
		{"item": "glow_spore",   "count_min": 1, "count_max": 1, "chance": 0.15},
	],
}

static func get_enemy(enemy_id: String) -> Dictionary:
	return ENEMIES.get(enemy_id, ENEMIES.cave_skitter)

static func get_collider(enemy_id: String) -> Dictionary:
	return COLLIDERS.get(enemy_id, COLLIDERS.cave_skitter)

## Roll all drops for an enemy and return an Array of { item, count } dicts.
## Returns an empty array if no drops roll.
static func roll_drops(enemy_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var table: Array = DROPS.get(enemy_id, [])
	for entry in table:
		if randf() <= float(entry.get("chance", 0.0)):
			var count_min: int = int(entry.get("count_min", 1))
			var count_max: int = int(entry.get("count_max", 1))
			var count: int = randi_range(count_min, count_max)
			if count > 0:
				result.append({"item": String(entry.get("item", "")), "count": count})
	return result
