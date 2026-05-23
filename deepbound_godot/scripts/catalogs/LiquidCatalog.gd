extends RefCounted
class_name LiquidCatalog

## Liquid type integer constants, visual data, and reaction rules.
##
## Liquid state is stored in ChunkStore.liquids (sparse Dictionary) as
## {"type": int, "volume": int} per tile.  Volume 0 = no liquid.

# ── Type constants ─────────────────────────────────────────────────────────────
const NONE  := 0
const WATER := 1
const LAVA  := 2
const HONEY := 3

# ── Volume ─────────────────────────────────────────────────────────────────────
## Maximum volume units per cell (completely full tile).
const MAX_VOLUME := 8
## Minimum remaining volume before horizontal spread is attempted.
## A lone 1-unit puddle will not spread sideways (prevents infinite thinning).
const MIN_SPREAD_VOLUME := 2

# ── Visuals ────────────────────────────────────────────────────────────────────
## Base fill colours (alpha handled dynamically by volume).
const LIQUID_COLORS: Dictionary = {
	WATER: Color8( 48, 112, 200),
	LAVA:  Color8(230,  85,  20),
	HONEY: Color8(220, 165,  25),
}

## Base alpha multiplier at full volume (volume == MAX_VOLUME).
const BASE_ALPHA: Dictionary = {
	WATER: 0.72,
	LAVA:  0.88,
	HONEY: 0.82,
}

const LIQUID_NAMES: Dictionary = {
	NONE:  "None",
	WATER: "Water",
	LAVA:  "Lava",
	HONEY: "Honey",
}

# ── Bucket items ───────────────────────────────────────────────────────────────
## Filled-bucket item IDs corresponding to each liquid type.
const BUCKET_ITEMS: Dictionary = {
	WATER: "water_bucket",
	LAVA:  "lava_bucket",
	HONEY: "honey_bucket",
}

# ── Reactions ──────────────────────────────────────────────────────────────────
## Tile placed when Water contacts Lava.
const WATER_LAVA_RESULT_TILE := "obsidian"

# ── Static helpers ─────────────────────────────────────────────────────────────

static func is_valid_type(t: int) -> bool:
	return t == WATER or t == LAVA or t == HONEY

static func get_color(t: int) -> Color:
	return Color(LIQUID_COLORS.get(t, Color.TRANSPARENT))

static func get_name(t: int) -> String:
	return String(LIQUID_NAMES.get(t, "Unknown"))

## Returns the draw alpha for a cell with the given type and volume.
static func get_alpha(t: int, volume: int) -> float:
	var base := float(BASE_ALPHA.get(t, 0.75))
	return base * clampf(float(volume) / float(MAX_VOLUME), 0.0, 1.0)

## Returns the tile_id produced when type_a contacts type_b,
## or "" if there is no reaction.
static func react(type_a: int, type_b: int) -> String:
	if (type_a == WATER and type_b == LAVA) or (type_a == LAVA and type_b == WATER):
		return WATER_LAVA_RESULT_TILE
	return ""

## Returns the filled-bucket item_id for a liquid type, or "" if invalid.
static func bucket_item_for_type(liquid_type: int) -> String:
	return String(BUCKET_ITEMS.get(liquid_type, ""))
