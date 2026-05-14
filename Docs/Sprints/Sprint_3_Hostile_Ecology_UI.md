# Deepbound Sprint 3: Hostile Ecology and UI

Source references:
- `Docs/Deepbound_Game_Design.md`
- `Docs/Deepbound_Art_Bible.md`
- `Docs/Sprints/Sprint_1_Core_Foundation.md`
- `Docs/Sprints/Sprint_2_Infinite_Deep_Autotiling.md`

Sprint focus: directional combat, tunneling worm ambushes, dynamic darkness, line-of-sight lighting, and minimalist UI that supports danger without burying the playfield.

## Agent Stand-Up

**Agent 1: The Game Designer.** I define combat rules, enemy behavior, darkness pressure, health, and inventory-facing player state.

**Agent 2: The Pixel Art Designer.** I define worm attack frames, darkness overlays, combat telegraphs, and crisp vector-style HUD overlays.

**Agent 3: The Programmer and Code Reviewer.** I specify lighting, pathfinding, combat state, and UI state flows with performance and fairness checks.

**Agent 4: The Player Persona.** I judge whether the dark is tense rather than annoying, and whether combat feels fair in cramped destructible tunnels.

## Agent 1: Game Designer

### Sprint 3 Player Promise

After Sprint 3, drilling in darkness should feel dangerous. The player should be able to aim attacks in tight tunnels, read enemy telegraphs, survive tunneling worm ambushes through skill, and monitor health, light, drill heat, and inventory without losing sight of the world.

### Directional Combat Rules

Combat uses the same 8-way aim vocabulary as drilling.

Player attack verbs:
- Quick melee jab: short cooldown, low commitment, works in tunnels.
- Heavy drill bash: longer windup, interrupts soft-block tunneling enemies.
- Emergency flare toss: creates light and briefly scares worms, but consumes inventory.

Prototype combat tuning:

```ts
const CombatTuning = {
  quickJabCooldown: 0.32,
  quickJabDamage: 12,
  quickJabReachTiles: 1.05,
  drillBashWindup: 0.28,
  drillBashCooldown: 0.85,
  drillBashDamage: 24,
  drillBashStaggerSeconds: 0.55,
  invulnerabilityAfterHit: 0.70,
  knockbackPxPerSecond: 150
};
```

Attack fairness:
- Every hostile attack must have a readable telegraph before damage.
- Worms cannot damage the player on the same frame they emerge.
- Enemies should not attack from fully offscreen unless the player has ignored a warning.
- Directional attacks use forgiving hitboxes that are wider than the pixel weapon sprite.
- In one-tile-high gaps, attacks use a compact forward box instead of a tall arc.

### Dynamic Lighting and Darkness

Light is a resource and a pressure system.

Lighting goals:
- The helmet lamp gives safe immediate visibility but limited range.
- Flares and glowing ores create local safety islands.
- Darkness increases enemy confidence and spawn pressure.
- UI must communicate light danger without placing huge warnings in the center.

Light levels:

| Level | Range | Gameplay Meaning |
| --- | --- | --- |
| Bright | `0.75-1.00` | Safe visibility, enemies fully readable |
| Dim | `0.35-0.74` | Playable tension, silhouettes remain readable |
| Dark | `0.10-0.34` | Ambush risk increases, low-value terrain fades |
| Blackout | `<0.10` | Navigation danger, enemy spawn pressure maxes nearby |

Line-of-sight lighting:
- Light spreads tile-by-tile from each source.
- Solid tiles with `blocksLight = true` occlude light.
- Resin blocks reduce light less harshly than stone to preserve their translucent identity.
- Glowing ores emit local light but do not replace dedicated player light sources.

Darkness danger:

```txt
danger = baseDepthDanger + darknessFactor + drillNoiseFactor - nearbyLightSafety
darknessFactor = smoothstep(0.35, 0.05, localLight)
drillNoiseFactor = drillActive ? 0.25 : 0
nearbyLightSafety = clamp(totalLightSourcesWithin8Tiles * 0.08, 0, 0.24)
```

### Tunneling Worm Ambush

The tunneling worm is the Sprint 3 flagship enemy. It senses vibration, digs through soft blocks, telegraphs emergence, strikes, then retreats or repositions.

Behavior goals:
- It should feel like it belongs in destructible terrain.
- It should punish careless drilling in darkness, not random exploration.
- It should create panic through sound and tile movement before direct damage.

Worm state loop:
1. `idle_buried`: dormant offscreen or outside immediate light.
2. `sense_vibration`: hears drilling, footsteps, or tile breaks.
3. `path_tunnel`: routes through soft blocks toward an intercept point.
4. `telegraph_emerge`: cracks nearby blocks and shows dust/sound warning.
5. `lunge_attack`: enters exposed space and attacks along a line.
6. `recover`: vulnerable window after missing or being blocked.
7. `retreat_burrow`: digs away if staggered, hurt, or after two attacks.

Fairness limits:
- Minimum warning time: `0.75 s`
- Minimum emergence distance from player: `1.5 tiles`
- No more than `2` active worms targeting the player in Sprint 3.
- A worm must spend at least `1.0 s` in recover after a missed lunge.
- Worms cannot path through hardened resin during Sprint 3.
- If the player is in bright light, worm aggression decays unless directly attacked.

## Required Schemas

```ts
type Vec2 = { x: number; y: number };
type TileCoord = { x: number; y: number };

interface LightSource {
  entityId: string;
  positionPx: Vec2;
  radiusTiles: number;
  intensity: number;
  color: string;
  flickerAmount: number;
  expiresAt?: number;
  blocksSpawnPressure: boolean;
}

interface LightCell {
  coord: TileCoord;
  visible: boolean;
  intensity: number;
  color: string;
  occlusion: number;
  lastSeenAt: number;
}

type CombatShape = "arc" | "box" | "line";

interface CombatHitbox {
  ownerEntityId: string;
  shape: CombatShape;
  originPx: Vec2;
  aimVector: Vec2;
  reachTiles: number;
  widthTiles: number;
  activeFrom: number;
  activeUntil: number;
  damage: number;
  staggerSeconds: number;
  tags: string[];
}

interface DamageEvent {
  sourceEntityId: string;
  targetEntityId: string;
  amount: number;
  knockback: Vec2;
  damageType: "melee" | "drill" | "bite" | "fall" | "darkness";
  hitPauseSeconds: number;
  invulnerabilitySeconds: number;
}

type TunnelingWormState =
  | "idle_buried"
  | "sense_vibration"
  | "path_tunnel"
  | "telegraph_emerge"
  | "lunge_attack"
  | "recover"
  | "retreat_burrow";

interface EnemyPathNode {
  coord: TileCoord;
  costFromStart: number;
  estimatedTotalCost: number;
  parentKey?: string;
  tileDigCost: number;
  lightPenalty: number;
}

interface HudState {
  health: {
    current: number;
    max: number;
    recentlyDamagedUntil: number;
  };
  drillHeat: {
    value: number;
    overheated: boolean;
  };
  quickSlots: InventoryHudDelta[];
  localLightLevel: number;
  dangerPulse: number;
}

interface InventoryHudDelta {
  slotIndex: number;
  itemId: string | null;
  count: number;
  changedAt: number;
  deltaCount: number;
}
```

## Agent 2: Pixel Art Designer

### Visual Intent

Sprint 3 is about readable tension. The darkness should make the world scarier, but the player, enemies, damage, and UI must stay understandable. The Art Bible's rule still leads: readability over detail.

### Tunneling Worm Sprite Specs

Native frame size:
- Body segment tile: `16x16 px`
- Head attack frame: `32x24 px`
- Full worm is assembled from head, `3-6` body segments, and tail
- Dark colored outline: `#20151d`, not pure black

Palette:

| Use | Hex |
| --- | --- |
| Worm outline | `#20151d` |
| Worm deep shadow | `#3b2330` |
| Worm body mid | `#8b4650` |
| Worm underbelly | `#c27a61` |
| Tooth highlight | `#e8d5a1` |
| Warning throat glow | `#f06f3a` |
| Burrow dust | `#b17b45` |
| Fresh tunnel shadow | `#2a1e1c` |

Animation sheet:

| Row | Frames | Animation | Timing |
| --- | ---: | --- | --- |
| 0 | 4 | Buried ripple and dirt bulge | `90 ms/frame` |
| 1 | 5 | Tunnel movement, segment wave | `70 ms/frame` |
| 2 | 4 | Telegraph emerge, cracked tile, glow throat | `110 ms/frame` |
| 3 | 4 | Lunge attack | `55 ms/frame` |
| 4 | 3 | Recover, jaw stuck, exposed weak point | state-driven |
| 5 | 4 | Retreat burrow | `65 ms/frame` |

Telegraph requirements:
- Before damage, show cracked ground or wall tiles near the emergence point.
- Add dust puffs that travel opposite the worm's movement.
- The head silhouette must be wider than the body so the threat direction is obvious.
- The attack frame must expose bright teeth and a warm throat glow.

### Darkness and Lighting Art

Lighting should be tile-informed but visually softened:
- Use a low-resolution light buffer upscaled smoothly over pixel art.
- Keep foreground sprites sharp; do not blur pixel sprites.
- Darkness overlay color starts at `#090b12` with subtle blue-violet bias.
- Recently seen areas remain faintly visible at `20-30%` brightness.
- Unseen blackout areas should not hide the player or UI.

Light source treatments:
- Helmet lamp: tight warm cone, slight flicker.
- Flare: pulsing orange circle with small falling sparks.
- Amber ore: soft golden aura, lower intensity than flare.
- Worm warning: short orange pulse from cracks, not a permanent light.

### Minimalist UI Overlay

The UI is crisp vector-style over chunky pixel art.

HUD layout:
- Top-left: health pips, `10` max visible pips before grouping.
- Bottom-left: `8` quick slots from Sprint 1, compact and edge-locked.
- Bottom-right: drill heat gauge with icon-only drill mark.
- Screen edge vignette: danger pulse when local light is low or worm is near.
- No center-screen panels during combat.

SVG-style visual rules:
- Use straight edges, small bevels, and `4px` or smaller corner radii.
- Hotbar slots have forged iron borders at early tier.
- Health pips use red crystal shards, not generic hearts.
- Drill heat uses amber fill that turns warning red only near overheat.
- All UI text is small, sparse, and optional; icons do the work.

UI contrast:
- UI must remain readable on bright ore and dark caverns.
- Add a thin dark backing behind pips and heat gauge.
- No UI element may cover the player in the central `60%` of the screen.

## Agent 3: Programmer and Code Reviewer

### System Boundaries

Recommended systems:
- `LightingSystem`
- `VisibilitySystem`
- `DarknessDangerSystem`
- `CombatSystem`
- `DamageSystem`
- `TunnelingWormAISystem`
- `SoftBlockPathfindingSystem`
- `HudStateSystem`
- `CombatFeedbackEventBus`

### Lighting Flow

Lighting is recomputed around active light sources and cached per chunk.

```ts
function updateLighting(world: World, lightSources: LightSource[], now: number): void {
  world.light.clearDynamicLight();

  for (const source of lightSources) {
    if (source.expiresAt !== undefined && now >= source.expiresAt) continue;
    castLightFromSource(world, source);
  }

  updateVisibilityMemory(world, now);
  updateChunkLightTextures(world);
}
```

Line-of-sight casting:

```ts
function castLightFromSource(world: World, source: LightSource): void {
  const origin = worldToTile(source.positionPx);
  const radius = Math.ceil(source.radiusTiles);

  for (let y = origin.y - radius; y <= origin.y + radius; y++) {
    for (let x = origin.x - radius; x <= origin.x + radius; x++) {
      const target = { x, y };
      const distance = tileDistance(origin, target);
      if (distance > source.radiusTiles) continue;

      const visibility = traceTileLineOfSight(world, origin, target);
      if (visibility <= 0) continue;

      const falloff = 1 - distance / source.radiusTiles;
      world.light.add(target, source.intensity * falloff * visibility, source.color);
    }
  }
}
```

Occlusion rules:
- Air occlusion: `0.0`
- Background wall occlusion: `0.05`
- Resin occlusion: `0.35`
- Dirt occlusion: `0.75`
- Stone occlusion: `0.95`
- Hardened resin still blocks worm movement, but lets more light through than stone.

### Combat Flow

```ts
function updateCombat(player: Player, enemies: Enemy[], input: InputState, now: number): void {
  if (input.quickAttackPressed && player.combat.canQuickAttack(now)) {
    spawnPlayerQuickJab(player, input.aimVector, now);
  }

  if (input.heavyAttackPressed && player.combat.canDrillBash(now)) {
    beginDrillBash(player, input.aimVector, now);
  }

  resolveActiveHitboxes(player, enemies, now);
  expireHitboxes(now);
}
```

Damage application:

```ts
function applyDamage(target: Damageable, event: DamageEvent, now: number): void {
  if (now < target.invulnerableUntil) return;

  target.health.current = Math.max(0, target.health.current - event.amount);
  target.velocity.x += event.knockback.x;
  target.velocity.y += event.knockback.y;
  target.invulnerableUntil = now + event.invulnerabilitySeconds;

  emitCombatFeedback({
    type: "damage_applied",
    targetEntityId: event.targetEntityId,
    amount: event.amount,
    damageType: event.damageType,
    hitPauseSeconds: event.hitPauseSeconds
  });
}
```

### Tunneling Worm AI

Vibration sensing:

```ts
function emitVibration(world: World, event: VibrationEvent): void {
  const radius = event.kind === "drill" ? 18 : event.kind === "tile_break" ? 14 : 8;
  world.vibrations.add({
    positionPx: event.positionPx,
    radiusTiles: radius,
    strength: event.strength,
    createdAt: event.createdAt,
    expiresAt: event.createdAt + 1.25
  });
}
```

Path costs:

| Tile Type | Cost |
| --- | ---: |
| Air tunnel | `1` |
| Loose dirt | `4` |
| Compacted dirt | `7` |
| Excavated earth | `5` |
| Soft stone | `18` |
| Hardened resin | blocked |

Worm update:

```ts
function updateTunnelingWorm(worm: TunnelingWorm, world: World, player: Player, now: number, dt: number): void {
  switch (worm.state) {
    case "idle_buried":
      if (canSenseVibration(worm, world, player)) enterSenseVibration(worm, now);
      break;
    case "sense_vibration":
      chooseInterceptPoint(worm, world, player);
      enterPathTunnel(worm, now);
      break;
    case "path_tunnel":
      followSoftBlockPath(worm, world, dt);
      if (nearEmergencePoint(worm)) enterTelegraphEmerge(worm, now);
      break;
    case "telegraph_emerge":
      emitEmergenceWarning(worm, world, now);
      if (now >= worm.telegraphEndsAt) enterLungeAttack(worm, player, now);
      break;
    case "lunge_attack":
      moveLungeAndSpawnHitbox(worm, now, dt);
      if (lungeFinished(worm, now)) enterRecover(worm, now);
      break;
    case "recover":
      if (now >= worm.recoverEndsAt) enterRetreatBurrow(worm, now);
      break;
    case "retreat_burrow":
      retreatFromLightAndPlayer(worm, world, player, dt);
      if (safeToIdle(worm, world, player)) enterIdleBuried(worm, now);
      break;
  }
}
```

Pathfinding review:
- Use A* over a bounded window around worm and player, not the entire world.
- Path search radius is `32 tiles` in Sprint 3.
- Cache path for `0.25 s`, then replan if the player moves or tiles change.
- Penalize bright light cells so worms prefer dark approaches.
- Stop pathing if the player returns to bright light for more than `1.5 s`.

### HUD State Flow

```ts
function buildHudState(player: Player, inventory: InventoryComponent, world: World, now: number): HudState {
  return {
    health: {
      current: player.health.current,
      max: player.health.max,
      recentlyDamagedUntil: player.health.recentlyDamagedUntil
    },
    drillHeat: {
      value: player.drill.heat,
      overheated: now < player.drill.overheatedUntil
    },
    quickSlots: buildQuickSlotDeltas(inventory, now),
    localLightLevel: world.light.sampleAt(worldToTile(player.transform.positionPx)).intensity,
    dangerPulse: computeDangerPulse(player, world, now)
  };
}
```

Code review notes:
- Lighting must be bounded to active source radii, never whole-world.
- UI state should be derived from game state; UI must not own gameplay values.
- Damage events must be idempotent within a hitbox activation window so one bite does not hit every frame.
- Worm pathfinding must respect tile changes from drilling and autotile updates.
- Darkness danger should influence spawns and aggression, not directly drain health in Sprint 3.

## Agent 4: Player Persona

### First-Pass Player Review

This sprint can make Deepbound exciting, but it can also become unfair fast. A worm coming through the wall is cool only if I get a warning I can understand. The `0.75 s` minimum warning is the right call, especially with dust, cracks, sound, and a glow.

The darkness system sounds tense without being hostile to basic navigation. Helmet lamp plus flares plus glowing ores gives me tools. If blackout simply hides everything, it will feel cheap. The visibility memory is important because it keeps the cave mentally mappable.

Combat needs generous hitboxes. Pixel-perfect melee in a destructible tunnel would feel awful. The 8-way aim matching the drill is smart because I do not need to learn a second control language.

The UI direction is good. Edge-locked pips, quick slots, drill heat, and a danger vignette are enough. Do not add a giant warning banner when the worm is coming. Let the world warn me.

The worm should sometimes retreat. If every encounter is a fight to the death, it becomes routine. A wounded worm disappearing into darkness is much scarier.

### Player Demands Before Sprint 3 Is Accepted

- I need readable warning before every worm hit.
- I need useful light tools, not just punishment for darkness.
- Combat must forgive aim slightly in tight tunnels.
- The HUD must never cover the player or the attack direction.
- A missed worm lunge must create a punish window.

## Final Revisions

The following revisions are accepted after Player Persona feedback:

1. Worm attacks require at least `0.75 s` of telegraph before damage.
2. Worms enter a recover state for at least `1.0 s` after a missed lunge.
3. Player attacks use generous directional hitboxes that are wider than the weapon sprite.
4. Darkness increases danger and aggression but does not directly drain health in Sprint 3.
5. HUD remains edge-locked, with no center-screen combat panels.
6. Visibility memory keeps recently seen tiles faintly readable.

## Sprint 3 Acceptance Criteria

- Directional combat uses the same 8-way aim model as drilling.
- Quick jab and drill bash have defined damage, timing, reach, cooldown, and feedback.
- Dynamic lighting uses tile-based line-of-sight with material occlusion.
- Light data is cached per chunk or active source radius, not computed globally.
- Darkness danger affects ambush pressure without direct health drain.
- Tunneling worm AI includes vibration sensing, soft-block pathing, telegraph, lunge, recover, and retreat states.
- Worm pathfinding uses soft-block costs and treats hardened resin as blocked.
- Every worm attack has a readable warning and punish window.
- HUD state includes health, drill heat, quick inventory, local light, and danger pulse.
- UI is minimalist, edge-locked, and crisp vector-style over pixel art.
- Player review concerns are resolved in final revisions.

## Out Of Scope For Sprint 3

- Boss fights
- Full faction AI
- Drow diplomacy and trading
- Base automation UI
- Structural integrity and cave-ins
- Networked multiplayer
- Runtime asset export or playable engine code

## Prototype Build Order

1. Add light source data and tile-based line-of-sight lighting.
2. Add visibility memory and darkness danger scoring.
3. Implement directional combat hitbox spawning and damage events.
4. Add tunneling worm state machine and vibration events.
5. Add bounded A* soft-block pathfinding with light penalties.
6. Add worm telegraph, lunge, recover, and retreat feedback hooks.
7. Build derived HUD state for health, drill heat, quick slots, light, and danger.
8. Validate combat fairness in one-tile tunnels, open ant chambers, and low-light transition zones.

