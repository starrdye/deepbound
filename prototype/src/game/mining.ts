import { addToInventory } from "./inventory";
import { getTileDefinition } from "./tiles";
import type { ChunkStore } from "./world";
import type { InventoryState, MiningResult, TileCoord, Vec2 } from "./types";

export const STARTER_DRILL = {
  power: 1,
  reachTiles: 1.45,
  heatPerSecond: 0.16,
  coolPerSecond: 0.34,
  overheatAt: 1
} as const;

export function normalizeAim(aim: Vec2): Vec2 {
  const length = Math.hypot(aim.x, aim.y);
  if (length < 0.001) return { x: 1, y: 0 };
  return { x: aim.x / length, y: aim.y / length };
}

export function findMiningTarget(originPx: Vec2, aim: Vec2, world: ChunkStore): TileCoord | null {
  const normal = normalizeAim(aim);
  const reachPx = STARTER_DRILL.reachTiles * 16;
  for (let distance = 4; distance <= reachPx; distance += 4) {
    const tile = {
      x: Math.floor((originPx.x + normal.x * distance) / 16),
      y: Math.floor((originPx.y + normal.y * distance) / 16)
    };
    if (world.isSolidAt(tile)) return tile;
  }
  return null;
}

export function mineTile(
  world: ChunkStore,
  target: TileCoord,
  inventory: InventoryState,
  dt: number,
  drillHeat: number
): MiningResult {
  const tileId = world.getTile(target);
  const def = getTileDefinition(tileId);

  if (!def.solid) {
    return { target, tileId, broke: false, progressRatio: 0, drops: [], blockedReason: "empty" };
  }

  if (!def.breakable) {
    return { target, tileId, broke: false, progressRatio: 0, drops: [], blockedReason: "unbreakable" };
  }

  const heatFactor = Math.max(0.45, 1 - drillHeat * 0.35);
  const addedProgress = STARTER_DRILL.power * heatFactor * dt;
  const progress = world.getDamage(target) + addedProgress;

  if (progress < def.hardness) {
    world.setDamage(target, progress);
    return {
      target,
      tileId,
      broke: false,
      progressRatio: progress / def.hardness,
      drops: []
    };
  }

  world.setTile(target, "air");
  const drops: MiningResult["drops"] = [];
  for (const drop of def.drops) {
    const count = drop.max;
    const remaining = addToInventory(inventory, drop.itemId, count);
    drops.push({ itemId: drop.itemId, count: count - remaining });
  }

  return {
    target,
    tileId,
    broke: true,
    progressRatio: 1,
    drops
  };
}

