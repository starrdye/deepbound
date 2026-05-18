# Deepbound Godot Studio: Sprints 1-5

This Godot version follows the six-agent loop exactly: Writer -> Designer -> Coder -> Art Designer -> Art Reviewer -> Veteran Player.

## Agent Introductions

**Agent 1: Story Writer.** I shape each Band as an ecosystem with lore, flora, fauna, hazards, and a reason to exist.

**Agent 2: Game Designer.** I turn that fiction into tile hardness, monster stats, crafting costs, drop rates, boss arcs, and mining ROI.

**Agent 3: Coder.** I implement deterministic Godot systems in GDScript: generation, mining, inventory, lighting, enemies, and UI state.

**Agent 4: Pixel Art Designer.** I define generated pixel textures, silhouettes, palettes, animation frames, and autotile intent.

**Agent 5: Art Reviewer.** I reject muddy palettes, unreadable enemies, and animation plans that do not preserve silhouette clarity.

**Agent 6: Veteran Player.** I judge whether the sprint is fun, fair, readable, and worth playing like a serious sandbox survival game.

## Sprint 1: Band 1 Foundation

**Writer:** Band 1 is the old survival layer: dirt, soft stone, root hairs, pale lichen, blind skitter fauna, and the first evidence that the deep is alive.

**Designer:** Loose dirt hardness `0.75`, compacted dirt `1.2`, soft stone `2.1`, copper `2.4`. Cave skitter: `24` health, `8` damage, `8` tile aggro radius. Copper has higher expected value than dirt, but dirt remains fast feedback.

**Coder:** Godot scene boots to `Main.tscn`, uses deterministic chunks, custom player collision, directional drilling, inventory drops, local light, starter enemy contact damage, and HUD state.

**Art Designer:** Generated `24x32` Delver texture, `16x16` terrain textures, copper highlights, dark colored outlines, and simple skitter silhouette.

**Art Reviewer:** Approved only because the player lamp, copper ore, and enemy body read clearly against Band 1 browns and grays.

**Veteran Player:** Pass. Movement, mining, and first combat are playable enough to proceed, though particles/audio are still future polish.

## Sprint 2: Band 1 Polish and Autotiling

**Writer:** Old pitons, broken anchors, and abandoned shafts give Band 1 a lived-in survival history.

**Designer:** Add flare bundles, copper brace crafting, and edge readability rules. Mining ROI remains positive without creating an early grind wall.

**Coder:** World rendering draws exposed tile edges as an autotile-style readability pass and supports flares as temporary light sources.

**Art Designer:** Terrain textures gain exposed-edge highlights and damage crack overlays.

**Art Reviewer:** Pass, with the constraint that true 47-tile atlases should replace generated edge lines in the production art pass.

**Veteran Player:** Pass. Mining reads better after exposed edges and remains fast enough.

## Sprint 3: Core UI and First Outpost

**Writer:** The first outpost beacon is a rescued survey post: tiny proof that the Delver can make the deep habitable.

**Designer:** Beacon placement creates a safe light island. Flares are immediate, temporary light. The hotbar shows resources without taking over the screen.

**Coder:** `HudController.gd` uses Godot `Control` drawing and labels for crisp scalable UI. `World.gd` stores beacons and flares.

**Art Designer:** UI uses forged dark panels, warm lamp color, and sparse labels.

**Art Reviewer:** Pass. The HUD is edge-weighted and does not cover the Delver.

**Veteran Player:** Pass. Beacon and flare tools make darkness feel manageable rather than punitive.

## Sprint 4: Band 2 Colossal Ant Chambers

**Writer:** Band 2 is a living megastructure of resin ribs, pheromone law, royal hunger, and caste movement.

**Designer:** Hardened resin hardness `3.8`; royal jelly hardness `1.0` with high resource value. Worker ants and soldier ants escalate threat.

**Coder:** Generator resolves `tileY 384-767`, places resin and deterministic royal jelly hooks, and spawns worker/soldier encounters when the player enters Band 2.

**Art Designer:** Resin uses amber-brown tiles with wet highlights. Ant silhouettes are warmer and more segmented than skitters.

**Art Reviewer:** Pass. Resin is distinct from dirt because it is warmer, glossier, and less opaque to light.

**Veteran Player:** Pass. Band 2 is a real gameplay shift, not just a recolor.

## Sprint 5: Band 3 Buried Pyramids

**Writer:** Band 3 is a swallowed tomb civilization dragged downward by the same force that made the Solid Dark Blocks.

**Designer:** Sandstone hardness `4.4`; cursed treasure has high value but belongs near trap logic. Mummy sentry: `72` health, `18` damage, slow pursuit.

**Coder:** Generator resolves `tileY 768-1151`, places sandstone, pressure plates, cursed treasure hooks, and spawns mummy sentries.

**Art Designer:** Band 3 uses right-angled sandstone, oxidized green trap accents, and stiff mummy silhouettes.

**Art Reviewer:** Pass, with production warning: pyramid rooms need true room-graph composition next.

**Veteran Player:** Pass for prototype. The tomb layer reads as risk/reward and has enough hooks for the next trap sprint.

## Acceptance Gates

- `godot4 --headless --path deepbound_godot --quit-after 1` imports without script errors.
- `godot4 --headless --path deepbound_godot --script tests/smoke_tests.gd` passes.
- Player can move, drill, collect resources, strike enemies, place a beacon, use a flare, and jump to prototype Band 2/3 encounters with `2` and `3`.
- Solid Dark Blocks resolve at `tileY >= 1920`.
