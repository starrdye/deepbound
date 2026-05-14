import type { TileDefinition, TileId } from "./types";

export const TILE_DEFINITIONS: Record<TileId, TileDefinition> = {
  air: {
    tileId: "air",
    bandId: "shared",
    displayName: "Air",
    material: "air",
    hardness: Number.POSITIVE_INFINITY,
    breakable: false,
    solid: false,
    blocksLight: false,
    lightOcclusion: 0,
    color: 0x000000,
    highlight: 0x000000,
    value: 0,
    drops: []
  },
  loose_dirt: {
    tileId: "loose_dirt",
    bandId: "standard_caverns",
    displayName: "Loose Dirt",
    material: "dirt",
    hardness: 0.75,
    breakable: true,
    solid: true,
    blocksLight: true,
    lightOcclusion: 0.68,
    color: 0x7a4b2e,
    highlight: 0xa86f3c,
    value: 1,
    drops: [{ itemId: "dirt_clod", min: 1, max: 1, chance: 1 }]
  },
  compacted_dirt: {
    tileId: "compacted_dirt",
    bandId: "standard_caverns",
    displayName: "Compacted Dirt",
    material: "dirt",
    hardness: 1.2,
    breakable: true,
    solid: true,
    blocksLight: true,
    lightOcclusion: 0.76,
    color: 0x5f3d2b,
    highlight: 0x8d5a36,
    value: 1.4,
    drops: [{ itemId: "dirt_clod", min: 1, max: 2, chance: 1 }]
  },
  soft_stone: {
    tileId: "soft_stone",
    bandId: "standard_caverns",
    displayName: "Soft Stone",
    material: "stone",
    hardness: 2.1,
    breakable: true,
    solid: true,
    blocksLight: true,
    lightOcclusion: 0.94,
    color: 0x59616a,
    highlight: 0x88939a,
    value: 2.2,
    drops: [{ itemId: "stone_chunk", min: 1, max: 1, chance: 1 }]
  },
  copper_ore: {
    tileId: "copper_ore",
    bandId: "standard_caverns",
    displayName: "Copper Ore",
    material: "ore",
    hardness: 2.4,
    breakable: true,
    solid: true,
    blocksLight: true,
    lightOcclusion: 0.88,
    color: 0x6e513d,
    highlight: 0xf0a84f,
    value: 5.5,
    drops: [{ itemId: "copper_nugget", min: 1, max: 2, chance: 1 }]
  },
  hardened_resin: {
    tileId: "hardened_resin",
    bandId: "colossal_ant_chambers",
    displayName: "Hardened Resin",
    material: "resin",
    hardness: 3.8,
    breakable: true,
    solid: true,
    blocksLight: true,
    lightOcclusion: 0.35,
    color: 0x8f5f22,
    highlight: 0xf1b85b,
    value: 4,
    drops: [{ itemId: "resin_shard", min: 1, max: 1, chance: 0.9 }]
  },
  sandstone_block: {
    tileId: "sandstone_block",
    bandId: "buried_pyramids",
    displayName: "Buried Sandstone",
    material: "sandstone",
    hardness: 4.4,
    breakable: true,
    solid: true,
    blocksLight: true,
    lightOcclusion: 0.9,
    color: 0x9b8150,
    highlight: 0xd2b36a,
    value: 4.8,
    drops: [{ itemId: "sandstone_shard", min: 1, max: 2, chance: 1 }]
  },
  glow_mushroom_loam: {
    tileId: "glow_mushroom_loam",
    bandId: "drow_enclaves",
    displayName: "Glow Loam",
    material: "loam",
    hardness: 5,
    breakable: true,
    solid: true,
    blocksLight: true,
    lightOcclusion: 0.5,
    color: 0x2d3f82,
    highlight: 0x55d6d2,
    value: 6,
    drops: [{ itemId: "glow_spore", min: 1, max: 2, chance: 0.85 }]
  },
  obsidian_ash: {
    tileId: "obsidian_ash",
    bandId: "abyssal_lava_slums",
    displayName: "Obsidian Ash",
    material: "obsidian",
    hardness: 7,
    breakable: true,
    solid: true,
    blocksLight: true,
    lightOcclusion: 0.98,
    color: 0x17141a,
    highlight: 0xff5d24,
    value: 8,
    drops: [{ itemId: "obsidian_chip", min: 1, max: 1, chance: 0.9 }]
  },
  solid_dark_block: {
    tileId: "solid_dark_block",
    bandId: "solid_dark_blocks",
    displayName: "Solid Dark Block",
    material: "dark_matter",
    hardness: 9999,
    breakable: false,
    solid: true,
    blocksLight: true,
    lightOcclusion: 1,
    color: 0x050611,
    highlight: 0x222746,
    value: 0,
    drops: []
  }
};

export function getTileDefinition(tileId: TileId): TileDefinition {
  return TILE_DEFINITIONS[tileId];
}

export function isSolid(tileId: TileId): boolean {
  return getTileDefinition(tileId).solid;
}

export function isBreakable(tileId: TileId): boolean {
  return getTileDefinition(tileId).breakable;
}

