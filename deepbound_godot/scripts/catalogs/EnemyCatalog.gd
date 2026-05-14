extends RefCounted
class_name EnemyCatalog

const ENEMIES := {
	"cave_skitter": {"name": "Cave Skitter", "band": "standard_caverns", "health": 24, "damage": 8, "speed": 34.0, "aggro_tiles": 8, "color": Color8(139, 70, 80)},
	"worker_ant": {"name": "Worker Ant", "band": "colossal_ant_chambers", "health": 34, "damage": 10, "speed": 42.0, "aggro_tiles": 9, "color": Color8(198, 134, 51)},
	"soldier_ant": {"name": "Soldier Ant", "band": "colossal_ant_chambers", "health": 58, "damage": 16, "speed": 36.0, "aggro_tiles": 10, "color": Color8(143, 95, 34)},
	"mummy_sentry": {"name": "Mummy Sentry", "band": "buried_pyramids", "health": 72, "damage": 18, "speed": 25.0, "aggro_tiles": 7, "color": Color8(210, 179, 106)}
}

const BOSSES := {
	"rootbound_foreman": {"band": "standard_caverns", "health": 420, "damage": 18, "unlock": "copper_brace"},
	"amber_queen": {"band": "colossal_ant_chambers", "health": 760, "damage": 26, "unlock": "royal_jelly"},
	"pharaoh_of_buried_sun": {"band": "buried_pyramids", "health": 920, "damage": 32, "unlock": "cursed_relic"},
	"drow_matriarch": {"band": "drow_enclaves", "health": 1100, "damage": 38, "unlock": "drow_silk"},
	"obsidian_baron": {"band": "abyssal_lava_slums", "health": 1360, "damage": 44, "unlock": "heat_core"}
}

static func get_enemy(enemy_id: String) -> Dictionary:
	return ENEMIES.get(enemy_id, ENEMIES.cave_skitter)

