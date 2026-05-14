import { describe, expect, it } from "vitest";
import { getDepthLabel, resolveBandForTileY, SOLID_DARK_START_TILE_Y } from "./bands";

describe("band resolution", () => {
  it("maps canonical five bands and Solid Dark Blocks by tileY", () => {
    expect(resolveBandForTileY(0).bandId).toBe("standard_caverns");
    expect(resolveBandForTileY(383).bandId).toBe("standard_caverns");
    expect(resolveBandForTileY(384).bandId).toBe("colossal_ant_chambers");
    expect(resolveBandForTileY(768).bandId).toBe("buried_pyramids");
    expect(resolveBandForTileY(1152).bandId).toBe("drow_enclaves");
    expect(resolveBandForTileY(1536).bandId).toBe("abyssal_lava_slums");
    expect(resolveBandForTileY(SOLID_DARK_START_TILE_Y).bandId).toBe("solid_dark_blocks");
  });

  it("labels local band depth without losing absolute dark-block depth", () => {
    expect(getDepthLabel(390)).toContain("Band 2");
    expect(getDepthLabel(1924)).toContain("1924m");
  });
});

