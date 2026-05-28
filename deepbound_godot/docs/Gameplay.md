# Deepbound Godot — Gameplay Guide

> v0.11 · Last updated 2026-05-28

This guide covers everything a player (or tester) needs to know about the current build. For system internals see `Architecture.md`; for adding content see `DEVELOPER_GUIDE.md`.

---

## Core Loop

1. Move through procedurally generated tile chunks.
2. Drill adjacent blocks — they crack, break, and drop materials.
3. Collect resources into your 24-slot inventory + 6-slot hotbar.
4. Craft gear at a Workbench / Furnace / Anvil (or use **god mode** for free crafting).
5. Equip weapons, armour, and accessories to boost your stats.
6. Manage liquids — scoop water or honey with a bucket, pour lava to create obsidian.
7. Watch the sky cycle from dawn to dusk — events like a Blood Moon change the world.
8. Descend through band settlements, fight enemies, defeat bosses.

---

## Controls

| Action | Input |
|--------|-------|
| Move | `A / D` or left / right arrows |
| Jump | `W`, up arrow, or space |
| Drill (hold) | Hold left mouse or `F` |
| Use / place hotbar item | Right mouse |
| Strike (melee) | `E` |
| Interact with NPC | `T` |
| Inventory + Equipment + Crafting | `I` |
| Close open panel / pause menu | `Escape` |
| Hotbar select | `1–6` or mouse wheel |
| Flare | `Q` |
| Beacon | `R` |
| Developer console | `` ` `` (tilde) — toggle |

**ESC priority chain:** closes Dialogue → Vendor → Container → Inventory → Pause menu.

---

## Main Menu & Saves

Boot scene is `MainMenu.tscn`. Options: **Start World**, **Continue** (single save slot), Prefab Designer, Quit.

The Escape pause menu in-world has: Resume, Save, Load, Template Editor, Main Menu, Quit.

Save file: `user://saves/slot_1.json` — schema **v3**. Saves include:
- Seed, tile overrides, tile damage, generated chunks, liquid state
- Player position, velocity, health
- Inventory, hotbar, selected slot
- Equipment slots and modifiers
- All container (chest) inventories
- Floor drops, beacons, flares
- Defeated boss flags
- **Current time of day** (hour / minute / day)

---

## Health and Hearts

| Value | Default |
|-------|---------|
| Max HP | 10 |
| HP per heart | 2 |
| Default display | 5 full hearts |

Equipment raises max HP via the `health_max` stat delta. Death resets the session.

---

## Mining and Drops

Left-click / hold `F` to drill the nearest tile in your facing direction. Each tile has a `hardness` value; repeated hits reduce it to zero and break it.

Break animations are material-specific (5 crack stages per tile).

When a tile breaks its loot tries to enter your inventory; overflow lands as floor drops.

---

## Day / Night Cycle

Time advances automatically at **0.5 real seconds per in-game minute** (1 real second = 2 in-game minutes). The sky colour transitions smoothly through 24 colour keyframes.

| Hour range | Appearance |
|---|---|
| 00:00 – 04:00 | Deep night (near-black) |
| 05:00 – 06:00 | Pre-dawn purple / sunrise orange |
| 07:00 – 08:00 | Golden hour → morning |
| 09:00 – 15:00 | Full daylight |
| 17:00 – 18:00 | Afternoon → sunset orange |
| 19:00 – 20:00 | Dusk red → twilight |
| 21:00 – 23:00 | Night |

The HUD is unaffected by sky tint (it lives in a separate CanvasLayer).

Console shortcuts: `set_time 6` (sunrise), `set_time 0` (midnight), `add_time 120` (+2 hours).

---

## World Events

Events are triggered through the developer console. They never fire automatically.

| Event ID | Name | Sky tint | Enemy change |
|---|---|---|---|
| `blood_moon` | Blood Moon | Deep red | Cave skitters, Soldier ants, Mummy sentries ×2 |
| `goblin_raid` | Goblin Raid | Yellow | Cave skitters, Worker ants ×3 |
| `meteor_shower` | Meteor Shower | Lavender | No change — visual only |

When an event starts:
- Sky colour is multiplied by the event tint on top of the normal day/night colour.
- A 4-second banner alert appears at the top of the screen.
- `_spawn_band_encounter` substitutes event enemies for the current band enemies.

```
event_start blood_moon
event_stop
```

---

## Liquids & Buckets

Three liquid types exist in the world: **Water**, **Lava**, and **Honey**. Each simulates as a cellular automaton — liquids fall under gravity and equalise horizontally at 10 Hz.

| Liquid | Colour | Behaviour |
|---|---|---|
| Water | Blue | Flows fast, spreads widely |
| Lava | Orange | Medium flow speed |
| Honey | Gold | Slow, viscous spread |

**Reaction:** Water + Lava = `obsidian` tile placed at the contact point.

### Bucket Mechanics

| Action | How |
|---|---|
| Scoop a liquid tile (volume = 8) | Right-click with `empty_bucket` equipped |
| Pour liquid | Right-click an empty air tile with a filled bucket |

Bucket items: `empty_bucket`, `water_bucket`, `lava_bucket`, `honey_bucket`.

The test chest near spawn contains 1× `empty_bucket` and 5× `water_bucket`.

---

## Loot Drops (Enemy Kills / Boss Rewards)

| Phase | What happens |
|-------|-------------|
| 0 – 0.5 s | Semi-transparent, cannot be picked up. Falls and bounces. |
| After 0.5 s | Collectible. Click, or enter the 90 px magnet radius. |
| Magnet | Flies toward the player, accelerating as it closes. |
| Collect | Auto-absorbed within 14 px or on left-click. |

Rarity glow: Common = none · Uncommon = green · Rare = blue · Epic = purple · Legendary = gold.

### Enemy Drop Tables

| Enemy | Drops |
|-------|-------|
| Cave Skitter | Dirt Clod (60%), Copper Nugget (25%) |
| Goblin Grunt | Stone Chunk (65%), Copper Nugget (40%) |
| Goblin Shaman | Copper Nugget (70%), Resin Shard (20%) |
| Soldier Ant | Copper Nugget (65%), Resin Shard (35%) |
| Mummy Sentry | Sandstone Shard (70%), Copper (55%), Cursed Relic (5%) |
| Giant Ant Queen (boss) | 12× Copper, 8× Stone, 4× Resin |

---

## Crafting

### Opening the Crafting Panel

Press **`I`** to open the inventory. The crafting panel appears to the **left** of the inventory grid automatically. It shows up to **10 recipes at once**; scroll the mouse wheel over the panel to see more. **▲** and **▼** arrows appear when there are hidden recipes above or below.

### Station Requirements

Stand within **6 tiles** of a station to unlock its recipes.

| Station | Unlocks |
|---|---|
| *(none)* | Hand-craft recipes (walls, workbench) |
| Workbench | Basic tools and placeables |
| Workbench + Furnace | Metal gear tier |
| Workbench + Anvil | Crystal gear tier |
| Workbench + Furnace + Anvil | Cursed / endgame tier |

### Current Recipes

#### Hand-craft

| Result | Ingredients |
|---|---|
| Workbench | 8× stone_chunk + 12× dirt_clod |
| Dirt Wall ×2 | 1× dirt_clod |
| Stone Wall ×2 | 1× stone_chunk |
| Wooden Wall ×2 | 2× dirt_clod |

#### Workbench

| Result | Ingredients |
|---|---|
| Wooden Sword | 5× stone_chunk |
| Hammer | 8× stone_chunk |
| Chest | 4× stone_chunk + 4× dirt_clod |
| Furnace | 20× stone_chunk + 5× copper_nugget |

#### Workbench + Furnace

| Result | Ingredients |
|---|---|
| Anvil | 10× stone_chunk + 20× copper_nugget |

#### Workbench + Anvil

| Result | Ingredients |
|---|---|
| Crystal Sword | 10× resin_shard + 15× copper_nugget |
| Crystal Drill | 8× resin_shard + 20× copper_nugget |

#### Workbench + Furnace + Anvil

| Result | Ingredients |
|---|---|
| Cursed Sword | 5× obsidian_chip + 1× cursed_relic + 3× drow_silk |
| Cursed Drill | 8× obsidian_chip + 2× cursed_relic + 15× copper_nugget |

### God Mode Crafting

Enable god mode (`god` in console): **all recipes are free** — no station proximity required and no materials consumed. The crafting panel footer shows a gold **★ God Mode (N)** label on an orange background, and all recipes render at full brightness.

---

## Equipment

Press `I` to open inventory. The equipment panel appears as a 7-slot column to the **right** of the inventory grid. Drag an item onto its slot to equip it; drag from a slot back to inventory to unequip. Stats update immediately.

### Slots & Stats

| Slot | Stat |
|------|------|
| Weapon | `damage` — added to melee strike |
| Head | `defense`, `health_max` |
| Body | `defense` |
| Legs | `defense` |
| Feet | `defense`, `speed` |
| Accessory | `defense`, `health_max`, `drill_cool` |
| Utility | `light_radius_tiles` |

### Equippable Items

| Item | Slot | Stats |
|------|------|-------|
| Wooden Sword | weapon | damage +3 |
| Crystal Sword | weapon | damage +6 |
| Cursed Sword | weapon | damage +10 |
| Iron Helm | head | defense +2 |
| Crystal Helm | head | defense +4, max HP +5 |
| Leather Vest | body | defense +1 |
| Iron Chestplate | body | defense +4 |
| Leather Pants | legs | defense +1 |
| Iron Greaves | legs | defense +2 |
| Leather Boots | feet | defense +1, speed +10% |
| Copper Ring | accessory | max HP +5 |
| Resin Amulet | accessory | defense +1, drill heat −10% |
| Torch | utility | 10-tile light radius |
| Lantern | utility | 17-tile light radius |

---

## Item Modifiers (Prefixes)

Weapons and accessories can carry a Terraria-style modifier prefix. Applied on craft (30% chance) or via the `modifier` console command.

Full modifier list: `legendary godly demonic keen sharp heavy swift lucky menacing violent warding quick broken blunt`

| Modifier | Tier | Key effect |
|---|---|---|
| Legendary / Godly | legendary | +15% damage, +crit |
| Demonic | rare | +15% damage, +10% crit |
| Sharp | uncommon | +10% damage |
| Swift / Quick | uncommon | +8–15% attack speed |
| Warding | uncommon | +2 defense |
| Broken / Blunt | broken | −25% damage / knockback |

---

## Status Effects

| Effect | Type | Duration | Stat change |
|---|---|---|---|
| Swiftness | buff | 30 s | speed +15% |
| Endurance | buff | 25 s | defense +3 |
| Fervor | buff | 20 s | damage +3 |
| Fortitude | buff | 30 s | max HP +20 |
| Vigor | buff | 20 s | damage +2, speed +10% |
| Slow | debuff | 10 s | speed −20% |
| Vulnerable | debuff | 10 s | defense −2 |
| Weakness | debuff | 10 s | damage −2 |
| Curse | debuff | **permanent** | damage −2, speed −10% |
| Frail | debuff | 12 s | defense −3, max HP −10 |

Use `clearfx` to remove all active effects.

---

## Developer Console

Open / close with **`` ` ``** (tilde). Type a command and press **Enter**. The terminal stays open between commands.

Output colour: `[OK]` green · `[ERR]` red · echoed command blue-white.

| Command | Effect |
|---|---|
| `god` | Toggle god mode (invincible + fly + free crafting) |
| `heal` | Restore full HP |
| `tp <1\|2\|3>` | Teleport to Band 1 / 2 / 3 |
| `give <id> [count] [modifier]` | Give items (`give crystal_sword 1 legendary`) |
| `modifier <mod> [slot]` | Apply modifier to equipped item |
| `buff <effect_id>` | Apply buff |
| `debuff <effect_id>` | Apply debuff |
| `clearfx` | Remove all status effects |
| `kill` | Despawn all enemies and bosses |
| `respawn monster <id>` | Spawn enemy near player |
| `respawn npc <id>` | Spawn friendly NPC near player |
| `respawn boss <id\|1>` | Reset + spawn boss |
| `event_start <id>` | Start world event |
| `event_stop` | End current event |
| `set_time <0-23>` | Jump to in-game hour |
| `add_time <minutes>` | Fast-forward time |
| `clear` | Clear console output |
| `help` | Print command list |

---

## NPCs and Dialogue

Three NPCs spawn near player start: Wandering Merchant, Old Miner, Cave Hermit (all use goblin sprite sheets). Walk close → `[T] Talk` hint appears. Press `T` to open dialogue.

**Vendor panel:** left-click to buy, right-click an inventory item to sell. Currency: copper nuggets.

Additional NPCs: `respawn npc <npc_id>`

---

## Inventory

- Player slots: **24**
- Hotbar: **6** (separate from main slots)
- Default stack cap: **99**

Stack rules: empty slot = move · matching = merge (overflow back to source) · different item = swap · outside panels = world drop.

---

## Hotbar

- Selection: `1–6` or mouse wheel
- Active slot: copper bracket highlight + bottom-left name label
- Right-click places held placeable on nearest valid tile (reach: 5.25 tiles)
- Placement preview: green = valid, red = rejected

---

## Chests and Containers

- Open distance: **46 px** (right-click chest tile)
- Inventory size: **18 slots**
- Test chest contents: 6× copper_nugget, 12× stone_chunk, 1× empty_bucket, 5× water_bucket
- Chest auto-closes when the player walks away
- Breaking a chest drops 1× chest item and spills its inventory as floor drops

---

## Boss Encounters

| Boss | Band | HP | Dmg | Unlock drop |
|---|---|---|---|---|
| Rootbound Foreman | 1 | 420 | 18 | copper_brace |
| Amber Queen | 2 | 760 | 26 | royal_jelly |
| Pharaoh of the Buried Sun | 3 | 920 | 32 | cursed_relic |
| Drow Matriarch | 4 | 1100 | 38 | drow_silk |
| Obsidian Baron | 5 | 1360 | 44 | heat_core |

A top-centre HP bar appears during fights (red >50%, orange 25–50%, bright-red <25%). Boss flees if player is > 1500 px away (not counted as defeated). Defeated bosses are saved.

Console: `respawn boss rootbound_foreman` or `respawn boss 1`

---

## HUD Overview

| Element | Notes |
|---|---|
| Hearts | Top-left — full / half / empty heart icons |
| Drill heat | Bar below hearts; overheating locks the drill briefly |
| Depth label | Band name + metres |
| Target tile | Name of tile under cursor |
| Local light % | Ambient light at player position |
| Danger pulse | Red screen overlay when enemies are near |
| Hotbar | Bottom-centre, always visible |
| God Mode indicator | Gold top-right label (when active) |
| Boss HP bar | Top-centre (during boss fight) |
| Event alert banner | Upper screen for 4 s on event start |

---

## Settlements and Templates

Structures are stamped into chunks from `data/templates/*.json`.

| Template | Band | Type |
|---|---|---|
| `goblin_village_full` | Band 1 | Goblin outpost |
| `dwarf_fortress_full` | Band 2 | Dwarf military fortress |
| `dwarf_settlement_full` | Band 2 | Dwarf civilian settlement |
| `drow_village_full` | Band 4 | Drow enclave |

Edit templates live in `scenes/PrefabDesigner.tscn` — changes apply to unvisited chunks immediately.
