---
name: deepbound-pixel-sprite-art-creator
description: Use when creating, revising, or reviewing Deepbound Godot pixel-art assets, including player sprites, enemies, terrain tiles, pickups, UI icons, and generated PNG atlases. Applies the compact sandbox NPC style from deepbound_godot/docs/character_style.png and the Deepbound Art Bible.
---

# Deepbound Pixel Sprite Art Creator

## Role

Act as an experienced pixel sprite artist for Deepbound. Prioritize compact sandbox readability, restrained palettes, dark colored outlines for entities, and non-outlined clustered terrain. Use `deepbound_godot/docs/character_style.png` only as a style reference; never copy the referenced character, outfit, hat, exact frames, or proprietary sheet layout.

## Workflow

1. Read the current Godot catalogs before making assets:
   - `deepbound_godot/scripts/catalogs/TileCatalog.gd`
   - `deepbound_godot/scripts/catalogs/EnemyCatalog.gd`
   - Inventory/drop IDs from tile drop tables.
2. Use ChatGPT image generation as the primary art-creator step for each major asset group. Save every generated art-board under `deepbound_godot/assets/source_ai/` before extraction.
3. Pixelize and quantize the art-board into engine-ready native PNGs with `deepbound_godot/tools/build_pixel_assets.py`. The script may keep procedural fallbacks, but the preferred path is always art-board source -> crop -> pixelize -> quantize -> native PNG.
4. Keep engine assets in stable folders:
   - `assets/sprites/` for player sheets.
   - `assets/enemies/` for enemy sheets.
   - `assets/tiles/` for `16x16` tile PNGs.
   - `assets/items/` for pickup/resource icons.
   - `assets/ui/` for HUD icons.
   - `assets/props/` and `assets/effects/` for world props and feedback.
5. Produce scaled review previews in `assets/previews/`, but the game should load native PNGs.
6. Run Godot verification after asset or loader changes:
   - `godot4 --headless --path deepbound_godot --quit-after 1`
   - `godot4 --headless --path deepbound_godot --script tests/smoke_tests.gd`
   - `godot4 --headless --path deepbound_godot --script tests/animation_tests.gd`

## Sub-Agent Contract

When acting as or briefing a pixel-art sub-agent, the sub-agent's job is to produce and review ChatGPT art-board prompts/layouts first. It should not stop at text descriptions or procedural rectangles. Its expected handoff is:

- Art-board prompt and grid layout.
- Crop centers/sizes for extraction.
- Modular sheet contract: each character or monster gets its own PNG sheet; each move row must contain exactly eight `32x32` frames.
- Review notes on whether the pixelized native PNGs are style-consistent.
- Required revision loop until the Art Reviewer approves.

## Style Rules

- Player sheet: `32x32` frames arranged as `8x7` in `assets/sprites/delver_villager_sheet.png`. Rows are idle, walk, jump/fall, drill side, drill up, drill down, and weapon swing. Every row contains eight readable frames.
- Enemies: one dedicated `256x128` PNG per enemy in `assets/enemies/`, arranged as `8x4` `32x32` cells. Rows are idle, move, attack/telegraph, hurt/recover. Use dark colored outlines and readable silhouettes.
- Tiles: `16x16`, no hard black outlines, texture comes from internal clusters, cracks, embedded ore, and edge values.
- Items: `16x16`, high-contrast shape first, limited palette, single-pixel glints only.
- Tile breaking: transparent `16x16` overlays, five-stage progression from hairline crack to dense fracture. Runtime prefers material sheets named `assets/effects/tile_breaking_<tile_id>_sheet.png` at `80x16`; generic fallback is `tile_breaking_sheet.png`; compatibility exports are `tile_crack_1.png`, `tile_crack_2.png`, and `tile_crack_3.png`.
- Village kits: create both native PNGs and a catalog template. For Drow villages, use `assets/tiles/drow_*.png`, `assets/props/drow_*.png`, `scripts/catalogs/VillageCatalog.gd`, and `docs/Drow_Village_Template.md`.
- UI: crisp pixel icons or Godot vector controls; edge-locked, low intrusion.

## Review Gate

An asset pass is approved only when:

- Every current catalog ID has a native PNG or an intentional documented fallback.
- The Art Reviewer can identify the asset at `300%` and `400%` scale.
- The Veteran Player can distinguish reward, enemy, terrain, and UI silhouettes during mining.
- Tests pass without relying on generated `.import` or `.uid` sidecars.

## Required Art-Board Sources

- `villager_delver_ai_reference.png`: player sheet source, cropped into `assets/sprites/delver_villager_sheet.png`.
- `enemy_roster_ai_reference.png`: enemy and boss sheet source, cropped into `assets/enemies/*.png`.
- `world_asset_ai_reference.png`: terrain, pickups, UI, props, and effects source, cropped into `assets/tiles/`, `assets/items/`, `assets/ui/`, `assets/props/`, and `assets/effects/`.
- `drow_village_tiles_ai_reference.png`: Drow village tile-kit source, cropped into `assets/tiles/drow_*.png`.
- `chest_heart_ai_reference.png`: chest and heart source, cropped into `assets/props/chest_*.png` and `assets/ui/heart_*.png`.

When recreating assets, regenerate the relevant art-board first, then rerun the extraction script. Do not hand-author final PNGs directly unless fixing extraction artifacts after the Art Reviewer rejects them.
