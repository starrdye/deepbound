# Deepbound — Developer Guide

> Version 0.11 · Godot 4.6 · GDScript · GL Compatibility renderer

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Directory Structure](#2-directory-structure)
3. [Architecture & Scene Tree](#3-architecture--scene-tree)
4. [Autoloads](#4-autoloads)
5. [World & Band System](#5-world--band-system)
6. [Developer Console](#6-developer-console)
7. [Item Catalog](#7-item-catalog)
8. [Crafting System](#8-crafting-system)
9. [Equipment System](#9-equipment-system)
10. [Item Modifiers](#10-item-modifiers)
11. [Status Effects](#11-status-effects)
12. [Enemy Catalog](#12-enemy-catalog)
13. [World Events](#13-world-events)
14. [Liquid System](#14-liquid-system)
15. [Time & Day/Night Cycle](#15-time--daynight-cycle)
16. [Save System](#16-save-system)
17. [Catalog Reference — Tiles](#17-catalog-reference--tiles)
18. [Adding New Content](#18-adding-new-content)

---

## 1. Project Overview

Deepbound is a 2-D side-scrolling cave exploration game. The player drills downward through procedurally generated biome bands, fights enemies, loots chests, crafts gear, and eventually confronts bosses at depth.

**Key design axioms:**
- All game data lives in **static catalog files** (`scripts/catalogs/`). No magic numbers scattered across gameplay scripts.
- All game logic lives in **pure-static system files** (`scripts/systems/`). Systems receive data; they do not own state.
- The scene tree drives **controllers** (`scripts/controllers/`) that wire systems together and own node state.
- Two **autoloads** (`TimeManager`, `EventManager`) provide global signals without requiring node references.

---

## 2. Directory Structure

```
deepbound_godot/
├── assets/
│   ├── enemies/          # 16×16 or sheet PNG per enemy (+ atlas)
│   ├── items/            # 16×16 PNG icon per item (+ atlas)
│   ├── tiles/            # Tile sprites (procedural fallback via TextureFactory)
│   ├── ui/               # HUD elements (hearts, slots, drill heat bar, etc.)
│   ├── props/            # Chest, goblin/dwarf/drow structures, placeables
│   ├── backgrounds/      # Parallax backgrounds per biome
│   ├── effects/          # Hit sparks, drill impacts, tile-break animations
│   └── source_ai/        # AI reference images (not loaded at runtime)
├── scenes/
│   ├── MainMenu.tscn     # Entry point (project.godot → run/main_scene)
│   └── Main.tscn         # In-game scene root
├── scripts/
│   ├── Main.gd           # Game controller — wires all systems together
│   ├── World.gd          # World node — chunks, tiles, liquids, lighting
│   ├── catalogs/         # Static data — items, tiles, enemies, recipes, …
│   ├── systems/          # Pure-static logic — crafting, saving, liquids, …
│   ├── controllers/      # Node-attached controllers — player, HUD, enemy, …
│   └── components/       # Lightweight resource types (StatusEffectData, …)
├── tests/                # GDScript unit tests (run via TestRunner scene)
├── tools/                # Python build scripts (pixel asset generation)
├── project.godot         # Engine config — autoloads, window size, renderer
└── DEVELOPER_GUIDE.md    # This file
```

---

## 3. Architecture & Scene Tree

```
Main (Node2D)  ← Main.gd
├── World (Node2D)  ← World.gd
│   └── [ChunkRenderLayer nodes created at runtime]
├── Props (Node2D)  — chest_block props, NPC scene roots
├── Drops (Node2D)  — DroppedItemController instances
├── Player (Node2D)  ← PlayerController.gd
│   ├── Sprite2D
│   └── Camera2D  ← CameraController.gd
├── Enemies (Node2D)  — EnemyController / BossController instances
├── DayNightModulate (CanvasModulate)  — tints world; NOT the HUD
└── HudLayer (CanvasLayer)
    └── Hud (Control)  ← HudController.gd
```

`Main.gd` is the central orchestrator. It:
- Holds references to `world`, `player`, `hud`, `enemies_node`, `props_node`, `drops_node`
- Runs `_update_crafting()`, `_update_sky_modulate()`, encounter spawning, and the developer terminal
- Connects to `TimeManager.hour_changed` and `EventManager.event_started / event_stopped`

---

## 4. Autoloads

Registered in `project.godot → [autoload]`. Accessible anywhere via `/root/<Name>`.

### TimeManager (`scripts/systems/TimeManager.gd`)

Global 24-hour clock. Drives the day/night sky cycle.

| Property | Type | Default | Notes |
|---|---|---|---|
| `current_hour` | int | 8 | 0–23 |
| `current_minute` | int | 0 | 0–59 |
| `current_day` | int | 1 | increments at midnight |
| `time_scale` | float | 1.0 | multiply to fast-forward time |

| Signal | Args | Fired when |
|---|---|---|
| `hour_changed` | `new_hour: int` | each in-game hour tick |
| `day_advanced` | `new_day: int` | midnight rollover |

| Method | Returns | Notes |
|---|---|---|
| `set_hour(h)` | void | snaps to hour, resets accumulator |
| `add_minutes(n)` | void | capped at 1440 total mins (24 h) |
| `get_normalized_time()` | float | 0.0–1.0 (includes fractional minute) |
| `get_time_string()` | String | `"08:30"` format |
| `sky_color_for_normalized(t)` | Color | lerps across 24-entry `SKY_COLORS` array |

**Tick speed:** `TICK_SPEED = 0.5` — one real second equals two in-game minutes (720× real time).

---

### EventManager (`scripts/systems/EventManager.gd`)

Console-driven world event director. Does **not** trigger automatically — all events are started via console commands or `force_start_event()`.

| Property | Type | Notes |
|---|---|---|
| `active_event_id` | String | `""` when no event is running |

| Signal | Args | Fired when |
|---|---|---|
| `event_started` | `event_id: String` | event begins |
| `event_stopped` | `event_id: String` | event ends |

| Method | Returns | Notes |
|---|---|---|
| `force_start_event(event_id)` | bool | stops current event first; returns false if id unknown |
| `force_stop_event()` | void | no-op if nothing is running |
| `is_event_active()` | bool | — |
| `get_event_sky_tint()` | Color | `Color.WHITE` if no event |

---

## 5. World & Band System

### Bands (depth layers)

The world is split into vertical bands. Each band has its own enemies, tiles, resources, and ambient light level. Band boundaries are measured in **tile units** (1 tile = 16 px).

| # | Band ID | Tile Y range | Danger | Key resources |
|---|---|---|---|---|
| 0 | `surface_area` | −96 → −1 | 0 | dirt_clod, stone_chunk |
| 1 | `standard_caverns` | 0 → 383 | 1 | copper_nugget |
| 2 | `colossal_ant_chambers` | 384 → 767 | 2 | resin_shard, royal_jelly |
| 3 | `buried_pyramids` | 768 → 1151 | 3 | sandstone_shard, cursed_relic |
| 4 | `drow_enclaves` | 1152 → 1535 | 4 | glow_spore, drow_silk |
| 5 | `abyssal_lava_slums` | 1536 → 1919 | 5 | obsidian_chip, heat_core |
| 6 | `solid_dark_blocks` | 1920 → ∞ | 6 | dark_block_sliver |

**Utility functions** (`BandCatalog.gd`):
```gdscript
BandCatalog.resolve_band_id(tile_y)   # → band_id String
BandCatalog.get_band(tile_y)          # → band Dictionary
BandCatalog.get_depth_label(tile_y)   # → "Band 1: Standard Caverns / 42m"
```

### ChunkStore

`World.gd` owns a `ChunkStore` instance (`world.store`). All tile and liquid data are stored here as sparse dictionaries keyed by `Vector2i`.

| Store dict | Key | Value |
|---|---|---|
| `overrides` | `Vector2i` tile pos | tile_id String |
| `background_overrides` | `Vector2i` | tile_id String |
| `damage` | `Vector2i` | float damage amount |
| `liquids` | `Vector2i` | `{type: int, volume: int}` |

---

## 6. Developer Console

Open / close with **`~`** (tilde). Type a command and press **Enter**.

### All Commands

#### Player

| Command | Description |
|---|---|
| `god` | Toggle god mode — invincible, infinite fly, all crafting free |
| `heal` | Restore player to full HP |
| `tp <1\|2\|3>` | Teleport to the start of band 1, 2, or 3 |
| `give <item_id> [count] [modifier_id]` | Add items to inventory. Count defaults to 1. |
| `modifier <mod_id> [slot]` | Apply a modifier to an equipped item. Slot defaults to `weapon`. |
| `buff <effect_id>` | Apply a timed buff (see Status Effects table) |
| `debuff <effect_id>` | Apply a timed debuff |
| `clearfx` | Remove all active status effects |

**Examples:**
```
give wooden_sword
give crystal_sword 1 legendary
give copper_nugget 99
modifier godly
modifier warding accessory
buff swiftness
debuff curse
```

#### Enemies & Bosses

| Command | Description |
|---|---|
| `kill` | Despawn all active enemies and bosses |
| `respawn monster <enemy_id>` | Spawn an enemy near the player |
| `respawn npc <npc_id>` | Spawn a friendly NPC near the player |
| `respawn boss <id\|1>` | Reset defeated flag and spawn boss (clears defeated list) |

**Examples:**
```
respawn monster cave_skitter
respawn monster drow_acolyte
respawn boss rootbound_foreman
respawn boss 1
```

#### World Events

| Command | Description |
|---|---|
| `event_start <event_id>` | Start a world event (stops any running event first) |
| `event_stop` | End the current event |

**Available events:** `blood_moon`  `goblin_raid`  `meteor_shower`

```
event_start blood_moon
event_stop
```

#### Time

| Command | Description |
|---|---|
| `set_time <0-23>` | Jump to an in-game hour (sky updates instantly) |
| `add_time <minutes>` | Fast-forward by N in-game minutes |

```
set_time 0      # midnight
set_time 12     # noon
add_time 60     # advance 1 hour
add_time 720    # advance 12 hours
```

#### Utility

| Command | Description |
|---|---|
| `clear` | Clear console output |
| `help` | Print command reference |

---

## 7. Item Catalog

All items are defined in `scripts/catalogs/ItemCatalog.gd`. The `category` field determines HUD placement and crafting behaviour.

### Materials (raw drops from tiles/enemies)

| ID | Name | Rarity | Source |
|---|---|---|---|
| `dirt_clod` | Dirt Clod | common | surface / cave dirt tiles |
| `stone_chunk` | Stone Chunk | common | stone tiles, dwarf structures |
| `copper_nugget` | Copper Nugget | common | copper_ore tile |
| `resin_shard` | Resin Shard | uncommon | hardened_resin tile (ant chambers) |
| `royal_jelly` | Royal Jelly | rare | royal_jelly tile / Amber Queen boss |
| `sandstone_shard` | Sandstone Shard | uncommon | sandstone_block tile (pyramids) |
| `cursed_relic` | Cursed Relic | epic | cursed_treasure tile / Pharaoh boss |
| `glow_spore` | Glow Spore | uncommon | glow_mushroom_loam / mushroom plank (drow) |
| `drow_silk` | Drow Silk | rare | drow_silk_canopy tile / Drow Matriarch boss |
| `obsidian_chip` | Obsidian Chip | rare | deep lava zone |

### Weapons

| ID | Name | Rarity | Damage | Slot |
|---|---|---|---|---|
| `wooden_sword` | Wooden Sword | common | 3 | weapon |
| `crystal_sword` | Crystal Sword | rare | 6 | weapon |
| `cursed_sword` | Cursed Sword | epic | 10 | weapon |

### Tools

| ID | Name | Rarity | Effect |
|---|---|---|---|
| `hammer` | Hammer | common | Breaks background walls |
| `crystal_drill` | Crystal Drill | rare | Faster mining |
| `cursed_drill` | Cursed Drill | epic | Cuts near-any material |
| `empty_bucket` | Empty Bucket | common | Scoops liquid tiles (right-click) |
| `water_bucket` | Bucket of Water | common | Pours water (right-click) |
| `lava_bucket` | Bucket of Lava | uncommon | Pours lava |
| `honey_bucket` | Bucket of Honey | uncommon | Pours honey |

### Armor — Head

| ID | Name | Rarity | Stats |
|---|---|---|---|
| `iron_helm` | Iron Helm | common | +2 Defense |
| `crystal_helm` | Crystal Helm | rare | +4 Defense, +5 Max HP |

### Armor — Body

| ID | Name | Rarity | Stats |
|---|---|---|---|
| `leather_vest` | Leather Vest | common | +1 Defense |
| `iron_chestplate` | Iron Chestplate | uncommon | +4 Defense |

### Armor — Legs

| ID | Name | Rarity | Stats |
|---|---|---|---|
| `leather_pants` | Leather Pants | common | +1 Defense |
| `iron_greaves` | Iron Greaves | uncommon | +2 Defense |

### Armor — Feet

| ID | Name | Rarity | Stats |
|---|---|---|---|
| `leather_boots` | Leather Boots | common | +1 Defense, +10% Speed |

### Accessories

| ID | Name | Rarity | Stats |
|---|---|---|---|
| `copper_ring` | Copper Ring | common | +5 Max HP |
| `resin_amulet` | Resin Amulet | uncommon | +1 Defense, −10% Drill Heat |

### Utility (Light Sources)

| ID | Name | Rarity | Light Radius |
|---|---|---|---|
| `torch` | Torch | common | 10 tiles |
| `lantern` | Lantern | uncommon | 17 tiles |

### Placeables

| ID | Name | Rarity | Notes |
|---|---|---|---|
| `workbench` | Workbench | common | Unlocks Workbench recipes |
| `furnace` | Furnace | common | Unlocks Furnace recipes |
| `anvil` | Anvil | uncommon | Unlocks Anvil recipes |
| `chest` | Chest | common | Storage container |
| `dirt_background_block` | Dirt Wall | common | Background wall |
| `stone_background_block` | Stone Wall | common | Background wall |
| `wooden_background_block` | Wooden Wall | common | Background wall |

### Item Rarity Colours

| Rarity | HUD colour |
|---|---|
| common | White `#FFFFFF` |
| uncommon | Green `#55FF55` |
| rare | Blue `#55AAFF` |
| epic | Purple `#C864FF` |
| legendary | Gold `#FFAA00` |

---

## 8. Crafting System

### How it works

1. `CraftingSystem.detect_active_stations(world, player_pos)` scans tiles within **6 tiles** of the player and returns a set of station names.
2. `CraftingSystem.get_craftable_statuses(inventory, active_stations)` annotates every recipe in `CraftingRecipeBook.RECIPES` with a `craftable: bool`.
3. Player clicks a recipe in the HUD crafting panel → `CraftingSystem.execute_craft()` consumes ingredients and returns the crafted stack.

**God mode** bypasses all station and ingredient requirements (see §6).

### Crafting Stations

| Tile ID | Station name | Needed for |
|---|---|---|
| `workbench_block` | Workbench | Most basic recipes |
| `furnace_block` | Furnace | Metal smelting tier |
| `anvil_block` | Anvil | Crystal / high-tier gear |

Station detection radius: **6 tiles**.

### Current Recipe List

#### Hand-craft (no station)

| Result | Count | Ingredients |
|---|---|---|
| `workbench` | 1 | 8× stone_chunk + 12× dirt_clod |
| `dirt_background_block` | 2 | 1× dirt_clod |
| `stone_background_block` | 2 | 1× stone_chunk |
| `wooden_background_block` | 2 | 2× dirt_clod |

#### Workbench

| Result | Count | Ingredients |
|---|---|---|
| `wooden_sword` | 1 | 5× stone_chunk |
| `hammer` | 1 | 8× stone_chunk |
| `chest` | 1 | 4× stone_chunk + 4× dirt_clod |
| `furnace` | 1 | 20× stone_chunk + 5× copper_nugget |

#### Workbench + Furnace

| Result | Count | Ingredients |
|---|---|---|
| `anvil` | 1 | 10× stone_chunk + 20× copper_nugget |

#### Workbench + Anvil

| Result | Count | Ingredients |
|---|---|---|
| `crystal_sword` | 1 | 10× resin_shard + 15× copper_nugget |
| `crystal_drill` | 1 | 8× resin_shard + 20× copper_nugget |

#### Workbench + Furnace + Anvil

| Result | Count | Ingredients |
|---|---|---|
| `cursed_sword` | 1 | 5× obsidian_chip + 1× cursed_relic + 3× drow_silk |
| `cursed_drill` | 1 | 8× obsidian_chip + 2× cursed_relic + 15× copper_nugget |

> **Note:** Armor, accessory, bucket, and light-source recipes are proposed for implementation — see §18.

---

## 9. Equipment System

### Slots

| Slot ID | Accepts categories |
|---|---|
| `weapon` | weapon |
| `head` | head |
| `body` | body |
| `legs` | legs |
| `feet` | feet |
| `accessory` | accessory |
| `utility` | utility (light sources, tools) |

Open the **Equipment panel** with **`E`** (or **`I`** to open Inventory, then equipment appears alongside). Click an item in inventory to equip it; click an equipped slot to unequip back to inventory.

### Stat Keys

Stats are processed by `StatCalculator` and applied in `Main.gd` each time equipment changes.

| Stat key | Effect |
|---|---|
| `damage` | Flat bonus to melee strike damage |
| `defense` | Flat damage reduction per hit |
| `health_max` | Bonus max HP (adjusts `equipment_health_delta`) |
| `speed` | Fractional walk/fly speed bonus (`0.10` = +10 %) |
| `drill_cool` | Fractional drill-heat reduction (`0.10` = −10 %) |

### Equippable Item Stats

| Item | Slot | Stats |
|---|---|---|
| `wooden_sword` | weapon | damage +3 |
| `crystal_sword` | weapon | damage +6 |
| `cursed_sword` | weapon | damage +10 |
| `iron_helm` | head | defense +2 |
| `crystal_helm` | head | defense +4, health_max +5 |
| `leather_vest` | body | defense +1 |
| `iron_chestplate` | body | defense +4 |
| `leather_pants` | legs | defense +1 |
| `iron_greaves` | legs | defense +2 |
| `leather_boots` | feet | defense +1, speed +10 % |
| `copper_ring` | accessory | health_max +5 |
| `resin_amulet` | accessory | defense +1, drill_cool −10 % |
| `torch` | utility | light radius 10 tiles |
| `lantern` | utility | light radius 17 tiles |

---

## 10. Item Modifiers

Modifiers are Terraria-style prefixes that alter weapon or accessory stats. Applied automatically on craft (75% chance) or manually via the console.

### Applying via Console

```
modifier <modifier_id>                  # applies to weapon slot
modifier <modifier_id> <slot_id>        # applies to specific slot
```

### Modifier Table

| ID | Name | Tier | Dmg × | Spd × | KB × | Crit + | Notes |
|---|---|---|---|---|---|---|---|
| `legendary` | Legendary | legendary | 1.15 | 1.05 | 1.15 | +5% | |
| `godly` | Godly | legendary | 1.15 | 1.10 | 1.15 | +7% | |
| `demonic` | Demonic | rare | 1.15 | 1.00 | 1.00 | +10% | |
| `keen` | Keen | rare | 1.05 | 1.00 | 1.00 | +4% | |
| `sharp` | Sharp | uncommon | 1.10 | 1.00 | 1.00 | — | |
| `heavy` | Heavy | uncommon | 1.00 | 0.90 | 1.25 | — | |
| `swift` | Swift | uncommon | 1.00 | 1.15 | 1.00 | — | |
| `lucky` | Lucky | uncommon | 1.00 | 1.00 | 1.00 | +8% | |
| `menacing` | Menacing | uncommon | 1.04 | 1.00 | 1.00 | — | |
| `violent` | Violent | uncommon | 1.00 | 1.00 | 1.00 | +6% | |
| `warding` | Warding | uncommon | 1.00 | 1.00 | 1.00 | — | +2 defense |
| `quick` | Quick | uncommon | 1.00 | 1.08 | 1.00 | — | |
| `broken` | Broken | broken | 0.75 | 0.90 | 0.75 | — | negative |
| `blunt` | Blunt | broken | 0.85 | 1.00 | 0.85 | — | negative |

**Roll pools:**
- Weapons: legendary, godly, demonic, keen, sharp, heavy, swift, lucky, broken, blunt
- Accessories: menacing, warding, violent, quick, lucky

---

## 11. Status Effects

Applied by console (`buff` / `debuff`) or future in-game triggers. All values are **additive** on top of base stats.

### Buffs

| ID | Name | Duration | Stat changes |
|---|---|---|---|
| `swiftness` | Swiftness | 30 s | speed +15% |
| `endurance` | Endurance | 25 s | defense +3 |
| `fervor` | Fervor | 20 s | damage +3 |
| `fortitude` | Fortitude | 30 s | health_max +20 |
| `vigor` | Vigor | 20 s | damage +2, speed +10% |

### Debuffs

| ID | Name | Duration | Stat changes |
|---|---|---|---|
| `slow` | Slow | 10 s | speed −20% |
| `vulnerable` | Vulnerable | 10 s | defense −2 |
| `weakness` | Weakness | 10 s | damage −2 |
| `curse` | Curse | **permanent** | damage −2, speed −10% |
| `frail` | Frail | 12 s | defense −3, health_max −10 |

`clearfx` removes all active effects. `curse` is the only permanent effect.

---

## 12. Enemy Catalog

Defined in `scripts/catalogs/EnemyCatalog.gd`.

### Regular Enemies

| ID | Name | Band | HP | Dmg | Speed | Aggro tiles |
|---|---|---|---|---|---|---|
| `cave_skitter` | Cave Skitter | standard_caverns | 24 | 8 | 34 | 8 |
| `goblin_grunt` | Goblin Grunt | standard_caverns | 34 | 10 | 42 | 10 |
| `goblin_slinger` | Goblin Slinger | standard_caverns | 26 | 8 | 46 | 12 |
| `goblin_shaman` | Goblin Shaman | standard_caverns | 42 | 13 | 30 | 11 |
| `worker_ant` | Worker Ant | colossal_ant_chambers | 34 | 10 | 42 | 9 |
| `soldier_ant` | Soldier Ant | colossal_ant_chambers | 58 | 16 | 36 | 10 |
| `dwarf_guard` | Dwarf Guard | colossal_ant_chambers | 62 | 16 | 31 | 9 |
| `dwarf_crossbowman` | Dwarf Crossbowman | colossal_ant_chambers | 46 | 14 | 34 | 13 |
| `dwarf_smith` | Dwarf Smith | colossal_ant_chambers | 70 | 18 | 27 | 9 |
| `mummy_sentry` | Mummy Sentry | buried_pyramids | 72 | 18 | 25 | 7 |
| `drow_warrior` | Drow Warrior | drow_enclaves | 95 | 24 | 32 | 11 |
| `drow_acolyte` | Drow Acolyte | drow_enclaves | 65 | 28 | 36 | 13 |

### Bosses

| ID | Name | Band | HP | Dmg | Unlock drop |
|---|---|---|---|---|---|
| `rootbound_foreman` | Rootbound Foreman | standard_caverns | 420 | 18 | `copper_brace` |
| `amber_queen` | Amber Queen | colossal_ant_chambers | 760 | 26 | `royal_jelly` |
| `pharaoh_of_buried_sun` | Pharaoh of the Buried Sun | buried_pyramids | 920 | 32 | `cursed_relic` |
| `drow_matriarch` | Drow Matriarch | drow_enclaves | 1100 | 38 | `drow_silk` |
| `obsidian_baron` | Obsidian Baron | abyssal_lava_slums | 1360 | 44 | `heat_core` |

**Respawning a boss via console:**
```
respawn boss rootbound_foreman
respawn boss 1   # same as rootbound_foreman (band 1 boss)
```

---

## 13. World Events

Defined in `scripts/catalogs/EventCatalog.gd`. Events are console-only — they never trigger automatically.

### How Events Work

1. `event_start <id>` → `EventManager.force_start_event(id)` → `event_started` signal
2. `Main.gd` receives `event_started`:
   - Multiplies `EventManager.get_event_sky_tint()` into the `DayNightModulate` colour
   - Shows a 4-second banner alert at top of screen
   - Calls `_spawn_band_encounter()` which substitutes `spawn_overrides` enemies
3. `event_stop` → `EventManager.force_stop_event()` → restores normal sky + normal spawns

### Event Table

| ID | Name | Sky tint | Spawn overrides | Spawn multiplier |
|---|---|---|---|---|
| `blood_moon` | Blood Moon | Red `(1.0, 0.35, 0.35)` | cave_skitter, soldier_ant, mummy_sentry | ×2 |
| `goblin_raid` | Goblin Raid | Yellow `(0.88, 0.82, 0.28)` | cave_skitter, worker_ant, cave_skitter | ×3 |
| `meteor_shower` | Meteor Shower | Lavender `(0.80, 0.65, 1.0)` | *(none — visual only)* | ×1 |

---

## 14. Liquid System

### Liquid Types

Defined in `scripts/catalogs/LiquidCatalog.gd`.

| Constant | Int | Name | Colour | Viscosity |
|---|---|---|---|---|
| `NONE` | 0 | — | — | — |
| `WATER` | 1 | Water | Blue `#3070C8` | fast spread |
| `LAVA` | 2 | Lava | Orange `#E65514` | medium spread |
| `HONEY` | 3 | Honey | Gold `#DCA519` | slow spread |

Volume range: **0–8** per tile (`MAX_VOLUME = 8`). A tile with volume 8 is visually full.

### Reactions

| Combination | Result |
|---|---|
| Water + Lava (or Lava + Water) | `obsidian` tile placed |

### Bucket Mechanics

- **Empty bucket** (right-click a full liquid tile, volume == 8): scoops liquid → item becomes `water_bucket` / `lava_bucket` / `honey_bucket`
- **Filled bucket** (right-click an empty air tile): pours 8 volume units of the liquid
- Bucket type is determined by `LiquidCatalog.BUCKET_ITEMS`

### CA Simulation

`LiquidSystem.tick(store, world, active_set)` runs at ~10 Hz (Timer in World.gd):
1. Sorts active tiles top-to-bottom (gravity first)
2. Tries to move liquid **down** into empty or lower-volume tile below
3. If cannot move down, tries to **equalise horizontally** with left/right neighbours
4. A tile that didn't move is **dropped from the active set** (sleep optimisation)
5. Returns `{next_active: Dictionary, reactions: Array}` — reactions become `set_tile()` calls in World.gd

---

## 15. Time & Day/Night Cycle

**TimeManager** drives a continuous 24-hour clock. The sky colour is updated every frame in `Main._update_sky_modulate()`:

```
sky_color = TimeManager.sky_color_for_normalized(t) × EventManager.get_event_sky_tint()
```

This result is written to the `DayNightModulate` CanvasModulate node, which tints the entire world layer. The HUD is in a separate `CanvasLayer` and is **not affected**.

### Sky colour schedule (default)

| Hour | Colour | Description |
|---|---|---|
| 00:00 | `#020310` | Deep night |
| 04:00 | `#12183A` | Pre-dawn |
| 05:00 | `#4A2E5A` | Early dawn |
| 06:00 | `#D46020` | Sunrise orange |
| 07:00 | `#E88C35` | Golden hour |
| 08:00 | `#F5C880` | Morning |
| 09:00–15:00 | `#FFFFFF` | Full daylight |
| 17:00 | `#F5C880` | Afternoon |
| 18:00 | `#E07830` | Sunset |
| 19:00 | `#A03820` | Dusk |
| 20:00 | `#28143C` | Twilight |
| 21:00–23:00 | `#020310` | Night |

### Console time commands

```
set_time 6      # jump to sunrise
set_time 0      # jump to midnight
add_time 120    # advance 2 in-game hours
```

---

## 16. Save System

`SaveGameSystem` (`scripts/systems/SaveGameSystem.gd`) is a pure-static class. Save file: `user://saves/slot_1.json`. Schema version: **3**.

### Public API

| Method | Returns | Notes |
|---|---|---|
| `has_save(path?)` | bool | Checks file existence |
| `save_game(main, path?)` | `{ok, error}` | Snapshots full game state and writes JSON |
| `load_game(path?)` | `{ok, error, data?}` | Reads + normalises save; calls `apply_game_state` |
| `snapshot_game_state(main)` | Dictionary | Raw game state dict — does not write to disk |
| `apply_game_state(main, data)` | `{ok, error}` | Restores from a normalised dict |
| `stash_pending_save(root, data)` | void | Stores data in Node meta (used during scene transitions) |
| `consume_pending_save(root)` | Dictionary | Retrieves and clears stashed data |
| `normalize_save_data(data)` | Dictionary | Sanitises / default-fills a raw dict |

### What is saved

| Key | Content |
|---|---|
| `world` | Seed, tile overrides, background overrides, tile damage, generated chunks, liquid state, frozen structures |
| `player` | Position, velocity, facing, health, max_health, equipment_health_delta |
| `inventory` | Hotbar slots + main slots (item_id, count, modifier) |
| `selected_hotbar_index` | Active hotbar slot |
| `containers` | All placed chest block inventories |
| `drops` | Floor item drops (item, count, position, velocity, timers) |
| `beacons` | Placed beacon positions |
| `flares` | Active flares |
| `defeated_bosses` | `{boss_id: true}` for each defeated boss |
| `time` | `{hour, minute, day}` from TimeManager |

---

## 17. Catalog Reference — Tiles

Tile hardness determines drill time. `INF` hardness = unbreakable. Tiles with `solid: false` can be walked through.

### Surface Area

| Tile ID | Name | Hardness | Drops |
|---|---|---|---|
| `surface_grass` | Surface Grass | 0.7 | dirt_clod ×1 |
| `surface_loam` | Surface Loam | 0.95 | dirt_clod ×1 |
| `surface_root_loam` | Rootbound Loam | 1.15 | dirt_clod ×1–2 |
| `surface_stone` | Surface Stone | 1.8 | stone_chunk ×1 |

### Band 1 — Standard Caverns

| Tile ID | Name | Hardness | Drops |
|---|---|---|---|
| `loose_dirt` | Loose Dirt | 0.75 | dirt_clod ×1 |
| `compacted_dirt` | Compacted Dirt | 1.2 | dirt_clod ×1–2 |
| `soft_stone` | Soft Stone | 2.1 | stone_chunk ×1 |
| `copper_ore` | Copper Ore | 2.4 | copper_nugget ×1–2 |
| `goblin_timber_wall` | Goblin Timber Wall | 1.4 | dirt_clod ×1 (45%) |
| `goblin_packed_floor` | Goblin Packed Floor | 1.0 | dirt_clod ×1 (65%) |
| `goblin_mossy_brick` | Goblin Mossy Brick | 2.2 | stone_chunk ×1 |
| `goblin_plank_platform` | Goblin Plank Platform | 1.1 | wooden_background_block ×1 (65%) |

### Band 2 — Colossal Ant Chambers

| Tile ID | Name | Hardness | Drops |
|---|---|---|---|
| `hardened_resin` | Hardened Resin | 3.8 | resin_shard ×1 (90%) |
| `royal_jelly` | Royal Jelly | 1.0 | royal_jelly ×1 |
| `dwarf_granite_brick` | Dwarf Granite Brick | 4.8 | stone_chunk ×1–2 |
| `dwarf_cut_granite_floor` | Dwarf Cut Granite Floor | 4.4 | stone_chunk ×1 |
| `dwarf_ironbound_block` | Dwarf Ironbound Block | 5.4 | stone_chunk ×1 (85%), copper_nugget ×1 (18%) |
| `dwarf_rune_block` | Dwarf Rune Block | 5.0 | stone_chunk ×1 |
| `dwarf_iron_platform` | Dwarf Iron Platform | 4.2 | stone_chunk (65%), copper_nugget (12%) |

### Band 3 — Buried Pyramids

| Tile ID | Name | Hardness | Drops |
|---|---|---|---|
| `sandstone_block` | Buried Sandstone | 4.4 | sandstone_shard ×1–2 |
| `pressure_plate` | Pressure Plate | 1.0 | sandstone_shard ×1 (50%) |
| `cursed_treasure` | Cursed Treasure | 1.8 | cursed_relic ×1 |

### Band 4 — Drow Enclaves

| Tile ID | Name | Hardness | Drops |
|---|---|---|---|
| `glow_mushroom_loam` | Glow Loam | 5.0 | glow_spore ×1–2 (85%) |
| `drow_basalt_brick` | Drow Basalt Brick | 5.8 | stone_chunk ×1–2 |
| `drow_carved_floor` | Drow Carved Floor | 4.9 | stone_chunk ×1 |
| `drow_mushroom_plank` | Drow Mushroom Plank | 2.6 | glow_spore ×1 (45%) |
| `drow_silk_canopy` | Drow Silk Canopy | 1.4 | drow_silk ×1 (90%) |

### Shared / Special

| Tile ID | Name | Hardness | Solid | Notes |
|---|---|---|---|---|
| `air` | Air | ∞ | false | Default empty tile |
| `chest_block` | Chest | 1.5 | true | Opens container UI |
| `obsidian` | Obsidian | 8.5 | true | Created by Water + Lava reaction |

---

## 18. Adding New Content

### Adding an Item

1. Add an entry to `ItemCatalog.ITEMS` in `scripts/catalogs/ItemCatalog.gd`:
   ```gdscript
   "iron_spear": {
       "name": "Iron Spear",
       "desc": "A long iron spear.\n8 damage  |  Melee",
       "rarity": "uncommon",
       "category": "weapon",
   },
   ```
2. Add its sprite to `assets/items/iron_spear.png` (16×16 px)
3. If equippable, add it to `EquipmentCatalog.EQUIPPABLES`
4. If craftable, add a recipe to `CraftingRecipeBook.RECIPES`

### Adding a Crafting Recipe

Open `scripts/catalogs/CraftingRecipeBook.gd` and add an entry to `RECIPES`:
```gdscript
"iron_spear": {
    "result": "iron_spear",
    "result_count": 1,
    "ingredients": [
        {"item": "stone_chunk",  "count": 5},
        {"item": "copper_nugget","count": 10},
    ],
    "stations": ["Workbench", "Furnace"],  # [] = hand-craft
},
```
Station names must match keys in `CraftingSystem.STATION_TILE_MAP`.

### Adding an Enemy

1. Add an entry to `EnemyCatalog.ENEMIES`:
   ```gdscript
   "fire_imp": {
       "name": "Fire Imp", "band": "abyssal_lava_slums",
       "health": 55, "damage": 14, "speed": 52.0,
       "aggro_tiles": 12, "color": Color8(220, 80, 30)
   },
   ```
2. Add sprite to `assets/enemies/fire_imp.png`
3. Add drop entries to `EnemyCatalog.DROPS` if desired

### Adding a World Event

Add an entry to `EventCatalog.EVENTS` in `scripts/catalogs/EventCatalog.gd`:
```gdscript
"solar_flare": {
    "name":             "Solar Flare",
    "message":          "A solar flare scorches the surface!",
    "sky_tint":         Color(1.0, 0.85, 0.30),
    "spawn_overrides":  ["fire_imp", "soldier_ant"],
    "spawn_multiplier": 2,
},
```
Trigger it in-game: `event_start solar_flare`

### Adding a Status Effect

Add an entry to `StatusEffectCatalog.EFFECTS` in `scripts/catalogs/StatusEffectCatalog.gd`:
```gdscript
"burning": {
    "display_name":  "Burning",
    "duration":      8.0,
    "stat_modifiers": {"damage": -1, "speed": -0.05},
    "is_debuff":     true,
},
```
Apply via console: `debuff burning`

### Adding a Modifier

Add an entry to `ModifierCatalog.MODIFIERS` and include it in the relevant pool (`MELEE_POOL` or `ACCESSORY_POOL`):
```gdscript
"serrated": {
    "name": "Serrated", "tier": "uncommon",
    "damage_mult": 1.08, "speed_mult": 1.0, "knockback_mult": 0.9,
    "crit_bonus": 0.02,  "value_mult": 1.2,
},
```

### Adding a Liquid Type

1. Add a constant to `LiquidCatalog` (`const OIL := 4`)
2. Add entries to `LIQUID_COLORS`, `BASE_ALPHA`, `LIQUID_NAMES`, and `BUCKET_ITEMS`
3. Add a reaction rule in `LiquidCatalog.react()` if desired
4. Add the corresponding `oil_bucket` item to `ItemCatalog`

---

## Controls Reference

| Key | Action |
|---|---|
| `WASD` / Arrow keys | Move / fly (fly only in god mode) |
| `Left-click` | Place tile / attack (held = drill) |
| `Right-click` | Place background tile / use bucket |
| `I` or `E` | Open inventory + equipment panel |
| `ESC` | Close open panels → pause menu |
| `~` (tilde) | Open / close developer console |
| `1–5` | Select hotbar slot |
| Scroll wheel | Scroll crafting list / zoom (camera) |

---

*Generated for Deepbound v0.11 — last updated 2026-05-25*
