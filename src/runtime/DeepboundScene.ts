import Phaser from "phaser";
import { resolveBandForTileY } from "../game/bands";
import { STARTER_ENEMY } from "../game/enemies";
import { buildHudState } from "../game/hud";
import { createInventory, countItem } from "../game/inventory";
import { computeLightCell } from "../game/lighting";
import { findMiningTarget, mineTile, STARTER_DRILL } from "../game/mining";
import { getTileDefinition } from "../game/tiles";
import { ChunkStore, tileCenterPx, worldToTile } from "../game/world";
import { TILE_SIZE, WORLD_SEED, type InventoryState, type LightSource, type TileCoord, type TileId, type Vec2 } from "../game/types";
import { SvgHud } from "./SvgHud";
import { createPrototypeTextures } from "./textures";

type Actor = {
  position: Vec2;
  velocity: Vec2;
  onGround: boolean;
  health: number;
  maxHealth: number;
  invulnerableUntil: number;
};

type EnemyActor = Actor & {
  sprite: Phaser.GameObjects.Image;
  alive: boolean;
};

type PickupSprite = {
  sprite: Phaser.GameObjects.Image;
  velocity: Vec2;
  life: number;
};

const PLAYER_WIDTH = 14;
const PLAYER_HEIGHT = 28;
const GRAVITY = 1900;
const MAX_FALL = 520;
const MOVE_ACCEL = 1800;
const FRICTION = 2200;
const MAX_SPEED = 94;
const JUMP_VELOCITY = -410;

function justDown(key: Phaser.Input.Keyboard.Key | undefined): boolean {
  return key ? Phaser.Input.Keyboard.JustDown(key) : false;
}

export class DeepboundScene extends Phaser.Scene {
  private world = new ChunkStore(WORLD_SEED);
  private inventory: InventoryState = createInventory();
  private hud?: SvgHud;
  private playerSprite?: Phaser.GameObjects.Image;
  private player: Actor = {
    position: { x: -8 * TILE_SIZE, y: 13 * TILE_SIZE },
    velocity: { x: 0, y: 0 },
    onGround: false,
    health: 5,
    maxHealth: 5,
    invulnerableUntil: 0
  };
  private drillHeat = 0;
  private overheatedUntil = 0;
  private cursors?: Phaser.Types.Input.Keyboard.CursorKeys;
  private keys?: Record<string, Phaser.Input.Keyboard.Key>;
  private tilePool: Phaser.GameObjects.Image[] = [];
  private crackPool: Phaser.GameObjects.Image[] = [];
  private pickups: PickupSprite[] = [];
  private worldGraphics?: Phaser.GameObjects.Graphics;
  private darknessGraphics?: Phaser.GameObjects.Graphics;
  private targetGraphics?: Phaser.GameObjects.Graphics;
  private enemy?: EnemyActor;
  private targetTile: TileCoord | null = null;
  private targetTileId: TileId = "air";

  constructor() {
    super("deepbound");
  }

  create(): void {
    createPrototypeTextures(this);
    this.cameras.main.setZoom(2);
    this.cameras.main.setRoundPixels(true);

    this.worldGraphics = this.add.graphics().setDepth(-5);
    this.darknessGraphics = this.add.graphics().setDepth(10);
    this.targetGraphics = this.add.graphics().setDepth(20);
    this.playerSprite = this.add.image(this.player.position.x, this.player.position.y - PLAYER_HEIGHT / 2, "delver").setDepth(15);
    this.playerSprite.setOrigin(0.5, 0.5);

    const enemySprite = this.add.image(10 * TILE_SIZE, 13 * TILE_SIZE - 7, "cave_skitter").setDepth(14);
    this.enemy = {
      position: { x: 10 * TILE_SIZE, y: 13 * TILE_SIZE },
      velocity: { x: 0, y: 0 },
      onGround: false,
      health: STARTER_ENEMY.maxHealth,
      maxHealth: STARTER_ENEMY.maxHealth,
      invulnerableUntil: 0,
      sprite: enemySprite,
      alive: true
    };

    this.cursors = this.input.keyboard?.createCursorKeys();
    this.keys = this.input.keyboard?.addKeys("W,A,S,D,SPACE,E,F") as Record<string, Phaser.Input.Keyboard.Key>;
    this.hud = new SvgHud(this.game.canvas.parentElement ?? document.body);

    this.cameras.main.startFollow(this.playerSprite, true, 0.12, 0.12);
    this.cameras.main.setBounds(-999999, -128, 1999998, 1920 * TILE_SIZE + 320);
  }

  update(timeMs: number, deltaMs: number): void {
    const dt = Math.min(deltaMs / 1000, 1 / 30);
    const now = timeMs / 1000;
    this.updatePlayer(dt);
    this.updateMining(dt, now);
    this.updateEnemy(dt, now);
    this.updatePickups(dt);
    this.renderWorld();
    this.updateHud(now);
  }

  private updatePlayer(dt: number): void {
    const left = Boolean(this.cursors?.left.isDown || this.keys?.A.isDown);
    const right = Boolean(this.cursors?.right.isDown || this.keys?.D.isDown);
    const jump = justDown(this.cursors?.up) || justDown(this.keys?.W) || justDown(this.keys?.SPACE);

    if (left) this.player.velocity.x -= MOVE_ACCEL * dt;
    if (right) this.player.velocity.x += MOVE_ACCEL * dt;
    if (!left && !right) {
      const sign = Math.sign(this.player.velocity.x);
      const next = Math.max(0, Math.abs(this.player.velocity.x) - FRICTION * dt);
      this.player.velocity.x = next * sign;
    }
    this.player.velocity.x = Phaser.Math.Clamp(this.player.velocity.x, -MAX_SPEED, MAX_SPEED);

    if (jump && this.player.onGround) {
      this.player.velocity.y = JUMP_VELOCITY;
      this.player.onGround = false;
    }

    this.player.velocity.y = Math.min(MAX_FALL, this.player.velocity.y + GRAVITY * dt);
    this.moveActor(this.player, dt, PLAYER_WIDTH, PLAYER_HEIGHT);

    if (this.playerSprite) {
      this.playerSprite.setPosition(this.player.position.x, this.player.position.y - PLAYER_HEIGHT / 2);
      if (Math.abs(this.player.velocity.x) > 4) {
        this.playerSprite.setFlipX(this.player.velocity.x < 0);
      }
    }
  }

  private updateMining(dt: number, now: number): void {
    const pointer = this.input.activePointer;
    const origin = { x: this.player.position.x, y: this.player.position.y - 14 };
    const aim = { x: pointer.worldX - origin.x, y: pointer.worldY - origin.y };
    this.targetTile = findMiningTarget(origin, aim, this.world);
    this.targetTileId = this.targetTile ? this.world.getTile(this.targetTile) : "air";

    const drillHeld = pointer.isDown || Boolean(this.keys?.F.isDown);
    const overheated = now < this.overheatedUntil;
    if (!drillHeld || overheated) {
      this.drillHeat = Math.max(0, this.drillHeat - STARTER_DRILL.coolPerSecond * dt);
      return;
    }

    this.drillHeat = Math.min(1, this.drillHeat + STARTER_DRILL.heatPerSecond * dt);
    if (this.drillHeat >= STARTER_DRILL.overheatAt) {
      this.overheatedUntil = now + 0.7;
    }

    if (!this.targetTile) return;
    const result = mineTile(this.world, this.targetTile, this.inventory, dt, this.drillHeat);
    if (result.broke) {
      const center = tileCenterPx(result.target);
      for (const drop of result.drops) {
        if (drop.count <= 0) continue;
        const sprite = this.add.image(center.x, center.y, "pickup").setDepth(18);
        this.pickups.push({
          sprite,
          velocity: { x: Phaser.Math.Between(-30, 30), y: Phaser.Math.Between(-70, -25) },
          life: 0.55
        });
      }
    }
  }

  private updateEnemy(dt: number, now: number): void {
    if (!this.enemy || !this.enemy.alive) return;
    const enemy = this.enemy;
    const distance = Phaser.Math.Distance.Between(enemy.position.x, enemy.position.y, this.player.position.x, this.player.position.y);
    const aggroPx = STARTER_ENEMY.aggroRadiusTiles * TILE_SIZE;

    if (distance < aggroPx) {
      enemy.velocity.x += Math.sign(this.player.position.x - enemy.position.x) * STARTER_ENEMY.speedPx * 6 * dt;
      enemy.velocity.x = Phaser.Math.Clamp(enemy.velocity.x, -STARTER_ENEMY.speedPx, STARTER_ENEMY.speedPx);
    } else {
      enemy.velocity.x *= 0.92;
    }

    enemy.velocity.y = Math.min(MAX_FALL, enemy.velocity.y + GRAVITY * dt);
    this.moveActor(enemy, dt, 16, 10);
    enemy.sprite.setPosition(enemy.position.x, enemy.position.y - 6);
    enemy.sprite.setFlipX(this.player.position.x < enemy.position.x);

    if (distance < 18 && now >= this.player.invulnerableUntil) {
      this.player.health = Math.max(0, this.player.health - 1);
      this.player.invulnerableUntil = now + 0.8;
      this.player.velocity.x += Math.sign(this.player.position.x - enemy.position.x) * 150;
      this.player.velocity.y = -170;
    }

    if (justDown(this.keys?.E) && distance < 32 && now >= enemy.invulnerableUntil) {
      enemy.health -= 12;
      enemy.invulnerableUntil = now + 0.22;
      enemy.velocity.x += Math.sign(enemy.position.x - this.player.position.x) * 180;
      enemy.sprite.setTintFill(0xffffff);
      this.time.delayedCall(80, () => enemy.sprite.clearTint());
      if (enemy.health <= 0) {
        enemy.alive = false;
        enemy.sprite.setVisible(false);
      }
    }
  }

  private updatePickups(dt: number): void {
    for (const pickup of this.pickups) {
      pickup.life -= dt;
      const dx = this.player.position.x - pickup.sprite.x;
      const dy = this.player.position.y - 12 - pickup.sprite.y;
      const dist = Math.max(1, Math.hypot(dx, dy));
      pickup.velocity.x += (dx / dist) * 320 * dt;
      pickup.velocity.y += (dy / dist) * 320 * dt;
      pickup.velocity.y += 320 * dt;
      pickup.sprite.x += pickup.velocity.x * dt;
      pickup.sprite.y += pickup.velocity.y * dt;
    }

    this.pickups = this.pickups.filter((pickup) => {
      if (pickup.life <= 0) {
        pickup.sprite.destroy();
        return false;
      }
      return true;
    });
  }

  private moveActor(actor: Actor, dt: number, width: number, height: number): void {
    actor.position.x += actor.velocity.x * dt;
    if (this.actorCollides(actor, width, height)) {
      const direction = Math.sign(actor.velocity.x);
      while (this.actorCollides(actor, width, height)) {
        actor.position.x -= direction || 1;
      }
      actor.velocity.x = 0;
    }

    actor.position.y += actor.velocity.y * dt;
    actor.onGround = false;
    if (this.actorCollides(actor, width, height)) {
      const direction = Math.sign(actor.velocity.y);
      while (this.actorCollides(actor, width, height)) {
        actor.position.y -= direction || 1;
      }
      if (actor.velocity.y > 0) actor.onGround = true;
      actor.velocity.y = 0;
    }
  }

  private actorCollides(actor: Actor, width: number, height: number): boolean {
    const left = Math.floor((actor.position.x - width / 2) / TILE_SIZE);
    const right = Math.floor((actor.position.x + width / 2 - 1) / TILE_SIZE);
    const top = Math.floor((actor.position.y - height) / TILE_SIZE);
    const bottom = Math.floor((actor.position.y - 1) / TILE_SIZE);

    for (let y = top; y <= bottom; y++) {
      for (let x = left; x <= right; x++) {
        if (this.world.isSolidAt({ x, y })) return true;
      }
    }
    return false;
  }

  private renderWorld(): void {
    const camera = this.cameras.main;
    const zoom = camera.zoom;
    const view = {
      left: camera.scrollX,
      right: camera.scrollX + camera.width / zoom,
      top: camera.scrollY,
      bottom: camera.scrollY + camera.height / zoom
    };

    this.worldGraphics?.clear();
    this.worldGraphics?.fillStyle(0x090b12, 1);
    this.worldGraphics?.fillRect(view.left - 32, view.top - 32, view.right - view.left + 64, view.bottom - view.top + 64);
    this.drawParallax(view);

    const minX = Math.floor(view.left / TILE_SIZE) - 2;
    const maxX = Math.floor(view.right / TILE_SIZE) + 2;
    const minY = Math.floor(view.top / TILE_SIZE) - 2;
    const maxY = Math.floor(view.bottom / TILE_SIZE) + 2;

    let poolIndex = 0;
    let crackIndex = 0;
    for (let y = minY; y <= maxY; y++) {
      for (let x = minX; x <= maxX; x++) {
        const tileId = this.world.getTile({ x, y });
        if (tileId === "air") continue;
        const image = this.tilePool[poolIndex] ?? this.add.image(0, 0, `tile:${tileId}`).setDepth(0).setOrigin(0.5);
        this.tilePool[poolIndex] = image;
        image.setTexture(`tile:${tileId}`);
        image.setPosition(x * TILE_SIZE + 8, y * TILE_SIZE + 8);
        image.setVisible(true);
        poolIndex++;

        const damage = this.world.getDamage({ x, y });
        if (damage > 0) {
          const def = getTileDefinition(tileId);
          const stage = Phaser.Math.Clamp(Math.ceil((damage / def.hardness) * 3), 1, 3);
          const crack = this.crackPool[crackIndex] ?? this.add.image(0, 0, `crack:${stage}`).setDepth(5).setOrigin(0.5);
          this.crackPool[crackIndex] = crack;
          crack.setTexture(`crack:${stage}`);
          crack.setPosition(x * TILE_SIZE + 8, y * TILE_SIZE + 8);
          crack.setVisible(true);
          crackIndex++;
        }
      }
    }

    for (let i = poolIndex; i < this.tilePool.length; i++) this.tilePool[i].setVisible(false);
    for (let i = crackIndex; i < this.crackPool.length; i++) this.crackPool[i].setVisible(false);

    this.drawTarget();
    this.drawLighting(minX, maxX, minY, maxY);
  }

  private drawParallax(view: { left: number; right: number; top: number; bottom: number }): void {
    const graphics = this.worldGraphics;
    if (!graphics) return;
    const band = resolveBandForTileY(worldToTile(this.player.position).y);
    graphics.fillStyle(band.palette.shadow, 0.4);
    for (let i = -2; i < 9; i++) {
      const x = view.left + ((i * 132 - view.left * 0.25) % 940);
      graphics.fillEllipse(x, view.top + 120 + Math.sin(i) * 30, 120, 260);
    }
    graphics.fillStyle(band.palette.mid, 0.1);
    graphics.fillRect(view.left, view.bottom - 80, view.right - view.left, 80);
  }

  private drawTarget(): void {
    const graphics = this.targetGraphics;
    if (!graphics) return;
    graphics.clear();
    if (!this.targetTile) return;
    const x = this.targetTile.x * TILE_SIZE;
    const y = this.targetTile.y * TILE_SIZE;
    graphics.lineStyle(1, 0xffd66b, 1);
    graphics.strokeRect(x + 1, y + 1, TILE_SIZE - 2, TILE_SIZE - 2);
  }

  private drawLighting(minX: number, maxX: number, minY: number, maxY: number): void {
    const graphics = this.darknessGraphics;
    if (!graphics) return;
    graphics.clear();
    const sources: LightSource[] = [
      {
        positionPx: { x: this.player.position.x, y: this.player.position.y - 18 },
        radiusTiles: 9,
        intensity: 0.95,
        color: 0xffd66b,
        blocksSpawnPressure: true
      }
    ];

    for (let y = minY; y <= maxY; y++) {
      for (let x = minX; x <= maxX; x++) {
        const light = computeLightCell(this.world, { x, y }, sources);
        const alpha = Phaser.Math.Clamp(0.88 - light.intensity * 0.88, 0, 0.86);
        if (alpha <= 0.02) continue;
        graphics.fillStyle(0x090b12, alpha);
        graphics.fillRect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE);
      }
    }
  }

  private updateHud(now: number): void {
    const playerTile = worldToTile(this.player.position);
    const sources: LightSource[] = [
      {
        positionPx: { x: this.player.position.x, y: this.player.position.y - 18 },
        radiusTiles: 9,
        intensity: 0.95,
        color: 0xffd66b,
        blocksSpawnPressure: true
      }
    ];
    const localLight = computeLightCell(this.world, playerTile, sources).intensity;
    const hostileNearby = Boolean(this.enemy?.alive && Phaser.Math.Distance.Between(this.enemy.position.x, this.enemy.position.y, this.player.position.x, this.player.position.y) < 120);
    const state = buildHudState({
      health: {
        current: this.player.health,
        max: this.player.maxHealth,
        recentlyDamaged: now < this.player.invulnerableUntil
      },
      drillHeat: {
        value: this.drillHeat,
        overheated: now < this.overheatedUntil
      },
      inventory: this.inventory,
      localLightLevel: localLight,
      playerTileY: playerTile.y,
      hostileNearby,
      targetTileId: this.targetTileId
    });

    this.hud?.update(state);

    if (this.player.health <= 0) {
      this.player.health = this.player.maxHealth;
      this.player.position = { x: -8 * TILE_SIZE, y: 13 * TILE_SIZE };
      this.player.velocity = { x: 0, y: 0 };
    }

    if (countItem(this.inventory, "dirt_clod") + countItem(this.inventory, "stone_chunk") > 8) {
      this.cameras.main.setBackgroundColor("#0b1018");
    }
  }
}
