# Deepbound Sprint 2: The Infinite Deep and Autotiling

Source references:
- `Docs/Deepbound_Game_Design.md`
- `Docs/Deepbound_Art_Bible.md`
- `Docs/Sprints/Sprint_1_Core_Foundation.md`

Sprint focus: horizontally unbounded signed chunk generation, the first depth-to-Band transition, and a 47-tile bitmask autotiling pipeline that keeps fully destructible terrain readable after every excavation.

## Agent Stand-Up

**Agent 1: The Game Designer.** I define generation rules, biome pacing, ore placement, and the way excavation reshapes the playable world.

**Agent 2: The Pixel Art Designer.** I define the terrain atlas, organic resin visuals, glowing ore contrast, background walls, and parallax depth language.

**Agent 3: The Programmer and Code Reviewer.** I turn the generation and autotile rules into deterministic TypeScript-ready systems that scale downward forever.

**Agent 4: The Player Persona.** I judge whether the descent feels deeper, stranger, and more readable rather than simply more crowded.

## Agent 1: Game Designer

### Sprint 2 Player Promise

After Sprint 2, the player should be able to drill beyond the starter cave and feel the world change. The terrain should generate deterministically in signed chunks, caverns should remain navigable, the Colossal Ant Chambers should emerge as Band 2, and every broken block should visually reconnect through autotiling.

### Core World Rules

- Tile size: `16x16 px`
- Chunk size: `32x32 tiles`
- Chunk coordinates: signed integers, with `chunkY` increasing downward
- Tile coordinates: signed integers, with `tileY` increasing downward
- Horizontal chunking remains unbounded
- Vertical generation follows five mapped Bands and clamps to Solid Dark Blocks at `tileY >= 1920`
- Generation must be deterministic from `worldSeed`, `chunkX`, and `chunkY`
- Chunks generate independently but may sample a one-tile neighbor margin for seams
- Foreground terrain, background walls, ores, and decorative decals are separate layers

Depth bands:

| Band | Tile Y Range | Biome Weight | Purpose |
| --- | ---: | --- | --- |
| Surface Crust | `-64` to `-1` | barren crust | Spawn cap and return landmark only |
| Standard Caverns | `0` to `383` | dirt, stone, open caves | Sprint 1 terrain extended into a real world |
| Ant Transition | `320` to `383` | 60% caverns, 40% ant influence | Warm palette shift, first resin seams |
| Colossal Ant Chambers | `384` to `767` | resin, excavated earth, large rooms | First signature biome and resource fantasy |
| Buried Pyramids | `768` to `1151` | sandstone, tomb rooms | Trap-heavy Band 3 |
| Drow Enclaves | `1152` to `1535` | glow flora, shadow cities | Diplomacy and ambush Band 4 |
| Abyssal Lava Rivers / Obsidian Slums | `1536` to `1919` | obsidian, lava, settlements | Heat and endgame Band 5 |
| Solid Dark Blocks | `1920+` | ultra-dense dark matter | Late-game boundary |

Biome pacing:
- The first ant visual hint appears no earlier than `tileY = 320`.
- The first full ant chamber room appears no earlier than `tileY = 384`.
- Transition chunks must contain normal stone/dirt anchors so the shift feels discovered, not teleported.
- A player descending at early-game speed should see the full transition over roughly `2-4 minutes`.

### Generation Pipeline

Chunk generation runs in this order:
1. Compute deterministic chunk seed.
2. Evaluate biome weights from depth and low-frequency noise.
3. Create base mass from density noise.
4. Carve standard cavern tunnels.
5. Blend ant chamber tunnels and rooms when ant weight is present.
6. Place material layers: dirt, compacted dirt, soft stone, excavated earth, hardened resin.
7. Place glowing ores and resin nodules.
8. Fill background walls behind solid and near-solid regions.
9. Add decorative decals: roots, resin veins, small shell fragments, pheromone streaks.
10. Compute initial 47-tile autotile variants for visible foreground tiles.

Base density:

```txt
depthPressure = clamp(tileY / 900, 0, 1)
cavernNoise = fbm(tileX * 0.035, tileY * 0.035, octaves = 4)
fineNoise = fbm(tileX * 0.11, tileY * 0.11, octaves = 2)
solidThreshold = 0.43 + depthPressure * 0.08
isSolid = cavernNoise + fineNoise * 0.18 > solidThreshold
```

Standard cavern carving:
- Carve long downward-biased worm tunnels with radius `2-5 tiles`.
- Add occasional horizontal connectors every `3-5 chunks` vertically.
- Never allow a generated chunk to be fully solid if it overlaps the player's active descent corridor.
- Keep at least one navigable opening crossing the top or side of most early chunks.

Colossal Ant Chambers:
- Chamber rooms are rounded cavities with radii from `8-22 tiles`.
- Major tunnels use radius `3-6 tiles` and bend smoothly.
- Pheromone paths run along tunnel floors and walls as decal strips.
- Hardened resin appears as structural ribs and sealed pockets.
- Royal jelly pockets are reserved for a later sprint but their placeholder cavity rules are defined now.

Ant influence formula:

```txt
depthBlend = smoothstep(320, 384, tileY)
organicNoise = fbm(tileX * 0.018 + 73, tileY * 0.018 - 29, 3)
antWeight = clamp(depthBlend * 0.82 + organicNoise * 0.18, 0, 1)
```

### Material Placement

Standard caverns:
- `loose_dirt`: dominant near `tileY 0-127`
- `compacted_dirt`: dominant near `tileY 128-255`
- `soft_stone`: dominant from `tileY 192+`

Ant transition:
- `excavated_earth`: replaces some compacted dirt at `antWeight >= 0.25`
- `hardened_resin`: appears as thin seams at `antWeight >= 0.35`
- `amber_glow_ore`: rare high-contrast lure at `antWeight >= 0.45`

Ant chambers:
- `hardened_resin`: walls, ribs, sealed pockets
- `excavated_earth`: tunnel interiors and packed floors
- `soft_stone`: occasional cold anchor blocks to preserve contrast
- `amber_glow_ore`: visible but not spammed; used to pull attention through darkness

Ore placement rules:
- Ores use a separate replacement pass over solid foreground tiles.
- Glowing ores must not form more than `8%` of visible solid tiles in any single screen.
- Place ore clusters with a `3-7 tile` radius, then remove noisy singletons.
- Ore clusters should prefer chamber edges and tunnel bends.

## Required Schemas

```ts
type Vec2 = { x: number; y: number };

interface ChunkCoord {
  x: number;
  y: number;
}

interface TileCoord {
  x: number;
  y: number;
}

type BiomeId =
  | "surface_crust"
  | "standard_caverns"
  | "ant_transition"
  | "colossal_ant_chambers"
  | "buried_pyramids"
  | "drow_enclaves"
  | "abyssal_lava_slums"
  | "solid_dark_blocks";

interface BiomeBand {
  biomeId: BiomeId;
  minTileY: number;
  maxTileY: number | null;
  primaryMaterials: string[];
  ambientLight: string;
  dangerRating: number;
}

interface ChunkGenerationContext {
  worldSeed: number;
  chunk: ChunkCoord;
  chunkSize: 32;
  tileYDownIsPositive: true;
  neighborMarginTiles: number;
  biomeWeights: Record<BiomeId, number>;
}

interface AutotileMask {
  north: boolean;
  east: boolean;
  south: boolean;
  west: boolean;
  northEast: boolean;
  southEast: boolean;
  southWest: boolean;
  northWest: boolean;
  canonicalIndex: number;
  atlasTileId: number;
}

interface TileDefinition {
  tileId: string;
  material: "dirt" | "compactedDirt" | "stone" | "excavatedEarth" | "resin" | "ore" | "air";
  hardness: number;
  breakable: boolean;
  solid: boolean;
  blocksLight: boolean;
  connectsTo: string[];
  biomeTags: BiomeId[];
  autotileSetId?: string;
  glowRadiusTiles?: number;
  drops: DropTableEntry[];
}

interface ParallaxLayerSpec {
  layerId: string;
  depthOrder: number;
  scrollScale: Vec2;
  opacity: number;
  paletteKey: string;
  tileRepeatPx: Vec2;
  biomeTags: BiomeId[];
}

interface OreSpawnRule {
  oreTileId: string;
  minTileY: number;
  maxTileY: number | null;
  clusterRadiusTiles: [number, number];
  clusterChancePerChunk: number;
  maxVisibleCoverageRatio: number;
  validHostMaterials: string[];
  glowColor: string;
}
```

## Agent 2: Pixel Art Designer

### Visual Intent

Sprint 2 must prove the Art Bible's descent pillar. The player starts in familiar brown and gray caverns, then notices warmth, translucency, and living shapes before entering the Colossal Ant Chambers. The transition should be attractive and legible, not muddy.

### Palette Expansion

| Use | Hex |
| --- | --- |
| Excavated earth shadow | `#3f2a20` |
| Excavated earth mid | `#7d5132` |
| Excavated earth highlight | `#b17b45` |
| Resin deep shadow | `#3a2416` |
| Resin body amber | `#8f5f22` |
| Resin translucent mid | `#c98633` |
| Resin wet highlight | `#f1b85b` |
| Pheromone yellow | `#f0d35e` |
| Amber ore core | `#ffe07a` |
| Amber ore aura | `#f6a63f` |
| Deep background brown | `#211b1d` |
| Far chamber violet shadow | `#292334` |

Rules:
- Resin is warm and organic, but it must not collapse into the same value range as dirt.
- Glowing ore cores are the brightest Sprint 2 terrain pixels.
- Background walls stay lower saturation and lower contrast than foreground.
- Pheromone decals should be readable as stripes, not text or icons.

### 47-Tile Autotile Atlas

Each material family that connects to itself uses a `47` tile canonical atlas. The atlas is authored on a `16x16 px` grid, arranged as `8 columns x 6 rows`, with one unused/debug slot.

Atlas groups:
- Row 0: isolated, solid fill, cardinal caps, single edges
- Row 1: outside corners
- Row 2: inside corners
- Row 3: edge plus corner combinations
- Row 4: tunnels, pillars, vertical shafts, horizontal bridges
- Row 5: rare diagonals, organic variants, one debug placeholder

Corner gating:
- A diagonal neighbor only contributes if both adjacent cardinal neighbors exist.
- Example: `northEast` is valid only when `north && east` are true.
- This prevents impossible diagonal blobs and keeps carved tunnels crisp.

Material-specific treatment:
- Dirt: crumbly edges, small pebble clusters, no outline.
- Stone: angular edges, cooler shadows, restrained crack detail.
- Excavated earth: smoother ant-carved curves, warmer compressed layers.
- Resin: rounded, glossy edge shapes with 1-2 pixel translucent highlights.

### Resin Tile Art Specs

Hardened resin:
- Base shape: organic rounded masses, never perfect squares.
- Edge highlight: wet amber rim on exposed sides.
- Interior: cloudy amber gradients made from pixel clusters, not smooth blur.
- Break overlay: bright fracture lines that look like cracked candy glass.
- Transparency impression: use internal lighter shapes offset from outer highlight, not actual alpha in foreground tile.

Excavated earth:
- Softer than stone and more compact than dirt.
- Add 1px curved scrape marks from ant mandibles.
- Use darker packed-floor variants for chamber floors.

Pheromone decals:
- Thin yellow-orange streaks on background walls and resin ribs.
- Render as non-colliding decals so autotile edges remain clean.

### Glowing Ore Specs

Amber glow ore:
- Native tile: `16x16 px`
- Core: 2-5 pixel bright cluster using `#ffe07a`
- Aura pixels: `#f6a63f` and `#f1b85b` around the core
- Host cracks: dark resin or stone lines framing the glow
- Glow map: separate mask with radius metadata, not baked into the tile image

Ore readability:
- At `300%` scale, the ore must be identifiable in a screenshot with the player lamp off.
- No ore sprite may use the same highlight color as normal resin wet highlights without a brighter core.

### Background and Parallax

Background wall tiles:
- Use the same biome material language at `45-65%` value and `50-70%` saturation.
- Remove sharp edge contrast.
- Add broad shapes, not noisy texture.

Parallax layers:

| Layer | Scroll Scale | Visual Content | Opacity |
| --- | --- | --- | ---: |
| Near wall | `0.82, 0.90` | dark wall silhouettes, roots, resin ribs | `0.70` |
| Mid void | `0.55, 0.68` | large cavern openings, ant tunnel silhouettes | `0.45` |
| Far chamber | `0.32, 0.42` | colossal room arcs and hanging resin | `0.30` |
| Deep haze | `0.15, 0.22` | subtle warmth and tiny ore glints | `0.18` |

Parallax must be full-width and unframed. The game should never feel like a flat tile grid pasted over a static wall.

## Agent 3: Programmer and Code Reviewer

### System Boundaries

Recommended systems:
- `ChunkGenerator`
- `BiomeResolver`
- `CavernCarver`
- `AntChamberCarver`
- `OrePlacementSystem`
- `AutotileSystem`
- `ChunkRenderCache`
- `ParallaxResolver`

### Deterministic Seeds

Chunk seeds must be stable and independent of generation order.

```ts
function hashChunkSeed(worldSeed: number, chunk: ChunkCoord): number {
  let h = worldSeed | 0;
  h ^= Math.imul(chunk.x, 0x27d4eb2d);
  h ^= Math.imul(chunk.y, 0x165667b1);
  h ^= h >>> 15;
  h = Math.imul(h, 0x85ebca6b);
  h ^= h >>> 13;
  return h >>> 0;
}
```

Generation flow:

```ts
function generateChunk(ctx: ChunkGenerationContext): GeneratedChunk {
  const rng = createRng(hashChunkSeed(ctx.worldSeed, ctx.chunk));
  const tiles = createFilledLayer("soft_stone", ctx.chunkSize, ctx.chunkSize);
  const walls = createFilledLayer("cavern_wall", ctx.chunkSize, ctx.chunkSize);

  applyBaseDensity(tiles, ctx);
  carveStandardCaverns(tiles, walls, ctx, rng);

  if (ctx.biomeWeights.ant_transition > 0 || ctx.biomeWeights.colossal_ant_chambers > 0) {
    carveAntChambers(tiles, walls, ctx, rng);
    applyAntMaterials(tiles, walls, ctx, rng);
  } else {
    applyStandardMaterials(tiles, walls, ctx, rng);
  }

  placeOres(tiles, ctx, rng);
  placeDecorDecals(walls, ctx, rng);
  const autotiles = computeChunkAutotiles(tiles, ctx);

  return { coord: ctx.chunk, tiles, walls, autotiles };
}
```

Biome resolution:

```ts
function resolveBiomeWeights(tileY: number, worldSeed: number, tileX: number): Record<BiomeId, number> {
  const antDepth = smoothstep(320, 384, tileY);
  const lateralVariation = noise2(worldSeed, tileX * 0.01, tileY * 0.01) * 0.18;
  const ant = clamp(antDepth + lateralVariation, 0, 1);

  return {
    surface_crust: tileY < 0 ? 1 : 0,
    standard_caverns: clamp(1 - ant, 0, 1),
    ant_transition: tileY >= 320 && tileY < 384 ? clamp(1 - Math.abs(ant - 0.5) * 2, 0, 1) : 0,
    colossal_ant_chambers: tileY >= 384 && tileY < 768 ? ant : 0,
    buried_pyramids: tileY >= 768 && tileY < 1152 ? 1 : 0,
    drow_enclaves: tileY >= 1152 && tileY < 1536 ? 1 : 0,
    abyssal_lava_slums: tileY >= 1536 && tileY < 1920 ? 1 : 0,
    solid_dark_blocks: tileY >= 1920 ? 1 : 0
  };
}
```

### 47-Tile Autotiling

Autotile connection rule:
- A tile connects to neighbors when the neighbor tile id is included in `tileDef.connectsTo`.
- Air never connects.
- Ores connect visually to their host material only if rendered as embedded ore variants.
- Background walls use a separate lower-detail autotile set.

Mask computation:

```ts
function computeAutotileMask(tile: TileCoord, store: TileReadStore): AutotileMask {
  const center = store.getTile(tile);
  const def = TileDefs[center];

  const north = connects(def, store.getTile({ x: tile.x, y: tile.y - 1 }));
  const east = connects(def, store.getTile({ x: tile.x + 1, y: tile.y }));
  const south = connects(def, store.getTile({ x: tile.x, y: tile.y + 1 }));
  const west = connects(def, store.getTile({ x: tile.x - 1, y: tile.y }));

  return {
    north,
    east,
    south,
    west,
    northEast: north && east && connects(def, store.getTile({ x: tile.x + 1, y: tile.y - 1 })),
    southEast: south && east && connects(def, store.getTile({ x: tile.x + 1, y: tile.y + 1 })),
    southWest: south && west && connects(def, store.getTile({ x: tile.x - 1, y: tile.y + 1 })),
    northWest: north && west && connects(def, store.getTile({ x: tile.x - 1, y: tile.y - 1 })),
    canonicalIndex: 0,
    atlasTileId: 0
  };
}
```

Dirty update rule after excavation:

```ts
function markAutotileDirtyAfterTileChange(tile: TileCoord, dirty: DirtyTileSet): void {
  for (let dy = -1; dy <= 1; dy++) {
    for (let dx = -1; dx <= 1; dx++) {
      dirty.add({ x: tile.x + dx, y: tile.y + dy });
    }
  }
}
```

Performance notes:
- Only recompute dirty `3x3` neighborhoods after tile changes.
- Chunk render caches are invalidated per changed chunk, not globally.
- Generation must not scan vertical history. Depth rules are functions of coordinate and seed.
- Neighbor seam reads should sample generated margins or a read-through chunk cache, never mutate adjacent chunks during generation.
- Store tile ids as compact numbers internally; keep string ids at authoring boundaries.

### Code Review Risks

- Negative chunk coordinates must keep using true floor division from Sprint 1.
- Do not let decorative resin decals influence collision or autotile masks.
- Do not overuse glowing ore. If every tile glows, the darkness system in Sprint 3 loses impact.
- Avoid per-frame full-chunk autotile recomputation. Excavation will happen constantly.
- Biome transitions need deterministic blending. Do not use runtime random calls outside seeded generation.

## Agent 4: Player Persona

### First-Pass Player Review

This sprint starts to make Deepbound feel like its own game. The key win is that the first real biome is not just a recolor. Resin ribs, ant-carved tunnels, pheromone streaks, and giant rounded chambers sound like a place with an ecology.

The risk is visual soup. Brown dirt, amber resin, yellow pheromones, and glowing ore can collapse into one warm smear if the values are too close. The stone anchors and bright ore cores are essential.

The transition pacing is promising. Seeing hints around `tileY 320`, then a full chamber past `384`, gives the player time to wonder what is below. If the game throws resin everywhere too early, the descent loses drama.

Autotiling is invisible when it works and ugly when it fails. Broken blocks need clean edges immediately. A single wrong diagonal corner after drilling will be more noticeable than a missing decorative decal.

Parallax is a major attractiveness multiplier. The game needs to feel like there is a huge space behind the playable layer, especially in ant chambers.

### Player Demands Before Sprint 2 Is Accepted

- I need to recognize the biome transition before entering the full ant chambers.
- Glowing ores must pop without turning the whole biome into a yellow wash.
- Drilled tunnel edges must reconnect cleanly every time.
- Background parallax must imply massive underground scale.
- Ant chamber rooms must feel navigable, not like random blobs.

## Final Revisions

The following revisions are accepted after Player Persona feedback:

1. Standard stone remains as a cool-value anchor inside ant transition chunks.
2. Glowing ore coverage is capped per screen and uses brighter cores than resin highlights.
3. Full Colossal Ant Chambers begin at `tileY >= 384`, with visual hints beginning near `tileY = 320`.
4. Autotile updates recompute the changed tile and its `3x3` neighborhood immediately after destruction.
5. Parallax layers are required for ant chambers, not optional polish.

## Sprint 2 Acceptance Criteria

- Chunks use signed `32x32` coordinates with `tileY` increasing downward.
- Generation is deterministic from `worldSeed`, `chunkX`, and `chunkY`.
- Standard caverns generate from `tileY 0-383`.
- Ant transition appears from `tileY 320-383`.
- Colossal Ant Chambers appear from `tileY 384-767`.
- Vertical generation clamps to Solid Dark Blocks at `tileY >= 1920`.
- Resin, excavated earth, pheromone decals, and amber glowing ores are specified.
- 47-tile autotiling uses 8-neighbor masks with cardinal-gated corners.
- Excavation marks a `3x3` dirty autotile neighborhood.
- Background walls are darker and lower saturation than foreground blocks.
- Parallax includes `3-5` layers with defined scroll scaling.
- Player review concerns are resolved in final revisions.

## Out Of Scope For Sprint 2

- Combat and hostile ecology
- Dynamic line-of-sight lighting
- Full royal jelly economy
- Ant queen or soldier caste encounters
- Surface base building and automation
- Runtime asset export or playable engine code

## Prototype Build Order

1. Extend the Sprint 1 tile store to generate signed `32x32` chunks on demand.
2. Implement depth band and biome weight resolution.
3. Add standard cavern generation and deterministic seeded noise.
4. Add ant transition and Colossal Ant Chambers generation.
5. Add material replacement, glowing ore rules, background wall rules, and decor decals.
6. Implement 47-tile mask computation and dirty-neighborhood updates.
7. Add parallax resolver data for cavern and ant chamber backgrounds.
8. Run visual checks at `tileY 320`, `384`, `768`, `1152`, `1536`, and `1920`.
