# Deepbound Godot Architecture

## Runtime Structure

- `scenes/Main.tscn` is the boot scene.
- `scripts/Main.gd` configures input, spawns Band encounters, updates HUD state, owns the test chest/drop layers, and coordinates sprint prototype controls.
- `scripts/World.gd` owns `ChunkStore`, tile drawing, mining calls, beacons, flares, and autotile-style edge rendering.
- `scripts/systems/CollisionSystem.gd` owns bottom-center AABB tile collision for all moving entities.
- `scripts/controllers/PlayerController.gd` owns Delver intent, villager-style sprite animation, drilling, health, heat, inventory, and calls the shared collision solver.
- `scripts/controllers/EnemyController.gd` is the shared enemy base for skitters, ants, and mummies and uses entity-specific collider dimensions.
- `scripts/controllers/ChestController.gd` owns chest inventory, the eight-frame open animation, and open/close state.
- `scripts/controllers/DroppedItemController.gd` owns physical item drops, safe toss movement, pickup delay, magnet movement, and partial collection.
- `scripts/controllers/HudController.gd` draws crisp Godot `Control` panels, heart icons, dual inventory/container grids, cursor stack drag/drop, and world-drop requests.
- `scripts/factories/TextureFactory.gd` generates prototype pixel-art sheets and tile textures at runtime.

## Data Modules

- `BandCatalog.gd` defines five Bands and Solid Dark Blocks.
- `TileCatalog.gd` defines tile hardness, drops, colors, light occlusion, and breakability.
- `EnemyCatalog.gd` defines monster and boss roadmap stats.
- `EconomyModel.gd` computes expected mining value and value per second.
- `InventorySystem.gd` stores slot arrays, stack caps, matching-stack merges, overflow, swaps, quick slots, and capacity checks.
- `HeartSystem.gd` maps HP to full, half, and empty heart states.
- `SpawnSystem.gd` finds clear enemy spawn points so monsters do not appear embedded in blocks.

## Procedural Generation

Generation is deterministic from seed and tile coordinate. Horizontal generation is unbounded. Vertical generation resolves through five mapped Bands and clamps to Solid Dark Blocks at `tileY >= 1920`.

## Inventory And Containers

The player owns a `24` slot inventory with `99` item stack caps. The test chest near spawn owns an `18` slot inventory. When the Delver is within `46px`, `Main.gd` opens the chest, passes both inventories to `HudController.gd`, and the HUD renders player and chest panels simultaneously.

Drag/drop is handled by the HUD cursor stack:

- Pick up a stack by pressing on an occupied slot.
- Release on an empty slot to move it.
- Release on a matching stack to merge up to the stack cap.
- Release on a different item to swap.
- Release outside all open inventory panels to emit `world_drop_requested`.

`Main.gd` receives world-drop requests and spawns a `DroppedItemController` at least `72px` from the player, outside the `42px` auto-pickup radius. Dropped items become collectible after `0.55s`, fly toward the player if inventory space exists, and collect at `12px`.

## Health HUD

Health is modeled in HP and displayed as hearts. `HeartSystem.gd` uses `2` HP per heart, starts the Delver at `10` HP, and resolves equipment HP deltas to whole-heart-friendly max HP values.

## Prototype Controls

- Move: `A/D` or arrow keys
- Jump: `W`, up arrow, or space
- Drill: mouse left or `F`
- Strike: `E`
- Flare: `Q`
- Beacon: `R`
- Prototype band jumps: `1`, `2`, `3`

## Gameplay Reference

See `Gameplay.md` for the player-facing description of mining, chests, inventory drag/drop, world tosses, auto-pickup, hearts, and HUD behavior.
