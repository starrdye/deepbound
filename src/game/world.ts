import { BAND_CONFIGS, resolveBandForTileY, SOLID_DARK_START_TILE_Y } from "./bands";
import { noise01 } from "./rng";
import { getTileDefinition } from "./tiles";
import { CHUNK_SIZE, TILE_SIZE, WORLD_SEED, type ChunkCoord, type TileCoord, type TileId, type WorldChunk } from "./types";

export function floorDiv(value: number, divisor: number): number {
  return Math.floor(value / divisor);
}

export function toChunkCoord(tile: TileCoord): ChunkCoord {
  return {
    x: floorDiv(tile.x, CHUNK_SIZE),
    y: floorDiv(tile.y, CHUNK_SIZE)
  };
}

export function toLocalTile(tile: TileCoord): TileCoord {
  return {
    x: ((tile.x % CHUNK_SIZE) + CHUNK_SIZE) % CHUNK_SIZE,
    y: ((tile.y % CHUNK_SIZE) + CHUNK_SIZE) % CHUNK_SIZE
  };
}

export function chunkKey(coord: ChunkCoord): string {
  return `${coord.x},${coord.y}`;
}

export function tileKey(coord: TileCoord): string {
  return `${coord.x},${coord.y}`;
}

export function worldToTile(positionPx: { x: number; y: number }): TileCoord {
  return {
    x: Math.floor(positionPx.x / TILE_SIZE),
    y: Math.floor(positionPx.y / TILE_SIZE)
  };
}

export function tileCenterPx(tile: TileCoord): { x: number; y: number } {
  return {
    x: tile.x * TILE_SIZE + TILE_SIZE / 2,
    y: tile.y * TILE_SIZE + TILE_SIZE / 2
  };
}

function isStarterCave(tileX: number, tileY: number): boolean {
  if (tileY < 0) return true;
  const ellipse = (tileX * tileX) / (19 * 19) + ((tileY - 7) * (tileY - 7)) / (7 * 7);
  const entryShaft = Math.abs(tileX) <= 2 && tileY >= 7 && tileY <= 28;
  return ellipse <= 1 || entryShaft;
}

function isMainCavernTunnel(worldSeed: number, tileX: number, tileY: number): boolean {
  const drift = Math.sin(tileY * 0.075 + worldSeed * 0.001) * 7 + Math.sin(tileY * 0.021) * 12;
  const halfWidth = 2.7 + noise01(worldSeed, 3, Math.floor(tileY / 9)) * 2.4;
  return Math.abs(tileX - drift) <= halfWidth;
}

function isSidePocket(worldSeed: number, tileX: number, tileY: number): boolean {
  const cellX = Math.floor(tileX / 11);
  const cellY = Math.floor(tileY / 8);
  const n = noise01(worldSeed + 17, cellX, cellY);
  if (n < 0.82) return false;
  const centerX = cellX * 11 + 5;
  const centerY = cellY * 8 + 4;
  const radius = 3 + n * 3;
  return Math.hypot(tileX - centerX, (tileY - centerY) * 1.35) < radius;
}

export function generateTileId(worldSeed: number, tile: TileCoord): TileId {
  if (tile.y < 0) return "air";
  if (tile.y >= SOLID_DARK_START_TILE_Y) return "solid_dark_block";
  if (isStarterCave(tile.x, tile.y)) return "air";

  const band = resolveBandForTileY(tile.y);
  if (isMainCavernTunnel(worldSeed, tile.x, tile.y) || isSidePocket(worldSeed, tile.x, tile.y)) {
    return "air";
  }

  const localNoise = noise01(worldSeed, tile.x, tile.y);
  const veinNoise = noise01(worldSeed + 222, Math.floor(tile.x / 3), Math.floor(tile.y / 3));

  switch (band.bandId) {
    case "standard_caverns":
      if (tile.y > 36 && veinNoise > 0.965) return "copper_ore";
      if (tile.y < 96) return localNoise > 0.7 ? "compacted_dirt" : "loose_dirt";
      if (tile.y < 240) return localNoise > 0.42 ? "soft_stone" : "compacted_dirt";
      return localNoise > 0.25 ? "soft_stone" : "compacted_dirt";
    case "colossal_ant_chambers":
      return localNoise > 0.42 ? "hardened_resin" : "compacted_dirt";
    case "buried_pyramids":
      return "sandstone_block";
    case "drow_enclaves":
      return localNoise > 0.62 ? "glow_mushroom_loam" : "soft_stone";
    case "abyssal_lava_slums":
      return localNoise > 0.2 ? "obsidian_ash" : "soft_stone";
    default:
      return "solid_dark_block";
  }
}

export function generateChunk(worldSeed: number, coord: ChunkCoord): WorldChunk {
  const tiles: TileId[] = [];
  for (let localY = 0; localY < CHUNK_SIZE; localY++) {
    for (let localX = 0; localX < CHUNK_SIZE; localX++) {
      const tile = {
        x: coord.x * CHUNK_SIZE + localX,
        y: coord.y * CHUNK_SIZE + localY
      };
      tiles.push(generateTileId(worldSeed, tile));
    }
  }

  return {
    coord,
    tiles,
    generatedAtSeed: worldSeed
  };
}

export class ChunkStore {
  readonly worldSeed: number;
  private readonly chunks = new Map<string, WorldChunk>();
  private readonly overrides = new Map<string, TileId>();
  private readonly damage = new Map<string, number>();

  constructor(worldSeed = WORLD_SEED) {
    this.worldSeed = worldSeed;
  }

  getChunk(coord: ChunkCoord): WorldChunk {
    const key = chunkKey(coord);
    const existing = this.chunks.get(key);
    if (existing) return existing;
    const generated = generateChunk(this.worldSeed, coord);
    this.chunks.set(key, generated);
    return generated;
  }

  getTile(tile: TileCoord): TileId {
    const override = this.overrides.get(tileKey(tile));
    if (override) return override;

    const chunk = this.getChunk(toChunkCoord(tile));
    const local = toLocalTile(tile);
    return chunk.tiles[local.y * CHUNK_SIZE + local.x];
  }

  setTile(tile: TileCoord, tileId: TileId): void {
    this.overrides.set(tileKey(tile), tileId);
    this.damage.delete(tileKey(tile));
  }

  getDamage(tile: TileCoord): number {
    return this.damage.get(tileKey(tile)) ?? 0;
  }

  setDamage(tile: TileCoord, progress: number): void {
    this.damage.set(tileKey(tile), progress);
  }

  clearDamage(tile: TileCoord): void {
    this.damage.delete(tileKey(tile));
  }

  isSolidAt(tile: TileCoord): boolean {
    return getTileDefinition(this.getTile(tile)).solid;
  }
}

export function getDepthDanger(tileY: number): number {
  return resolveBandForTileY(tileY).dangerRating / BAND_CONFIGS.solid_dark_blocks.dangerRating;
}

