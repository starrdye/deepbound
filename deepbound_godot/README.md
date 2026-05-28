# Deepbound Godot

> **v0.11** — Godot 4.6 · GDScript · GL Compatibility renderer

Deepbound is a 2-D side-scrolling cave exploration game. Drill down through procedurally generated biome bands, fight enemies, loot chests, craft gear, and face bosses.

## Run

```bash
godot --path deepbound_godot
```

Or open `deepbound_godot/project.godot` in the Godot editor and press **Play**.

## Headless compile check

```bash
godot --headless --editor --quit
```

No output = no parse errors.

## Test suites

```bash
# Run a single suite
godot --headless --path deepbound_godot --script tests/smoke_tests.gd

# Run all suites
for f in tests/*_tests.gd; do
  godot --headless --path deepbound_godot --script "$f"
done
```

Available test files:

```
tests/smoke_tests.gd
tests/collision_tests.gd
tests/spawn_tests.gd
tests/background_tests.gd
tests/village_template_tests.gd
tests/prefab_template_tests.gd
tests/goblin_village_tests.gd
tests/dwarf_fortress_tests.gd
tests/animation_tests.gd
tests/asset_tests.gd
tests/input_tests.gd
tests/heart_tests.gd
tests/chest_tests.gd
tests/inventory_tests.gd
tests/menu_tests.gd
tests/save_game_tests.gd
tests/dwarf_settlement_tests.gd
tests/movement_perf_tests.gd
tests/liquid_tests.gd
```

Exit code `0` = pass, `1` = fail.

## Regenerate pixel assets

```bash
cd deepbound_godot
python3 tools/build_pixel_assets.py
```

## v0.11 Feature Set

| System | Status |
|---|---|
| Band 1–5 procedural world | ✅ |
| Tile mining + break animations | ✅ |
| Grid inventory, hotbar, drag/drop | ✅ |
| Equipment system (7 slots, stat engine) | ✅ |
| Item modifier / prefix system (Terraria-style) | ✅ |
| Character status effects (buffs / debuffs) | ✅ |
| Crafting system (stations, recipes, god mode) | ✅ |
| Dynamic liquid simulation (water / lava / honey) | ✅ |
| Bucket mechanics (scoop / pour) | ✅ |
| Day / night cycle (24-hour clock, sky gradient) | ✅ |
| World events via console (Blood Moon, Goblin Raid, Meteor Shower) | ✅ |
| Physics loot drops, rarity glow | ✅ |
| Boss encounters (FSM, HP bar, despawn) | ✅ |
| NPC dialogue + vendor | ✅ |
| Settlement prefabs (goblin, dwarf ×2, drow) | ✅ |
| Single-slot save / load (schema v3 + time persistence) | ✅ |
| Developer console (15+ commands) | ✅ |
| All item icons + drow_acolyte sprite | ✅ |

## Documentation

| File | Contents |
|---|---|
| `DEVELOPER_GUIDE.md` | **Start here.** Full reference — architecture, all catalogs, console commands, adding content. |
| `docs/Gameplay.md` | Player-facing guide: controls, crafting, liquids, events, HUD. |
| `docs/Architecture.md` | System design: patterns, signal flows, deep dives. |
| `docs/Developer_Guide.md` | Legacy deep-dive guide (pre-v0.11, kept for reference). |
| `docs/Directory_Guide.md` | Every folder and file explained for contributors. |
| `docs/Prefab_Template_System.md` | Template authoring, validation, worldgen integration. |
| `docs/Art_Production_Package.md` | Art handoff guide, crop conventions, palette rules. |

## Art

Engine-ready pixel assets: `assets/tiles/`, `assets/items/`, `assets/enemies/`, `assets/ui/`, `assets/props/`.
AI reference boards (not loaded at runtime): `assets/source_ai/`.
Scaled previews (not loaded at runtime): `assets/previews/`.

The Delver uses an `8×7` `32px` sheet (idle, move, jump, drill, weapon rows).
Each enemy uses an `8×4` `32px` sheet (idle, move, attack, hurt rows).
Item icons are `16×16` PNGs — one per `item_id`.

The reusable art-production skill is at `../.codex/skills/deepbound-pixel-sprite-art-creator/SKILL.md`.
