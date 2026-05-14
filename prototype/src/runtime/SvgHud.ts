import type { HudState, ItemId, SvgHudModel } from "../game/types";

function itemLabel(itemId: ItemId | null): string {
  if (!itemId) return "";
  return itemId
    .split("_")
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("");
}

export class SvgHud {
  private readonly root: HTMLDivElement;

  constructor(parent: HTMLElement) {
    this.root = document.createElement("div");
    this.root.className = "hud-root";
    parent.appendChild(this.root);
  }

  update(state: HudState): void {
    const model: SvgHudModel = {
      ...state,
      width: window.innerWidth,
      height: window.innerHeight
    };

    const healthPips = Array.from({ length: model.health.max }, (_, index) => {
      const filled = index < model.health.current;
      const x = 22 + index * 18;
      const fill = filled ? "#cf5546" : "#2a1f28";
      return `<polygon points="${x},24 ${x + 7},15 ${x + 14},24 ${x + 7},34" fill="${fill}" stroke="#181724" stroke-width="2"/>`;
    }).join("");

    const slots = model.quickSlots
      .map((slot, index) => {
        const x = 22 + index * 42;
        const label = itemLabel(slot.itemId);
        const count = slot.count > 0 ? slot.count : "";
        return `
          <rect class="hud-slot" x="${x}" y="${model.height - 58}" width="34" height="34"/>
          <text class="hud-small" x="${x + 17}" y="${model.height - 38}" text-anchor="middle">${label}</text>
          <text class="hud-small" x="${x + 28}" y="${model.height - 28}" text-anchor="end">${count}</text>
        `;
      })
      .join("");

    const heatWidth = Math.round(96 * Math.max(0, Math.min(1, model.drillHeat.value)));
    const dangerAlpha = Math.max(0, Math.min(0.62, model.dangerPulse * 0.62)).toFixed(2);
    const heatFill = model.drillHeat.overheated ? "#cf5546" : "#c08b3e";

    this.root.innerHTML = `
      <svg viewBox="0 0 ${model.width} ${model.height}" preserveAspectRatio="none" aria-label="Deepbound HUD">
        <rect x="0" y="0" width="${model.width}" height="${model.height}" fill="none" stroke="#cf5546" stroke-width="18" opacity="${dangerAlpha}"/>
        <rect class="hud-panel" x="14" y="12" width="${Math.max(210, model.health.max * 18 + 26)}" height="50"/>
        ${healthPips}
        <rect class="hud-panel" x="14" y="${model.height - 68}" width="364" height="54"/>
        ${slots}
        <rect class="hud-panel" x="${model.width - 160}" y="${model.height - 66}" width="136" height="52"/>
        <text class="hud-small" x="${model.width - 146}" y="${model.height - 43}">DRILL</text>
        <rect x="${model.width - 94}" y="${model.height - 50}" width="96" height="12" fill="#161922" stroke="#4d5962" stroke-width="2"/>
        <rect x="${model.width - 94}" y="${model.height - 50}" width="${heatWidth}" height="12" fill="${heatFill}"/>
        <text class="hud-text" x="22" y="88">${model.depthLabel}</text>
        <text class="hud-small" x="22" y="108">Target: ${model.targetTileName}</text>
        <text class="hud-small" x="${model.width - 160}" y="32">Light ${Math.round(model.localLightLevel * 100)}%</text>
      </svg>
    `;
  }
}

