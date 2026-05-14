import type { InventoryState, ItemId } from "./types";

export function createInventory(slotCount = 24, stackCap = 99): InventoryState {
  return {
    maxSlots: slotCount,
    slots: Array.from({ length: slotCount }, () => ({
      itemId: null,
      count: 0,
      stackCap
    }))
  };
}

export function countItem(inventory: InventoryState, itemId: ItemId): number {
  return inventory.slots.reduce((sum, slot) => (slot.itemId === itemId ? sum + slot.count : sum), 0);
}

export function addToInventory(inventory: InventoryState, itemId: ItemId, count: number): number {
  let remaining = count;

  for (const slot of inventory.slots) {
    if (remaining <= 0) break;
    if (slot.itemId !== itemId || slot.count >= slot.stackCap) continue;
    const moved = Math.min(remaining, slot.stackCap - slot.count);
    slot.count += moved;
    remaining -= moved;
  }

  for (const slot of inventory.slots) {
    if (remaining <= 0) break;
    if (slot.itemId !== null) continue;
    const moved = Math.min(remaining, slot.stackCap);
    slot.itemId = itemId;
    slot.count = moved;
    remaining -= moved;
  }

  return remaining;
}

export function getQuickSlots(inventory: InventoryState, count = 8): InventoryState["slots"] {
  return inventory.slots.slice(0, count);
}

