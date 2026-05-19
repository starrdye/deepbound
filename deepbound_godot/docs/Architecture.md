# Deepbound Godot Architecture

## Runtime Structure

- `scenes/MainMenu.tscn` is the boot scene and launches fresh worlds, the single save slot, the prefab designer, or quit.
- `scenes/Main.tscn` is the playable world scene.
- `scripts/Main.gd` configures input, spawns Band encounters, updates HUD state, owns drop spawning, coordinates right-click chest use and selected-hotbar placement, and provides the Escape pause menu.
- `scripts/World.gd` owns `ChunkStore`, tile drawing, mining calls, beacons, flares, and autotile-style edge rendering.
- `scripts/systems/CollisionSystem.gd` owns bottom-center AABB tile collision for all moving entities.
- `scripts/systems/SaveGameSystem.gd` owns schema-versioned single-slot JSON save/load and pending save handoff from the main menu.
- `scripts/systems/PrefabTemplateRegistry.gd` loads built-in and user templates, validates JSON, caches deterministic structure instances, and answers chunk/nearby light/spawn/container queries.
- `scripts/controllers/PrefabDesignerController.gd` powers the standalone `scenes/PrefabDesigner.tscn` utility for drawing and saving reusable prefab templates.
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
- `data/templates/*.json` stores built-in sparse prefab templates. `goblin_village_full.json` is the imported Band 1 village, while `dwarf_fortress_full.json` and `dwarf_settlement_full.json` are Band 2 dwarf settlements.

## Procedural Generation

Generation is deterministic from seed and tile coordinate. Horizontal generation is unbounded. Vertical generation resolves through five mapped Bands and clamps to Solid Dark Blocks at `tileY >= 1920`.

Structure generation is template-backed for active settlements. `StructureGenerator.gd` delegates chunk overlap and nearby marker lookups to `PrefabTemplateRegistry.gd`, which scans deterministic spawn regions, applies allowed mirror/rotation metadata, checks band bounds and starter avoidance, and returns structure dictionaries with `tiles`, `backgrounds`, `props`, `spawns`, `lights`, and `containers`.

Built-in templates currently include:

- `goblin_village_full`: Band 1 `standard_caverns`, imported from the legacy deterministic goblin village generator.
- `dwarf_fortress_full`: Band 2 `colossal_ant_chambers`, a granite/iron fortress with forge rooms, ladders, bridge decks, storage, lanterns, and dwarf spawn markers.
- `dwarf_settlement_full`: Band 2 `colossal_ant_chambers`, a multi-level settlement with a great hall, forge, backdrop houses, rails, lights, containers, and dwarf spawn markers.

The old live goblin village builder remains available for importer/reference tests. Runtime chunk generation uses template overlays so settlement output is stable regardless of chunk generation order.

## Save/Load

`SaveGameSystem.gd` writes `user://saves/slot_1.json` as schema version `2`. The save stores the world seed, player state, inventory/hotbar state, tile and background overrides, damage, containers, drops, beacons, flares, generated foreground/background chunks, and frozen structure metadata for visited/generated chunks.

Loading restores generated chunks before applying player edits, so explored areas remain stable if templates are later changed. Unexplored chunks continue to use the current generator and latest enabled templates. Enemies are not serialized; band and structure encounter logic refreshes them after load.

## Prefab Designer

`scenes/PrefabDesigner.tscn` is a standalone utility scene. It builds its palette from `TileCatalog`, `BackgroundCatalog`, `EnemyCatalog`, and `assets/props/*.png`, supports foreground/background/prop/spawn layers, and saves sparse JSON through `PrefabTemplateRegistry.save_template`.

The editor canvas is fixed inside a clipped central frame. Large templates use a Pan tool, mouse drag/wheel shortcuts, Fit View, 100%, Zoom +/- buttons, and visible horizontal/vertical canvas scrollbars. Undo/redo covers normal mutating edits while view changes remain non-undoable.

Template cells are sparse: blank cells mean "do not stamp", explicit `air` foreground entries carve terrain, and explicit `empty` background entries clear walls. Template props can expose light and container markers based on prop kind/id; multi-tile container props stamp their runtime `chest_block` marker on the bottom-left occupied cell.

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

`TextureFactory.warm_runtime_cache()` preloads the core player, tile, item, enemy, prop, UI, and break-overlay textures once during `Main.gd` startup. Missing texture lookups are cached as misses, so fallback rendering does not keep probing the filesystem during draw passes.

`World.gd` uses cached foreground/background chunk render nodes instead of one monolithic terrain draw. Camera movement refreshes the visible chunk window and only creates or redraws chunks when chunk coordinates change; tile/background mutation and mining damage invalidate only the touched chunk plus neighbor chunks when edge rendering depends on them. Static structure props draw through cached prop overlays, while beacons, flares, mining overlays, and placement previews live on lightweight dynamic overlay nodes.

`PrefabTemplateRegistry.gd` caches template region instantiation results, chunk overlap results, and near-query results for spawns, lights, and containers. The movement performance tests exercise short jumps, long falls, placement previews, and template-heavy falls to keep camera movement from reintroducing full-world redraw or repeated template-instantiation spikes.

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
