# Deepbound Godot

Godot 4.6 implementation of the Deepbound playable prototype.

## Run

```bash
godot4 --path deepbound_godot
```

## Verify

```bash
godot4 --headless --path deepbound_godot --quit-after 1
godot4 --headless --path deepbound_godot --script tests/smoke_tests.gd
godot4 --headless --path deepbound_godot --script tests/collision_tests.gd
godot4 --headless --path deepbound_godot --script tests/spawn_tests.gd
godot4 --headless --path deepbound_godot --script tests/village_template_tests.gd
godot4 --headless --path deepbound_godot --script tests/animation_tests.gd
godot4 --headless --path deepbound_godot --script tests/asset_tests.gd
godot4 --headless --path deepbound_godot --script tests/input_tests.gd
godot4 --headless --path deepbound_godot --script tests/heart_tests.gd
godot4 --headless --path deepbound_godot --script tests/chest_tests.gd
godot4 --headless --path deepbound_godot --script tests/inventory_tests.gd
```

## Prototype Scope

This build covers playable Sprints 1-5: Band 1 foundation, Band 1 polish/UI, first outpost beacon, Band 2 ant chamber hooks, Band 3 pyramid hooks, swept collision, modular sprite animation, block-backed chest containers, grid inventory, extra-slot hotbar placement, physical world drops, click pickup, special auto-pickup, and the heart HUD.

## Gameplay Docs

The current player/system guide is in `docs/Gameplay.md`. It covers controls, `I` inventory, hotbar selection with `1-6` and mouse wheel, right-click chest use and placement, dual inventory panels, drag/drop stack rules, physical world drops, click pickup, special auto-pickup, heart HP rules, and the HUD.

## Art Production

The current Art Bible handoff for the Godot build is in `docs/Art_Production_Package.md`.
The villager-style sprite and animation review loop is in `docs/Villager_Sprite_Reference_Sprints.md`.
The Drow village building kit and template roster is in `docs/Drow_Village_Template.md`.
Engine-ready pixel assets live in `assets/sprites/`, `assets/tiles/`, and `assets/ui/`; regenerated previews live in `assets/previews/`.
Characters and monsters use modular native sheets: the Delver is `8x7` `32px` frames with idle, move, jump, drill, and weapon rows; each enemy/boss owns an `8x4` `32px` sheet with idle, move, attack, and hurt rows.
The reusable Codex art-production skill is stored at `../.codex/skills/deepbound-pixel-sprite-art-creator/SKILL.md`.
