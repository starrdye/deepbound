# Deepbound

Deepbound is a 2D pixel-art sandbox adventure prototype about drilling downward through five mapped underground Bands while the lore insists the deep is older and stranger than any map.

## Current Build

This repository now contains:

- A Phaser + Vite + TypeScript browser vertical slice in `prototype/`.
- A Godot 4.6 playable prototype in `deepbound_godot/`.
- Deterministic chunk generation for the five-Band world model.
- Band 1 movement, swept collision, mining, physical drops, grid inventory, extra-slot hotbar, chest containers, heart HUD, lighting, starter enemy pressure, cached terrain rendering, and Godot `Control` UI.
- A template-backed settlement system with a standalone prefab designer, the imported Band 1 goblin village, and a Band 2 dwarf fortress prefab.
- Vitest coverage for the Phaser reference build, plus Godot headless tests for bands, generation, mining, collision, animation, assets, hearts, chests, inventory, settlements, prefabs, spawning, and movement performance.
- Godot gameplay docs in `deepbound_godot/docs/Gameplay.md`.
- Gold Master roadmap docs under `Docs/GoldMaster/`.

## Run

Phaser reference prototype:

```bash
cd prototype
npm install
npm run dev
```

Godot prototype:

```bash
godot4 --path deepbound_godot
```

## Verify

Phaser reference prototype:

```bash
cd prototype
npm test
npm run build
```

Godot prototype:

```bash
godot4 --headless --path deepbound_godot --quit-after 1
godot4 --headless --path deepbound_godot --script tests/smoke_tests.gd
godot4 --headless --path deepbound_godot --script tests/inventory_tests.gd
godot4 --headless --path deepbound_godot --script tests/prefab_template_tests.gd
godot4 --headless --path deepbound_godot --script tests/dwarf_fortress_tests.gd
godot4 --headless --path deepbound_godot --script tests/movement_perf_tests.gd
```

## Controls

- Move: `A/D` or arrow keys
- Jump: `W`, up arrow, or space
- Drill: hold mouse/touch or `F`
- Strike starter hostile: `E`
- Inventory: `I`
- Hotbar: number keys `1-6` or mouse wheel
- Flare: `Q`
- Beacon: `R`
- Use/place: right-click a nearby chest to open it, or right-click a clear reachable tile with a placeable hotbar item selected
- Chest/container: chests are solid mineable blocks; breaking one spills its contents as physical click-pickup drops plus one empty chest item
