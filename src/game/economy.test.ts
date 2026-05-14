import { describe, expect, it } from "vitest";
import { computeMiningRoi, estimateResourcePerMinute } from "./economy";

describe("Band 1 economy", () => {
  it("keeps basic dirt mining quick and profitable", () => {
    const dirt = computeMiningRoi("loose_dirt");
    expect(dirt.breakSeconds).toBeLessThan(1);
    expect(dirt.valuePerSecond).toBeGreaterThan(1);
  });

  it("makes ore a higher-value but slower target", () => {
    const stone = computeMiningRoi("soft_stone");
    const copper = computeMiningRoi("copper_ore");
    expect(copper.breakSeconds).toBeGreaterThan(stone.breakSeconds);
    expect(copper.expectedValue).toBeGreaterThan(stone.expectedValue);
    expect(estimateResourcePerMinute("copper_ore")).toBeGreaterThan(estimateResourcePerMinute("loose_dirt"));
  });
});

