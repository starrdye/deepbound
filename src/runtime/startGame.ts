import Phaser from "phaser";
import { DeepboundScene } from "./DeepboundScene";

export function startGame(parentId: string): Phaser.Game {
  const config: Phaser.Types.Core.GameConfig = {
    type: Phaser.AUTO,
    parent: parentId,
    width: window.innerWidth,
    height: window.innerHeight,
    backgroundColor: "#090b12",
    pixelArt: true,
    roundPixels: true,
    scene: [DeepboundScene],
    scale: {
      mode: Phaser.Scale.RESIZE,
      autoCenter: Phaser.Scale.CENTER_BOTH
    }
  };

  return new Phaser.Game(config);
}

