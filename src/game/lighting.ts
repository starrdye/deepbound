import { resolveBandForTileY } from "./bands";
import { getTileDefinition } from "./tiles";
import type { ChunkStore } from "./world";
import { worldToTile } from "./world";
import type { LightCell, LightSource, TileCoord } from "./types";

function tileDistance(a: TileCoord, b: TileCoord): number {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

export function traceTileLineOfSight(world: ChunkStore, origin: TileCoord, target: TileCoord): number {
  const dx = target.x - origin.x;
  const dy = target.y - origin.y;
  const steps = Math.max(Math.abs(dx), Math.abs(dy));
  if (steps === 0) return 1;

  let visibility = 1;
  for (let i = 1; i <= steps; i++) {
    const tile = {
      x: Math.round(origin.x + (dx * i) / steps),
      y: Math.round(origin.y + (dy * i) / steps)
    };
    const def = getTileDefinition(world.getTile(tile));
    visibility -= def.lightOcclusion * 0.36;
    if (visibility <= 0) return 0;
  }

  return Math.max(0, visibility);
}

export function computeLightCell(world: ChunkStore, tile: TileCoord, sources: LightSource[]): LightCell {
  let intensity = resolveBandForTileY(tile.y).ambientLight;
  let occlusion = getTileDefinition(world.getTile(tile)).lightOcclusion;

  for (const source of sources) {
    const origin = worldToTile(source.positionPx);
    const distance = tileDistance(origin, tile);
    if (distance > source.radiusTiles) continue;
    const visibility = traceTileLineOfSight(world, origin, tile);
    const falloff = 1 - distance / source.radiusTiles;
    intensity += source.intensity * falloff * visibility;
  }

  intensity = Math.max(0, Math.min(1, intensity));
  return {
    coord: tile,
    intensity,
    visible: intensity >= 0.1,
    occlusion
  };
}

export function computeDangerPulse(localLightLevel: number, depthDanger: number, hostileNearby: boolean): number {
  const darkness = localLightLevel < 0.35 ? (0.35 - localLightLevel) / 0.35 : 0;
  return Math.max(0, Math.min(1, darkness * 0.55 + depthDanger * 0.25 + (hostileNearby ? 0.35 : 0)));
}

