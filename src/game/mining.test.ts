import { describe, expect, it } from "vitest";
import { createInventory, countItem } from "./inventory";
import { mineTile } from "./mining";
import { ChunkStore } from "./world";

describe("mining", () => {
  it("damages and then breaks a tile into inventory drops", () => {
    const world = new ChunkStore(1);
    const inventory = createInventory();
    const target = { x: 40, y: 40 };
    world.setTile(target, "loose_dirt");

    const partial = mineTile(world, target, inventory, 0.25, 0);
    expect(partial.broke).toBe(false);
    expect(partial.progressRatio).toBeGreaterThan(0);
    expect(world.getTile(target)).toBe("loose_dirt");

    const broken = mineTile(world, target, inventory, 2, 0);
    expect(broken.broke).toBe(true);
    expect(world.getTile(target)).toBe("air");
    expect(countItem(inventory, "dirt_clod")).toBe(1);
  });

  it("leaves excess drops uncollected when inventory is full", () => {
    const world = new ChunkStore(1);
    const inventory = createInventory(1, 1);
    const target = { x: 41, y: 40 };
    world.setTile(target, "compacted_dirt");

    const broken = mineTile(world, target, inventory, 3, 0);
    expect(broken.broke).toBe(true);
    expect(countItem(inventory, "dirt_clod")).toBe(1);
    expect(broken.drops[0]?.count).toBe(1);
  });
});

