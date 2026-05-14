import { describe, expect, it } from "vitest";
import { SOLID_DARK_START_TILE_Y } from "./bands";
import { generateChunk, generateTileId, toChunkCoord, toLocalTile } from "./world";

describe("world generation", () => {
  it("uses floor division and positive local tile coordinates for negative space", () => {
    expect(toChunkCoord({ x: -1, y: -1 })).toEqual({ x: -1, y: -1 });
    expect(toLocalTile({ x: -1, y: -1 })).toEqual({ x: 31, y: 31 });
  });

  it("is deterministic from seed and chunk coordinates", () => {
    const a = generateChunk(42, { x: -3, y: 7 });
    const b = generateChunk(42, { x: -3, y: 7 });
    const c = generateChunk(43, { x: -3, y: 7 });
    expect(a.tiles).toEqual(b.tiles);
    expect(a.tiles).not.toEqual(c.tiles);
  });

  it("clamps the mapped descent to Solid Dark Blocks", () => {
    expect(generateTileId(42, { x: 0, y: SOLID_DARK_START_TILE_Y })).toBe("solid_dark_block");
    expect(generateTileId(42, { x: 99, y: SOLID_DARK_START_TILE_Y + 300 })).toBe("solid_dark_block");
  });
});

