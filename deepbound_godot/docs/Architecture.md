# Deepbound Godot Architecture

## Runtime Structure

- `scenes/Main.tscn` is the boot scene.
- `scripts/Main.gd` configures input, spawns Band encounters, updates HUD state, and coordinates sprint prototype controls.
- `scripts/World.gd` owns `ChunkStore`, tile drawing, mining calls, beacons, flares, and autotile-style edge rendering.
- `scripts/controllers/PlayerController.gd` owns Delver movement, custom tile collision, drilling, health, heat, and inventory.
- `scripts/controllers/EnemyController.gd` is the shared enemy base for skitters, ants, and mummies.
- `scripts/controllers/HudController.gd` draws crisp Godot `Control` panels and labels.

## Data Modules

- `BandCatalog.gd` defines five Bands and Solid Dark Blocks.
- `TileCatalog.gd` defines tile hardness, drops, colors, light occlusion, and breakability.
- `EnemyCatalog.gd` defines monster and boss roadmap stats.
- `EconomyModel.gd` computes expected mining value and value per second.

## Procedural Generation

Generation is deterministic from seed and tile coordinate. Horizontal generation is unbounded. Vertical generation resolves through five mapped Bands and clamps to Solid Dark Blocks at `tileY >= 1920`.

## Prototype Controls

- Move: `A/D` or arrow keys
- Jump: `W`, up arrow, or space
- Drill: mouse left or `F`
- Strike: `E`
- Flare: `Q`
- Beacon: `R`
- Prototype band jumps: `1`, `2`, `3`

