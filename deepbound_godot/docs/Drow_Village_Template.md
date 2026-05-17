# Drow Village Template

This package defines the first Drow Enclaves village kit for Band 4 (`tileY 1152-1535`). It is a template and asset handoff, not a full generator pass.

## Art Creator

The village should feel built into dark underground pockets rather than placed on top of flat terrain. The visual language is cool basalt, cyan glowglass, violet silk, fungal timber, and thin ceremonial arches. Terrain tiles still avoid hard black outlines; props use dark colored silhouettes for readability.

ChatGPT image-generated tile art-board source: `assets/source_ai/drow_village_tiles_ai_reference.png`. The asset builder crops, pixelizes, and quantizes this board into the six native `16x16` Drow construction tiles below, with procedural tile art kept only as a fallback when the source board is absent.

Generated native assets:

| Type | Asset IDs |
| --- | --- |
| Tiles | `drow_basalt_brick`, `drow_carved_floor`, `drow_mushroom_plank`, `drow_silk_canopy`, `drow_arch_inlay`, `drow_glowglass` |
| Props | `drow_door`, `drow_lantern`, `drow_silk_banner`, `drow_market_crate`, `drow_moon_shrine`, `drow_watch_crystal`, `drow_bridge_post`, `drow_mushroom_lamp`, `drow_web_bridge` |
| Existing Band 4 ground | `glow_mushroom_loam` |

Preview atlas: `assets/previews/drow_village_kit_preview.png`.

## Building Roster

The village template is defined in `scripts/catalogs/VillageCatalog.gd` as `drow_village`.

| Building | Purpose | Primary Tiles | Required Props |
| --- | --- | --- | --- |
| Silent Gate Arch | Settlement threshold and safe-room boundary | `drow_basalt_brick`, `drow_arch_inlay`, `drow_carved_floor` | `drow_lantern`, `drow_silk_banner` |
| Glowmote Plaza | Village heart and layout anchor | `drow_carved_floor`, `drow_glowglass` | `drow_mushroom_lamp`, `drow_market_crate`, `drow_lantern` |
| Sporehome Dwelling | Common home shell | `drow_basalt_brick`, `drow_mushroom_plank`, `drow_silk_canopy`, `drow_glowglass` | `drow_door`, `drow_mushroom_lamp` |
| Silk Weaver House | Crafting/trade hut for silk upgrades | `drow_basalt_brick`, `drow_mushroom_plank`, `drow_silk_canopy` | `drow_silk_banner`, `drow_market_crate`, `drow_door` |
| Lowlight Market Stall | Merchant and pickup platform | `drow_mushroom_plank`, `drow_silk_canopy`, `drow_carved_floor` | `drow_lantern`, `drow_market_crate` |
| Moonless Shrine | Lore node and cyan light source | `drow_basalt_brick`, `drow_arch_inlay`, `drow_glowglass`, `drow_carved_floor` | `drow_moon_shrine`, `drow_lantern`, `drow_silk_banner` |
| Crystal Watch Spire | Vertical landmark and route signal | `drow_basalt_brick`, `drow_arch_inlay`, `drow_carved_floor` | `drow_watch_crystal`, `drow_lantern` |
| Silk-Web Bridge Span | Connector between cave pockets | `drow_mushroom_plank` | `drow_bridge_post`, `drow_web_bridge`, `drow_lantern` |

## Symbol Legend

Village layouts use compact text stamps:

| Symbol | Meaning |
| --- | --- |
| `.` | Empty air |
| `#` | Drow basalt brick |
| `=` | Carved floor |
| `P` | Mushroom plank |
| `^` | Silk canopy |
| `A` | Arch inlay |
| `G` | Glowglass |
| `L` | Lantern |
| `D` | Door |
| `B` | Silk banner |
| `C` | Market crate |
| `M` | Moon shrine |
| `W` | Watch crystal |
| `O` | Mushroom lamp |
| `\|` | Bridge post |
| `~` | Web bridge |

## Placement Rules

- Place only in Band 4, `tileY 1152-1535`.
- Prefer a wide side pocket connected to the main tunnel.
- Reserve about `54x20` tiles for a full village.
- Stamp `central_plaza` first, then attach `entry_arch` toward the main approach.
- Cluster two to four `sporehome` variants around the plaza.
- Place `silk_weaver_house` and `market_stall` close together for readable economy flow.
- Put `moon_shrine` slightly deeper, higher, or behind a short bridge so it feels sacred.
- Use `watch_spire` as a vertical silhouette near ledges or route transitions.
- Use `web_bridge_span` to connect separated platforms and prevent dead-end village pockets.

## Art Reviewer

Approved for template production. The kit has a distinct Band 4 palette without becoming one-note purple: cyan glowglass, dark basalt, muted violet silk, and fungal magenta planks each have a clear job. The props are readable at `300%` and should remain visible against `glow_mushroom_loam`.

## Veteran Player

Approved as a future exploration beat. The village has the right sandbox affordances: obvious doorways, bridges, market shape, shrine landmark, and vertical watchtower silhouette. It should feel like a place to investigate, not just decorative ruins.
