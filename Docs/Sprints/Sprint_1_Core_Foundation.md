# Deepbound Sprint 1: Core Foundation

Source references:
- `Docs/Deepbound_Game_Design.md`
- `Docs/Deepbound_Art_Bible.md`

Sprint focus: the Delver's base movement, gravity, and the fundamental block-breaking/drilling loop. The prototype must sell Deepbound's identity early: downward-first traversal, total destructibility, drill-led excavation, and readable high-contrast pixel art.

## Agent Stand-Up

**Agent 1: The Game Designer.** I define the rules, formulas, component data, and the moment-to-moment loop.

**Agent 2: The Pixel Art Designer.** I translate the Art Bible into readable sprites, tiles, palettes, and animation sheet layouts.

**Agent 3: The Programmer and Code Reviewer.** I convert the rules into TypeScript-ready systems and call out performance risks before they become architecture debt.

**Agent 4: The Player Persona.** I judge whether the prototype feels satisfying, readable, and worth continuing.

## Agent 1: Game Designer

### Sprint 1 Player Promise

Within the first playable prototype, the player should be able to run, jump, fall, aim a starter drill, destroy dirt and stone blocks, receive resources, and immediately understand that the game is about digging downward into a hostile living world.

### Core Units

- Tile size: `16x16 px`
- Player sprite: `24x32 px`
- Player collision box: `14x28 px`, bottom-center anchored
- Physics timestep: fixed `1/60 s`
- World coordinates: pixel positions for entities, integer tile coordinates for terrain
- Prototype chunk size: `32x32 tiles`, using signed chunk coordinates for future infinite generation

### Movement Tuning

The Delver should feel heavier than a pure platform hero but more agile than a miner simulation character.

```ts
const MovementTuning = {
  groundAcceleration: 1800, // px/s^2
  airAcceleration: 1150,    // px/s^2
  maxRunSpeed: 94,          // px/s, about 5.9 tiles/s
  groundFriction: 2200,     // px/s^2
  gravity: 1900,            // px/s^2
  terminalVelocity: 520,    // px/s
  jumpVelocity: -410,       // px/s
  shortHopGravityMultiplier: 1.65,
  coyoteTime: 0.10,         // seconds
  jumpBufferTime: 0.10,     // seconds
  maxStepAssist: 2          // px, tiny ledge tolerance for rough terrain
};
```

Movement rules:
- Horizontal acceleration depends on grounded versus airborne state.
- Ground friction applies only when no horizontal input is held.
- Jump input uses both coyote time and jump buffering.
- Releasing jump while rising applies the short-hop multiplier.
- Collision resolves one axis at a time with a small skin width.
- Head bumps zero upward velocity.
- Landing from high speed triggers a 2-frame dust puff and slight sprite squash, not physics squash.

### Drilling Loop

Deepbound should prefer drilling over swinging. Sprint 1 uses a starter pneumatic drill with precise targeting and tactile feedback.

Player loop:
1. Move through a small cave testbed.
2. Aim the drill using mouse, right stick, or directional input.
3. Hold drill input to damage one foreground block.
4. See crack stages and particles while hearing drill pitch respond to material.
5. Block breaks into drops.
6. Drops magnetize into the player and update inventory.
7. Nearby blocks visually reconnect later through the Sprint 2 autotile system.

Starter drill targeting:
- Aim directions: 8-way normalized vector.
- Reach: `1.35 tiles` from the player center.
- Target selection: short raycast through solid foreground tiles.
- Target priority: first breakable solid tile intersected by ray.
- Downward drilling while grounded requires explicit down aim to reduce accidental falls.
- The drill cannot damage an occupied tile that overlaps the player's current collision box.

Starter drill formula:

```txt
drillDps = tool.power * material.drillEfficiency * heatFactor * aimStability
breakProgress += drillDps * dt
blockBreaksWhen breakProgress >= tile.hardness
```

Prototype values:

```ts
const StarterDrill = {
  power: 1.0,
  reachTiles: 1.35,
  heatPerSecond: 0.18,
  coolPerSecond: 0.34,
  overheatAt: 1.0,
  overheatLockout: 0.75
};

const MaterialDrillEfficiency = {
  dirt: 1.35,
  compactedDirt: 1.0,
  stone: 0.9
};
```

Tile hardness targets:

| Tile | Hardness | Starter Break Time | Intended Feeling |
| --- | ---: | ---: | --- |
| Loose Dirt | `0.75` | `0.56 s` | Fast, crumbly, satisfying |
| Compacted Dirt | `1.20` | `1.20 s` | Noticeable resistance |
| Soft Stone | `2.10` | `2.33 s` | Early obstacle, not a wall |

Drill heat is included in Sprint 1 only to prevent holding the drill forever without thought. It should be generous. Heat must never interrupt the first few seconds of casual dirt mining.

### Data Components

```ts
type Facing = "left" | "right";

interface TransformComponent {
  positionPx: Vec2;
  previousPositionPx: Vec2;
  velocityPx: Vec2;
  facing: Facing;
}

interface MotorComponent {
  grounded: boolean;
  coyoteTimer: number;
  jumpBufferTimer: number;
  wasGroundedLastFrame: boolean;
}

interface ColliderComponent {
  widthPx: number;
  heightPx: number;
  offsetPx: Vec2;
}

interface DrillComponent {
  toolId: "starter_drill";
  heat: number;
  overheatedUntil: number;
  activeTarget?: TileCoord;
  aimVector: Vec2;
}

interface InventoryComponent {
  slots: InventorySlot[];
  maxSlots: number;
}

interface TileDefinition {
  tileId: string;
  material: "dirt" | "compactedDirt" | "stone" | "air";
  hardness: number;
  breakable: boolean;
  solid: boolean;
  blocksLight: boolean;
  drillEfficiency: number;
  drops: DropTableEntry[];
}

interface BlockDamageState {
  coord: TileCoord;
  progress: number;
  lastHitTime: number;
  crackStage: 0 | 1 | 2 | 3;
}
```

### Tile Definitions

```ts
const TileDefs: Record<string, TileDefinition> = {
  air: {
    tileId: "air",
    material: "air",
    hardness: Infinity,
    breakable: false,
    solid: false,
    blocksLight: false,
    drillEfficiency: 0,
    drops: []
  },
  loose_dirt: {
    tileId: "loose_dirt",
    material: "dirt",
    hardness: 0.75,
    breakable: true,
    solid: true,
    blocksLight: true,
    drillEfficiency: 1.35,
    drops: [{ itemId: "dirt_clod", min: 1, max: 1 }]
  },
  compacted_dirt: {
    tileId: "compacted_dirt",
    material: "compactedDirt",
    hardness: 1.2,
    breakable: true,
    solid: true,
    blocksLight: true,
    drillEfficiency: 1.0,
    drops: [{ itemId: "dirt_clod", min: 1, max: 2 }]
  },
  soft_stone: {
    tileId: "soft_stone",
    material: "stone",
    hardness: 2.1,
    breakable: true,
    solid: true,
    blocksLight: true,
    drillEfficiency: 0.9,
    drops: [{ itemId: "stone_chunk", min: 1, max: 1 }]
  }
};
```

### Inventory Rules

- Starter backpack: `24 slots`
- Default stack cap: `99`
- Tile drops spawn as small physical pickups with a `0.15 s` delay before magnetizing.
- Pickup magnet radius: `0.75 tiles`
- Pickup collection radius: `0.25 tiles`
- If inventory is full, remaining drops stay in the world.
- Inventory updates emit a delta event for the HUD and sound system.

```ts
interface InventoryDelta {
  itemId: string;
  previousCount: number;
  newCount: number;
  added: number;
}
```

### Required Feedback

- Targeted tile gets a subtle 1px corner bracket highlight, not a full outline.
- Break progress drives 4 crack overlay stages.
- Dirt particles are short-lived, chunky, and gravity-affected.
- Stone emits fewer but brighter chips.
- Drill sound pitch lowers against stone and rises slightly just before a block breaks.
- Item pickup shows a compact `+1 dirt_clod` or `+1 stone_chunk` near the hotbar.

## Agent 2: Pixel Art Designer

### Visual Intent

The Art Bible prioritizes readability over detail, dark colored outlines on characters, no terrain outlines, and high contrast for interactive elements. Sprint 1 should look earthy but not dull. The player and drill must remain readable against dirt and stone at `300%` and `400%` integer scale.

### Master Palette Slice

This is a Sprint 1 working slice of the future indexed palette.

| Use | Hex |
| --- | --- |
| Character outline, not pure black | `#181724` |
| Deep cool shadow | `#252a35` |
| Suit mid gray-blue | `#61717d` |
| Suit highlight | `#a9b7ba` |
| Leather padding | `#774f33` |
| Brass lamp and buckles | `#c08b3e` |
| Lamp glow | `#ffd66b` |
| Drill dark metal | `#4d5962` |
| Drill bright metal | `#9aa8ae` |
| Warning red accent | `#cf5546` |
| Loose dirt shadow | `#4b2f22` |
| Loose dirt mid | `#7a4b2e` |
| Loose dirt highlight | `#a86f3c` |
| Root fleck | `#3b2b22` |
| Stone shadow | `#303642` |
| Stone mid | `#59616a` |
| Stone highlight | `#88939a` |
| Crack highlight dust | `#d6b071` |

### Modular Delver Sprite

Canvas:
- Native frame size: `24x32 px`
- Anchor: bottom center at pixel `(12, 31)`
- Collision guide: `14x28 px`, drawn only in dev overlay
- Outline: dark colored outline using `#181724`, typically 1px

Layer order:
1. Back equipment: backpack, rear hose, rear arm
2. Legs
3. Torso
4. Head and helmet
5. Front arm
6. Drill/tool
7. Helmet lamp glow overlay

Required modules:
- `delver_base_body_24x32`
- `delver_head_24x32`
- `delver_torso_24x32`
- `delver_arms_24x32`
- `delver_legs_24x32`
- `starter_drill_24x32`
- `helmet_lamp_glow_24x32`

Readability notes:
- Helmet lamp should create an unmistakable head silhouette.
- Drill silhouette must be longer than the forearm and angled clearly.
- Boots need a 2px value contrast from legs so walking reads at small scale.
- Avoid tiny noisy buckles on the base body; save detail for armor upgrades.

### Delver Sprite Sheet Layout

Each module uses the same frame grid so armor and tools can be swapped without reauthoring animation timing.

| Row | Frames | Animation | Timing |
| --- | ---: | --- | --- |
| 0 | 4 | Idle, helmet bob, lamp flicker | `160 ms/frame` |
| 1 | 6 | Run | `80 ms/frame` |
| 2 | 4 | Jump, rise, fall, land | state-driven |
| 3 | 4 | Drill side | `60 ms/frame` |
| 4 | 4 | Drill down | `60 ms/frame` |
| 5 | 4 | Drill up | `60 ms/frame` |
| 6 | 3 | Pickup, recoil, hurt placeholder | state-driven |

Drilling poses:
- Side drill: feet planted wide, torso leans 1px into drill direction.
- Down drill: knees bent, drill between boots, helmet tilted downward.
- Up drill: front arm locks upward, drill plume falls around player sides.
- Animation should vibrate the tool by 1px, not the whole character.

### Dirt and Stone Tiles

Tile canvas: `16x16 px`

Terrain must not use character-style outlines. Boundaries should read through internal shading and future autotile edges.

Loose dirt:
- Rounded clumps, diagonal pebble shadows, tiny root flecks.
- Top-facing variants include sparse surface crumbs.
- Avoid high-frequency noise; use clusters of 2 to 4 pixels.

Compacted dirt:
- Same hue family as loose dirt, darker and less saturated.
- More horizontal strata lines, good for early depth change.

Soft stone:
- Cooler gray-blue family to separate it from dirt.
- Chunk shapes should be angular but not geometric like pyramid tiles.
- Cracks are low contrast until damaged.

### Terrain Sheet Layout

The Sprint 1 sheet should be compatible with the Sprint 2 47-tile system but only needs core variants now.

| Row | Columns | Content |
| --- | ---: | --- |
| 0 | 0-7 | Loose dirt fill variants |
| 1 | 0-7 | Compacted dirt fill variants |
| 2 | 0-7 | Soft stone fill variants |
| 3 | 0-3 | Dirt break overlays, stages 0-3 |
| 3 | 4-7 | Stone break overlays, stages 0-3 |
| 4 | 0-7 | Dirt/stone loose particle sprites |
| 5 | 0-7 | Developer collision/debug tiles, excluded from final export |

### Break Overlay Rules

Break overlays are transparent sprites rendered over the target tile:
- Stage 0: hairline chip, 10-20 percent damaged
- Stage 1: visible center crack, 30-50 percent damaged
- Stage 2: branching crack, 50-75 percent damaged
- Stage 3: heavy fractured shape, 75-99 percent damaged

The overlay should be brighter than the tile but less bright than ores will be in later sprints.

### Minimal Sprint 1 HUD Visual

Even though Sprint 3 owns UI, Sprint 1 needs inventory feedback:
- Bottom-left compact hotbar stub with 8 visible slots.
- SVG/vector-style overlay, crisp at any scale.
- Material theme: dull forged iron border with dark translucent fill.
- No large panels, no center-screen tutorial card.

## Agent 3: Programmer and Code Reviewer

### System Boundaries

Sprint 1 should implement real gameplay logic, but keep world content tiny. The data model must already be compatible with infinite signed chunks so Sprint 2 does not require a rewrite.

Recommended systems:
- `PlayerControllerSystem`
- `CollisionSystem`
- `DrillSystem`
- `TileDamageSystem`
- `InventorySystem`
- `PickupSystem`
- `FeedbackEventBus`
- `ChunkTileStore`

### TypeScript-Ready Logic

```ts
type Vec2 = { x: number; y: number };
type TileCoord = { x: number; y: number };
type ChunkCoord = { x: number; y: number };

type ItemId = "dirt_clod" | "stone_chunk";

interface InventorySlot {
  itemId: ItemId | null;
  count: number;
  stackCap: number;
}

interface DrillResult {
  target?: TileCoord;
  brokeTile?: TileCoord;
  drops: Array<{ itemId: ItemId; count: number; positionPx: Vec2 }>;
  crackStage?: number;
}
```

Chunk coordinate conversion must handle negative positions correctly:

```ts
const CHUNK_SIZE = 32;

function floorDiv(value: number, divisor: number): number {
  return Math.floor(value / divisor);
}

function toChunkCoord(tile: TileCoord): ChunkCoord {
  return {
    x: floorDiv(tile.x, CHUNK_SIZE),
    y: floorDiv(tile.y, CHUNK_SIZE)
  };
}

function toLocalTile(tile: TileCoord): TileCoord {
  return {
    x: ((tile.x % CHUNK_SIZE) + CHUNK_SIZE) % CHUNK_SIZE,
    y: ((tile.y % CHUNK_SIZE) + CHUNK_SIZE) % CHUNK_SIZE
  };
}
```

Player update flow:

```ts
function updatePlayer(player: Player, input: InputState, world: World, dt: number): void {
  updateJumpTimers(player.motor, input, dt);
  applyHorizontalMovement(player.transform, player.motor, input, dt);
  applyJump(player.transform, player.motor, input);
  applyGravity(player.transform, input, dt);

  moveAndCollideX(player, world, dt);
  moveAndCollideY(player, world, dt);

  updateFacing(player.transform, input);
}
```

Drill update flow:

```ts
function updateDrill(
  player: Player,
  input: InputState,
  world: World,
  inventory: InventoryComponent,
  now: number,
  dt: number
): DrillResult {
  coolDrillWhenInactive(player.drill, input.drillHeld, dt);

  if (!input.drillHeld || now < player.drill.overheatedUntil) {
    clearActiveTarget(player.drill);
    return { drops: [] };
  }

  const target = findDrillTarget(player, input.aimVector, world);
  if (!target) {
    addDrillHeat(player.drill, dt);
    return { drops: [] };
  }

  const tileId = world.tiles.getTile(target);
  const tileDef = TileDefs[tileId];
  if (!tileDef.breakable) return { target, drops: [] };

  const heatFactor = getHeatFactor(player.drill.heat);
  const aimStability = getAimStability(player, input.aimVector);
  const drillDps = StarterDrill.power * tileDef.drillEfficiency * heatFactor * aimStability;

  const damage = world.tileDamage.addDamage(target, drillDps * dt, now, tileDef.hardness);
  addDrillHeat(player.drill, dt);

  emitFeedback({
    type: "drill_tick",
    target,
    material: tileDef.material,
    progressRatio: damage.progress / tileDef.hardness
  });

  if (damage.progress < tileDef.hardness) {
    return { target, drops: [], crackStage: damage.crackStage };
  }

  world.tiles.setTile(target, "air");
  world.tileDamage.clear(target);
  world.tiles.markNeighborsDirtyForAutotile(target);

  const drops = rollDrops(tileDef.drops, tileCenterPx(target));
  spawnPickupsOrCollect(drops, player, inventory);

  emitFeedback({ type: "tile_broke", target, material: tileDef.material });
  return { target, brokeTile: target, drops };
}
```

Inventory add flow:

```ts
function addToInventory(inv: InventoryComponent, itemId: ItemId, count: number): number {
  let remaining = count;

  for (const slot of inv.slots) {
    if (remaining <= 0) break;
    if (slot.itemId !== itemId || slot.count >= slot.stackCap) continue;

    const moved = Math.min(remaining, slot.stackCap - slot.count);
    slot.count += moved;
    remaining -= moved;
  }

  for (const slot of inv.slots) {
    if (remaining <= 0) break;
    if (slot.itemId !== null) continue;

    const moved = Math.min(remaining, slot.stackCap);
    slot.itemId = itemId;
    slot.count = moved;
    remaining -= moved;
  }

  return remaining;
}
```

### Destruction Edge Cases

- If the player is overlapping a tile, the drill must not target that tile.
- If a tile is destroyed, collision should use the updated tile map on the next physics step, not halfway through an axis resolution.
- Damage progress should decay after `2.5 s` without being hit, clearing crack overlays.
- Damage state is sparse and stored by tile coordinate, never baked into tile definitions.
- If the inventory is full, pickups remain physical and keep trying to magnetize.
- If the target tile changes, the prior tile keeps its damage until decay.
- Drill heat increases even when the drill spins against an invalid target, but more slowly than when damaging a block.

### Code Review Notes

- Keep all physics on a fixed timestep. Variable timestep collision will create tunneling bugs, especially when the world becomes vertically infinite.
- Do not scan all nearby tiles every frame for mining. A short DDA/raycast is enough.
- Do not use array indices based on global tile coordinates. Signed chunks prevent memory blowups when the player digs left, right, or downward forever.
- Keep tile definitions immutable. Chunks store tile ids; damage and crack stages live in sparse runtime maps.
- Emit gameplay events for sound, particles, and HUD instead of calling presentation code from `DrillSystem`.
- `markNeighborsDirtyForAutotile` is a no-op in Sprint 1 except for debug logging, but the hook must exist for Sprint 2.

## Agent 4: Player Persona

### First-Pass Player Review

The foundation is promising because the drill is already treated as the core verb, not a reskinned pickaxe. Dirt breaking in about half a second sounds good. Stone above three seconds would feel like punishment this early, so the revised `2.33 s` soft stone target is acceptable as long as the feedback is crunchy.

Movement should not feel floaty. The gravity and terminal velocity numbers imply a heavier platformer, which suits underground descent. The Delver needs a crisp landing response because falling through player-made shafts will happen constantly.

The biggest risk is accidental downward drilling. If I hold down near my feet and the tile pops instantly, I may blame the controls for the fall. Requiring explicit down aim helps, but the target highlight is mandatory.

Sprite readability is solid on paper. The lamp, drill, and boots are the most important shapes. If the torso gets too detailed, the character will dissolve into the dirt. Keep the base suit plain and let the silhouette carry the design.

The inventory update should be satisfying but tiny. A loud center-screen popup would damage the mining rhythm. A little hotbar bump and small text near the edge is enough.

### Player Demands Before Sprint 1 Is Accepted

- I need to know exactly which block I am drilling before it breaks.
- Dirt must burst with visible particles, not simply disappear.
- The drill must sound and animate differently on dirt versus stone.
- Downward drilling must feel intentional.
- The Delver must remain readable against both dirt and stone at `300%` scale.

## Final Revisions

The following revisions are accepted after Player Persona feedback:

1. Downward drilling requires explicit down aim and a visible target bracket.
2. Soft stone break time is capped near `2.33 s` for the starter drill.
3. Dirt destruction must include particles, crack overlay, pickup motion, and a small inventory delta.
4. The starter drill can overheat, but heat tuning must be forgiving enough that it does not interrupt basic dirt tunneling.
5. The animation sheet gives drill poses their own rows so the drill reads clearly in side, up, and down use cases.

## Sprint 1 Acceptance Criteria

- Player can run, jump, fall, and collide with `16x16` tile terrain at a fixed timestep.
- Player can drill loose dirt, compacted dirt, and soft stone.
- Block damage is visible through 4 crack stages.
- Destroyed blocks become air and update collision.
- Destroyed blocks spawn or grant inventory drops.
- Inventory changes emit delta events.
- Downward drilling is deliberate and visibly targeted.
- Delver sprite is readable at `300%` scale against dirt and stone.
- Terrain art uses no pure black outlines and no high-frequency noise.
- Tile storage uses signed chunk coordinates, even if the Sprint 1 testbed is small.
- Neighbor autotile dirty hooks exist for Sprint 2.

## Out Of Scope For Sprint 1

- Full 47-tile autotiling implementation
- Infinite biome generation
- Colossal Ant Chambers
- Combat and hostile ecology
- Dynamic darkness and monster spawning
- Structural integrity and cave-ins
- Ropes, grappling hooks, elevators, and outposts
- Full inventory menus

## Prototype Build Order

1. Implement fixed-step player motor and collision.
2. Add chunk-backed tile store with a small hand-authored test cave.
3. Add drill targeting, tile damage, and tile destruction.
4. Add inventory slots, pickup magnetism, and inventory delta events.
5. Add crack overlays, dirt/stone particles, drill animation hooks, and sound event hooks.
6. Validate movement and drilling feel with a 5-minute mining test.

