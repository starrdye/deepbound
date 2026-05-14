export const TILE_SIZE = 16;
export const CHUNK_SIZE = 32;
export const WORLD_SEED = 133742;

export type BandId =
  | "standard_caverns"
  | "colossal_ant_chambers"
  | "buried_pyramids"
  | "drow_enclaves"
  | "abyssal_lava_slums"
  | "solid_dark_blocks";

export type TileId =
  | "air"
  | "loose_dirt"
  | "compacted_dirt"
  | "soft_stone"
  | "copper_ore"
  | "hardened_resin"
  | "sandstone_block"
  | "glow_mushroom_loam"
  | "obsidian_ash"
  | "solid_dark_block";

export type ItemId =
  | "dirt_clod"
  | "stone_chunk"
  | "copper_nugget"
  | "resin_shard"
  | "sandstone_shard"
  | "glow_spore"
  | "obsidian_chip"
  | "dark_block_sliver";

export type Vec2 = { x: number; y: number };

export interface ChunkCoord {
  x: number;
  y: number;
}

export interface TileCoord {
  x: number;
  y: number;
}

export interface ResourceDrop {
  itemId: ItemId;
  min: number;
  max: number;
  chance: number;
}

export interface TileDefinition {
  tileId: TileId;
  bandId: BandId | "shared";
  displayName: string;
  material: string;
  hardness: number;
  breakable: boolean;
  solid: boolean;
  blocksLight: boolean;
  lightOcclusion: number;
  color: number;
  highlight: number;
  value: number;
  drops: ResourceDrop[];
}

export interface BandConfig {
  bandId: BandId;
  name: string;
  minTileY: number;
  maxTileY: number | null;
  palette: {
    shadow: number;
    mid: number;
    highlight: number;
    accent: number;
  };
  hazards: string[];
  primaryResources: ItemId[];
  ambientLight: number;
  dangerRating: number;
}

export interface WorldChunk {
  coord: ChunkCoord;
  tiles: TileId[];
  generatedAtSeed: number;
}

export interface InventorySlot {
  itemId: ItemId | null;
  count: number;
  stackCap: number;
}

export interface InventoryState {
  slots: InventorySlot[];
  maxSlots: number;
}

export interface MiningResult {
  target: TileCoord;
  tileId: TileId;
  broke: boolean;
  progressRatio: number;
  drops: Array<{ itemId: ItemId; count: number }>;
  blockedReason?: string;
}

export interface EntityDefinition {
  entityId: string;
  displayName: string;
  maxHealth: number;
  contactDamage: number;
  speedPx: number;
}

export interface EnemyDefinition extends EntityDefinition {
  bandId: BandId;
  aggroRadiusTiles: number;
  dropTable: ResourceDrop[];
}

export interface BossDefinition extends EntityDefinition {
  bandId: BandId;
  arenaWidthTiles: number;
  requiredUnlockItem?: ItemId;
  phases: Array<{ name: string; healthRatio: number; behavior: string }>;
}

export interface CombatHitbox {
  ownerEntityId: string;
  originPx: Vec2;
  aimVector: Vec2;
  reachTiles: number;
  widthTiles: number;
  activeUntil: number;
  damage: number;
  tags: string[];
}

export interface DamageEvent {
  sourceEntityId: string;
  targetEntityId: string;
  amount: number;
  knockback: Vec2;
  damageType: "melee" | "drill" | "contact" | "darkness";
  invulnerabilitySeconds: number;
}

export interface LightSource {
  positionPx: Vec2;
  radiusTiles: number;
  intensity: number;
  color: number;
  blocksSpawnPressure: boolean;
}

export interface LightCell {
  coord: TileCoord;
  intensity: number;
  visible: boolean;
  occlusion: number;
}

export interface HudState {
  health: {
    current: number;
    max: number;
    recentlyDamaged: boolean;
  };
  drillHeat: {
    value: number;
    overheated: boolean;
  };
  quickSlots: Array<{
    slotIndex: number;
    itemId: ItemId | null;
    count: number;
    deltaCount: number;
  }>;
  localLightLevel: number;
  dangerPulse: number;
  depthLabel: string;
  targetTileName: string;
}

export interface SvgHudModel extends HudState {
  width: number;
  height: number;
}

