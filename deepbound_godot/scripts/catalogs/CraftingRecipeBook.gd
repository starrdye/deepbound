extends RefCounted
class_name CraftingRecipeBook

## All recipes keyed by recipe_id (matches the result item_id for single-output recipes).
## stations: [] = hand-craft; any entries must match CraftingSystem.STATION_TILE_MAP values.
const RECIPES := {
	# ── Hand ──────────────────────────────────────────────────────────────────
	"workbench": {
		"result": "workbench",
		"result_count": 1,
		"ingredients": [
			{"item": "stone_chunk", "count": 8},
			{"item": "dirt_clod",   "count": 12},
		],
		"stations": [],
	},
	"dirt_background_block": {
		"result": "dirt_background_block",
		"result_count": 2,
		"ingredients": [{"item": "dirt_clod", "count": 1}],
		"stations": [],
	},
	"stone_background_block": {
		"result": "stone_background_block",
		"result_count": 2,
		"ingredients": [{"item": "stone_chunk", "count": 1}],
		"stations": [],
	},
	"wooden_background_block": {
		"result": "wooden_background_block",
		"result_count": 2,
		"ingredients": [{"item": "dirt_clod", "count": 2}],
		"stations": [],
	},
	# ── Workbench ─────────────────────────────────────────────────────────────
	"wooden_sword": {
		"result": "wooden_sword",
		"result_count": 1,
		"ingredients": [{"item": "stone_chunk", "count": 5}],
		"stations": ["Workbench"],
	},
	"hammer": {
		"result": "hammer",
		"result_count": 1,
		"ingredients": [{"item": "stone_chunk", "count": 8}],
		"stations": ["Workbench"],
	},
	"chest": {
		"result": "chest",
		"result_count": 1,
		"ingredients": [
			{"item": "stone_chunk", "count": 4},
			{"item": "dirt_clod",   "count": 4},
		],
		"stations": ["Workbench"],
	},
	"furnace": {
		"result": "furnace",
		"result_count": 1,
		"ingredients": [
			{"item": "stone_chunk",  "count": 20},
			{"item": "copper_nugget","count": 5},
		],
		"stations": ["Workbench"],
	},
	# ── Workbench + Furnace ───────────────────────────────────────────────────
	"anvil": {
		"result": "anvil",
		"result_count": 1,
		"ingredients": [
			{"item": "stone_chunk",  "count": 10},
			{"item": "copper_nugget","count": 20},
		],
		"stations": ["Workbench", "Furnace"],
	},
	# ── Workbench + Anvil ─────────────────────────────────────────────────────
	"crystal_sword": {
		"result": "crystal_sword",
		"result_count": 1,
		"ingredients": [
			{"item": "resin_shard",  "count": 10},
			{"item": "copper_nugget","count": 15},
		],
		"stations": ["Workbench", "Anvil"],
	},
	"crystal_drill": {
		"result": "crystal_drill",
		"result_count": 1,
		"ingredients": [
			{"item": "resin_shard",  "count": 8},
			{"item": "copper_nugget","count": 20},
		],
		"stations": ["Workbench", "Anvil"],
	},
	# ── Workbench + Furnace + Anvil ───────────────────────────────────────────
	"cursed_sword": {
		"result": "cursed_sword",
		"result_count": 1,
		"ingredients": [
			{"item": "obsidian_chip", "count": 5},
			{"item": "cursed_relic",  "count": 1},
			{"item": "drow_silk",     "count": 3},
		],
		"stations": ["Workbench", "Furnace", "Anvil"],
	},
	"cursed_drill": {
		"result": "cursed_drill",
		"result_count": 1,
		"ingredients": [
			{"item": "obsidian_chip", "count": 8},
			{"item": "cursed_relic",  "count": 2},
			{"item": "copper_nugget", "count": 15},
		],
		"stations": ["Workbench", "Furnace", "Anvil"],
	},
}
