import { getDepthLabel } from "./bands";
import { getQuickSlots } from "./inventory";
import { getTileDefinition } from "./tiles";
import { getDepthDanger } from "./world";
import { computeDangerPulse } from "./lighting";
import type { HudState, InventoryState, TileId } from "./types";

export function buildHudState(input: {
  health: { current: number; max: number; recentlyDamaged: boolean };
  drillHeat: { value: number; overheated: boolean };
  inventory: InventoryState;
  localLightLevel: number;
  playerTileY: number;
  hostileNearby: boolean;
  targetTileId: TileId;
}): HudState {
  return {
    health: input.health,
    drillHeat: input.drillHeat,
    quickSlots: getQuickSlots(input.inventory).map((slot, slotIndex) => ({
      slotIndex,
      itemId: slot.itemId,
      count: slot.count,
      deltaCount: 0
    })),
    localLightLevel: input.localLightLevel,
    dangerPulse: computeDangerPulse(input.localLightLevel, getDepthDanger(input.playerTileY), input.hostileNearby),
    depthLabel: getDepthLabel(input.playerTileY),
    targetTileName: getTileDefinition(input.targetTileId).displayName
  };
}

