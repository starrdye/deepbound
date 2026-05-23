extends RefCounted
class_name VendorCatalog

## Static registry of vendor shops.
## stock entries:
##   item  — item_id from ItemCatalog
##   price — cost in copper_nuggets
##   count — available stock (-1 = unlimited)

const SHOPS := {
	"wandering_merchant": {
		"title": "Wandering Merchant",
		"stock": [
			{"item": "wooden_sword",  "price": 6,  "count": -1},
			{"item": "hammer",        "price": 8,  "count": -1},
			{"item": "chest",         "price": 10, "count": -1},
			{"item": "stone_chunk",   "price": 2,  "count": -1},
			{"item": "dirt_clod",     "price": 1,  "count": -1},
			{"item": "crystal_sword", "price": 60, "count": 1},
			{"item": "crystal_drill", "price": 70, "count": 1},
		],
	},
}

## How many copper_nuggets the vendor pays the player for one of an item.
const SELL_PRICES := {
	"dirt_clod":       1,
	"stone_chunk":     1,
	"copper_nugget":   2,
	"resin_shard":     5,
	"sandstone_shard": 4,
	"royal_jelly":    20,
	"glow_spore":      8,
	"drow_silk":      15,
	"obsidian_chip":  12,
	"cursed_relic":   40,
	"wooden_sword":    3,
	"hammer":          4,
	"crystal_sword":  30,
	"cursed_sword":   50,
	"crystal_drill":  35,
	"cursed_drill":   55,
}

static func get_shop(shop_id: String) -> Dictionary:
	return SHOPS.get(shop_id, {})

static func get_sell_price(item_id: String) -> int:
	return int(SELL_PRICES.get(item_id, 0))
