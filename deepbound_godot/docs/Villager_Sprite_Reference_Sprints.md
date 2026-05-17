# Deepbound Villager Sprite Reference Sprints

Reference input: the user-provided Terraria NPC sheet is used for pixel-art readability lessons only: compact side-view proportions, strong silhouette, few colors per material, and clear walk-cycle limb changes. A ChatGPT-generated art-board reference is saved at `assets/source_ai/villager_delver_ai_reference.png`, and engine-ready native pixel assets are saved under `assets/sprites/`, `assets/tiles/`, and `assets/ui/`. The Deepbound sprite must remain original and should not copy the Angler's outfit, hat, face, or frame arrangement. The final main character is a simple villager-clothed Delver.

## Fixed Style Targets

- Native size: `32x32` per frame for the main Delver sheet, with the existing `14x28` collider retained for tight movement.
- Look: small side-view sandbox NPC proportions with a large readable head, short limbs, and crisp colored outline.
- Clothing: simple villager tunic, blue work pants, dark boots, brown hair, bare head, no copied hat.
- Palette: outline `#181724`, skin `#E09A74`, hair `#543527`, tunic `#B28A52`, pants `#314A68`, boots `#2F231F`, drill brass `#C08B3E`.
- Animation rows: idle, walk, jump/fall, drill side, drill up, drill down, weapon swing.
- Sheet contract: every character or monster owns its own sheet. Every movement row contains exactly eight `32x32` frames for smoother Godot playback.
- Terrain companion style: `16x16` tiles with dense clusters and internal texture, no hard black outlines.

## Sprint 1 - Art Creator Draft

### Art Creator

The first character draft uses a chibi sandbox silhouette: a `32x32` frame, face occupying the top third, tunic and belt in the middle, and short legs below. The sprite sheet is arranged as six rows with eight frames per row:

| Row | Frames | Intent |
| --- | ---: | --- |
| Idle | 8 | Subtle breathing and hand movement. |
| Walk | 8 | Alternating leg stride and counter-swinging arms. |
| Jump/Fall | 8 | Crouch, rise, hang, fall, and brace poses. |
| Drill Side | 8 | Right-facing drill extension with spinning bright tip. |
| Drill Up | 8 | Raised arms and overhead drill. |
| Drill Down | 8 | Bent knees and downward drill. |

Tiles are revised toward compact pixel clusters: Band 1 dirt/stone keep rough internal patches; Band 2 resin gets rounded amber pockets; copper ore uses only a few bright pixels so it reads as loot, not noise.

### Coder

The player switches from a single static texture to a generated sprite sheet. `Sprite2D.region_rect` selects the active frame, and the visual is bottom-aligned to the collision body by offsetting the sprite up by half a frame. Walk uses horizontal velocity, jump/fall uses vertical velocity, and drill rows use the mouse aim direction.

### Art Reviewer

Revision required. The silhouette direction is correct, but the first pass risks looking too much like a generic miner if the drill and lamp dominate. Because the user requested simple villager cloth, the tunic must remain visually primary. Terrain passes the no-hard-outline requirement if edge shading stays internal and low contrast.

### Final Revision

Remove helmet emphasis, keep the bare-haired villager head, and treat drill brass as an accessory rather than the main identity. Keep side-view proportions but avoid copying the reference outfit.

## Sprint 2 - Animation Smoothness Pass

### Art Creator

Walk is changed to eight frames so the feet cycle through contact, passing, extension, and return poses without visible stutter. The head bobs by only one pixel to preserve the tiny NPC feel without shaking the sprite. Jump and fall use fixed poses selected from the eight-frame row, which reads cleaner than looping while airborne.

### Coder

Animation state now resets time when changing rows, which prevents walk frames from popping when the player starts drilling or jumps. Walk runs at `10fps`, idle at `4fps`, and drilling at `13fps` for a fast mechanical feel.

### Art Reviewer

Revision required but close. Walk timing is smooth enough, but the drill side frame needs a brighter alternating tip so the action reads at small scale. Down-drilling should bend the knees to sell weight.

### Final Revision

Add alternating bright drill pixels and keep the down-drill row in a crouched posture. The Art Reviewer marks the motion as smooth for prototype production.

## Sprint 3 - Style Similarity and Production Approval

### Art Creator

The final pass keeps the reference-compatible pixel language: compact body, readable face, small repeated frame cells, restrained palette, and clear profile animation. The character remains original through villager clothing, hair, and Deepbound drilling poses.

### Coder

The generated sprite sheet is available from `TextureFactory.make_delver_sprite_sheet()`. `PlayerController` drives the following state order:

1. Directional drilling if the drill is held and a target tile exists.
2. Jump/fall if the player is airborne.
3. Walk if horizontal motion or input is active.
4. Idle otherwise.

### Art Reviewer

Approved. The sprite has the requested compact sandbox NPC feel, but it does not duplicate the reference character. The walk cycle is smooth enough for the current build, the jump states read clearly, and the villager clothing remains the main visual identity.

### Veteran Player

Approved for game feel. The smaller, villager-style body makes mining corridors easier to read, and the visible frame changes give enough feedback for walking, jumping, and drilling. The next production need is sound and particle timing, not more base sprite revisions.

## Sprint 4 - ChatGPT Art-Board Pixelization Pass

### Art Creator

The previous purely procedural sheet was rejected as too boxy. A ChatGPT-generated art-board was produced from the reference style brief and saved as `assets/source_ai/villager_delver_ai_reference.png`. The production sheet now pixelizes that art-board into native `32x32` frames, quantizes it to a restrained palette, removes border background, resamples each animation row to eight frames, and exports `assets/sprites/delver_villager_sheet.png`.

Additional engine-ready samples were exported:

- `assets/tiles/loose_dirt.png`
- `assets/tiles/soft_stone.png`
- `assets/tiles/copper_ore.png`
- `assets/tiles/hardened_resin.png`
- `assets/tiles/royal_jelly.png`
- `assets/ui/hud_icons.png`

### Coder

`TextureFactory` now loads PNG assets from `assets/sprites/` and `assets/tiles/` before using procedural fallback textures. `PlayerController` uses `32x32` sprite regions while preserving the tight `14x28` collision box. The animation state order remains drilling, airborne, walking, idle.

### Art Reviewer

Approved. The new sheet has a much closer compact sandbox NPC feel: larger expressive hair silhouette, softer villager tunic shape, more readable stride frames, and drill poses with enough width to avoid clipping. It is still original because it avoids the reference character's hat, outfit, and exact frame shapes.

### Veteran Player

Approved. The art now looks like a real character pass instead of programmer rectangles. The walk row reads better at small scale, the jump row has enough energy, and the drill rows finally feel like an action. Keep this sheet for the current build.

## Sprint 5 - Full Asset Roster Art-Board Pass

### Art Creator

The asset workflow was corrected so non-player assets follow the same production path as the main character: ChatGPT art-board first, then crop, pixelize, background-strip, quantize, and export native PNGs. New source boards are saved as:

- `assets/source_ai/enemy_roster_ai_reference.png`
- `assets/source_ai/world_asset_ai_reference.png`

### Coder

`build_pixel_assets.py` now prefers those source boards for enemies, tiles, item icons, UI icons, props, and effects. Procedural drawings remain only as a fallback if an art-board is missing. `asset_tests.gd` now verifies all three source art-boards exist.

### Art Reviewer

Approved. The enemy sheets now carry the painterly-pixel silhouette language from the generated board, then compress down to native `32x32` frame sheets. The world board provides richer `16x16` terrain, pickup, UI, prop, and effect samples than the old procedural rectangles.

### Veteran Player

Approved for the current prototype. Enemies, pickups, and UI now feel closer to a real sandbox sprite pass. Some atlas crops will need hand cleanup later, but the asset pipeline is now pointed in the right direction.

## Sprint 6 - Modular Eight-Frame Sheet Pass

### Art Creator

The sheet format is now uniform across the roster. The Delver is a single `8x7` sheet: idle, walk, jump/fall, drill side, drill up, drill down, and weapon swing. Each enemy and boss is its own `8x4` sheet: idle, move, attack/telegraph, and hurt/recover. Source art-boards remain the style authority, while extraction expands every row to eight frames for smoother playback.

### Coder

`build_pixel_assets.py` exports `assets/sprites/delver_villager_sheet.png` at `256x224` and every `assets/enemies/*.png` sheet at `256x128`. `PlayerController` and `EnemyController` both advance eight-frame rows, and `asset_tests.gd` rejects legacy 4-frame enemy strips.

### Art Reviewer

Approved with a production note. The new modular format is much easier to review because every creature has a predictable move grid. Attack and hurt rows need hand-polished cleanup later, but the current eight-frame rhythm is consistent enough for prototype play and avoids the choppy strip feeling.

### Veteran Player

Approved. The player and hostile animations now feel less placeholder-like during mining and close combat. The important win is readability: each enemy has a dedicated sheet, and row changes make attack/hurt states much clearer in motion.
