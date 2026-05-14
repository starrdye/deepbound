import { describe, expect, it } from "vitest";
import { createInventory } from "./inventory";
import { buildHudState } from "./hud";
import { computeDangerPulse, computeLightCell } from "./lighting";
import { ChunkStore } from "./world";

describe("lighting and HUD state", () => {
  it("reduces light behind occluding tiles", () => {
    const world = new ChunkStore(2);
    world.setTile({ x: 0, y: 0 }, "air");
    world.setTile({ x: 1, y: 0 }, "soft_stone");
    world.setTile({ x: 2, y: 0 }, "air");

    const sources = [
      {
        positionPx: { x: 8, y: 8 },
        radiusTiles: 5,
        intensity: 1,
        color: 0xffd66b,
        blocksSpawnPressure: true
      }
    ];

    const litNear = computeLightCell(world, { x: 0, y: 0 }, sources);
    const litBehindStone = computeLightCell(world, { x: 2, y: 0 }, sources);
    expect(litNear.intensity).toBeGreaterThan(litBehindStone.intensity);
  });

  it("derives HUD model without owning gameplay state", () => {
    const inventory = createInventory();
    inventory.slots[0] = { itemId: "dirt_clod", count: 4, stackCap: 99 };
    const state = buildHudState({
      health: { current: 4, max: 5, recentlyDamaged: false },
      drillHeat: { value: 0.25, overheated: false },
      inventory,
      localLightLevel: 0.3,
      playerTileY: 12,
      hostileNearby: true,
      targetTileId: "loose_dirt"
    });

    expect(state.quickSlots[0]).toMatchObject({ itemId: "dirt_clod", count: 4 });
    expect(state.targetTileName).toBe("Loose Dirt");
    expect(state.dangerPulse).toBeGreaterThan(0);
  });

  it("increases danger in darkness and near hostiles", () => {
    expect(computeDangerPulse(0.9, 0.2, false)).toBeLessThan(computeDangerPulse(0.1, 0.2, true));
  });
});

