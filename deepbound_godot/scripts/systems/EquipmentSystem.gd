extends RefCounted
class_name EquipmentSystem

const EquipmentCatalog = preload("res://scripts/catalogs/EquipmentCatalog.gd")

## Manages the 7 equipment slots as a separate data structure from the main
## inventory.  Emits equipment_changed whenever a slot is modified so that
## StatCalculator can recompute derived stats.
##
## Slot IDs: weapon | head | body | legs | feet | accessory | utility

signal equipment_changed

const SLOT_IDS: Array[String] = [
	"weapon", "head", "body", "legs", "feet", "accessory", "utility"
]

## Keyed by slot_id → item_id string ("" = empty)
var _slots: Dictionary = {}

func _init() -> void:
	for slot_id in SLOT_IDS:
		_slots[slot_id] = ""

# ── Queries ───────────────────────────────────────────────────────────────────

func get_item(slot_id: String) -> String:
	return String(_slots.get(slot_id, ""))

func is_slot_empty(slot_id: String) -> bool:
	return get_item(slot_id) == ""

func all_slots() -> Dictionary:
	return _slots.duplicate()

## Returns the slot_id that item_id occupies, or "" if not equipped.
func find_item_slot(item_id: String) -> String:
	if item_id == "":
		return ""
	for slot_id in SLOT_IDS:
		if String(_slots.get(slot_id, "")) == item_id:
			return slot_id
	return ""

# ── Mutations ─────────────────────────────────────────────────────────────────

## Equip item_id into the matching slot.  Returns the item that was displaced
## ("" if the slot was empty), or returns item_id unchanged if the item cannot
## be equipped (not in EquipmentCatalog or wrong slot requested).
##
## If force_slot is "" the correct slot is looked up from EquipmentCatalog.
func equip(item_id: String, force_slot: String = "") -> String:
	if item_id == "" or not EquipmentCatalog.is_equippable(item_id):
		return item_id

	var target_slot := force_slot if force_slot != "" else EquipmentCatalog.get_slot_for_item(item_id)
	if target_slot == "" or not _slots.has(target_slot):
		return item_id

	var displaced := String(_slots.get(target_slot, ""))
	_slots[target_slot] = item_id
	equipment_changed.emit()
	return displaced

## Unequip the item in slot_id.  Returns the item that was there ("" if empty).
func unequip(slot_id: String) -> String:
	if not _slots.has(slot_id):
		return ""
	var removed := String(_slots.get(slot_id, ""))
	_slots[slot_id] = ""
	if removed != "":
		equipment_changed.emit()
	return removed

## Unequip by item_id regardless of slot.  Returns true if item was found.
func unequip_item(item_id: String) -> bool:
	var slot_id := find_item_slot(item_id)
	if slot_id == "":
		return false
	_slots[slot_id] = ""
	equipment_changed.emit()
	return true

## Swap: place incoming_item into slot_id, return whatever was there.
## Returns incoming_item unchanged if the swap is invalid.
func swap(slot_id: String, incoming_item: String) -> String:
	if not _slots.has(slot_id):
		return incoming_item

	# Empty incoming means just unequip
	if incoming_item == "":
		return unequip(slot_id)

	# Validate the incoming item belongs in this slot
	var required_slot := EquipmentCatalog.get_slot_for_item(incoming_item)
	if required_slot != slot_id:
		return incoming_item  # reject

	var displaced := String(_slots.get(slot_id, ""))
	_slots[slot_id] = incoming_item
	equipment_changed.emit()
	return displaced
