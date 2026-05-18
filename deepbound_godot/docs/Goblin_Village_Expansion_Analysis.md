# Goblin Village Expansion Analysis

Reference goal: a side-view cavern settlement with playable foreground rooms, stacked scaffold reads, vertical ladder shafts, warm torch pools, teal cave-glow accents, and several houses that are decorative background silhouettes rather than collision structures.

## Required Construction Tiles

- `goblin_mossy_brick`: dark, cracked retaining brick for the reference image's stone wall sections, lower foundations, and side-room borders.
- `goblin_plank_platform`: rough timber deck/floor for scaffold spans, raised huts, and rope-bridge approaches.
- `goblin_timber_wall`: solid timber room shell for huts, cages, and palisade inserts.
- `goblin_packed_floor`: packed dirt floor for excavated rooms and lower chambers.
- `goblin_hide_canopy`: stitched hide roof/canopy tile for hut roofs and ragged shade panels.

## Required Props And Facades

- `goblin_rope_ladder`: vertical ladder segment for shaft readability.
- `goblin_rope_bridge`: horizontal rope-rail piece for platforms and suspended walks.
- `goblin_scaffold_post`: tall support post for multi-tier village construction.
- `goblin_diagonal_brace`: diagonal support/stair-read piece for timber structures.
- `goblin_central_hut`: large foreground hut facade used as the main visual anchor.
- `goblin_back_hut_lit` and `goblin_back_hut_dark`: background-only hut facades drawn behind foreground tiles.
- `goblin_work_shelf`: shelf/workbench prop for storehouse and market rooms.
- `goblin_wall_torch`: taller wall torch prop for reference-style vertical light sources.

## Structure Rules

- Keep collision on foreground tile IDs only; ladders and hut facades are props for now.
- Draw decorative huts on the `backdrop` prop layer so stone/floor tiles remain readable in front.
- Use the large central hut inside the main chamber and raised hut template, then surround it with mossy brick and plank floors.
- Use ladder shafts as tall optional buildings with platform rows, scaffold posts, and bridge rail props, while keeping entrances near the same baseline for current movement constraints.
- Preserve three-tile-high connectors so existing pathing tests and player movement remain stable.
- Prioritize one ladder, raised hut, or scaffold setpiece per generated village so the reference-image silhouette appears consistently.
- Use plank-platform connector floors when attaching those setpieces, while keeping packed-floor connectors for older excavated rooms.

## Source Board

The generated source board is saved as `assets/source_ai/goblin_village_expansion_ai_reference.png`. Engine-ready crops are extracted by `tools/build_pixel_assets.py` into `assets/tiles/`, `assets/props/`, `assets/effects/`, and `assets/previews/`.
