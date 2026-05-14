import type { BandConfig, BandId } from "./types";

export const BAND_HEIGHT_TILES = 384;
export const SOLID_DARK_START_TILE_Y = 1920;

export const BAND_CONFIGS: Record<BandId, BandConfig> = {
  standard_caverns: {
    bandId: "standard_caverns",
    name: "Band 1: Standard Caverns",
    minTileY: 0,
    maxTileY: 383,
    palette: {
      shadow: 0x252a35,
      mid: 0x7a4b2e,
      highlight: 0xa86f3c,
      accent: 0xffd66b
    },
    hazards: ["loose cave floors", "starter skitters", "light scarcity"],
    primaryResources: ["dirt_clod", "stone_chunk", "copper_nugget"],
    ambientLight: 0.18,
    dangerRating: 1
  },
  colossal_ant_chambers: {
    bandId: "colossal_ant_chambers",
    name: "Band 2: Colossal Ant Chambers",
    minTileY: 384,
    maxTileY: 767,
    palette: {
      shadow: 0x3a2416,
      mid: 0x8f5f22,
      highlight: 0xf1b85b,
      accent: 0xf0d35e
    },
    hazards: ["pheromone swarms", "resin choke points", "soldier caste patrols"],
    primaryResources: ["resin_shard", "stone_chunk"],
    ambientLight: 0.14,
    dangerRating: 2
  },
  buried_pyramids: {
    bandId: "buried_pyramids",
    name: "Band 3: Buried Pyramids",
    minTileY: 768,
    maxTileY: 1151,
    palette: {
      shadow: 0x3a3328,
      mid: 0x9b8150,
      highlight: 0xd2b36a,
      accent: 0x3e8f74
    },
    hazards: ["pressure plates", "cursed chambers", "mummy sentries"],
    primaryResources: ["sandstone_shard", "copper_nugget"],
    ambientLight: 0.1,
    dangerRating: 3
  },
  drow_enclaves: {
    bandId: "drow_enclaves",
    name: "Band 4: Drow Enclaves",
    minTileY: 1152,
    maxTileY: 1535,
    palette: {
      shadow: 0x17142f,
      mid: 0x2d3f82,
      highlight: 0x55d6d2,
      accent: 0xb45cff
    },
    hazards: ["ambush patrols", "spore fog", "diplomacy traps"],
    primaryResources: ["glow_spore", "stone_chunk"],
    ambientLight: 0.24,
    dangerRating: 4
  },
  abyssal_lava_slums: {
    bandId: "abyssal_lava_slums",
    name: "Band 5: Abyssal Lava Rivers / Obsidian Slums",
    minTileY: 1536,
    maxTileY: 1919,
    palette: {
      shadow: 0x0d0c12,
      mid: 0x2b2026,
      highlight: 0xd94324,
      accent: 0xff8a1f
    },
    hazards: ["magma rivers", "heat pressure", "hostile slum raiders"],
    primaryResources: ["obsidian_chip", "stone_chunk"],
    ambientLight: 0.2,
    dangerRating: 5
  },
  solid_dark_blocks: {
    bandId: "solid_dark_blocks",
    name: "The Solid Dark Blocks",
    minTileY: SOLID_DARK_START_TILE_Y,
    maxTileY: null,
    palette: {
      shadow: 0x02030a,
      mid: 0x080914,
      highlight: 0x1d2038,
      accent: 0x535d8f
    },
    hazards: ["near-impenetrable mass", "light absorption", "late-game boundary pressure"],
    primaryResources: ["dark_block_sliver"],
    ambientLight: 0.02,
    dangerRating: 6
  }
};

export function resolveBandForTileY(tileY: number): BandConfig {
  if (tileY >= SOLID_DARK_START_TILE_Y) {
    return BAND_CONFIGS.solid_dark_blocks;
  }

  if (tileY < 384) return BAND_CONFIGS.standard_caverns;
  if (tileY < 768) return BAND_CONFIGS.colossal_ant_chambers;
  if (tileY < 1152) return BAND_CONFIGS.buried_pyramids;
  if (tileY < 1536) return BAND_CONFIGS.drow_enclaves;
  return BAND_CONFIGS.abyssal_lava_slums;
}

export function getDepthLabel(tileY: number): string {
  const band = resolveBandForTileY(tileY);
  if (band.bandId === "solid_dark_blocks") {
    return `${band.name} / ${tileY}m`;
  }
  const localDepth = tileY - band.minTileY;
  return `${band.name} / ${localDepth}m`;
}

