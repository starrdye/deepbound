import type { ChunkCoord } from "./types";

export function hashNumber(value: number): number {
  let h = value | 0;
  h ^= h >>> 16;
  h = Math.imul(h, 0x7feb352d);
  h ^= h >>> 15;
  h = Math.imul(h, 0x846ca68b);
  h ^= h >>> 16;
  return h >>> 0;
}

export function hashChunkSeed(worldSeed: number, chunk: ChunkCoord): number {
  let h = hashNumber(worldSeed);
  h ^= Math.imul(chunk.x, 0x27d4eb2d);
  h ^= Math.imul(chunk.y, 0x165667b1);
  return hashNumber(h);
}

export function hashTile(worldSeed: number, x: number, y: number): number {
  let h = hashNumber(worldSeed);
  h ^= Math.imul(x, 0x9e3779b1);
  h ^= Math.imul(y, 0x85ebca77);
  return hashNumber(h);
}

export function noise01(worldSeed: number, x: number, y: number): number {
  return hashTile(worldSeed, x, y) / 0xffffffff;
}

export function createRng(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 0xffffffff;
  };
}

export function randomInt(rng: () => number, min: number, max: number): number {
  return Math.floor(rng() * (max - min + 1)) + min;
}

