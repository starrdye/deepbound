# Deepbound

Deepbound is a 2D pixel-art sandbox adventure prototype about drilling downward through five mapped underground Bands while the lore insists the deep is older and stranger than any map.

## Current Build

This repository now contains:

- A Phaser + Vite + TypeScript browser vertical slice in `prototype/`.
- A Godot 4.6 playable prototype in `deepbound_godot/`.
- Deterministic chunk generation for the five-Band world model.
- Band 1 movement, swept collision, mining, drops, grid inventory, chest containers, heart HUD, lighting, starter enemy pressure, and Godot `Control` UI.
- Vitest coverage for the Phaser reference build, plus Godot headless tests for bands, generation, mining, collision, animation, hearts, chests, inventory, and pickups.
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
```

## Controls

- Move: `A/D` or arrow keys
- Jump: `W`, up arrow, or space
- Drill: hold mouse/touch or `F`
- Strike starter hostile: `E`
- Flare: `Q`
- Beacon: `R`
- Chest/inventory: walk near the spawn chest, drag stacks between panels, or release a held stack outside the panels to toss it into the world
