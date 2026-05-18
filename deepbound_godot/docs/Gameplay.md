# Deepbound Godot Gameplay Guide

This guide describes the currently playable Godot prototype systems. It is the gameplay-facing companion to `Architecture.md` and the sprint/art-production documents.

## Core Loop

The Delver starts in Band 1 near a test chest and a starter cave skitter encounter. The current loop is:

1. Move through deterministic tile chunks.
2. Drill adjacent blocks until they crack, break, and award drops.
3. Collect resources into the personal inventory.
4. Manage resources through the extra hotbar, chest inventory, and world drops.
5. Watch health, drill heat, local light, and danger while descending through template-backed settlements such as Band 1 goblin villages and Band 2 dwarf fortresses.

## Controls

- Move: `A/D` or left/right arrows
- Jump: `W`, up arrow, or space
- Drill: hold left mouse or `F`
- Use/place selected hotbar item: right mouse
- Strike: `E`
- Inventory: `I`
- Hotbar select: `1-6` or mouse wheel
- Flare: `Q`
- Beacon: `R`
- Prototype band jumps: `F1`, `F2`, `F3`

Focus-loss protection clears transient input when the app window loses or regains focus, so returning to the game should not leave the Delver stuck walking in one direction.

## Health And Hearts

Health is stored as hit points while the HUD renders hearts.

- Default max HP: `10`
- One heart: `2` HP
- Default display: five full hearts
- Heart states: full, half, empty
- Equipment can raise or lower max HP through an HP delta, then `HeartSystem.gd` rounds to heart-friendly values and clamps the minimum to one heart.

## Mining And Drops

Mining targets the nearest valid tile in the drill direction. Tile definitions control hardness, breakability, drops, colors, and light blocking.

Break feedback is material-specific. Dirt, stone, copper, resin, sandstone, drow materials, pressure plates, cursed treasure, and other current tile classes each have matching crack/break sheets under `assets/effects/` so breaking reads as a transformation of that material rather than a generic overlay.

When a tile breaks, its drops try to enter the player inventory. If inventory space is unavailable, remaining drops can stay or be spawned into the world depending on the calling system.

## Settlements And Templates

Underground settlements are generated from sparse prefab templates under `data/templates/`. These templates stamp foreground tiles, background walls, props, lights, containers, and enemy/NPC spawn markers into deterministic spawn regions.

Current built-in settlement templates:

- `goblin_village_full`: Band 1 `standard_caverns`, imported from the original goblin village generator.
- `dwarf_fortress_full`: Band 2 `colossal_ant_chambers`, built from granite brick, cut granite floors, ironbound supports, rune blocks, forge walls, ladders, bridge decks, lanterns, chests, and dwarf spawn markers.

Template props can be decorative, lights, or containers. Container props stamp runtime `chest_block` collision markers so storage remains compatible with the existing chest/container systems. Light props expose structure light markers for the world lighting pass.

Developers can launch `scenes/PrefabDesigner.tscn` to author or edit templates using the same in-game tile, background, prop, and enemy catalogs.

## Inventory

The player inventory uses `InventorySystem.gd`.

- Player slots: `24`
- Default stack cap: `99`
- Hotbar display: six extra slots that do not consume the `24` inventory slots
- Chest test inventory: `18` slots

Stack rules:

- Dropping onto an empty slot moves the cursor stack there.
- Dropping onto a matching stack merges up to the slot stack cap.
- Dragging is a preview until mouse release; source and target slots do not commit early.
- Merge overflow returns to the original source slot after release.
- Dropping onto a different item swaps the source and target stacks.

## Hotbar

The hotbar is always visible during normal gameplay and acts as six extra storage slots separate from the player's `24` slot inventory grid.

- Hotbar size: `6` slots
- Inventory impact: extra storage, not shared with inventory slots `0-23`
- Selection: number keys `1-6`
- Cycling: mouse wheel up/down
- Drag/drop: items can be moved between the inventory panel, chest panel, and visible hotbar slots
- Commit timing: hotbar and inventory data update only on mouse release, while the held item is drawn as a cursor preview
- Visual feedback: copper corner brackets mark the active slot
- Active item label: bottom-left HUD text names the selected stack
- Placement: right-click places mapped hotbar items on clear reachable tiles after player-overlap and occupancy checks
- Placement reach: `5.25` tiles
- Placement preview: the target tile is highlighted while a placeable hotbar item is selected; valid targets are green and rejected targets are red

Current placeable mappings:

- `chest` -> `chest_block`
- `dirt_clod` -> `loose_dirt`
- `stone_chunk` -> `soft_stone`
- `resin_shard` -> `hardened_resin`
- `sandstone_shard` -> `sandstone_block`

Opening the inventory with `I` shows the full inventory while the always-visible hotbar remains available as a drag/drop target. Moving an item into the hotbar changes what appears in the active item bar without removing any normal inventory slot.

## Chests And Containers

A block-backed test chest spawns near the first spawn area. It contains starter copper and stone for fast UI testing.

- Chest open distance: `46px`
- Chest inventory size: `18` slots
- Default test contents: `6` copper nuggets and `12` stone chunks
- The chest opens only when the Delver is in range and the player right-clicks directly on the chest.
- The chest automatically closes when the Delver walks away.
- Left-click mining damages and breaks the chest block.
- Breaking a chest drops one empty `chest` item and spills each non-empty inventory stack as separate physical world drops. Contents are not preserved inside the chest item.

Pressing `I` opens only the player inventory. Right-clicking a nearby chest opens the container view, and the HUD shows both inventories at once:

- Player inventory panel on the left
- Chest panel on the right
- Cursor stack drawn under the mouse while dragging

Closing a container flushes the held cursor stack back into the player inventory where possible. Any remaining cursor stack is emitted as a world drop instead of being destroyed.

## Drag, Drop, And World Items

When a stack is picked up from any open inventory panel, releasing it outside all open panels turns it into a physical world item.

World-drop behavior:

- Entity: `DroppedItemController.gd`
- Spawn point: the Delver's current bottom-center position
- Chest spill point: the broken chest tile center
- Initial velocity: `Vector2.ZERO` for player-dropped stacks
- Physics: gravity, floor/wall collision, and solver substeps prevent dropped items from passing through solid blocks
- Pickup delay: `0.55s`
- Pickup method: click the visible item in the world
- World drag: press and drag a visible dropped item to reposition it, then release to let physics resume
- Special auto-pickup: only explicit boss, quest, or scripted reward drops opt in to automatic collection

Normal player-dropped stacks fall from the Delver's current position, settle on terrain, and stay there until the player clicks them.

## Pickup Rules

Normal dropped items are collected by direct click after they land or while they are falling. The click must hit the item's small world pickup rectangle, and collection still respects inventory capacity. If the mouse moves more than a small drag threshold before release, the item is moved through the world instead of collected.

Collected items fill the hotbar before the main inventory: existing hotbar stacks are topped off first, then empty hotbar slots fill left to right, then the main inventory is used.

While an inventory stack or world item is being dragged, the Delver ignores movement, jump, drill, weapon, flare, and beacon inputs. This keeps inventory handling from accidentally drilling blocks or swinging weapons.

Boss, quest, or scripted reward drops can opt in to automatic pickup. An auto-pickup item starts flying toward the Delver only when:

- It is within the auto-pickup radius.
- The player inventory can accept at least part of the stack.
- The item has completed its short pickup delay.

If the player has a matching stack with room or an empty slot, the special item is added automatically at collect distance. If only part of the stack fits, the remaining count stays in the world.

## HUD

The Godot HUD is a crisp `Control` overlay, not a bitmap screenshot. It currently shows:

- Hearts for health
- Drill heat percentage
- Current depth band
- Target tile name
- Local light percentage
- Danger pulse overlay
- Always-visible hotbar with active slot selection
- Inventory and chest panels when a container is open

The HUD is edge-biased so it does not cover the Delver or the immediate mining target during normal play.

## Current Acceptance Checks

The current gameplay systems are covered by these Godot scripts:

- `tests/smoke_tests.gd`: project boot, bands, mining, economy, lighting, Sprint 4/5 hooks
- `tests/collision_tests.gd`: swept tile collision, dropped item collision, and anti-embedding rules
- `tests/spawn_tests.gd`: enemy spawn clearance
- `tests/background_tests.gd`: background wall placement and break behavior
- `tests/input_tests.gd`: jump, focus-loss, inventory key, and hotbar key/scroll behavior
- `tests/animation_tests.gd`: drill and weapon animation state
- `tests/asset_tests.gd`: generated pixel assets, source boards, previews, and material break sheets
- `tests/heart_tests.gd`: full, half, and empty heart logic
- `tests/chest_tests.gd`: block-backed chest open/close, mining spill drops, hotbar placement, and placement rejection behavior
- `tests/inventory_tests.gd`: stack merge/swap, extra hotbar storage, hotbar drag/drop, manual world-item dragging, click pickup, and special auto-pickup
- `tests/village_template_tests.gd`: legacy village catalog metadata and building templates
- `tests/goblin_village_tests.gd`: goblin village reference generation and template-backed chunk overlays
- `tests/prefab_template_tests.gd`: prefab JSON validation, designer operations, import, and worldgen integration
- `tests/dwarf_fortress_tests.gd`: Band 2 dwarf fortress assets, template validation, spawning, lights, containers, and chunk overlay stability
- `tests/movement_perf_tests.gd`: cached terrain redraw, camera movement, chunk warm-ahead, and template-heavy fall regressions
