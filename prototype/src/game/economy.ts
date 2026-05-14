import { TILE_DEFINITIONS } from "./tiles";
import type { TileId } from "./types";

export interface MiningRoi {
  tileId: TileId;
  breakSeconds: number;
  expectedValue: number;
  valuePerSecond: number;
}

export const BAND1_CRAFTING_COSTS = {
  firstTorchBundle: {
    dirt_clod: 3,
    stone_chunk: 2
  },
  copperBrace: {
    copper_nugget: 6,
    stone_chunk: 4
  }
} as const;

export function expectedTileDropValue(tileId: TileId): number {
  const tile = TILE_DEFINITIONS[tileId];
  return tile.drops.reduce((sum, drop) => {
    const averageCount = (drop.min + drop.max) / 2;
    return sum + averageCount * drop.chance * tile.value;
  }, 0);
}

export function computeMiningRoi(tileId: TileId, drillPower = 1): MiningRoi {
  const tile = TILE_DEFINITIONS[tileId];
  const breakSeconds = tile.breakable ? tile.hardness / drillPower : Number.POSITIVE_INFINITY;
  const expectedValue = expectedTileDropValue(tileId);
  return {
    tileId,
    breakSeconds,
    expectedValue,
    valuePerSecond: expectedValue / breakSeconds
  };
}

export function estimateResourcePerMinute(tileId: TileId, drillPower = 1, uptime = 0.72): number {
  const roi = computeMiningRoi(tileId, drillPower);
  if (!Number.isFinite(roi.breakSeconds)) return 0;
  return (60 / roi.breakSeconds) * uptime * roi.expectedValue;
}

