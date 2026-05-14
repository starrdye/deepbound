import Phaser from "phaser";
import { TILE_DEFINITIONS } from "../game/tiles";
import type { TileId } from "../game/types";

function canvasTexture(scene: Phaser.Scene, key: string, width: number, height: number, draw: (ctx: CanvasRenderingContext2D) => void): void {
  if (scene.textures.exists(key)) return;
  const texture = scene.textures.createCanvas(key, width, height);
  if (!texture) return;
  const ctx = texture.getContext();
  ctx.imageSmoothingEnabled = false;
  ctx.clearRect(0, 0, width, height);
  draw(ctx);
  texture.refresh();
}

function colorHex(value: number): string {
  return `#${value.toString(16).padStart(6, "0")}`;
}

function drawTile(ctx: CanvasRenderingContext2D, tileId: TileId): void {
  const def = TILE_DEFINITIONS[tileId];
  const base = colorHex(def.color);
  const hi = colorHex(def.highlight);
  ctx.fillStyle = base;
  ctx.fillRect(0, 0, 16, 16);

  if (tileId === "solid_dark_block") {
    ctx.fillStyle = "#02030a";
    ctx.fillRect(0, 0, 16, 16);
    ctx.fillStyle = "#1d2038";
    ctx.fillRect(2, 2, 2, 2);
    ctx.fillRect(12, 11, 2, 3);
    ctx.fillStyle = "#080914";
    ctx.fillRect(4, 5, 8, 7);
    return;
  }

  ctx.fillStyle = "rgba(0, 0, 0, 0.22)";
  ctx.fillRect(0, 12, 16, 4);
  ctx.fillStyle = hi;
  ctx.fillRect(2, 2, 4, 2);
  ctx.fillRect(10, 5, 3, 2);

  if (tileId.includes("dirt")) {
    ctx.fillStyle = "#3b2b22";
    ctx.fillRect(4, 8, 2, 1);
    ctx.fillRect(11, 11, 3, 1);
  }

  if (tileId === "soft_stone") {
    ctx.fillStyle = "#303642";
    ctx.fillRect(2, 11, 7, 1);
    ctx.fillRect(8, 4, 5, 1);
  }

  if (tileId === "copper_ore") {
    ctx.fillStyle = "#ffd66b";
    ctx.fillRect(5, 5, 2, 2);
    ctx.fillRect(10, 9, 3, 2);
    ctx.fillStyle = "#f0a84f";
    ctx.fillRect(7, 6, 1, 1);
  }
}

export function createPrototypeTextures(scene: Phaser.Scene): void {
  (Object.keys(TILE_DEFINITIONS) as TileId[]).forEach((tileId) => {
    if (tileId === "air") return;
    canvasTexture(scene, `tile:${tileId}`, 16, 16, (ctx) => drawTile(ctx, tileId));
  });

  canvasTexture(scene, "delver", 24, 32, (ctx) => {
    ctx.fillStyle = "#181724";
    ctx.fillRect(7, 2, 10, 8);
    ctx.fillRect(5, 10, 14, 13);
    ctx.fillRect(4, 18, 6, 11);
    ctx.fillRect(14, 18, 6, 11);
    ctx.fillStyle = "#61717d";
    ctx.fillRect(8, 5, 8, 5);
    ctx.fillRect(7, 12, 10, 10);
    ctx.fillStyle = "#a9b7ba";
    ctx.fillRect(9, 6, 5, 2);
    ctx.fillStyle = "#774f33";
    ctx.fillRect(6, 21, 5, 7);
    ctx.fillRect(13, 21, 5, 7);
    ctx.fillStyle = "#c08b3e";
    ctx.fillRect(16, 4, 4, 3);
    ctx.fillStyle = "#ffd66b";
    ctx.fillRect(20, 5, 2, 1);
    ctx.fillStyle = "#4d5962";
    ctx.fillRect(17, 14, 6, 3);
    ctx.fillRect(21, 13, 3, 5);
  });

  canvasTexture(scene, "cave_skitter", 20, 12, (ctx) => {
    ctx.fillStyle = "#20151d";
    ctx.fillRect(2, 3, 16, 7);
    ctx.fillStyle = "#8b4650";
    ctx.fillRect(4, 4, 12, 5);
    ctx.fillStyle = "#c27a61";
    ctx.fillRect(12, 5, 3, 2);
    ctx.fillStyle = "#e8d5a1";
    ctx.fillRect(16, 4, 2, 1);
    ctx.fillRect(17, 7, 2, 1);
    ctx.strokeStyle = "#20151d";
    ctx.beginPath();
    ctx.moveTo(5, 9);
    ctx.lineTo(2, 12);
    ctx.moveTo(10, 9);
    ctx.lineTo(10, 12);
    ctx.moveTo(14, 9);
    ctx.lineTo(18, 12);
    ctx.stroke();
  });

  canvasTexture(scene, "pickup", 8, 8, (ctx) => {
    ctx.fillStyle = "#181724";
    ctx.fillRect(1, 1, 6, 6);
    ctx.fillStyle = "#d6b071";
    ctx.fillRect(2, 2, 4, 4);
    ctx.fillStyle = "#ffd66b";
    ctx.fillRect(4, 2, 1, 1);
  });

  for (let stage = 1; stage <= 3; stage++) {
    canvasTexture(scene, `crack:${stage}`, 16, 16, (ctx) => {
      ctx.strokeStyle = stage === 3 ? "#ffe0a1" : "#d6b071";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(8, 2);
      ctx.lineTo(7, 7);
      ctx.lineTo(10, 12);
      if (stage >= 2) {
        ctx.moveTo(7, 7);
        ctx.lineTo(3, 9);
        ctx.moveTo(9, 9);
        ctx.lineTo(13, 7);
      }
      if (stage >= 3) {
        ctx.moveTo(10, 12);
        ctx.lineTo(5, 15);
        ctx.moveTo(7, 5);
        ctx.lineTo(12, 3);
      }
      ctx.stroke();
    });
  }
}

