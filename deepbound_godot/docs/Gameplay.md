# Deepbound Godot Gameplay Guide

This guide describes the currently playable Godot prototype systems. It is the gameplay-facing companion to `Architecture.md` and `Developer_Guide.md`.

## Core Loop

The Delver starts in Band 1 near a test chest and a starter cave skitter encounter. The current loop is:

1. Move through deterministic tile chunks.
2. Drill adjacent blocks until they crack, break, and award drops.
3. Collect resources into the personal inventory.
4. Manage resources through the extra hotbar, chest inventory, and world drops.
5. **Equip gear** found or crafted — armour increases defense, boots increase speed, a torch widens the light radius.
6. **Talk to NPCs** using `T` — merchants sell gear, miners share lore, hermits offer quests.
7. Watch health, drill heat, local light, and danger while descending through template-backed settlements.

---

## Controls

| Action | Input |
|--------|-------|
| Move | `A / D` or left/right arrows |
| Jump | `W`, up arrow, or space |
| Drill | Hold left mouse or `F` |
| Use / place hotbar item | Right mouse |
| Strike (melee) | `E` |
| Interact with NPC | `T` |
| Inventory | `I` |
| Pause / menu | `Escape` |
| Hotbar select | `1–6` or mouse wheel |
| Flare | `Q` |
| Beacon | `R` |
| Prototype band jumps | `F1`, `F2`, `F3` |

Focus-loss protection clears transient input when the app window loses or regains focus, so returning to the game should not leave the Delver stuck walking in one direction.

---

## Main Menu and Saves

The game boots to `MainMenu.tscn`. From there the player can start a fresh world, load the single save slot, open the prefab designer, or quit.

The Escape pause menu in the world supports Resume, Save, Load, Template Editor, Main Menu, and Quit. Save/load uses one slot at `user://saves/slot_1.json`.

Saved games restore the seed, player state, inventory and hotbar, selected hotbar index, tile/background edits, damage, containers, drops, beacons, flares, and generated chunks. Explored/generated chunks are frozen in the save so later template edits do not rewrite already-visited areas; unexplored chunks still use current templates when generated. Enemies are refreshed after load rather than serialised.

---

## Health and Hearts

Health is stored as hit points while the HUD renders hearts.

- Default max HP: `10`
- One heart: `2` HP
- Default display: five full hearts
- Heart states: full, half, empty
- Equipment can raise max HP through an HP delta (`health_max` stat). `HeartSystem.gd` rounds to heart-friendly values and clamps the minimum to one heart.

---

## Mining and Drops

Mining targets the nearest valid tile in the drill direction. Tile definitions control hardness, breakability, drops, colours, and light blocking.

Break feedback is material-specific. Dirt, stone, copper, resin, sandstone, drow materials, pressure plates, cursed treasure, and other tile classes each have matching crack/break sheets under `assets/effects/` so breaking reads as a transformation of that material rather than a generic overlay.

When a tile breaks, its drops try to enter the player inventory. If inventory space is unavailable, remaining drops can stay or be spawned into the world.

---

## Equipment

### Overview

Press `I` to open the inventory. The **equipment panel** appears as a 7-slot column to the right of the inventory grid. Drag any equippable item from the inventory or hotbar and drop it onto the correct slot to equip it. Drag from an equipment slot back to inventory (or anywhere outside all panels) to unequip.

### Equipment Slots

| Slot | Effect stat(s) |
|------|----------------|
| Weapon | `damage` — added to melee strike damage |
| Head | `defense`, `health_max` |
| Body | `defense` |
| Legs | `defense` |
| Feet | `defense`, `speed` |
| Accessory | `defense`, `health_max`, `drill_cool` |
| Utility | `light_radius_tiles` (widens the ambient light circle) |

Stats update **immediately** when an item is equipped or unequipped — there is no "apply" button.

### Current Equippables

| Item | Slot | Stats |
|------|------|-------|
| Wooden Sword | Weapon | +3 damage |
| Crystal Sword | Weapon | +6 damage |
| Cursed Sword | Weapon | +10 damage |
| Iron Helm | Head | +2 defense |
| Crystal Helm | Head | +4 defense, +5 max HP |
| Leather Vest | Body | +1 defense |
| Iron Chestplate | Body | +4 defense |
| Leather Pants | Legs | +1 defense |
| Iron Greaves | Legs | +2 defense |
| Leather Boots | Feet | +1 defense, +10% speed |
| Copper Ring | Accessory | +5 max HP |
| Resin Amulet | Accessory | +1 defense, −10% drill heat |
| Torch | Utility | 10-tile light radius |
| Lantern | Utility | 17-tile light radius |

### Slot Validation

Dropping the wrong item type onto a slot silently rejects the drop — the item stays on the cursor. Only items whose slot matches the target slot are accepted. For example, leather boots cannot go in the weapon slot.

---

## NPCs and Dialogue

### Finding NPCs

NPCs spawn deterministically near settlement areas. Walk close to one and a **`[T] Talk`** hint floats above their name. The hint disappears when you move out of range.

### Talking

Press `T` while in range to begin dialogue. The dialogue panel opens at the bottom of the screen with:

- Portrait box (left)
- NPC name (above the text)
- Typewriter text animation (~42 characters per second)

While text is animating, press `T` again to skip to the end instantly. When the text is fully shown, press `T` to advance to the next node, or close the dialogue if it is the last node.

### Vendor / Shop

Some dialogue nodes trigger the vendor panel (e.g. "Browse wares" on the Wandering Merchant). The vendor panel opens alongside the inventory:

- **Buy**: Left-click a shop item to purchase it (deducts copper nuggets).
- **Sell**: Right-click an inventory item while the vendor panel is open to sell it.
- Currency: copper nuggets. Current copper count is shown in the vendor panel header.

---

## Settlements and Templates

Underground settlements are generated from sparse prefab templates under `data/templates/`. These templates stamp foreground tiles, background walls, props, lights, containers, and enemy/NPC spawn markers into deterministic spawn regions.

Current built-in templates:

- `goblin_village_full`: Band 1 `standard_caverns`, imported from the original goblin village generator.
- `dwarf_fortress_full`: Band 2 `colossal_ant_chambers`, built from granite brick, cut granite floors, ironbound supports, rune blocks, forge walls, ladders, bridge decks, lanterns, chests, and dwarf spawn markers.
- `dwarf_settlement_full`: Band 2 `colossal_ant_chambers`, a multi-level settlement with a great hall, forge, bridge decks, backdrop homes, lights, containers, and dwarf spawn markers.

Developers can launch `scenes/PrefabDesigner.tscn` to author or edit templates using the same in-game tile, background, prop, and enemy catalogs.

---

## Inventory

The player inventory uses `InventorySystem.gd`.

- Player slots: `24`
- Default stack cap: `99`
- Hotbar display: six extra slots that do not consume the 24 inventory slots
- Chest test inventory: `18` slots

Stack rules:

- Dropping onto an empty slot moves the cursor stack there.
- Dropping onto a matching stack merges up to the slot stack cap.
- Dragging is a preview until mouse release; source and target slots do not commit early.
- Merge overflow returns to the original source slot after release.
- Dropping onto a different item swaps the source and target stacks.

---

## Hotbar

The hotbar is always visible during normal gameplay and acts as six extra storage slots separate from the player's 24-slot inventory grid.

- Hotbar size: `6` slots
- Selection: number keys `1–6`
- Cycling: mouse wheel up/down
- Drag/drop: items can be moved between the inventory panel, chest panel, equipment panel, and visible hotbar slots
- Commit timing: hotbar and inventory data update only on mouse release
- Visual feedback: copper corner brackets mark the active slot
- Active item label: bottom-left HUD text names the selected stack
- Placement: right-click places mapped hotbar items on clear reachable tiles after player-overlap and occupancy checks
- Placement reach: `5.25` tiles
- Placement preview: the target tile is highlighted while a placeable hotbar item is selected; valid targets are green, rejected targets are red

Current placeable item mappings:

| Item | Places tile |
|------|-------------|
| `chest` | `chest_block` |
| `dirt_clod` | `loose_dirt` |
| `stone_chunk` | `soft_stone` |
| `resin_shard` | `hardened_resin` |
| `sandstone_shard` | `sandstone_block` |

---

## Chests and Containers

A block-backed test chest spawns near the first spawn area.

- Chest open distance: `46 px`
- Chest inventory size: `18` slots
- Default test contents: `6` copper nuggets and `12` stone chunks
- The chest opens only when the Delver is in range and the player right-clicks directly on it.
- The chest automatically closes when the Delver walks away.
- Left-click mining damages and breaks the chest block.
- Breaking a chest drops one empty `chest` item and spills each non-empty inventory stack as separate world drops.

Pressing `I` opens only the player inventory. Right-clicking a nearby chest opens the container view, and the HUD shows both inventories at once: player panel on the left, chest panel on the right.

Closing a container flushes the held cursor stack back into the player inventory where possible. Any remaining cursor stack is emitted as a world drop instead of being destroyed.

---

## Drag, Drop, and World Items

When a stack is picked up from any open inventory panel, releasing it outside all open panels turns it into a physical world item.

- Entity: `DroppedItemController.gd`
- Spawn point: the Delver's current bottom-centre position
- Physics: gravity, floor/wall collision, solver substeps prevent dropped items passing through solid blocks
- Pickup delay: `0.55 s`
- Pickup method: click the visible item in the world
- World drag: press and drag a visible dropped item to reposition it, then release to let physics resume
- Special auto-pickup: only explicit boss, quest, or scripted reward drops opt in to automatic collection

Normal player-dropped stacks fall from the Delver's current position, settle on terrain, and stay there until the player clicks them.

---

## Pickup Rules

Normal dropped items are collected by direct click after they land or while falling. Collection still respects inventory capacity. If the mouse moves more than a small drag threshold before release, the item is moved through the world instead of collected.

Collected items fill the hotbar before the main inventory: existing hotbar stacks are topped off first, then empty hotbar slots fill left to right, then the main inventory is used.

While an inventory stack or world item is being dragged, the Delver ignores movement, jump, drill, weapon, flare, and beacon inputs.

---

## HUD

The Godot HUD is a crisp `Control` overlay rendered in immediate-mode `_draw()`. It shows:

- **Hearts** — current health as full/half/empty heart icons
- **Drill heat** — percentage bar; overheating locks the drill briefly
- **Depth band** — current band name (e.g. "Band 1 — Standard Caverns")
- **Target tile name** — name of the tile under the drill cursor
- **Local light** — percentage of ambient light at the player's position
- **Danger pulse** — red overlay pulsing when enemies are near
- **Hotbar** — always visible; active slot highlighted with copper brackets
- **Inventory panel** (when `I` is pressed) — 24-slot grid + equipment column + crafting panel
- **Container panel** (when a chest is open) — chest's 18-slot grid alongside inventory
- **Equipment panel** (alongside inventory) — 7-slot column: weapon, head, body, legs, feet, accessory, utility
- **Dialogue panel** (during NPC conversation) — portrait, typewriter text, hint
- **Vendor panel** (during shop) — stock list, prices, sell mode

The HUD is edge-biased so it does not cover the Delver or the immediate mining target during normal play.

---

## Current Acceptance Checks

The current gameplay systems are covered by these Godot test scripts:

- `tests/smoke_tests.gd`: project boot, bands, mining, economy, lighting, Sprint 4/5 hooks, scene instantiation
- `tests/equipment_tests.gd`: EquipmentCatalog queries, EquipmentSystem slot mutations, StatCalculator totals, HudController equipment panel drag-drop
- `tests/inventory_tests.gd`: stack merge/swap, hotbar drag/drop, manual world-item dragging, click pickup, special auto-pickup
- `tests/heart_tests.gd`: full, half, and empty heart logic
- `tests/chest_tests.gd`: block-backed chest open/close, mining spill drops, hotbar placement, placement rejection
- `tests/collision_tests.gd`: swept tile collision, dropped item collision, and anti-embedding rules
- `tests/spawn_tests.gd`: enemy spawn clearance
- `tests/background_tests.gd`: background wall placement and break behaviour
- `tests/input_tests.gd`: jump, focus-loss, inventory key, and hotbar key/scroll behaviour
- `tests/animation_tests.gd`: drill and weapon animation state
- `tests/asset_tests.gd`: generated pixel assets, source boards, previews, and material break sheets
- `tests/menu_tests.gd`: main menu button handlers, load-game path, and safe quit behaviour
- `tests/save_game_tests.gd`: single-slot save/load round trips, generated chunk freezing, frozen structures, schema compatibility
- `tests/village_template_tests.gd`: legacy village catalog metadata and building templates
- `tests/goblin_village_tests.gd`: goblin village reference generation and template-backed chunk overlays
- `tests/prefab_template_tests.gd`: prefab JSON validation, designer operations, import, and worldgen integration
- `tests/dwarf_fortress_tests.gd`: Band 2 dwarf fortress assets, template validation, spawning, lights, containers, chunk overlay stability
- `tests/dwarf_settlement_tests.gd`: Band 2 dwarf settlement template validation, generated placement, lights, containers, prop drawing
- `tests/movement_perf_tests.gd`: cached terrain redraw, camera movement, chunk warm-ahead, template-heavy fall regressions
