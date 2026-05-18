# Deepbound Godot Architecture

## Runtime Structure

- `scenes/Main.tscn` is the boot scene.
- `scripts/Main.gd` configures input, spawns Band encounters, updates HUD state, owns drop spawning, and coordinates right-click chest use and selected-hotbar placement.
- `scripts/World.gd` owns `ChunkStore`, tile drawing, mining calls, beacons, flares, and autotile-style edge rendering.
- `scripts/systems/CollisionSystem.gd` owns bottom-center AABB tile collision for all moving entities.
- `scripts/controllers/PlayerController.gd` owns Delver intent, villager-style sprite animation, drilling, health, heat, inventory, and calls the shared collision solver.
- `scripts/controllers/EnemyController.gd` is the shared enemy base for skitters, ants, and mummies and uses entity-specific collider dimensions.
- `scripts/controllers/ChestController.gd` owns chest inventory, anchor tile metadata, the eight-frame open animation, and open/close state.
- `scripts/controllers/DroppedItemController.gd` owns physical item drops, click pickup, optional special-drop magnet movement, pickup delay, and partial collection.
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

The player owns a `24` slot inventory with `99` item stack caps. Pressing `I` calls `HudController.open_inventory` and shows only the player panel. Chests are tracked by anchor tile in `World.gd`, use `chest_block` for collision/mining, and own `18` slot inventories with no hidden hotbar. A chest opens only when the Delver is within `46px` and the right-click lands on the chest hit area; then `Main.gd` passes both inventories to `HudController.gd`, and the HUD renders player and chest panels simultaneously.

Drag/drop is handled by the HUD cursor stack:

- Pick up a stack by pressing on an occupied slot.
- The press starts a visual drag preview; source data is not mutated yet.
- `HudController.drag_state_changed` tells `Main.gd` to lock player controls while the cursor is carrying an item.
- Release on an empty slot to move it.
- Release on a matching stack to merge up to the stack cap.
- Release on a different item to swap source and target.
- Release outside all open inventory panels to emit `world_drop_requested`.

`Main.gd` receives world-drop requests and spawns a `DroppedItemController` at either the Delver's current bottom-center position or an explicit world position such as a broken chest tile. Normal player-dropped and chest-spilled stacks do not auto-pick up; they remain physical world items until clicked. Boss, quest, or scripted reward drops use `_spawn_auto_pickup_drop` to opt in to special magnet behavior.

## Hotbar

The hotbar is six extra slots on `InventorySystem.gd`, separate from the player's `24` normal inventory slots. `InventorySystem.hotbar_slots(6)` returns those dedicated hotbar stacks instead of slicing the inventory grid, so the hotbar behaves as extra space.

`Main.gd` owns `selected_hotbar_index`, binds number keys `1-6`, cycles the selection with mouse wheel up/down, and passes `hotbar_slots`, `selected_hotbar_index`, and `active_item` into `HudController.gd`. `HudController.gd` draws the hotbar bottom-center even when the inventory page is closed, emits `hotbar_slot_selected` when a visible hotbar slot is clicked, and treats hotbar cells as drag/drop slots while the inventory page or a container is open.

## Dropped Item Physics

`DroppedItemController.gd` applies gravity, drag, pickup delay, and tile collision through `CollisionSystem.gd`. Dropped stacks use a small item collider and solver substeps so falling items stop on floors and walls instead of passing through solid blocks. World items can be manually dragged; while held, their physics pauses and player controls are locked. Click pickup and optional auto-pickup both respect inventory/hotbar capacity.

## Animation Performance

`TextureFactory.warm_runtime_cache()` preloads the core player, tile, item, enemy, prop, UI, and break-overlay textures once during `Main.gd` startup. Missing texture lookups are cached as misses, so fallback rendering does not keep probing the filesystem during `_draw()`.

`World.gd` redraws terrain when the camera enters a new tile, terrain changes, mining damage advances, or flares expire. The visible tile radius is calculated from the active camera zoom plus a small tile margin instead of drawing a fixed oversized rectangle every frame.

`HudController.gd` skips redraws when the derived HUD signature is unchanged, and static dropped items rely on transform updates rather than queuing a custom redraw every process tick.

## Health HUD

Health is modeled in HP and displayed as hearts. `HeartSystem.gd` uses `2` HP per heart, starts the Delver at `10` HP, and resolves equipment HP deltas to whole-heart-friendly max HP values.

## Prototype Controls

- Move: `A/D` or arrow keys
- Jump: `W`, up arrow, or space
- Drill: mouse left or `F`
- Strike: `E`
- Inventory: `I`
- Hotbar: `1-6` or mouse wheel
- Flare: `Q`
- Beacon: `R`
- Prototype band jumps: `F1`, `F2`, `F3`

## Gameplay Reference

See `Gameplay.md` for the player-facing description of mining, chests, inventory drag/drop, world drops, click pickup, special auto-pickup, hearts, and HUD behavior.
