# Deepbound Sprints 1-5: Six-Agent Studio Loop

## Sprint 1: Band 1 Vertical Slice

**Story Writer:** Band 1 is the old survival layer where humanity first fled beneath the dead surface. It is familiar enough to feel safe, but every echo hints that the deeper world is alive. Flora is sparse: root hairs, pale lichen, and dust fungus. Fauna includes cave skitters and small blind scavengers. Hazards are loose floors, darkness, and unstable starter tunnels.

**Game Designer:** Core tiles are loose dirt (`0.75` hardness), compacted dirt (`1.2`), soft stone (`2.1`), and copper ore (`2.4`). Cave skitter stats: `24` health, `8` contact damage, `8` tile aggro radius. Starter mining should produce enough dirt/stone for first torch bundles within `2-3` minutes, with copper as a slower but higher-value target. Expected value per second must keep copper above dirt while preserving dirt as fast feedback.

**Coder:** Implement Phaser + Vite + TypeScript, deterministic horizontal chunking, Band resolution, tile collision, mining state, inventory, local lighting, starter enemy state, and SVG HUD derived from gameplay state. The runtime flow is input -> physics -> chunk reads -> mining/combat -> lighting -> Phaser render -> SVG HUD render.

**Pixel Art Designer:** Use earthy browns, cool stone grays, brass lamp accents, and copper glints. The Delver is `24x32`, tiles are `16x16`, and all textures are runtime-generated prototype pixel art. UI uses forged iron borders and crystal health pips.

**Art Reviewer:** Approve only if the Delver silhouette reads against both dirt and stone, the cave skitter is clearly hostile, copper ore has a brighter value than normal stone, and darkness does not hide interactable silhouettes.

**Veteran Player:** Pass condition: the player can move, mine, collect drops, read the HUD, and fight or avoid the first skitter without feeling confused. Fail if early mining feels empty, if drilling lacks feedback, or if the HUD covers the play space.

**Status:** Approved for vertical-slice implementation.

## Sprint 2: Band 1 Polish and Autotiling

**Story Writer:** Band 1 should feel hand-worn by generations of refugees: old pitons, broken rope anchors, and abandoned starter shafts.

**Game Designer:** Add copper brace crafting, flare bundles, and early drill upgrade math. Autotile changes must never affect collision timing. Cave-in hints remain visual only until later structural integrity work.

**Coder:** Implement 47-tile autotile masks, dirty `3x3` neighbor updates after excavation, particle event hooks, and render cache invalidation. Add save-ready chunk override persistence.

**Pixel Art Designer:** Expand dirt, stone, copper, break overlays, and particle sprites. Add background wall variants at `45-65%` foreground value.

**Art Reviewer:** Reject noisy tile variants. Corners must reconnect cleanly after mining, and foreground/background separation must remain obvious.

**Veteran Player:** Pass condition: ten minutes of mining remains satisfying and visually readable.

## Sprint 3: Core UI and First Outpost

**Story Writer:** The first outpost is a rescued survey post: small, practical, and emotional because it proves the Delver is not alone.

**Game Designer:** Add quickbar selection, inventory panel, flare crafting, outpost beacon placement, and beacon safety radius. Light should reduce danger but not remove all tension.

**Coder:** Add scalable SVG inventory overlays, item drag/drop state, beacon placement validation, flare light sources, and save/load for inventory and placed beacon data.

**Pixel Art Designer:** UI panels use forged iron and stone tablet motifs. Beacon art uses brass legs, warm lamp glass, and a compact silhouette.

**Art Reviewer:** UI must not use rounded pill labels where icons work better. Text must stay small and never overlap at mobile or desktop sizes.

**Veteran Player:** Pass condition: the outpost loop makes returning from a dig feel rewarding without turning the game into menu management.

## Sprint 4: Band 2 Colossal Ant Chambers

**Story Writer:** Band 2 is a living megastructure. Ants are not evil; they are a civilization of instinct, pheromone law, and royal hunger. Flora is replaced by waxy fungus and amber sacs. Hazards are resin seals, swarm routes, and pheromone alarms.

**Game Designer:** Add excavated earth, hardened resin, amber ore, worker ants, soldier ants, and royal jelly pockets. Resin is slower than Band 1 stone but partly translucent to light. Royal jelly has high value but triggers escalating swarm attention.

**Coder:** Add Band 2 generation from `tileY 384-767`, chamber rooms, tunnel ribs, pheromone decals, swarm director state, and ant pathing. Preserve deterministic chunk generation.

**Pixel Art Designer:** Use amber, mustard yellow, resin browns, wet highlights, rounded organic tiles, and segmented ant silhouettes. Amber ore needs a bright core and separate glow mask.

**Art Reviewer:** Reject any resin that reads as ordinary dirt. Ant castes must be distinguishable by silhouette, not only color.

**Veteran Player:** Pass condition: the Band transition is exciting, readable, and mechanically different without becoming a sudden difficulty cliff.

## Sprint 5: Band 3 Buried Pyramids

**Story Writer:** Band 3 is an impossible desert civilization folded underground. Its tombs were not buried by sand; they were dragged downward by the same force that created the Solid Dark Blocks. Fauna is sparse, undead, and ceremonial. Hazards are traps, curses, and collapsing ritual corridors.

**Game Designer:** Add sandstone blocks, oxidized copper, mummy sentries, scarab swarms, dart traps, pressure plates, and cursed treasure rooms. Mining ROI shifts toward risk/reward: tomb blocks are slower, but treasure caches create burst value.

**Coder:** Add room-graph generation, locked tomb doors, trap trigger state, line-of-sight dart logic, mummy patrol routes, and treasure roll tables. Trap state must serialize cleanly.

**Pixel Art Designer:** Use desaturated sand, cracked sandstone, oxidized copper greens, and right-angled geometry. Mummies shamble with stiff `4-6` frame animation.

**Art Reviewer:** Reject organic cave curves in primary pyramid architecture. Traps must be visually readable before activation.

**Veteran Player:** Pass condition: tomb exploration feels tense and profitable, not like random unavoidable damage.

