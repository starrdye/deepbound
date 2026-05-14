# Deepbound

Deepbound is a 2D pixel-art sandbox adventure prototype about drilling downward through five mapped underground Bands while the lore insists the deep is older and stranger than any map.

## Current Build

This repository now contains:

- A Phaser + Vite + TypeScript browser vertical slice in `prototype/`.
- Deterministic chunk generation for the five-Band world model.
- Band 1 movement, collision, mining, drops, inventory, lighting, starter enemy pressure, and SVG HUD.
- Vitest coverage for Band boundaries, chunk generation, mining, economy, lighting, and HUD state.
- Gold Master roadmap docs under `Docs/GoldMaster/`.

## Run

```bash
cd prototype
npm install
npm run dev
```

Open the local Vite URL printed in the terminal.

## Verify

```bash
cd prototype
npm test
npm run build
```

## Controls

- Move: `A/D` or arrow keys
- Jump: `W`, up arrow, or space
- Drill: hold mouse/touch or `F`
- Strike starter hostile: `E`
