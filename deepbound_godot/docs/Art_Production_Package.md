# Deepbound Godot Art Production Package

Source of truth: `Docs/Deepbound_Art_Bible.md`. This package turns the Art Bible into production-ready specifications for the current Godot build. It does not create final PNG sheets; it defines exact sprite sheet layouts, palettes, animation targets, collision readability rules, and three internal review cycles.

## Fixed Production Rules

- Native pixel units: foreground tiles are `16x16`; character and monster sheets use `32x32` cells for consistent animation playback. Smaller enemies may occupy less silhouette space inside the cell; larger jaws, robes, and antennae may overhang visually inside the same cell.
- Modular sheet rule: each character, monster, and boss owns a dedicated PNG sheet. Every move row has exactly eight frames.
- Runtime scale: assets must be displayed at integer scale only, normally `300%` or `400%`.
- Terrain: no hard outlines. Terrain contrast comes from clusters, interior cracks, edge highlights, and negative space.
- Characters and enemies: use dark colored outlines, never pure black. Recommended outline: `#20151D` for warm enemies, `#181724` for the Delver, `#111523` for deep silhouettes.
- Interactive highlights: ores, pickups, attack tells, pressure plates, and UI state changes use high-value colors against the dark background.
- HUD: Godot `Control` UI must stay locked to screen edges, with no large central panels during mining or combat.

## Final Collision Box Contract

All moving entity colliders are bottom-center anchored. The visual sprite may overhang the collider for readable helmets, antennae, tails, tools, or robes.

| Entity | Visual Size | Collider | Notes |
| --- | ---: | ---: | --- |
| Delver | `32x32` | `14x28` | Hair, arms, tunic corners, and drill poses may overhang. Feet align to bottom center. |
| Cave Skitter | `20x12` | `14x10` | Legs overhang horizontally so the body reads in darkness without snagging tiles. |
| Worker Ant | `24x12` | `18x10` | Antennae and mandibles are non-colliding silhouette features. |
| Soldier Ant | `28x16` | `22x12` | Larger mandibles telegraph danger but do not widen collision unfairly. |
| Dwarf Guard | `24x30` | `16x24` | Helmet, beard, shield, and hammer overhang the compact humanoid collider. |
| Dwarf Crossbowman | `24x30` | `16x23` | Crossbow arms are visual-only and should not widen the collision body. |
| Dwarf Smith | `26x31` | `18x25` | Hammer and apron pixels can overhang; feet stay bottom-center aligned. |
| Lost Mummy | `24x32` | `14x28` | Robe strips and raised arms are visual overhangs. |
| Tunneling Worm Head | `32x24` | `26x18` | Jaw flare is readable but should not make tunnel dodges feel unfair. |
| Worm Segment | `16x16` | `12x12` | Segments follow the head path and should not catch on corners. |
| Pickup | `8x8` | trigger radius `6px` | Non-solid collection trigger. |

## Final Asset Specifications

Current generated/processed assets:

- ChatGPT player art-board source: `assets/source_ai/villager_delver_ai_reference.png`
- ChatGPT enemy art-board source: `assets/source_ai/enemy_roster_ai_reference.png`
- ChatGPT world/UI/effects art-board source: `assets/source_ai/world_asset_ai_reference.png`
- Dwarf fortress source board: `assets/source_ai/dwarf_fortress_ai_reference.png`
- Engine player sheet: `assets/sprites/delver_villager_sheet.png`
- Enemy sheets and atlas: `assets/enemies/*.png`
- Terrain samples: `assets/tiles/*.png`
- Pickup/resource icons: `assets/items/*.png`
- UI icon samples: `assets/ui/hud_icons.png`
- Props and effects: `assets/props/*.png`, `assets/effects/*.png`
- Tile breaking animation: generic `assets/effects/tile_breaking_sheet.png` plus material-specific `assets/effects/tile_breaking_<tile_id>_sheet.png` files, each five `16x16` transparent crack stages from hairline fracture to collapse.
- Scaled review previews: `assets/previews/*.png`

### The Delver

Sheet: `delver_villager_sheet`, native `32x32` cells, `8x7` grid, final PNG size `256x224`. Body layers are Head, Torso, Arms, Legs, Drill, Weapon, and small item accents. Each layer shares the same frame grid so armor overlays can be swapped later.

Palette:

- Outline: `#181724`
- Deep shadow: `#2A2630`
- Suit cloth: `#5C6670`
- Suit highlight: `#A7B0AE`
- Leather pads: `#6D452D`
- Brass lamp: `#C58A32`
- Lamp glow: `#FFD66B`
- Copper drill bit: `#F0A84F`

Frames:

| Row | Frames | Description |
| --- | ---: | --- |
| Idle | 8 | Breathing loop, tiny hand movement, drill rests low. |
| Walk | 8 | Two-step cycle, 1-pixel head bob, contact/passing/extension/return poses. |
| Jump/Fall | 8 | Crouch release, rising, hang, falling, landing brace poses. |
| Drill Side | 8 | Arm locks forward, drill spins with alternating copper teeth. |
| Drill Up | 8 | Head tilts back, drill clears top of collider without changing collider. |
| Drill Down | 8 | Knees bend, drill points below feet, sparks appear outside collider. |
| Weapon Swing | 8 | Short sword/tool swipe triggered by strike input, with readable steel arc and 1-frame spark accents. |

Readability note: the body must remain visible when surrounded by Band 1 dirt and Band 2 resin. The lamp glow is a gameplay accent, not the only silhouette separator.

### Environment and Terrain

Tile atlas: each biome foreground set uses `16x16` cells in an `8x6` atlas. Slots `00-46` are active; slot `47` is reserved for debug or future variant. The engine uses an 8-neighbor mask: `N=1`, `E=2`, `S=4`, `W=8`, `NE=16`, `SE=32`, `SW=64`, `NW=128`. Corner bits are valid only when both adjacent cardinal bits are present.

47-tile layout:

| Row | Slots | Purpose |
| --- | --- | --- |
| 0 | 00 isolated, 01 cap N, 02 cap E, 03 cap S, 04 cap W, 05 corridor NS, 06 corridor EW, 07 full center |
| 1 | 08 open N, 09 open E, 10 open S, 11 open W, 12 outer NE, 13 outer SE, 14 outer SW, 15 outer NW |
| 2 | 16 inner NE, 17 inner SE, 18 inner SW, 19 inner NW, 20 tee N, 21 tee E, 22 tee S, 23 tee W |
| 3 | 24 inner NE+SE, 25 inner SE+SW, 26 inner SW+NW, 27 inner NW+NE, 28 opposite inner NE+SW, 29 opposite inner SE+NW, 30 island vertical, 31 island horizontal |
| 4 | 32 open N with NE, 33 open N with NW, 34 open E with NE, 35 open E with SE, 36 open S with SE, 37 open S with SW, 38 open W with SW, 39 open W with NW |
| 5 | 40 three-inner missing NE, 41 three-inner missing SE, 42 three-inner missing SW, 43 three-inner missing NW, 44 all inners, 45 ore inset, 46 damaged inset, 47 reserved |

Band 1 foreground sets:

- Loose dirt: base `#7A4B2E`, shadow `#5F3D2B`, highlight `#A86F3C`, pebble flecks `#C5854C`.
- Compacted dirt: base `#5F3D2B`, shadow `#3B2A24`, highlight `#8D5A36`.
- Soft stone: base `#59616A`, shadow `#343C45`, highlight `#88939A`, cool chip `#A7B0AE`.
- Copper ore: stone base plus ore sparks `#F0A84F`, `#FFD66B`, and shadowed copper `#6E513D`.

Band 2 resin set:

- Hardened resin: base `#8F5F22`, inner shadow `#5A351F`, amber midtone `#C68633`, glow highlight `#F1B85B`.
- Royal jelly: base `#F0D35E`, highlight `#FFEE9A`, shadow `#9A7631`. It may use soft internal glow but no terrain outline.
- Resin edge rule: edges should be rounded and organic, but the tile boundary must stay legible at `300%`.

Parallax:

| Layer | Band 1 Standard Caverns | Band 2 Ant Chambers | Scroll |
| --- | --- | --- | ---: |
| Far void | almost black cave mass `#090B12` | warm dark hive void `#120C0A` | `0.10` |
| Distant walls | low-sat stone silhouettes | giant rounded chamber walls | `0.20` |
| Mid ribs | roots, old supports, broken ledges | resin ribs and egg alcoves | `0.38` |
| Near dust | soft motes and falling grit | amber motes and translucent strands | `0.62` |

### Enemies and Hazards

Each enemy and boss sheet is a dedicated `256x128` PNG in `assets/enemies/`, using four `32x32` rows with eight frames each: idle, move, attack/telegraph, hurt/recover.

Cave Skitter, `20x12` silhouette inside a `32x32` cell.

- Palette: outline `#20151D`, body `#8B4650`, belly `#C56B65`, eye `#E8D5A1`.
- Silhouette: low oval body with four long angled legs. Bite frame extends mandibles by 3 pixels.

Tunneling Worm, head `32x24` silhouette and segment `16x16` silhouette inside `32x32` cells.

- Palette: outline `#20151D`, hide `#7A3142`, underbelly `#C06A53`, teeth `#EAD7B0`, warning glow `#FF8A1F`.
- Telegraph: two dust cracks, then a warm crescent under the target tile. The head must be readable before damage begins.

Worker Ant and Soldier Ant, worker `24x12` silhouette and soldier `28x16` silhouette inside `32x32` cells.

- Worker palette: outline `#20151D`, shell `#C68633`, shadow `#5A351F`, eye `#FFE17A`.
- Soldier palette: outline `#20151D`, shell `#8F5F22`, mandible `#F1B85B`, warning mark `#FF8A1F`.
- Soldier mandibles must be larger than the worker silhouette, but attack range is shown with a bright pre-snap frame.

Dwarf Guard, Dwarf Crossbowman, and Dwarf Smith, compact humanoid silhouettes inside `32x32` cells.

- Shared palette: dark warm outline `#20151D`, granite metal `#596062`, brass `#D8AA53`, leather `#4E3A2C`, beard accents from rust orange to dark auburn.
- Dwarf Guard: squat helmet, shield block, and hammer head. The weapon and shield can overhang visually, but combat collision stays narrow.
- Dwarf Crossbowman: short stance with a horizontal crossbow silhouette. The bow limbs are non-colliding and must read clearly against forge and granite backgrounds.
- Dwarf Smith: heavier apron/body, bright hammer spark, and ember highlight. The smith should feel like a fortress worker who can still fight.

Lost Mummy, `24x32` silhouette inside a `32x32` cell.

- Palette: outline `#2B2219`, wraps `#D2B36A`, shadow `#8F7750`, oxidized charm `#3E8F74`, curse glow `#70CEB1`.
- Silhouette: stiff shoulders, dragging leg, angular head wrap. Never reuse the Delver stance.

Hazards:

- Pressure plate: `16x16`, depressed state uses a 1-pixel vertical change and oxidized green `#3E8F74`.
- Dart trap: `16x16` wall/floor variant, dark sandstone body with a 2-pixel bright aperture.
- Dart projectile: `8x3`, high-contrast tip, one-frame streak at integer scale.
- Pickups: `8x8` icons with 1-pixel colored rim and no black outline.

### Dwarf Fortress Kit

The Band 2 dwarf fortress uses a colder stone-and-metal construction language embedded in the warm resin band. It should read as an engineered pocket inside the Colossal Ant Chambers, not as another organic hive.

Generated native assets:

| Type | Asset IDs |
| --- | --- |
| Tiles | `dwarf_granite_brick`, `dwarf_cut_granite_floor`, `dwarf_ironbound_block`, `dwarf_rune_block`, `dwarf_iron_platform` |
| Backgrounds | `dwarf_granite_background`, `dwarf_forge_background`, `dwarf_rune_background` |
| Props | `dwarf_forge`, `dwarf_anvil`, `dwarf_lantern`, `dwarf_banner`, `dwarf_gate`, `dwarf_barrel`, `dwarf_ladder`, `dwarf_chain_lift`, `dwarf_bridge`, `dwarf_chest`, `dwarf_armor_rack`, `dwarf_back_tower_lit`, `dwarf_back_tower_dark`, `dwarf_ore_cart`, `dwarf_rune_marker` |
| Enemies/NPC markers | `dwarf_guard`, `dwarf_crossbowman`, `dwarf_smith` |

Preview atlas: `assets/previews/dwarf_fortress_kit_preview.png`.

Template: `data/templates/dwarf_fortress_full.json`.

Construction analysis:

- Shell and towers use `dwarf_granite_brick` with `dwarf_ironbound_block` buttresses so the fortress reads as heavy and defensive.
- Floors and room decks use `dwarf_cut_granite_floor`; bridge and shaft crossing pieces use `dwarf_iron_platform`.
- Rune blocks mark corners, lift shafts, and important vertical route anchors.
- Forge rooms use `dwarf_forge_background` plus forge/anvil/ore-cart props and warm lights.
- Main halls use `dwarf_granite_background`; shrine/lift areas use `dwarf_rune_background`.
- Ladders and chain lifts provide vertical movement cues. Gates, banners, back towers, and bridge props establish scale without changing collision.
- `dwarf_chest` is a two-tile container prop and stamps a runtime chest marker on its bottom-left occupied cell.

### UI and HUD

Godot `Control` layout:

- Health: top-left pips, `12x10` vector hearts or stone-lamp cells, spacing `4px`, color changes from `#C94E4E` to `#5A2531` when empty.
- Drill heat: left edge vertical gauge, brass frame `#C58A32`, fill from `#FFD66B` to `#FF8A1F`.
- Hotbar: bottom-center 6 extra slots, max height `42px`, selected slot has a 2-pixel copper bracket, not a glowing card.
- Inventory panel: pauses mining focus, dark slate panel `#181724`, iron border `#5C6670`, material icons from the same pickup sheet.
- Danger pulse: screen-edge vignette only. No center-screen red overlay.
- Beacon/flare states: small right-edge indicators with warm light icons and cooldown rings.

## Cycle 1 - Diagnosis and First Art Pass

### Coder

The original controllers moved entities into solid tiles and rewound one pixel at a time. That made fast motion depend on frame delta and could trap the Delver on tile corners. The fix is a shared bottom-center AABB solver that resolves X then Y, clamps the leading edge to tile boundaries, uses a `0.05px` skin, and limits movement substeps to `8px`.

Required dimensions are the Final Collision Box Contract above. The Delver collision must stay narrower than the visual body so shoulder pixels and the drill arm do not snag on walls.

### Pixel Art Designer

First pass creates the core Band 1 and Band 2 readable asset suite:

- Delver sprite has a dark navy outline, brass lamp, gray suit, and copper drill bit.
- Dirt and stone tiles use interior texture with no hard outlines.
- Resin tiles use rounded amber forms and translucent inner highlights.
- Cave skitter, ants, worm, and mummy all use dark colored outlines with distinct silhouettes.
- HUD uses edge-locked vector panels with stone, brass, and lamp motifs.

### Art Reviewer

Mandatory revisions:

- Delver drill side frames need a brighter drill tip so the active tool reads against stone.
- Resin cannot become a flat orange field. Add darker internal pockets and cooler shadow edges.
- Worm telegraph must be visible before the head appears. Dust alone is too subtle.
- Hotbar selected state should use brackets, not a full glowing rectangle, to avoid covering bottom combat space.

### Veteran Player

Controls will feel tighter with the narrower collider, but the art must sell that fairness. The Delver can look chunky, yet the feet need a clear center line. Enemies pass the silhouette test except the worker ant and cave skitter are too close in height; the skitter should stay flatter and faster-looking. HUD direction is good because it leaves the center clear.

### Final Revisions

- Add a 1-pixel boot shadow and centered sole highlight to the Delver walk frames.
- Keep cave skitter height at `12px`; worker ant remains longer with visible antennae.
- Add orange pre-lunge crescent for tunneling worm.
- Add hotbar copper corner brackets instead of full-slot glow.

## Cycle 2 - Collision Readability and Biome Refinement

### Coder

Corner checks now sample only the active leading edge. Horizontal wall contact no longer blocks vertical falling motion, and downward floor contact alone sets `on_ground`. Enemy movement uses the same solver as the player with entity-specific colliders, preventing ants and mummies from inheriting skitter dimensions.

### Pixel Art Designer

Second pass refines collision-to-art alignment:

- Delver helmet and backpack extend beyond the collider, but boots stay within the `14px` collider width.
- Soldier ant mandibles flare outside the `22x12` collider and get a 2-frame warning snap.
- Lost mummy wraps trail outside the collider, but shoulders remain inside the readable body mass.
- Band 1 tile damage overlays use cracks and bright chips, not outlines.
- Band 2 resin damage reveals pale amber internal stress lines.

### Art Reviewer

Approved with revisions:

- Terrain still follows the no-outline rule.
- Character outlines are dark colored and consistent.
- Copper ore needs fewer spark pixels per tile so it remains special and does not look like UI noise.
- Mummy curse glow should use oxidized green from Band 3 only, not Band 2 amber.

### Veteran Player

The hitboxes now sound fair on paper. The Delver can squeeze through two-tile shafts without the helmet catching, which is critical for a mining game. Biggest risk is combat readability in low light: attack tells need to be brighter than ore, but shorter-lived, so players can distinguish reward from danger.

### Final Revisions

- Limit copper ore to 3 to 5 bright pixels per `16x16` tile.
- Keep attack warning colors animated and temporary.
- Add a one-frame white-yellow impact spark only on confirmed drill contact.
- Make pressure plates geometric and green so they do not resemble resin pickups.

## Cycle 3 - Final QA Signoff

### Coder

The collision contract is ready for implementation tests:

- Floor landing clamps to the tile top minus skin.
- High-speed wall motion stops before overlap.
- Corner contact blocks only the colliding axis.
- Enemy collider dimensions are selected by enemy id.
- Mining adjacent tiles cannot create embedded player states because removed tiles only open space.

### Pixel Art Designer

Final art spec is approved for production:

- Delver modular grid supports future armor without replacing base animation timing.
- Band 1 and Band 2 autotile atlases share the same 47-slot layout.
- Enemy silhouettes are distinct by footprint, posture, and attack telegraph.
- HUD elements are crisp vector controls and remain edge-locked.

### Art Reviewer

Approval granted with production checklist:

- Verify every sprite at `300%` and `400%`.
- Check outlines are colored, not pure black.
- Check terrain has no hard border outlines.
- Test all enemies against dark backgrounds and active lamp light.
- Keep UI labels and icons readable without oversized panels.

### Veteran Player

Approved for the current build. The tighter collider should make mining shafts feel fair, the enemies have recognizable shapes, and the HUD avoids the classic sandbox problem of covering the tiles the player is trying to mine. The next fun-factor risk is feedback polish: drill vibration, tile chips, pickup sounds, and enemy hit flashes need to land hard in later production.

### Final Revisions

- Proceed with the shared collision solver and the collision tests.
- Keep this package as the Godot art handoff for prototype asset production.
- Do not replace these specs with final assets until the collision hotfix is stable.
- Prioritize Delver, Band 1 terrain, cave skitter, HUD, and worm telegraph in the first asset export batch.

## Cycle 4 - Tile Breaking Transformation Pass

### Coder

The previous tile damage logic drew one or two hardcoded lines, so a damaged tile did not visibly transform before breaking. Mining now reports a `stage` from `1` to `5` while damage accumulates, and the world renderer samples `tile_breaking_sheet.png` by damage ratio. When damage reaches hardness, the tile becomes `air`, its stored damage is cleared, and the final stage is reported in the mining result.

### Pixel Art Designer

The new effect sheet is a transparent `80x16` strip of five `16x16` overlays:

| Stage | Visual Intent |
| ---: | --- |
| 1 | One hairline fracture and a small chip, readable but subtle. |
| 2 | A second branch appears, making repeated drilling feedback obvious. |
| 3 | A diagonal split crosses the tile and begins to imply structural failure. |
| 4 | Edge chips and branching lines show the tile is nearly gone. |
| 5 | Dense fracture network and bright exposed chips telegraph the next drill tick as the break. |

### Art Reviewer

Approved. The crack frames are overlays, not outlined terrain, so they preserve the Art Bible rule that tiles should avoid hard borders. The warm bright chips read over dirt, stone, resin, and sandstone without becoming as saturated as ore or enemy attack tells.

### Veteran Player

Approved. The damage ramp now feels like real mining feedback: every drill tick makes the target look worse, then it pops into air. This should reduce confusion around whether the drill is actually working on higher-hardness tiles.

### Final Revisions

- Keep `tile_crack_1`, `tile_crack_2`, and `tile_crack_3` as compatibility exports.
- Use material-specific `tile_breaking_<tile_id>_sheet.png` files for runtime rendering, with `tile_breaking_sheet.png` as fallback.
- Asset tests must reject missing stages or a sheet that is not exactly five `16x16` frames.

## Cycle 5 - Material Breaks and Weapon Animation

### Coder

Runtime tile damage now chooses `tile_breaking_<tile_id>_sheet.png` before falling back to the generic crack sheet. The Delver gains a timed weapon-swing state that plays row `6` of the `8x7` sprite sheet when strike is pressed.

### Pixel Art Designer

Created material-specific break sheets for dirt, compacted dirt, stone, copper ore, resin, royal jelly, sandstone, pressure plates, cursed treasure, glow loam, and obsidian ash. Each keeps the same five-stage damage language but changes crack shadows, exposed chips, and highlights to match the tile material. The Delver weapon row uses a compact villager stance, a short steel blade/tool arc, brass grip, and tiny impact sparks.

### Art Reviewer

Approved. The material cracks no longer look like a universal golden overlay; stone reads cool, resin reads amber, glow loam reads cyan, and obsidian reads hot red. The weapon row stays inside the `32x32` cell and does not compromise the `14x28` collider.

### Veteran Player

Approved for prototype combat readability. Pressing strike should now look like an actual action rather than invisible damage, and different materials communicate damage state more clearly while mining.

## Cycle 6 - Chest and Heart UI Art Pass

### Coder

Added `HeartSystem.gd` so health is modeled in HP while the HUD renders hearts. One heart equals `2` HP; the Delver starts at `10/10` HP, and equipment can raise or lower max HP while clamping to at least one heart. Added `ChestController.gd` as a reusable controller for an eight-frame open animation.

### Pixel Art Designer

Used `assets/source_ai/chest_heart_ai_reference.png` as the art-board source. The builder crops the red heart into `heart_full.png`, derives `heart_half.png` and `heart_empty.png`, and exports `heart_sheet.png` as a `48x16` full/half/empty strip. The gold chest crop exports `chest_closed.png`, `chest_open.png`, and `chest_open_sheet.png` as eight `32x32` frames.

### Art Reviewer

Initial review rejected the first heart export: the crop touched the frame edges, the lower point read as chopped off, and the large highlight made the heart feel visually lopsided. Final revision approved after rebuilding all heart states from one symmetrical `16x16` mask with a preserved two-pixel bottom tip. The chest sheet is approved after widening the source crop and keeping the lid path inside the `32x32` prop cell.

### Veteran Player

Approved. Five hearts for `10` HP is immediately understandable, and half-heart damage gives better feedback than a plain numeric label. The chest animation gives treasure interactions a visible reward beat without adding UI clutter.
