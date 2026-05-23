extends RefCounted
class_name LiquidSystem

## Pure static cellular-automata liquid simulation.
##
## No Node or scene-tree dependency — takes a ChunkStore and a world-reference
## (duck-typed for is_solid_tile()) as parameters.  All state lives in the
## store's `liquids` dictionary.
##
## Algorithm (per tick, per active cell):
##   1. Gravity   — move as much volume as possible downward.
##   2. Dispersion — if below is blocked/full, equalize volume across eligible
##                   horizontal neighbours (same type or empty, not solid).
##   3. Reactions  — when incompatible types (Water + Lava) would merge, consume
##                   liquid from both and emit a solid-block placement event.
##
## Optimisation:
##   Cells that neither move nor receive liquid are dropped from the active set.
##   Neighbours of any moved cell are always re-queued, which "wakes" liquid when
##   an adjacent block is broken or new liquid is poured.

const LiquidCatalog = preload("res://scripts/catalogs/LiquidCatalog.gd")

const MAX_VOLUME     := LiquidCatalog.MAX_VOLUME
const MIN_SPREAD_VOL := LiquidCatalog.MIN_SPREAD_VOLUME

## Run one simulation tick across the provided active_set.
##
## Parameters:
##   store      — ChunkStore (must expose get_liquid/set_liquid/clear_liquid)
##   world      — DeepboundWorld (must expose is_solid_tile(Vector2i) -> bool)
##   active_set — Dictionary mapping Vector2i → true  (set of cells to process)
##
## Returns:
##   {
##     "reactions":   Array[Dictionary]  [{"tile": Vector2i, "tile_id": String}]
##     "next_active": Dictionary          next active set (Vector2i → true)
##   }
static func tick(store, world, active_set: Dictionary) -> Dictionary:
	var reactions: Array[Dictionary] = []
	var next_active: Dictionary      = {}
	# h_moved: tiles that already performed a horizontal spread this tick
	# (prevents double-spreading the same volume leftward twice).
	var h_moved: Dictionary          = {}

	# Process top-to-bottom (ascending y) so gravity cascades downward in one tick.
	var sorted_tiles: Array = active_set.keys()
	sorted_tiles.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y if a.y != b.y else a.x < b.x
	)

	for raw_tile in sorted_tiles:
		var tile: Vector2i = Vector2i(raw_tile)
		var liq: Dictionary      = Dictionary(store.get_liquid(tile))
		var liq_type := int(liq.get("type",   0))
		var volume   := int(liq.get("volume", 0))

		if liq_type == 0 or volume <= 0:
			continue

		# ── Gravity ───────────────────────────────────────────────────────────
		var below: Vector2i    = tile + Vector2i(0, 1)
		var did_react := false

		if not world.is_solid_tile(below):
			var below_liq: Dictionary  = Dictionary(store.get_liquid(below))
			var below_type := int(below_liq.get("type",   0))
			var below_vol  := int(below_liq.get("volume", 0))

			if below_type != 0 and below_type != liq_type:
				# Potentially reactive neighbour.
				var result_tile := LiquidCatalog.react(liq_type, below_type)
				if result_tile != "":
					# Consume 1 unit of the source liquid; remove all from the lava/
					# reactive cell and schedule the solid block placement.
					volume -= 1
					if volume <= 0:
						store.clear_liquid(tile)
					else:
						store.set_liquid(tile, liq_type, volume)
					store.clear_liquid(below)
					reactions.append({"tile": below, "tile_id": result_tile})
					_add_with_neighbors(next_active, tile)
					_add_with_neighbors(next_active, below)
					did_react = true
			else:
				# Compatible cell (same type or empty) — flow downward.
				var space    := MAX_VOLUME - below_vol
				var transfer := mini(volume, space)
				if transfer > 0:
					volume -= transfer
					if volume <= 0:
						store.clear_liquid(tile)
					else:
						store.set_liquid(tile, liq_type, volume)
					store.set_liquid(below, liq_type, below_vol + transfer)
					if volume > 0:
						next_active[tile] = true
					_add_with_neighbors(next_active, below)
					if volume <= 0:
						continue  # tile emptied — nothing left to spread

		if did_react:
			continue

		# Re-read volume (may have changed after gravity step).
		var cur_liq: Dictionary = Dictionary(store.get_liquid(tile))
		liq_type     = int(cur_liq.get("type",   liq_type))
		volume       = int(cur_liq.get("volume", 0))
		if volume <= 0:
			continue

		# ── Horizontal Spread ─────────────────────────────────────────────────
		# Only spread if this cell hasn't already dispersed this tick and has
		# enough volume to justify spreading.
		if h_moved.has(tile) or volume < MIN_SPREAD_VOL:
			next_active[tile] = true
			continue

		# Collect eligible horizontal neighbours: same type or empty, not solid,
		# no conflicting reaction.
		var neighbors: Array = [tile]
		for dx in [-1, 1]:
			var nb: Vector2i = tile + Vector2i(dx, 0)
			if world.is_solid_tile(nb):
				continue
			var nb_liq: Dictionary = Dictionary(store.get_liquid(nb))
			var nb_type := int(nb_liq.get("type",   0))
			var nb_vol  := int(nb_liq.get("volume", 0))

			if nb_type != 0 and nb_type != liq_type:
				# Check for horizontal reaction.
				var h_result := LiquidCatalog.react(liq_type, nb_type)
				if h_result != "" and nb_vol > 0:
					# Horizontal reaction: consume 1 from source, clear reaction cell.
					volume -= 1
					if volume <= 0:
						store.clear_liquid(tile)
					else:
						store.set_liquid(tile, liq_type, volume)
					store.clear_liquid(nb)
					reactions.append({"tile": nb, "tile_id": h_result})
					_add_with_neighbors(next_active, tile)
					_add_with_neighbors(next_active, nb)
					# Re-read volume for remaining spread logic.
					var post_liq: Dictionary = Dictionary(store.get_liquid(tile))
					volume = int(post_liq.get("volume", 0))
				# Don't include the reactive cell in eligible neighbours.
				continue
			neighbors.append(nb)

		if volume <= 0:
			continue

		if neighbors.size() <= 1:
			# No eligible horizontal neighbours — stay put.
			next_active[tile] = true
			continue

		# Equalize volume across all eligible neighbours (including this cell).
		var total := 0
		for nb in neighbors:
			total += int(store.get_liquid(nb).get("volume", 0))

		# Conservation check: don't equalize if this cell would gain volume
		# (only spread outward, never pull inward here).
		var avg       := total / neighbors.size()
		var remainder := total % neighbors.size()
		# Centre cell (index 0) receives any leftover volume.

		var did_spread := false
		for idx in range(neighbors.size()):
			var nb: Vector2i = neighbors[idx]
			var old_vol  := int(store.get_liquid(nb).get("volume", 0))
			var want_vol := avg + (1 if idx == 0 and remainder > 0 else 0)
			# Additional remainder units go to the leftmost neighbour (index 1).
			if idx == 1 and remainder > 1:
				want_vol += remainder - 1
			if old_vol == want_vol:
				continue
			if want_vol <= 0:
				store.clear_liquid(nb)
			else:
				store.set_liquid(nb, liq_type, want_vol)
			did_spread = true
			next_active[nb] = true

		if did_spread:
			h_moved[tile] = true
			for nb in neighbors:
				h_moved[nb] = true
			_add_with_neighbors(next_active, tile)
		else:
			next_active[tile] = true

	return {"reactions": reactions, "next_active": next_active}

# ── Helpers ───────────────────────────────────────────────────────────────────

## Adds tile and its four cardinal neighbours to dict (used as a set).
static func _add_with_neighbors(dict: Dictionary, tile: Vector2i) -> void:
	dict[tile]                    = true
	dict[tile + Vector2i( 0, -1)] = true
	dict[tile + Vector2i( 0,  1)] = true
	dict[tile + Vector2i(-1,  0)] = true
	dict[tile + Vector2i( 1,  0)] = true
