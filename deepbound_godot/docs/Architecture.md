# Deepbound — Systems Architecture

> **Design philosophy in brief:** decouple UI from logic via signals, model
> static data in catalogues, favour composition of small components over deep
> inheritance, and keep every system testable in isolation.

---

## Table of Contents

1. [Runtime Structure](#1-runtime-structure)
2. [Architectural Patterns in Use](#2-architectural-patterns-in-use)
3. [Inventory & Hotbar System](#3-inventory--hotbar-system)
4. [Equipment & Stat Engine](#4-equipment--stat-engine)
5. [Crafting System](#5-crafting-system)
6. [NPC, Dialogue & Vendor System](#6-npc-dialogue--vendor-system)
7. [Interactable Component](#7-interactable-component)
8. [World & Lighting](#8-world--lighting)
9. [Procedural Generation & Prefabs](#9-procedural-generation--prefabs)
10. [v0.11 Systems](#10-v011-systems)
11. [Save / Load](#11-save--load)
12. [Health & Hearts](#12-health--hearts)
13. [Controls Reference](#13-controls-reference)
14. [Future Architecture Roadmap](#14-future-architecture-roadmap)

---

## 1. Runtime Structure

| Node / File | Responsibility |
|---|---|
| `scenes/MainMenu.tscn` | Boot scene. Launches fresh world, single save slot, prefab designer, or quit. |
| `scenes/Main.tscn` | Playable world scene. |
| `scripts/Main.gd` | Composition root. Wires signals, owns encounter spawning, coordinates all cross-system transitions (equipment → player stats, NPC interact → dialogue → vendor). |
| `scripts/World.gd` | `ChunkStore`, tile drawing, mining, beacons, flares, light sources, utility-light radius for equipped items. |
| `scripts/controllers/PlayerController.gd` | Delver physics (custom AABB), sprite animation, drilling, health, equipment stat hooks (`speed_bonus`, `defense_bonus`, `health_delta`). |
| `scripts/controllers/HudController.gd` | All HUD rendering: hearts, hotbar, inventory/container panels, equipment panel, crafting panel, dialogue panel, vendor panel. Communicates outward via signals only. |
| `scripts/controllers/EnemyController.gd` | Shared enemy base (skitters, ants, mummies). |
| `scripts/controllers/ChestController.gd` | Chest inventory, anchor tile, open/close animation. |
| `scripts/controllers/DroppedItemController.gd` | Physical item drops, click-pickup, gravity, partial collection. |
| `scripts/controllers/NpcController.gd` | Friendly NPC: drawn body, name label. Owns an `InteractableComponent` child. |
| `scripts/controllers/PrefabDesignerController.gd` | Standalone `PrefabDesigner.tscn` drawing tool. |
| `scripts/factories/TextureFactory.gd` | Runtime pixel-art texture generation. Warmed at startup. |
| `scripts/systems/CollisionSystem.gd` | Shared bottom-centre AABB tile collision for all movers. |
| `scripts/systems/SaveGameSystem.gd` | Schema-versioned single-slot JSON save/load (schema v3). |
| `scripts/systems/PrefabTemplateRegistry.gd` | Template loading, deterministic structure instantiation, chunk/light/spawn/container queries. |
| `autoload/TimeManager.gd` | 24-hour in-game clock. Advances time, emits `hour_changed`, exposes `current_hour / current_minute / current_day`. |
| `autoload/EventManager.gd` | World events (Blood Moon, Goblin Raid, Meteor Shower). Manages sky tint multiplier and enemy substitution. |
| `autoload/DebugSystem.gd` | Developer flags. `god_mode_enabled: bool` read by `CraftingSystem` and `HudController` — no Node-tree coupling. |
| `autoload/LiquidSystem.gd` | Cellular-automaton liquid simulation (Water / Lava / Honey) at 10 Hz against `World.gd`'s ChunkStore. |

---

## 2. Architectural Patterns in Use

### 2.1 Signal-Driven UI (applied)

`HudController` never holds direct references to `PlayerController` or
`EquipmentSystem`. It receives data through method calls (e.g.
`set_hud_state`, `set_equipment_system`) and pushes changes outward through
signals (`world_drop_requested`, `drag_state_changed`, `dialogue_event`).

`EquipmentSystem` emits `equipment_changed` whenever a slot mutates.
`Main.gd` listens and dispatches the resulting stat delta to
`PlayerController` and `World` — neither of those two objects knows about
the HUD or each other.

### 2.2 Composition over Inheritance (applied)

The **`InteractableComponent`** (see §7) is a drop-in child node that adds
proximity detection, a hint label, and an `interacted` signal to *any* host
entity (NPC, chest, door, lever …) without the host extending a shared base
class.

`StatCalculator` is a stateless utility class that takes an
`EquipmentSystem` snapshot and returns a plain stat dictionary — no
inheritance, no shared state.

### 2.3 Catalogue / Data-Object Pattern (applied, migration path in §13)

All static game data lives in catalogue files (`ItemCatalog`, `TileCatalog`,
`EquipmentCatalog`, `NPCCatalog`, `VendorCatalog`, `DialogueCatalog`,
`BandCatalog`, `PlaceableCatalog`, `BackgroundCatalog`, `EnemyCatalog`,
`LiquidCatalog`, `EventCatalog`, `ModifierCatalog`, `StatusEffectCatalog`,
`CraftingRecipeBook`).
These are `RefCounted` classes with `const` dictionaries. A future migration
to Godot `Resource` assets (`.tres` files) is planned — see §14.1.

### 2.4 Encapsulated Data Systems (applied)

`InventorySystem` and `EquipmentSystem` are `RefCounted` objects — pure
data + logic with no Node tree coupling. The HUD and Main.gd hold
references to them but the systems themselves know nothing about the scene
tree.

---

## 3. Inventory & Hotbar System

### Data Layer — `InventorySystem`

`scripts/systems/InventorySystem.gd` — extends `RefCounted`

| Feature | Detail |
|---|---|
| Main inventory | 24 slots, 99-item stack cap |
| Hotbar | 6 dedicated slots, separate array from main slots |
| Key methods | `add_item`, `remove_item`, `place_stack`, `take_slot`, `count_item`, `available_space_for` |
| Hotbar methods | `get_hotbar_slot`, `set_hotbar_slot`, `take_hotbar_slot`, `place_hotbar_stack`, `decrement_hotbar_slot` |

Items are stored as plain `{"item": String, "count": int, "stack_cap": int}`
dictionaries. No signals are emitted by `InventorySystem` itself; `Main.gd`
calls `HudController.queue_redraw()` after mutations.

### UI Layer — `HudController`

Inventory rendering is purely immediate-mode `_draw()` on a `Control` node.
Pressing `I` calls `hud.toggle_inventory(player.inventory)`.

**Drag/Drop flow:**
1. `_gui_input` left-press → `_slot_at(point)` identifies hit slot → `_begin_drag(hit)` (visual only, source not mutated yet).
2. Release on empty slot → `_take_hit_stack(drag_source)` + `_place_hit_stack(hit, stack)`.
3. Release on matching stack → merge up to `stack_cap`, remainder stays on cursor.
4. Release on different item → swap source and target.
5. Release outside all panels → emit `world_drop_requested`; `Main.gd` spawns a `DroppedItemController`.

Panels supported in a single inventory session: player inventory, container
(chest), equipment column, crafting panel, vendor panel.

### World Drops — `DroppedItemController`

`scripts/controllers/DroppedItemController.gd` — applies gravity, drag,
tile collision via `CollisionSystem`, pickup delay, and optional auto-magnet
for boss/quest drops.

---

## 4. Equipment & Stat Engine

### Data — `EquipmentCatalog`

`scripts/catalogs/EquipmentCatalog.gd`

14 equippable items across 7 slot types:

| Slot | Items |
|---|---|
| `weapon` | wooden_sword, crystal_sword, cursed_sword |
| `head` | iron_helm, crystal_helm |
| `body` | leather_vest, iron_chestplate |
| `legs` | leather_pants, iron_greaves |
| `feet` | leather_boots |
| `accessory` | copper_ring, resin_amulet |
| `utility` | torch, lantern |

Each entry: `{"slot": String, "stats": {"damage"?, "defense"?, "health_max"?, "speed"?, "drill_cool"?}}`.
Utility items also carry `"light_radius_tiles": float`.

Matching `ItemCatalog` entries exist for all 14 items.

### Data Structure — `EquipmentSystem`

`scripts/systems/EquipmentSystem.gd` — extends `RefCounted`

Holds a `Dictionary` keyed by the 7 slot IDs. Slot validation is enforced
via `EquipmentCatalog.get_slot_for_item()` before any write.

```
SLOT_IDS = ["weapon", "head", "body", "legs", "feet", "accessory", "utility"]
```

**Key methods:** `equip(item_id)`, `unequip(slot_id)`, `swap(slot_id, item_id)`,
`get_item(slot_id)`, `find_item_slot(item_id)`.

**Signal:** `equipment_changed` — fired on every slot mutation.

### Stat Aggregation — `StatCalculator`

`scripts/systems/StatCalculator.gd` — extends `RefCounted`, static methods only

`StatCalculator.compute(equipment_system) → Dictionary` iterates all 7
slots, sums `damage / defense / health_max / speed / drill_cool` from each
equipped item's `stats` dict, returns a flat totals dict.

`StatCalculator.get_utility_light_radius(equipment_system) → float` reads
the utility slot's `light_radius_tiles` for World lighting.

### Stat Application — `Main._on_equipment_changed()`

`equipment_system.equipment_changed` → `Main._on_equipment_changed()`:

```
StatCalculator.compute(es)
  → player.set_equipment_health_delta(health_max)
  → player.set_equipment_speed_bonus(speed)
  → player.set_equipment_defense_bonus(defense)
  → world.set_player_utility_light(utility_radius)
```

No polling. Stats update exactly once per equip/unequip event.

### Stat Hooks — `PlayerController`

| Method | Effect |
|---|---|
| `set_equipment_health_delta(int)` | Recalculates `max_health` via `HeartSystem.resolve_max_hp` |
| `set_equipment_speed_bonus(float)` | Multiplies `MAX_SPEED` in `_physics_process_normal` |
| `set_equipment_defense_bonus(int)` | Subtracted from incoming damage before HP deduction |

### Equipment Panel — `HudController`

Rendered as a 7-slot column to the right of the player inventory panel.
Each slot shows the equipped item icon, slot abbreviation hint when empty,
and slot name label. Full drag-drop integration:

- **Pick up** from equipment slot → `EquipmentSystem.unequip(slot_id)`, item
  goes to cursor.
- **Drop** onto equipment slot → `EquipmentSystem.swap(slot_id, item_id)`;
  wrong-slot items are rejected and stay on cursor; displaced items go to
  inventory.

Weapon damage is read at strike time:
```
Main._strike_nearby_enemy()
  → EquipmentCatalog.get_equippable(equipment_system.get_item("weapon"))
  → base_damage from stats.damage
```

---

## 5. Crafting System

### Recipe Data — `CraftingSystem`

`scripts/systems/CraftingSystem.gd` — holds recipe definitions and craftable
status evaluation.

Recipe entries: `{id, result, ingredients: [{item, count}], stations: [String]}`.

`CraftingSystem.detect_active_stations(world, player_pos)` scans nearby
tiles for workbench / furnace / anvil tags.

`CraftingSystem.get_craftable_statuses(inventory, active_stations)` returns
an array of `{id, recipe, craftable: bool}` for all known recipes.

### Proximity Detection

Station detection is tile-scan based (not Area2D). `Main._update_crafting()`
calls `CraftingSystem.detect_active_stations()` on an interval
(`STATION_CHECK_INTERVAL = 0.35 s`) to avoid per-frame work.

Results feed `HudController.receive_craft_statuses()`, which rebuilds the
visible recipe list.

### Crafting Panel — `HudController`

Displayed to the left of the inventory when inventory is open and no
container/vendor is active. Shows up to **10 visible recipe rows**
(`CRAFT_VISIBLE_SLOTS = 10`). **▲ / ▼ scroll arrows** appear when recipes
exist above or below the visible window. Scroll the mouse wheel over the
panel to navigate.

A footer button toggles between "Craftable (N)" (only show unlocked recipes)
and "Show All (N)" (show every recipe regardless of station/material).

**God mode override:** when `DebugSystem.god_mode_enabled` is true, all
recipes are always visible, every recipe is clickable, all items render at
full brightness, and the footer shows a gold **★ God Mode (N)** label.

Hold-to-craft: press a craftable recipe slot → `craft_hold_started` signal;
release → `craft_hold_ended`. `Main.gd` charges a delay (`CRAFT_HOLD_DELAY`)
then fires `receive_crafted_item` on `HudController`.

---

## 6. NPC, Dialogue & Vendor System

### Catalogues

| File | Content |
|---|---|
| `NPCCatalog.gd` | 3 NPCs: `wandering_merchant`, `old_miner`, `cave_hermit`. Fields: name, sprite_key, dialogue (node_id array), shop, interact_radius. |
| `DialogueCatalog.gd` | 11 dialogue nodes. Fields: text, speaker, event ("" or "open_shop"). |
| `VendorCatalog.gd` | `wandering_merchant` shop — 7 stock entries with buy prices. `get_sell_price(item_id)` for player sell-back. |

### Dialogue Flow

```
Player presses T
  → Main._handle_interact()
  → NPC's InteractableComponent.try_interact(player)   ← signal fires
  → Main._on_npc_interacted(_, npc_id)
  → HudController.open_dialogue(npc_id, node_ids)

HudController typewriter (42 chars/sec in _process)
T again:
  - if typing  → skip animation
  - if event node → emit dialogue_event(event_name, npc_id)
  - otherwise  → advance to next node or close

Main._on_dialogue_event("open_shop", npc_id)
  → hud.close_dialogue()
  → hud.open_vendor(shop_id, player.inventory)
```

### Dialogue Panel

`HudController._draw_dialogue_panel()` — above the hotbar, full screen
width minus padding. Draws portrait box, NPC name, typewriter text, and a
blinking `[T] Next ▶ / [T] Close` hint when animation is complete.

### Vendor Panel

Right side of screen alongside the player inventory. Shows shop title,
player copper count, up to 6 scrollable stock rows.

- **Buy**: left-click a stock row → deduct copper, add item to inventory.
- **Sell**: right-click an inventory slot while vendor is open → add copper,
  remove item.

Currency: `copper_nugget` item.

---

## 7. Interactable Component

`scripts/components/InteractableComponent.gd` — extends `Node2D`

A **composition component** that adds standardised proximity + interact
behaviour to any host entity. Drop it as a child node — no base-class
changes needed on the host.

```
InteractableComponent
  signal interacted(interactor: Node)
  signal proximity_changed(is_nearby: bool)
  @export var interact_radius: float
  @export var hint_text: String
  @export var label_offset: Vector2
  func update_proximity(player_world_pos)   → call each frame
  func try_interact(interactor)             → call on T press; emits signal
  func is_nearby(world_pos) → bool
  func set_hint_visible(v: bool)
```

**Currently used by:** `NpcController` (creates the component in `setup()`,
sets radius and hint text from `NPCCatalog`).

**Extendable to:** chest doors (proximity-open), switches, levers, item
pedestals, boss triggers — add the child node and connect `interacted`.

> **Note:** The component currently uses a `distance_to()` check because the
> player uses a custom AABB solver (not `CharacterBody2D`). If the player ever
> gains a Godot physics body, this component can be upgraded to an `Area2D`
> with `body_entered` / `body_exited` for zero-polling proximity detection.

---

## 8. World & Lighting

`scripts/World.gd` owns the `ChunkStore`, tile draw, tile mutation, mining
damage, beacons, flares, autotile edge rendering, and light source
aggregation.

### Light Sources

`World.get_light_sources(player_position) → Array[Dictionary]`

Returns a list of `{position: Vector2, radius_tiles: float, intensity: float}`
entries:

| Source | Radius | Intensity |
|---|---|---|
| Player ambient | 9.0 tiles | 0.95 |
| Equipped utility item (torch/lantern) | see EquipmentCatalog | 0.88 |
| Beacon | 12.0 tiles | 0.75 |
| Flare | 8.0 tiles | 0.82 |
| Structure lanterns | varies | varies |

The utility light radius is set via `World.set_player_utility_light(radius_tiles)`
from `Main._on_equipment_changed()`.

---

## 9. Procedural Generation & Prefabs

Generation is deterministic from seed and tile coordinate. Horizontal
generation is unbounded. Vertical generation resolves through five Bands;
Solid Dark Blocks clamp at `tileY >= 1920`.

`StructureGenerator.gd` delegates to `PrefabTemplateRegistry.gd` for chunk
overlap, spawn/light/container markers, and mirror/rotation metadata.

**Built-in templates:**

| Template | Band | Description |
|---|---|---|
| `goblin_village_full` | Band 1 `standard_caverns` | Imported legacy goblin village |
| `dwarf_fortress_full` | Band 2 `colossal_ant_chambers` | Granite/iron fortress with forge rooms |
| `dwarf_settlement_full` | Band 2 `colossal_ant_chambers` | Multi-level settlement with great hall |

### Prefab Designer

`scenes/PrefabDesigner.tscn` — standalone tool scene. Builds palette from
`TileCatalog`, `BackgroundCatalog`, `EnemyCatalog`, and `assets/props/*.png`.
Supports foreground / background / prop / spawn layers. Saves sparse JSON via
`PrefabTemplateRegistry.save_template`.

Blank cells = "do not stamp"; explicit `air` foreground entries carve
terrain; explicit `empty` background entries clear walls. Container props
stamp a `chest_block` marker on the bottom-left occupied cell.

---

## 10. v0.11 Systems

### TimeManager

`autoload/TimeManager.gd` — global clock singleton.

- Advances at **0.5 real seconds per in-game minute** (1 real second = 2 in-game minutes).
- Exposes `current_hour`, `current_minute`, `current_day` (float; hour 0–23, minute 0–59, day ≥ 1).
- Emits `hour_changed(hour: int)` once per in-game hour transition.
- `World.gd` reads `TimeManager.current_hour` each draw frame to blend the 24-step sky gradient.
- Console shortcuts: `set_time <0–23>` (jump to hour), `add_time <minutes>` (fast-forward).

### EventManager

`autoload/EventManager.gd` — world event controller.

| Field | Role |
|---|---|
| `active_event_id: String` | `""` when idle; `"blood_moon"` / `"goblin_raid"` / `"meteor_shower"` while active. |
| `event_sky_tint: Color` | Multiplied on top of the normal day/night sky colour by `World.gd`. |

Event lifecycle:
1. `event_start <id>` console command → `EventManager.start_event(id)` → sky tint applied, 4-second banner shown, enemy table swapped via `_spawn_band_encounter`.
2. `event_stop` → `EventManager.stop_event()` → sky restored, normal band encounter resumes.

Enemy substitutions are defined per event in `EventCatalog.gd`.

### LiquidSystem

`autoload/LiquidSystem.gd` — cellular-automaton liquid engine.

- Runs a **10 Hz tick** driven by an accumulator in `_physics_process`.
- Three liquid types: `water`, `lava`, `honey` — each with distinct `flow_speed` and `spread_limit` from `LiquidCatalog`.
- Liquid cells are stored in `World.ChunkStore` as `{Vector2i → {type: String, volume: int}}`.
- **Reaction:** adjacent `water` + `lava` cells → `obsidian` tile placed, both liquids consumed.
- **Bucket actions** (`empty_bucket`, `water_bucket`, `lava_bucket`, `honey_bucket`) are handled in `Main._handle_bucket_action()` via right-click while the item is hotbar-active.

### DebugSystem

`autoload/DebugSystem.gd` — developer flag registry.

| Flag | Effect |
|---|---|
| `god_mode_enabled: bool` | Invincibility + free flight + fully free crafting. |

Three `CraftingSystem` entry points respect this flag:

| Entry point | Behaviour when flag is true |
|---|---|
| `detect_active_stations()` | Returns all station names — no proximity check needed. |
| `_can_craft()` | Returns `true` immediately. |
| `_consume_ingredients()` | Returns without deducting anything. |

`HudController` additionally renders all recipes at full brightness and shows a gold **★ God Mode (N)** footer. Console: `god` toggles the flag; HUD shows the indicator top-right while active.

### ModifierSystem & StatusEffectSystem

`scripts/systems/ModifierSystem.gd` and `StatusEffectSystem.gd` — item prefix and buff/debuff logic.

**Modifiers** (14 prefixes, `legendary` → `broken`):
- Applied on craft at a 30% roll, or forced via `modifier <prefix> [slot]` console command.
- Stored as `{prefix_id, stat_deltas}` alongside the item stack dictionary.
- `ModifierCatalog.gd` lists all tier / stat-delta definitions.

**Status effects** (10 total — 5 buffs, 5 debuffs):
- Tracked in `StatusEffectSystem` with per-effect countdown timers.
- Stat deltas feed into `StatCalculator.compute()` alongside equipment stats.
- `Curse` debuff is **permanent** until `clearfx` or manual removal.
- Console: `buff <id>`, `debuff <id>`, `clearfx`.

---

## 11. Save / Load

`SaveGameSystem.gd` writes `user://saves/slot_1.json` at schema version **3**.

**Persisted in schema v3:**

| Category | Keys |
|---|---|
| World | seed, tile overrides, tile damage, generated chunks, liquid state |
| Player | position, velocity, health |
| Inventory | inventory slots, hotbar, selected slot |
| Equipment | all 7 equipment slots + active modifiers |
| Containers | all chest inventories |
| World objects | floor drops, beacons, flares |
| Progression | defeated boss flags |
| Time | `hour`, `minute`, `day` |

**Not persisted:** enemy positions (re-spawned on load), NPC positions (deterministic from seed).

### Load Order

Loading restores generated chunks before applying player edits so explored areas remain stable if templates change after the fact:

1. Regenerate all previously-visited chunks from seed.
2. Apply tile overrides (mining damage, block edits).
3. Restore liquid state.
4. Restore containers, drops, beacons, flares.
5. Restore player position + health.
6. Restore inventory + hotbar + equipment.
7. Restore time via `TimeManager`.

### Time Persistence Helpers

Three static methods in `SaveGameSystem`:

| Method | Role |
|---|---|
| `_snapshot_time(main)` | Reads `TimeManager` from the scene tree via `main.get_node_or_null("/root/TimeManager")`, returns `{hour, minute, day}`. |
| `_time_from_data(data)` | Validates and clamps a loaded dict; returns safe defaults (`hour 8, minute 0, day 1`) on missing keys. |
| `_restore_time(main, time_data)` | Writes `current_hour / current_minute / current_day` on `TimeManager` and resets `_accumulator` to 0. |

---

## 12. Health & Hearts

`HeartSystem.gd` models health as HP integers:

| Constant | Value |
|---|---|
| `DEFAULT_MAX_HP` | 10 HP |
| HP per heart | 2 HP |
| States | `full`, `half`, `empty` |

Equipment can add `health_max` delta (whole-heart-friendly values resolved by
`HeartSystem.resolve_max_hp`).

---

## 13. Controls Reference

| Action | Input |
|---|---|
| Move | `A / D` or arrow keys |
| Jump | `W`, up arrow, or space |
| Drill (hold) | Left mouse or `F` |
| Use / place hotbar item | Right mouse |
| Strike (melee) | `E` |
| Interact (NPC) | `T` |
| Inventory + Equipment + Crafting | `I` |
| Hotbar select | `1–6` or mouse wheel |
| Flare | `Q` |
| Beacon | `R` |
| Developer console | `` ` `` (tilde) — toggle |

**ESC priority chain:** closes Dialogue → Vendor → Container → Inventory → Pause menu.

### Developer Console Commands

| Command | Effect |
|---|---|
| `god` | Toggle god mode (invincible + fly + free crafting) |
| `heal` | Restore full HP |
| `tp <1\|2\|3>` | Teleport to Band 1 / 2 / 3 |
| `give <id> [count] [modifier]` | Give items to inventory |
| `modifier <mod> [slot]` | Apply modifier prefix to equipped item |
| `buff <effect_id>` | Apply buff |
| `debuff <effect_id>` | Apply debuff |
| `clearfx` | Remove all active status effects |
| `kill` | Despawn all enemies and bosses |
| `respawn monster <id>` | Spawn enemy near player |
| `respawn npc <id>` | Spawn friendly NPC near player |
| `respawn boss <id\|1–5>` | Reset + spawn boss |
| `event_start <id>` | Start a world event |
| `event_stop` | End the current event |
| `set_time <0–23>` | Jump to in-game hour |
| `add_time <minutes>` | Fast-forward in-game time |
| `clear` | Clear console output |
| `help` | Print command list |

---

## 14. Future Architecture Roadmap

The following improvements are planned but not yet implemented. They are
documented here so new contributors understand the intended direction.

### 14.1 Data via Godot Resources (high priority)

**Current state:** all item/NPC/dialogue data is hardcoded in `const`
dictionaries inside catalogue GDScript files.

**Target state:** each item becomes a custom `Resource` file (`.tres`):

```
# ItemData.gd
extends Resource
class_name ItemData
@export var item_id: String
@export var display_name: String
@export var description: String
@export var rarity: StringName
@export var category: StringName
```

**Why:** the editor can inspect and edit individual items, artists can
create new items without touching GDScript, and `ResourceLoader` enables
async loading for large item sets.

**Migration path:** create `ItemData.gd`, write a one-time migration script
that reads the existing `ItemCatalog.ITEMS` dict and emits `.tres` files into
`res://data/items/`, then replace `ItemCatalog.get_item(id)` with
`ResourceLoader.load("res://data/items/%s.tres" % id)` (cached in an
`ItemRegistry` autoload).

### 14.2 Area2D-based InteractableComponent

Once `PlayerController` migrates to `CharacterBody2D`, the
`InteractableComponent` (§7) can be upgraded:

- Extend `Area2D` instead of `Node2D`.
- Set a `CircleShape2D` of radius `interact_radius`.
- Use `body_entered` / `body_exited` to set `_is_nearby` instead of a
  distance check.
- `_update_npc_proximity()` in `Main.gd` can be removed entirely.

The public interface (`try_interact`, `interacted` signal) stays the same —
no callers break.

### 14.3 Global Signal Bus (EventBus autoload)

For events that cross multiple distant systems (e.g. player death, day/night
cycle, quest completion), a dedicated `EventBus.gd` autoload avoids chaining
signal connections through Main.gd:

```gdscript
# autoload: EventBus.gd
signal player_died
signal equipment_changed(slot_id: String, item_id: String)
signal quest_completed(quest_id: String)
```

### 14.4 Scene-Based Slot UI

`HudController` currently draws all inventory slots in immediate-mode
`_draw()`. A scene-based approach (`SlotUI.tscn` + `InventoryUI.tscn` using
Godot's built-in `_get_drag_data` / `_can_drop_data` / `_drop_data`) would
let the Godot editor preview the layout and support accessibility features.
Recommended when the UI design is stable.

### 14.5 ~~Equipment Save/Load~~ ✅ Done in v0.11

Equipment serialization was completed in schema v3. All 7 equipment slots
and their active modifier prefixes are now persisted and restored on load.
See §11 for the full schema v3 field list.
