import type { BossDefinition, EnemyDefinition } from "./types";

export const STARTER_ENEMY: EnemyDefinition = {
  entityId: "cave_skitter",
  displayName: "Cave Skitter",
  bandId: "standard_caverns",
  maxHealth: 24,
  contactDamage: 8,
  speedPx: 34,
  aggroRadiusTiles: 8,
  dropTable: [{ itemId: "stone_chunk", min: 1, max: 1, chance: 0.45 }]
};

export const BAND_BOSS_ROADMAP: BossDefinition[] = [
  {
    entityId: "rootbound_foreman",
    displayName: "Rootbound Foreman",
    bandId: "standard_caverns",
    maxHealth: 420,
    contactDamage: 18,
    speedPx: 42,
    arenaWidthTiles: 42,
    phases: [
      { name: "Lantern Smash", healthRatio: 1, behavior: "breaks player light islands" },
      { name: "Collapse Orders", healthRatio: 0.5, behavior: "drops soft cave-in tiles" }
    ]
  },
  {
    entityId: "amber_queen",
    displayName: "Amber Queen",
    bandId: "colossal_ant_chambers",
    maxHealth: 760,
    contactDamage: 26,
    speedPx: 28,
    arenaWidthTiles: 52,
    requiredUnlockItem: "resin_shard",
    phases: [
      { name: "Royal Guard", healthRatio: 1, behavior: "summons soldier ants" },
      { name: "Pheromone Flood", healthRatio: 0.35, behavior: "turns safe tunnels into swarm paths" }
    ]
  }
];

