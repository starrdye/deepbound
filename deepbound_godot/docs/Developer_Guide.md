# Deepbound — Developer Guide

> **Start here.** This guide covers every major system, explains how the pieces connect, and gives you step-by-step recipes for the most common tasks: adding new items, weapons, equipment, NPCs, crafting recipes, and tests.

---

## Table of Contents

1. [Getting Started](#1-getting-started)
2. [Project Tour](#2-project-tour)
3. [Core Patterns](#3-core-patterns)
4. [System Deep Dives](#4-system-deep-dives)
   - 4.1 [Inventory & Hotbar](#41-inventory--hotbar)
   - 4.2 [Equipment & Stat Engine](#42-equipment--stat-engine)
   - 4.3 [Crafting](#43-crafting)
   - 4.4 [NPCs, Dialogue & Vendors](#44-npcs-dialogue--vendors)
   - 4.5 [InteractableComponent](#45-interactablecomponent)
   - 4.6 [HUD Architecture](#46-hud-architecture)
   - 4.7 [World & Lighting](#47-world--lighting)
   - 4.8 [Procedural Generation & Prefabs](#48-procedural-generation--prefabs)
   - 4.9 [Health & Hearts](#49-health--hearts)
   - 4.10 [Mining](#410-mining)
   - 4.11 [Debug Terminal](#411-debug-terminal)
   - 4.12 [Save / Load](#412-save--load)
5. [Adding New Content](#5-adding-new-content)
   - 5.1 [New regular item](#51-new-regular-item)
   - 5.2 [New equippable item](#52-new-equippable-item)
   - 5.3 [New crafting recipe](#53-new-crafting-recipe)
   - 5.4 [New NPC](#54-new-npc)
   - 5.5 [New enemy](#55-new-enemy)
   - 5.6 [New tile / material](#56-new-tile--material)
6. [Testing](#6-testing)
7. [GDScript 4.6 Gotchas](#7-gdscript-46-gotchas)
8. [Signal Flow Reference](#8-signal-flow-reference)
9. [Roadmap](#9-roadmap)

---

## 1. Getting Started

### Prerequisites

- **Godot 4.6** — `Godot.app` (macOS) or equivalent. The exact binary is at `/Applications/Godot.app/Contents/MacOS/Godot`.
- **Python 3.10+** with `Pillow` — only needed if regenerating pixel assets.

### Running the game

Open `deepbound_godot/project.godot` in the Godot editor, or from the terminal:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --path /path/to/deepbound_godot
```

The game boots to `MainMenu.tscn`. Press **Start World** to enter the main game.

### Running tests

From inside `deepbound_godot/`:

```bash
# Run one suite
/Applications/Godot.app/Contents/MacOS/Godot --headless -s tests/smoke_tests.gd

# Run all suites in sequence
for f in tests/*_tests.gd; do
  /Applications/Godot.app/Contents/MacOS/Godot --headless -s "$f"
done
```

Exit code `0` = pass, `1` = fail. Failed assertions also print to stderr via `push_error`.

### Regenerating pixel assets

```bash
cd deepbound_godot
python3 tools/build_pixel_assets.py
```

This reads AI reference boards from `assets/source_ai/` and writes all PNGs into `assets/`. Re-run whenever you add new tile IDs or change palette definitions.

---

## 2. Project Tour

```
deepbound_godot/
├── scripts/
│   ├── catalogs/      # Read-only data tables (ItemCatalog, EquipmentCatalog, TileCatalog …)
│   ├── systems/       # Data objects and stateless helpers (InventorySystem, EquipmentSystem …)
│   ├── components/    # Reusable Node2D composition components (InteractableComponent)
│   ├── controllers/   # Scene-bound Node logic (PlayerController, HudController, NpcController …)
│   └── factories/     # Shared runtime resources (TextureFactory)
├── scenes/            # Thin .tscn node graphs — logic lives in controllers/
├── data/templates/    # Prefab JSON files — add a file here and worldgen picks it up
├── assets/            # PNGs (generated — do not hand-edit)
├── tests/             # Headless *_tests.gd suites
├── docs/              # Documentation (you are here)
└── tools/             # Python asset pipeline
```

### The single composition root

`scripts/Main.gd` is where everything is wired together. It:

- Creates `EquipmentSystem` and connects its `equipment_changed` signal.
- Passes the equipment system to `HudController.set_equipment_system()`.
- Spawns enemies, NPCs, and the test chest on `_ready`.
- Handles cross-system transitions: equip → player stats, NPC interact → dialogue → vendor.

If you need two systems to talk to each other, **the connection belongs in `Main.gd`**, not inside either system.

---

## 3. Core Patterns

### 3.1 Signal-driven UI

`HudController` never holds a direct reference to `PlayerController` or `EquipmentSystem`. It receives data through setter methods (`set_hud_state`, `set_equipment_system`, `open_inventory`) and pushes events outward through signals:

```
HudController signals (outgoing only):
  world_drop_requested(stack)
  hotbar_slot_selected(index)
  dialogue_event(event_name, npc_id)
  craft_hold_started(recipe_id)
  craft_hold_ended
```

`Main.gd` connects these signals once in `_ready` and routes them to the correct system.

### 3.2 Composition over inheritance

Drop-in child nodes add behaviour without requiring a shared base class. The canonical example is `InteractableComponent` — any entity (NPC, chest, door) becomes interactable by adding this node as a child and connecting its `interacted` signal.

```gdscript
# Adding interactability to a new chest-type entity:
var ic := InteractableComponent.new()
ic.interact_radius = 40.0
ic.hint_text = "[T] Open"
add_child(ic)
ic.interacted.connect(_on_opened)
```

### 3.3 Catalogue / data-object pattern

All static game data lives in catalogue files (`scripts/catalogs/`). Catalogs are `RefCounted` classes with `const` dictionaries — they are never instantiated and never written to at runtime.

```gdscript
# Reading from a catalog:
var item_def := ItemCatalog.get_item("copper_ring")
var eq_def   := EquipmentCatalog.get_equippable("copper_ring")
var slot     := EquipmentCatalog.get_slot_for_item("copper_ring") # "accessory"
```

A data-object (`InventorySystem`, `EquipmentSystem`) is a `RefCounted` instance that owns mutable state for one entity. Systems know nothing about the scene tree.

### 3.4 Preload over class_name for external references

In Godot 4.6, `class_name` global registration is not reliable when scripts are loaded via `--headless -s`. Always add an explicit `const` preload at the top of any script that uses an external class:

```gdscript
# At the top of your script — even if class_name already exists:
const EquipmentCatalog = preload("res://scripts/catalogs/EquipmentCatalog.gd")
const EquipmentSystem  = preload("res://scripts/systems/EquipmentSystem.gd")
```

See [Section 7](#7-gdscript-46-gotchas) for the complete list of GDScript 4.6 pitfalls.

---

## 4. System Deep Dives

### 4.1 Inventory & Hotbar

**File:** `scripts/systems/InventorySystem.gd`

`InventorySystem` stores items as plain dictionaries:

```gdscript
# Slot shape:
{"item": "copper_nugget", "count": 12, "stack_cap": 99}
# Empty slot:
{"item": "", "count": 0, "stack_cap": 99}
```

The player has **24 inventory slots** and **6 hotbar slots** (stored separately; hotbar is not a subset of inventory slots).

**Key methods:**

| Method | What it does |
|--------|-------------|
| `add_item(item_id, count)` | Fills hotbar stacks first, then hotbar empties, then inventory. Returns count that didn't fit. |
| `remove_item(item_id, count)` | Removes count from inventory + hotbar. |
| `place_stack(index, stack)` | Drops a stack onto an inventory slot. Returns overflow/swapped stack. |
| `take_slot(index)` | Lifts the stack out of slot `index`. Returns it. |
| `count_item(item_id)` | Total count across all slots + hotbar. |
| `get_hotbar_slot(i)` / `set_hotbar_slot(i, id, count)` | Direct hotbar access. |

**No signals.** `Main.gd` calls `hud.queue_redraw()` after any mutation.

**HUD drag-drop flow (5 steps):**

1. Mouse press on a slot → `_slot_at(point)` returns a hit descriptor `{panel, index}` → `_begin_drag(hit)` (visual only, no data change yet).
2. Release on empty slot → `_take_hit_stack(drag_source)` then `_place_hit_stack(target, stack)`.
3. Release on same-item stack → merge up to `stack_cap`; overflow stays on cursor.
4. Release on different item → swap source and target.
5. Release outside all panels → emit `world_drop_requested`; `Main.gd` spawns a `DroppedItemController`.

The equipment panel participates in the same drag-drop flow using `{panel:"equip", slot_id:String}` hit descriptors instead of `{panel, index}`.

---

### 4.2 Equipment & Stat Engine

**Files:**
- `scripts/catalogs/EquipmentCatalog.gd` — static data
- `scripts/systems/EquipmentSystem.gd` — mutable state
- `scripts/systems/StatCalculator.gd` — stateless aggregation
- `scripts/controllers/HudController.gd` — equipment panel rendering
- `scripts/controllers/PlayerController.gd` — stat application hooks
- `scripts/World.gd` — utility light hook

#### Data — EquipmentCatalog

Each entry defines the slot and a `stats` dict:

```gdscript
"crystal_helm": {
    "slot": "head",
    "stats": {"defense": 4, "health_max": 5}
},
"torch": {
    "slot": "utility",
    "stats": {},
    "light_radius_tiles": 10.0
},
```

**Stat keys:** `damage`, `defense`, `health_max`, `speed` (0.10 = +10%), `drill_cool` (0.10 = −10% heat).

#### State — EquipmentSystem

```gdscript
var eq := EquipmentSystem.new()

eq.equip("wooden_sword")          # → "" (slot was empty)
eq.equip("crystal_sword")         # → "wooden_sword" (displaced)
eq.equip("dirt_clod")             # → "dirt_clod" (rejected: not equippable)

eq.get_item("weapon")             # → "crystal_sword"
eq.unequip("weapon")              # → "crystal_sword", slot now ""
eq.swap("feet", "leather_boots")  # → "" (empty displaced), feet now "leather_boots"
eq.swap("weapon", "leather_boots")# → "leather_boots" (rejected: wrong slot)

eq.find_item_slot("leather_boots")# → "feet"
eq.all_slots()                    # → {"weapon": "", "head": "", ...}
```

`equipment_changed` is emitted on every successful mutation (equip, unequip, swap). It is **not** emitted on rejected equips or unequipping an already-empty slot.

#### Stat aggregation — StatCalculator

```gdscript
var stats := StatCalculator.compute(eq)
# → {"damage": 0, "defense": 5, "health_max": 10, "speed": 0.1, "drill_cool": 0.0}

var radius := StatCalculator.get_utility_light_radius(eq)
# → 10.0 when torch is equipped, 0.0 when empty
```

`compute()` iterates all 7 slots, reads each item's `stats` dict from `EquipmentCatalog`, and sums them. It returns a fresh dict every call — it is stateless.

#### Signal flow on equip

```
User drags item to equipment slot
  → HudController._place_hit_stack(equip_hit, stack)
  → EquipmentSystem.swap(slot_id, item_id)
  → equipment_changed emitted
  → Main._on_equipment_changed()
      → StatCalculator.compute(equipment_system)
      → player.set_equipment_health_delta(int(stats.health_max))
      → player.set_equipment_speed_bonus(float(stats.speed))
      → player.set_equipment_defense_bonus(int(stats.defense))
      → world.set_player_utility_light(radius)
```

Stats propagate once per equip event — no polling.

#### PlayerController hooks

```gdscript
# Speed: multiplied into MAX_SPEED each physics frame
velocity.x = move_toward(velocity.x,
    input_axis * MAX_SPEED * (1.0 + equipment_speed_bonus), accel)

# Defense: subtracted from incoming damage
func damage(amount: int) -> void:
    var mitigated := maxi(0, amount - equipment_defense_bonus)
    # … deduct mitigated from HP
```

---

### 4.3 Crafting

**File:** `scripts/systems/CraftingSystem.gd`

Recipe entries:

```gdscript
{
  "id": "iron_chestplate",
  "result": {"item": "iron_chestplate", "count": 1},
  "ingredients": [{"item": "copper_nugget", "count": 8}],
  "stations": ["workbench", "furnace"]
}
```

**Station detection** is tile-scan based: `CraftingSystem.detect_active_stations(world, player_pos)` scans tiles within a fixed radius for `workbench`, `furnace`, or `anvil` tags. Detection runs on an interval (`STATION_CHECK_INTERVAL = 0.35 s`) to avoid per-frame work.

**Craftable status** is recomputed whenever the active stations change or the inventory changes: `CraftingSystem.get_craftable_statuses(inventory, active_stations)` returns an array of `{id, recipe, craftable: bool}`.

**HUD interaction:**

- Crafting panel appears to the left of the inventory when `I` is open and a station is nearby.
- Press and hold a craftable recipe row to craft.
- `HudController` emits `craft_hold_started(recipe_id)` on press and `craft_hold_ended` on release.
- `Main.gd` starts a `CRAFT_HOLD_DELAY` timer; on expiry it calls `hud.receive_crafted_item(result)` and decrements ingredients from the inventory.

---

### 4.4 NPCs, Dialogue & Vendors

**Files:** `scripts/catalogs/NPCCatalog.gd`, `DialogueCatalog.gd`, `VendorCatalog.gd`,
`scripts/controllers/NpcController.gd`

#### NPC visuals — goblin sprite sheets

`NpcController` renders using goblin enemy sprite sheets (32×32, 8 frames × 4 rows).
Row 0 is the idle animation, which plays at a slower FPS than combat enemies to give a relaxed feel:

```gdscript
# In NpcController:
const NPC_SPRITE_MAP := {
    "wandering_merchant": "goblin_shaman",
    "old_miner":          "goblin_grunt",
    "cave_hermit":        "goblin_slinger",
}
```

The sheet is loaded via `TextureFactory.make_enemy_texture(sprite_id)`. If the PNG is missing, a coloured capsule fallback is drawn. To change an NPC's appearance, update `NPC_SPRITE_MAP`.

NPC origin is at the feet (same convention as `EnemyController`). The name label and interaction hint both derive their Y offsets from `LABEL_Y = -(SPRITE_FRAME_SIZE.y + 8.0)`.

#### Spawning

`Main._spawn_npc(npc_id, world_pos)` creates an `NpcController` node:

```gdscript
var npc: NpcController = NpcController.new()
npc.setup(npc_id)           # builds InteractableComponent + name label
npc.global_position = world_pos
npc.interactable.interacted.connect(_on_npc_interacted.bind(npc_id))
npcs_node.add_child(npc)
```

#### Proximity (per frame in Main)

```gdscript
func _update_npc_proximity() -> void:
    for child in npcs_node.get_children():
        child.interactable.update_proximity(player.global_position)
```

#### Interaction

```gdscript
# Player presses T:
func _try_interact_nearby_npc() -> void:
    var nearest := _find_nearest_npc()
    if nearest:
        nearest.interactable.try_interact(player)
        # InteractableComponent emits interacted → _on_npc_interacted
```

#### Dialogue

`_on_npc_interacted(_, npc_id)` → `hud.open_dialogue(npc_id, node_ids)`.

The typewriter runs in `_process` at ~42 chars/sec. Each `T` press either skips animation, advances to the next node, or fires a `dialogue_event` if the current node has an `event` key.

#### Vendor

`dialogue_event("open_shop", npc_id)` → `hud.close_dialogue()` → `hud.open_vendor(shop_id, player.inventory)`.

`VendorCatalog` provides stock (item ID + price) and `get_sell_price(item_id)`. The HUD handles buy clicks (left-click stock row) and sell clicks (right-click inventory slot while vendor is open). Currency is `copper_nugget`.

---

### 4.5 InteractableComponent

**File:** `scripts/components/InteractableComponent.gd`

```
InteractableComponent (Node2D child)
  @export interact_radius: float = 52.0
  @export hint_text: String = "[T]"
  @export label_offset: Vector2

  signal interacted(interactor: Node)
  signal proximity_changed(is_nearby: bool)

  func update_proximity(player_world_pos: Vector2)  # call every frame
  func try_interact(interactor: Node) → bool         # call on T press
  func is_nearby(world_pos: Vector2) → bool
  func set_hint_visible(v: bool)
```

The component uses a `distance_to()` check (not `Area2D`) because the player uses a custom AABB collision solver. When `CharacterBody2D` is adopted, the component can be upgraded to `Area2D` with `body_entered/exited` — the public interface stays identical.

**To add interactability to any entity:**

```gdscript
func _ready() -> void:
    var ic := InteractableComponent.new()
    ic.interact_radius = 40.0
    ic.hint_text = "[T] Open"
    add_child(ic)
    ic.interacted.connect(_on_interacted)

func _on_interacted(_interactor: Node) -> void:
    # respond here
```

---

### 4.6 HUD Architecture

**File:** `scripts/controllers/HudController.gd`

The HUD is a single `Control` node using **immediate-mode** `_draw()`. Everything is drawn fresh each frame; there are no child `TextureRect` or `Label` nodes for inventory slots (only dialogue and NPC hint labels are actual node children).

**Panel layout (when inventory is open):**

```
[Crafting Panel] [Player Inventory] [Equipment Column] [Container or Vendor Panel]
```

Each panel has a corresponding `_*_panel_rect()` method that returns its `Rect2`. Slot positions are derived from that rect.

**Hit testing:**

```gdscript
# _slot_at(point) returns one of:
{"panel": "player",    "index": 3}
{"panel": "container", "index": 7}
{"panel": "hotbar",    "index": 2}
{"panel": "equip",     "slot_id": "feet"}
# or {} (miss)
```

**To add a new panel**, follow this pattern:
1. Add a `_my_panel_rect() → Rect2` method.
2. Add a `_my_slot_at(point) → Dictionary` hit-test method.
3. Call `_my_slot_at(point)` from the aggregated `_slot_at(point)`.
4. Handle `panel == "my_panel"` in `_get_hit_stack`, `_take_hit_stack`, `_place_hit_stack`.
5. Call `_draw_my_panel()` from `_draw()` when the panel should be visible.

**Important:** `HudController` communicates **outward only via signals**. It never calls methods on `Main`, `PlayerController`, or `EquipmentSystem` directly. Pass data into it via setters; subscribe to its signals for output.

---

### 4.7 World & Lighting

**File:** `scripts/World.gd`

`World` owns:
- `ChunkStore` — memoised tile data per seed
- Tile draw, autotile edge rendering, tile mutation
- Mining damage tracking
- Beacons and flares
- Light source aggregation

**Adding a light source:**

```gdscript
# World.get_light_sources(player_position) aggregates all sources:
# The player ambient, equipped utility item, beacons, flares, structure lanterns.
# To add a persistent world light, push to World._beacons or emit a flare via Main.
```

**Utility light from equipment:**

```gdscript
# In Main._on_equipment_changed():
var radius := StatCalculator.get_utility_light_radius(equipment_system)
world.set_player_utility_light(radius)
# World then includes an extra entry in get_light_sources()
```

---

### 4.8 Procedural Generation & Prefabs

**Files:** `scripts/systems/WorldGenerator.gd`, `StructureGenerator.gd`, `PrefabTemplateRegistry.gd`

Generation is deterministic from `(seed, tile_coord)`. Horizontal extent is unbounded. Vertical layout uses five bands; Solid Dark Blocks clamp at `tileY >= 1920`.

**The key entry points:**

```gdscript
WorldGenerator.generate_tile_id(seed, Vector2i(x, y))       # → tile_id String
WorldGenerator.generate_background_id(seed, Vector2i(x, y)) # → background_id String
WorldGenerator.generate_chunk(seed, chunk_coord)            # → Array of tile_ids
```

**Adding a new template:**

1. Build it in `scenes/PrefabDesigner.tscn`.
2. Save as `data/templates/my_structure.json`.
3. Add the path to `PrefabDesignerController.BUILTIN_TEMPLATE_PATHS`.
4. Set `"enabled": true` and the correct `"bands"` array in the JSON metadata.
5. WorldGenerator picks it up automatically on next boot — no code change needed.

---

### 4.9 Health & Hearts

**File:** `scripts/systems/HeartSystem.gd`

```
DEFAULT_MAX_HP = 10 HP
HP_PER_HEART  =  2 HP
```

`HeartSystem.resolve_max_hp(base_hp, delta)` returns a new max HP that is heart-aligned (multiple of 2) and at least 2 HP (one heart). `PlayerController` calls this when `set_equipment_health_delta` is invoked.

The HUD reads `player.health_current` and `player.health_max` from `hud_state` and renders the correct number of full/half/empty hearts.

---

### 4.10 Mining

**File:** `scripts/systems/MiningSystem.gd`

Mining works as a damage accumulator:

```gdscript
var result := mining.mine_tile(chunk_store, tile_pos, inventory, drill_power, heat)
# result.broke  → bool
# result.stage  → int (0-4, visual break stage)
# result.drops  → Dictionary
```

When `result.broke` is true, the tile becomes `"air"` in `ChunkStore` and drop items are added to the inventory. Tile hardness (`TileCatalog`) and drill power determine how many hits are needed.

---

### 4.11 Debug Terminal

**Files:** `scripts/systems/TerminalSystem.gd`, `scripts/controllers/HudController.gd` (terminal section), `scripts/Main.gd` (`_on_terminal_command`)

#### Architecture

```
Backtick key
  → Main._unhandled_input()
  → hud.toggle_terminal()
  → TerminalSystem.is_open = true
  → LineEdit visible + focused

Player types command + Enter
  → HudController._on_terminal_submitted(text)
  → TerminalSystem.push_output("> " + text)   ← echo
  → terminal_command signal emitted
  → Main._on_terminal_command(cmd)
      → executes command
      → TerminalSystem.push_output("[OK]/[ERR] ...")
      → hud.queue_redraw()   ← updates output panel

Backtick key again
  → hud.toggle_terminal()
  → TerminalSystem.is_open = false
  → LineEdit hidden
```

The terminal **does not close on Enter**. The output panel draws the last 8 history lines above the input strip, colour-coded by prefix.

#### TerminalSystem state

`TerminalSystem` is a static singleton (no instantiation needed):

```gdscript
TerminalSystem.push_output("[OK] Something happened")
TerminalSystem.is_open          # bool
TerminalSystem.history          # Array of strings
TerminalSystem.clear_history()
```

#### Adding a new command

1. Open `scripts/Main.gd`, find `_on_terminal_command()`.
2. Add a new `match` branch:

```gdscript
"mycommand":
    if parts.size() < 2:
        TerminalSystem.push_output("[ERR] Usage: mycommand <arg>")
    else:
        var arg := parts[1]
        # … do the work …
        TerminalSystem.push_output("[OK] Did the thing: %s" % arg)
```

3. Add a help line in the `"help"` branch:

```gdscript
TerminalSystem.push_output("  mycommand <arg> — description of what it does")
```

4. Document it in `docs/Gameplay.md` under the Debug Terminal commands table.

#### Current commands

| Command | Implementation | Effect |
|---------|---------------|--------|
| `god` | `DebugSystem.toggle_god_mode()` | Invincible + fly |
| `heal` | `player.heal(max_health)` | Full HP restore |
| `tp <1\|2\|3>` | `_teleport_to_band(tile_y)` | Jump to band |
| `give <id> [n]` | `player.inventory.add_item(id, n)` | Add items |
| `spawn <enemy_id>` | `_spawn_enemy(id, pos)` | Spawn enemy |
| `npc <npc_id>` | `_spawn_npc(id, pos)` | Spawn friendly NPC |
| `kill` | `queue_free` all enemy children | Remove enemies |
| `clear` | `TerminalSystem.clear_history()` | Clear output |
| `help` | `push_output` each line | Print command list |

### 4.12 Save / Load

**File:** `scripts/systems/SaveGameSystem.gd`

Saves to `user://saves/slot_1.json` at schema version `3`.

**Persisted:** world seed, player position + HP, inventory/hotbar, selected hotbar index, tile/background overrides (modified chunks), damage map, chest contents, world drops, beacons, flares, structure metadata, **defeated bosses dict**.

**Not persisted:** equipment slots, enemy positions.

**Schema history:**

| Version | Added |
|---------|-------|
| 1 | Initial save (seed, player, inventory) |
| 2 | Generated chunk freezing, frozen structures |
| 3 | `defeated_bosses` dictionary |

Older saves are normalised up automatically. v1/v2 files gain an empty `defeated_bosses: {}` on first load.

---

### 4.13 Loot Drop System

**Files:** `scripts/controllers/LootDropController.gd`, `scenes/LootDrop.tscn`, `scripts/catalogs/EnemyCatalog.gd` (`DROPS` + `roll_drops`)

#### Two drop types — which to use

| Type | Node | When to use |
|------|------|------------|
| `DroppedItemController` | `Node2D` | Player throws items, chest spills, inventory drag-to-world |
| `LootDropController` | `Node2D` | Enemy deaths, boss loot, mining rewards |

#### Physics model

The world has no Godot physics bodies, so `LootDropController` uses the same custom `CollisionSystem.move_actor()` as the player and enemies rather than `RigidBody2D`. It adds:

- **Bounce** — when `blocked_y` fires on a downward frame, Y velocity is reflected × `bounce` (default **0.4**). Tiny bounces < 12 px/s are killed to avoid infinite jitter.
- **Wall bounce** — `blocked_x` reflects X × `bounce × 0.5`.
- **Friction** — horizontal deceleration on ground: `friction × 320 px/s²` (default **0.8**).
- **Angular spin** — `_angular_vel` (rad/s) is applied to `angular_rotation` each frame; decays via `SPIN_DRAG = 3.5 rad/s²`. Rotation is visual only (applied to `draw_set_transform`).

Both `bounce` and `friction` are public vars — override them on an instance for specialised drops (e.g. slippery ice tiles: `drop.friction = 0.1`).

#### Pop impulse

`setup()` accepts an optional `pop_impulse: Vector2`. If `Vector2.ZERO` is passed (default), a random pop is generated:

- Horizontal: `±60–130 px/s` (biased away from zero)
- Vertical: `−180–−310 px/s` (always upward)
- Angular: random `±1.2 × 2π rad/s`

#### Pickup delay

A `Timer` node named `PickupDelay` is added as a child of each `LootDrop` in `setup()`:
- `wait_time = 0.5 s`, `one_shot = true`, `autostart = true`
- On timeout: `can_be_picked_up = true`
- `try_collect()` and the magnet both check this flag first.

During the delay, the sprite fades in from 50 % to 100 % alpha so the player can see the item appearing without being able to absorb it instantly.

#### Magnetic attraction

Once `can_be_picked_up` is true, `_update_magnet(delta)` runs each frame:
1. If player is farther than `MAGNET_RADIUS (90 px)` or inventory is full → return false (normal physics continue).
2. Pull speed is interpolated quadratically: `lerp(80, 260, ratio²)` where `ratio = 1 - distance / MAGNET_RADIUS`.
3. Speed is smoothed with `move_toward(..., 300 × delta)` to avoid instant snapping.
4. Collect on `distance ≤ COLLECT_RADIUS (14 px)`.

#### Rarity glow

`_resolve_rarity_color()` looks up the item in `ItemCatalog.get_item(id)` and maps `rarity` to a colour:

```gdscript
"uncommon"  → Color8(80,  210, 100)   # green
"rare"      → Color8(80,  140, 255)   # blue
"epic"      → Color8(180, 80,  255)   # purple
"legendary" → Color8(255, 200, 40)    # gold
"common"    → Color.TRANSPARENT       # no glow
```

The ring pulses in opacity (`sin(time × 1.1 Hz)`) so it catches the eye.

#### Enemy drop tables

`EnemyCatalog.DROPS` maps every enemy id to an `Array` of entries:

```gdscript
{"item": "copper_nugget", "count_min": 1, "count_max": 2, "chance": 0.40}
```

`EnemyCatalog.roll_drops(enemy_id)` iterates the table and rolls each entry independently. Returns an `Array[Dictionary]` of `{ item, count }` for the entries that fired.

#### Wiring into Main.gd

- `EnemyController.died` signal (added alongside existing `take_damage`) carries `(enemy_id, position)`.
- `Main._spawn_enemy()` connects `died` with `CONNECT_ONE_SHOT` to `_on_enemy_died`.
- `_on_enemy_died` calls `roll_drops` and `_spawn_loot_drop` for each result.
- `_spawn_loot_drop(stack, pos, pop_impulse)` instantiates `LootDrop.tscn` and calls `setup()`.
- Boss loot (`_on_boss_loot_dropped`) also goes through `_spawn_loot_drop`.

#### Adding a new enemy drop

1. Open `EnemyCatalog.gd`.
2. Add an entry to `DROPS`:

```gdscript
"new_enemy": [
    {"item": "rare_gem", "count_min": 1, "count_max": 1, "chance": 0.08},
    {"item": "stone_chunk", "count_min": 2, "count_max": 5, "chance": 0.70},
],
```

No other code changes are needed — `roll_drops` picks it up automatically.

---

### 4.14 Boss Encounters

**Files:** `scripts/systems/BossEncounterSystem.gd`, `scripts/boss/`

#### Architecture at a glance

```
Main._spawn_boss("giant_ant_queen", pos)
    └─ creates GiantAntQueen node
       └─ GiantAntQueen._ready()       → builds FSM (Idle/Chase/Attack/Flee nodes)
       └─ GiantAntQueen.setup(p, w)    → BossEncounterSystem.start_encounter(...)
                                         ↳ BossEncounterSystem.encounter_started emitted
                                           ↳ BossUI shows health bar
```

#### BossEncounterSystem (static singleton)

`BossEncounterSystem` is a `RefCounted` subclass with only **static** vars and methods — no Autoload required. Call `BossEncounterSystem.get_instance()` to get the signal-emitting object.

```gdscript
# Any script:
BossEncounterSystem.start_encounter("giant_ant_queen", "Giant Ant Queen", 300)
BossEncounterSystem.report_hp(250, 300)
BossEncounterSystem.end_encounter()
BossEncounterSystem.defeat("giant_ant_queen")
BossEncounterSystem.is_defeated("giant_ant_queen")   # → true
```

**Signals** (on the instance):

| Signal | Args | When |
|--------|------|------|
| `encounter_started` | `boss_id, boss_name, max_hp` | Boss becomes active |
| `boss_hp_changed` | `current, maximum` | Every `take_damage()` call |
| `boss_ended` | — | Boss dies **or** flees |
| `boss_defeated` | `boss_id` | Boss dies only |

#### Node-based FSM

```
BossEntity (CharacterBody2D)
└── StateMachine (BossStateMachine)
    ├── Idle    (BossStateIdle)   ← default
    ├── Chase   (BossStateChase)
    ├── Attack  (BossStateAttack)
    └���─ Flee    (BossStateFlee)   ← despawn path
```

`BossStateMachine.setup(boss, initial_state_name)` injects `boss` and `state_machine` references into every child `BossState`, then enters the initial state. Each `BossState` calls `transition_to("StateName")` to request a state change.

#### Terraria-style dynamic despawn

**There is no static arena or Area2D.** The world is infinite. Instead, `BossStateChase` checks `boss.global_position.distance_to(player.global_position)` each physics frame. If the distance exceeds `boss.max_chase_radius` (default **1500 px**), the FSM transitions to `Flee`. `BossStateFlee` calls `BossEncounterSystem.end_encounter()` immediately, moves the boss away, and calls `queue_free()` after 4 seconds. The boss is **not** marked defeated on a flee.

#### Adding a new boss

1. Create `scripts/boss/MyBoss.gd` that `extends "res://scripts/boss/BossEntity.gd"`.
2. Override `_get_boss_id()` → return a unique snake_case string.
3. Override `_get_boss_name()` → return the display name.
4. In `_ready()`, set stat properties (`max_health`, `attack_damage`, `move_speed` etc.), then call `super._ready()` to build the FSM.
5. Override `_get_collider()` to match your sprite bounding box.
6. Override `_drop_loot()` to emit the `loot_dropped` signal with your reward stacks.
7. Override `_draw()` for sprite/art.
8. Register in `Main._spawn_boss()` match block.

```gdscript
# scripts/boss/MyBoss.gd
extends "res://scripts/boss/BossEntity.gd"

func _get_boss_id()   -> String: return "my_boss"
func _get_boss_name() -> String: return "My Boss"

func _ready() -> void:
    max_health    = 500
    health        = 500
    attack_damage = 20
    move_speed    = 90.0
    super._ready()

func _drop_loot() -> void:
    emit_signal("loot_dropped", global_position, [
        {"item": "crystal_shard", "count": 5},
    ])

signal loot_dropped(pos: Vector2, drops: Array)
```

#### BossUI

`BossUI.gd` is a `CanvasLayer` (layer 30) attached programmatically by `Main._setup_boss_ui()`. It connects to `BossEncounterSystem` signals in `_ready()` and draws the health bar using the `Control._draw()` pattern. No `.tscn` file is required.

---

## 5. Adding New Content

### 5.1 New regular item

1. **Add to `ItemCatalog.gd`:**

```gdscript
"glowing_crystal": {
    "name": "Glowing Crystal",
    "desc": "A crystal that pulses with inner light.\nUsed in advanced gear.",
    "rarity": "rare",
    "category": "material",
},
```

2. **Add an icon** to `assets/items/` (16×16 PNG) — or regenerate via `build_pixel_assets.py` if the icon atlas is generated.

3. **Done.** The item can now appear in inventory, be picked up from drops, and be referenced in crafting recipes.

---

### 5.2 New equippable item

Follow 5.1 first, then:

1. **Set the correct `category`** in `ItemCatalog` to match the slot name (e.g. `"head"`, `"body"`, `"accessory"`).

2. **Add to `EquipmentCatalog.gd`:**

```gdscript
"crystal_boots": {
    "slot": "feet",
    "stats": {"defense": 2, "speed": 0.20},
},
```

The stat keys are: `damage`, `defense`, `health_max`, `speed` (float, 0.10 = +10%), `drill_cool` (float, 0.10 = −10%). Utility items also accept `"light_radius_tiles": float`.

3. **Test it.** Add assertions to `tests/equipment_tests.gd`:

```gdscript
# In _test_equipment_catalog():
var cboots := EquipmentCatalog.get_equippable("crystal_boots")
_assert(String(cboots.get("slot","")) == "feet", "crystal_boots should go in feet")
_assert(absf(float(cboots.get("stats",{}).get("speed",0.0)) - 0.20) < 0.0001,
    "crystal_boots should give 0.20 speed")
```

4. **No code changes needed** in `StatCalculator`, `HudController`, or `PlayerController` — they read stats dynamically from the catalog.

---

### 5.3 New crafting recipe

1. **Open `scripts/systems/CraftingSystem.gd`** and add a new entry to the recipes array:

```gdscript
{
    "id": "crystal_boots",
    "result": {"item": "crystal_boots", "count": 1},
    "ingredients": [
        {"item": "obsidian_chip", "count": 4},
        {"item": "crystal_sword", "count": 0},  # example catalyst
    ],
    "stations": ["anvil"]
},
```

2. **Ensure all ingredient items exist** in `ItemCatalog`.

3. **Ensure the result item exists** in `ItemCatalog` (and `EquipmentCatalog` if it is gear).

4. The crafting panel picks up the new recipe automatically — no HUD changes needed.

---

### 5.4 New NPC

1. **Add to `NPCCatalog.gd`:**

```gdscript
"relic_trader": {
    "name": "Relic Trader",
    "sprite_key": "relic_trader",
    "dialogue": ["relic_0", "relic_1"],
    "shop": "relic_shop",
    "interact_radius": 52.0,
},
```

2. **Add dialogue nodes to `DialogueCatalog.gd`:**

```gdscript
"relic_0": {
    "text": "Cursed relics fetch high prices down here.",
    "speaker": "Relic Trader",
    "event": "",
},
"relic_1": {
    "text": "What do you want?",
    "speaker": "Relic Trader",
    "event": "open_shop",
},
```

3. **(If selling goods) Add a shop to `VendorCatalog.gd`:**

```gdscript
"relic_shop": {
    "title": "Relic Trader",
    "stock": [
        {"item": "cursed_relic", "price": 20},
        {"item": "resin_amulet", "price": 12},
    ],
},
```

4. **Spawn the NPC in `Main.gd`** (inside `_spawn_friendly_npcs()` or wherever appropriate):

```gdscript
_spawn_npc("relic_trader", Vector2(spawn_x * TILE_SIZE, spawn_y * TILE_SIZE))
```

5. **No changes needed** to `NpcController`, `HudController`, or `InteractableComponent` — they read everything from the catalogs dynamically.

---

### 5.5 New enemy

1. **Add to `EnemyCatalog.gd`:**

```gdscript
"drow_soldier": {
    "name": "Drow Soldier",
    "band": "drow_enclaves",
    "health": 60,
    "damage": 14,
    "aggro_radius": 10,
    "sprite_key": "drow_soldier",
},
```

2. **Add a spawn marker** to a prefab template JSON in `data/templates/`:

```json
"spawns": [{"x": 64, "y": 52, "enemy_id": "drow_soldier"}]
```

3. **Add pixel art** to `assets/enemies/` via `build_pixel_assets.py` (see `tools/` section of `Directory_Guide.md`).

4. **Register the sprite sheet** in `TextureFactory` if needed.

---

### 5.6 New tile / material

1. **Add to `TileCatalog.gd`:**

```gdscript
"obsidian_block": {
    "name": "Obsidian Block",
    "hardness": 6.0,
    "breakable": true,
    "solid": true,
    "occlusion": true,
    "color": Color8(30, 10, 40),
    "drops": [{"item": "obsidian_chip", "count": 1, "chance": 1.0}],
    "band": "drow_enclaves",
},
```

2. **Add an icon** in `assets/tiles/` (5 PNGs: base + 4 break stages).

3. **Optionally add a drop item** to `ItemCatalog.gd` (see 5.1).

4. **Use the tile** in prefab templates or `WorldGenerator` generation rules.

---

## 6. Testing

### Test file structure

All test files `extend SceneTree` and use the same scaffold:

```gdscript
extends SceneTree

const MySystem = preload("res://scripts/systems/MySystem.gd")

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)

func _run() -> void:
    _test_something()
    await _test_something_with_nodes()
    if failures.is_empty():
        print("My tests passed.")
        quit(0)
    else:
        print("My tests failed: %d" % failures.size())
        quit(1)

func _test_something() -> void:
    var obj := MySystem.new()
    _assert(obj.some_method() == "expected", "some_method should return expected")
```

### Tests that need a scene tree

Use `await process_frame` after `add_child` to allow `_ready` to run:

```gdscript
func _test_something_with_nodes() -> void:
    var hud := HudController.new()
    get_root().add_child(hud)
    await process_frame
    hud.open_inventory(player_inventory)
    _assert(bool(hud.inventory_open), "inventory should be open after open_inventory()")
    hud.free()
```

### Signal assertions without lambdas

GDScript 4.6 lambda closures do **not** share primitive variables by reference. Use an `Array` container as a reference-type counter:

```gdscript
# WRONG — signal_count stays 0 in the outer scope:
var signal_count := 0
my_signal.connect(func(): signal_count += 1)

# CORRECT — arrays are reference types, lambda mutation is visible:
var signal_count := [0]
my_signal.connect(func(): signal_count[0] += 1)
_assert(signal_count[0] == 1, "signal should fire once")
```

### What to test

- **Catalogs:** verify stat values, slot assignments, and edge cases (empty string, non-existent ID).
- **Systems:** test every mutation method — happy path, rejection, signal side-effects.
- **HUD panels:** test panel geometry (`_*_panel_rect` returns non-zero when open), hit-test (`_*_slot_at` returns correct descriptor), and drag-drop round-trips.
- **Integration:** use `Main` + `HudController` together to test full flows (open inventory → drag item → equip → check stat).

### Running all tests

```bash
for f in tests/*_tests.gd; do
  /Applications/Godot.app/Contents/MacOS/Godot --headless -s "$f" && echo "PASS $f" || echo "FAIL $f"
done
```

---

## 7. GDScript 4.6 Gotchas

### 7.1 class_name not resolved in headless mode

When running `--headless -s mytest.gd`, scripts are loaded on demand and the global class registry may not be populated. Always add explicit `const` preloads to any script that references an external class:

```gdscript
# In EquipmentSystem.gd:
const EquipmentCatalog = preload("res://scripts/catalogs/EquipmentCatalog.gd")

# In StatCalculator.gd:
const EquipmentSystem  = preload("res://scripts/systems/EquipmentSystem.gd")
const EquipmentCatalog = preload("res://scripts/catalogs/EquipmentCatalog.gd")
```

The `const` shadows the global class name within the file. This is intentional and safe.

### 7.2 Static methods with typed external-class parameters

Static methods whose parameter types reference an external `class_name` cause `"Could not resolve external class member"` at the call site:

```gdscript
# BROKEN — parameter type triggers resolution failure:
static func compute(equipment_system: EquipmentSystem) -> Dictionary:

# FIXED — untyped parameter; add a preload at the top instead:
static func compute(equipment_system) -> Dictionary:
```

### 7.3 := inference on Variant return values

When calling a method on a Variant-typed variable, the return type is also `Variant`. Using `:=` for type inference fails because GDScript cannot infer the type:

```gdscript
var equipment_system = null    # Variant — no declared type

# BROKEN:
var item_id := equipment_system.get_item("weapon")   # Can't infer String

# FIXED — explicit type annotation:
var item_id: String = equipment_system.get_item("weapon")
```

### 7.4 get_parent() returns Node, not Node2D

`get_parent()` has return type `Node`. If you need `global_position` (a `CanvasItem`/`Node2D` property), cast explicitly:

```gdscript
# BROKEN — Node has no global_position:
var origin := get_parent().global_position

# FIXED:
var par := get_parent()
var origin: Vector2 = (par as Node2D).global_position if par is Node2D else global_position
```

### 7.5 Lambda closures capture primitives by value

```gdscript
# Counter stays 0 in outer scope:
var count := 0
some_signal.connect(func(): count += 1)

# Use an Array reference instead:
var count := [0]
some_signal.connect(func(): count[0] += 1)
```

### 7.6 Premature closing brace in const dicts

A `}` inside a `const ITEMS := { ... }` dict closes it early. All entries after the stray brace become invalid class-body-level syntax and cause cascade parse errors across every script that preloads the file. Always count braces carefully when editing catalog files.

---

## 8. Signal Flow Reference

```
┌─────────────────────────────────────────────────────────────────┐
│  INPUT LAYER                                                     │
│  PlayerController._unhandled_input                               │
│  HudController._gui_input                                        │
└──────────────────────────┬──────────────────────────────────────┘
                           │ signals / method calls
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  COMPOSITION ROOT — Main.gd                                      │
│                                                                  │
│  equipment_system.equipment_changed ──► _on_equipment_changed    │
│    → StatCalculator.compute()                                    │
│    → player.set_equipment_*                                      │
│    → world.set_player_utility_light                              │
│                                                                  │
│  hud.world_drop_requested ──────────► _spawn_world_drop          │
│  hud.hotbar_slot_selected ──────────► _select_hotbar_index       │
│  hud.dialogue_event ───────────────► _on_dialogue_event          │
│  hud.craft_hold_started ───────────► _begin_craft                │
│                                                                  │
│  npc.interactable.interacted ───────► _on_npc_interacted         │
│    → hud.open_dialogue                                           │
│                                                                  │
│  boss.setup(player, world)                                       │
│    → BossEncounterSystem.start_encounter(id, name, hp)           │
│    → BossEncounterSystem.encounter_started signal                │
│    → BossUI shows health bar                                     │
│  boss.take_damage(n)                                             │
│    → BossEncounterSystem.report_hp(current, max)                 │
│    → BossUI updates fill                                         │
│  boss._on_death()                                                │
│    → BossEncounterSystem.end_encounter()  → BossUI hides         │
│    → BossEncounterSystem.defeat(id)       → defeated_bosses set  │
│    → SaveGameSystem persists defeated_bosses in schema v3        │
└─────────────────────────────────────────────────────────────────┘
                           │
              ┌────────────┼─────────────┐
              ▼            ▼             ▼
         HudController  PlayerController  World
         (renders UI)   (physics/stats)  (tiles/light)
```

### Equipment stat path (condensed)

```
equip item
  → EquipmentSystem.swap()
  → equipment_changed signal
  → Main._on_equipment_changed()
  → StatCalculator.compute()  →  player stat setters
                              →  world.set_player_utility_light()
```

### NPC interaction path (condensed)

```
Player presses T
  → Main._try_interact_nearby_npc()
  → InteractableComponent.try_interact(player)
  → interacted signal
  → Main._on_npc_interacted(_, npc_id)
  → hud.open_dialogue(npc_id, node_ids)
  [T presses advance dialogue]
  → hud.dialogue_event("open_shop", npc_id)
  → Main._on_dialogue_event()
  → hud.open_vendor(shop_id, inventory)
```

---

## 9. Roadmap

| # | Task | Status | Priority |
|---|------|--------|---------|
| — | Boss Encounters framework (BossEncounterSystem, FSM, BossEntity, GiantAntQueen, BossUI) | ✅ Done | — |
| 13.1 | Migrate catalog data to Godot `Resource` `.tres` files | Planned | High |
| 13.2 | Upgrade `InteractableComponent` to `Area2D` (after CharacterBody2D migration) | Planned | Medium |
| 13.3 | Add `EventBus` autoload for cross-system signals (player death, quests) | Planned | Medium |
| 13.4 | Refactor HUD to scene-based `SlotUI.tscn` panels | Planned | Low |
| — | Additional boss encounters (Band 3 Pyramid Pharaoh, Band 4 Drow Spider Queen) | Planned | Medium |
| — | Boss summon triggers in-world (approach zone, item use) | Planned | Medium |
| — | Persist equipment slots to save (schema v4) | Planned | High |
| 13.5 | Persist `EquipmentSystem` in save file (schema v3) | High |
| — | Equipment save/load: `EquipmentSystem.serialize()` + `deserialize()` + bump schema to v3 | High |

The most impactful next step is **13.5 equipment save/load** — currently equipping items is lost between sessions. Implementation requires:

1. Add `serialize() → Dictionary` and `deserialize(data: Dictionary)` to `EquipmentSystem`.
2. Include `"equipment"` in `SaveGameSystem`'s save schema.
3. Bump schema version constant from `2` to `3`.
4. Add migration logic in `SaveGameSystem` for schema `2 → 3` (empty equipment dict for old saves).
5. Add assertions to `tests/save_game_tests.gd`.
