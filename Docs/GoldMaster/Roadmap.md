# Deepbound Gold Master Roadmap

This roadmap converts Deepbound from a docs-only pre-production package into a commercial-ready sandbox adventure through a disciplined six-agent studio loop.

## Studio Loop

Every sprint runs in this exact order:

1. **Story Writer (Worldbuilder):** Defines lore, ecology, hazards, flora, fauna, and Band identity.
2. **Game Designer (Mechanics and Balance):** Defines tile stats, monster stats, boss encounters, resource drop rates, crafting costs, and mining return on investment.
3. **Coder (Logic and Architecture):** Converts the design into TypeScript systems, procedural generation, state management, and scalable SVG UI overlays.
4. **Pixel Art Designer (Visuals):** Specifies sprite sheets, autotiles, animation keyframes, palettes, silhouettes, and UI motifs.
5. **Art Reviewer (Visual QA):** Rejects unclear silhouettes, inconsistent outlines, muddy palettes, and animation timing problems.
6. **Veteran Player (Playability QA):** Approves or fails the sprint based on fun factor, pacing, grind, clarity, and combat fairness.

## Canonical World

| Layer | Tile Y Range | Gameplay Role |
| --- | ---: | --- |
| Band 1: Standard Caverns | `0-383` | Foundation mining, movement, starter combat, copper economy |
| Band 2: Colossal Ant Chambers | `384-767` | Resin terrain, swarm pressure, royal jelly economy |
| Band 3: Buried Pyramids | `768-1151` | Trap logic, tomb routing, cursed treasure |
| Band 4: Drow Enclaves | `1152-1535` | Bioluminescent navigation, diplomacy, stealth hunters |
| Band 5: Abyssal Lava Rivers / Obsidian Slums | `1536-1919` | Heat management, lava routes, hostile settlements |
| Solid Dark Blocks | `1920+` | Final boundary, late-game mystery, ultimate tool gating |

The world is horizontally unbounded. The vertical axis is the mapped descent: five Bands plus Solid Dark Blocks. Lore may describe infinite depth, but gameplay progression is balanced around this finite mapped structure.

## Phase 1: Foundation

**Sprint 1: Band 1 Vertical Slice**
- Deliver movement, gravity, tile collision, drilling, block damage, drops, inventory, starter HUD, Band 1 terrain generation, lighting, and one starter hostile.
- Veteran Player gate: mining and combat must feel readable, useful, and not grindy.

**Sprint 2: Band 1 Polish and Autotiling**
- Add 47-tile terrain transitions, better cave shapes, particle feedback, audio hooks, and copper crafting.
- Veteran Player gate: excavation must look clean and remain satisfying for at least ten minutes.

**Sprint 3: Core UI and First Outpost**
- Add full quickbar, inventory panel, flare crafting, first outpost beacon, and darkness safety rules.
- Veteran Player gate: UI must stay edge-locked and support play without explaining itself in center-screen panels.

## Phase 2: The 5 Bands Expansion

**Sprint 4: Band 2 Colossal Ant Chambers**
- Implement resin tiles, ant chamber generation, pheromone trails, worker/soldier ants, royal jelly economy, and amber palette.

**Sprint 5: Band 3 Buried Pyramids**
- Implement tomb room graphs, sandstone tiles, trap triggers, mummy patrols, cursed treasure, and geometric art language.

**Sprint 6: Band 4 Drow Enclaves**
- Implement glow flora, diplomacy flags, drow patrol AI, spore hazards, and cool bioluminescent palettes.

**Sprint 7: Band 5 Abyssal Lava Rivers**
- Implement flowing lava hazards, heat pressure, obsidian resources, and heat-resistant gear progression.

**Sprint 8: Obsidian Slums Subregion**
- Implement hanging settlement generation, hostile outcasts, trade/raid decisions, and late-game forge economy.

## Phase 3: Bosses and Solid Dark Blocks

**Sprint 9: Band Apex Bosses**
- Add one apex boss per Band, each with environmental triggers, multi-phase attacks, and resource unlocks.

**Sprint 10: Solid Dark Blocks**
- Add dark-block contact rules, late-game drill requirements, light absorption, sliver harvesting, and boundary lore.

**Sprint 11: Endgame Core Myth**
- Add Core route clues, final expedition preparation, and the choice between restoring the surface or mastering the deep.

## Gold Master Hardening

**Sprint 12: Content Lock**
- Freeze progression, balance crafting costs, verify all drops, and remove dead-end generation.

**Sprint 13: Performance and Save Stability**
- Stress-test chunk generation, save/load, inventory persistence, lighting, and long-session memory use.

**Sprint 14: Accessibility and Readability**
- Validate color contrast, remappable controls, UI scaling, damage clarity, and low-vision readability.

**Sprint 15: Release Candidate**
- Final bug triage, Steam/demo packaging, trailer capture build, and Gold Master sign-off.

