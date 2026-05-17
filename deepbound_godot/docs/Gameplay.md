# Deepbound Godot Gameplay Guide

This guide describes the currently playable Godot prototype systems. It is the gameplay-facing companion to `Architecture.md` and the sprint/art-production documents.

## Core Loop

The Delver starts in Band 1 near a test chest and a starter cave skitter encounter. The current loop is:

1. Move through deterministic tile chunks.
2. Drill adjacent blocks until they crack, break, and award drops.
3. Collect resources into the personal inventory.
4. Manage resources through the quickbar, chest inventory, and world drops.
5. Watch health, drill heat, local light, and danger while descending toward Bands 2 and 3 test hooks.

## Controls

- Move: `A/D` or left/right arrows
- Jump: `W`, up arrow, or space
- Drill: hold left mouse or `F`
- Strike: `E`
- Flare: `Q`
- Beacon: `R`
- Prototype band jumps: `1`, `2`, `3`

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

## Inventory

The player inventory uses `InventorySystem.gd`.

- Player slots: `24`
- Default stack cap: `99`
- Quickbar display: first `8` slots
- Chest test inventory: `18` slots

Stack rules:

- Dropping onto an empty slot moves the cursor stack there.
- Dropping onto a matching stack merges up to the slot stack cap.
- Overflow remains on the cursor.
- Dropping onto a different item swaps the cursor stack with the slot stack.

## Chests And Containers

A test chest spawns near the first spawn area. It contains starter copper and stone for fast UI testing.

- Chest open distance: `46px`
- Chest inventory size: `18` slots
- Default test contents: `6` copper nuggets and `12` stone chunks
- The chest automatically opens when the Delver enters range.
- The chest automatically closes when the Delver walks away.

When the chest is open, the HUD shows both inventories at once:

- Player inventory panel on the left
- Chest panel on the right
- Cursor stack drawn under the mouse while dragging

Closing a container flushes the held cursor stack back into the player inventory where possible. Any remaining cursor stack is emitted as a world drop instead of being destroyed.

## Drag, Drop, And World Toss

When a stack is picked up from any open inventory panel, releasing it outside all open panels turns it into a physical world item.

World-drop behavior:

- Entity: `DroppedItemController.gd`
- Safe toss distance: `72px`
- Initial toss velocity: cursor/player-facing direction plus a small upward arc
- Pickup delay: `0.55s`
- Auto-pickup radius: `42px`
- Collect radius: `12px`

The safe toss distance intentionally places the item outside the automatic pickup radius, so dropping an item from the UI does not instantly re-collect it.

## Auto-Pickup

Dropped items detect the player each frame after the pickup delay.

An item starts flying toward the Delver only when:

- It is within the auto-pickup radius.
- The player inventory can accept at least part of the stack.
- The item has completed its short pickup delay.

If the player has a matching stack with room or an empty slot, the item is added automatically at collect distance. If only part of the stack fits, the remaining count stays in the world.

## HUD

The Godot HUD is a crisp `Control` overlay, not a bitmap screenshot. It currently shows:

- Hearts for health
- Drill heat percentage
- Current depth band
- Target tile name
- Local light percentage
- Danger pulse overlay
- Quickbar text summary
- Inventory and chest panels when a container is open

The HUD is edge-biased so it does not cover the Delver or the immediate mining target during normal play.

## Current Acceptance Checks

The current gameplay systems are covered by these Godot scripts:

- `tests/smoke_tests.gd`: project boot, bands, mining, economy, lighting, Sprint 4/5 hooks
- `tests/collision_tests.gd`: swept tile collision and anti-embedding rules
- `tests/spawn_tests.gd`: enemy spawn clearance
- `tests/input_tests.gd`: jump and focus-loss input behavior
- `tests/animation_tests.gd`: drill and weapon animation state
- `tests/heart_tests.gd`: full, half, and empty heart logic
- `tests/chest_tests.gd`: chest animation and auto-close behavior
- `tests/inventory_tests.gd`: stack merge/swap, drag/drop, safe world toss, and auto-pickup
