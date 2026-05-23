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
## Keyed by slot_id → modifier_id string ("" = no modifier)
var _slot_modifiers: Dictionary = {}

func _init() -> void:
	for slot_id in SLOT_IDS:
		_slots[slot_id] = ""
		_slot_modifiers[slot_id] = ""

# ── Queries ───────────────────────────────────────────────────────────────────

func get_item(slot_id: String) -> String:
	return String(_slots.get(slot_id, ""))

func is_slot_empty(slot_id: String) -> bool:
	return get_item(slot_id) == ""

func all_slots() -> Dictionary:
	return _slots.duplicate()

## Returns the modifier_id for a slot ("" = no modifier).
func get_slot_modifier(slot_id: String) -> String:
	return String(_slot_modifiers.get(slot_id, ""))

## Returns a full stack dict for a slot, including "modifier" if set.
## Returns an empty stack dict when the slot is vacant.
func get_slot_stack(slot_id: String) -> Dictionary:
	var item_id: String = get_item(slot_id)
	if item_id == "":
		return {"item": "", "count": 0, "stack_cap": 1}
	var mod_id := get_slot_modifier(slot_id)
	var stack  := {"item": item_id, "count": 1, "stack_cap": 1}
	if mod_id != "":
		stack["modifier"] = mod_id
	return stack

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
	_slot_modifiers[target_slot] = ""   # plain equip carries no modifier
	equipment_changed.emit()
	return displaced

## Equip a full stack dict into the correct slot, preserving its modifier.
## Returns the displaced stack dict ("" item = slot was empty).
func equip_stack(stack: Dictionary) -> Dictionary:
	var item_id := String(stack.get("item", ""))
	var mod_id  := String(stack.get("modifier", ""))
	if item_id == "" or not EquipmentCatalog.is_equippable(item_id):
		return stack.duplicate()
	var target_slot := EquipmentCatalog.get_slot_for_item(item_id)
	if target_slot == "" or not _slots.has(target_slot):
		return stack.duplicate()
	var displaced_stack := get_slot_stack(target_slot)
	_slots[target_slot] = item_id
	_slot_modifiers[target_slot] = mod_id
	equipment_changed.emit()
	return displaced_stack

## Unequip the item in slot_id.  Returns the item that was there ("" if empty).
func unequip(slot_id: String) -> String:
	if not _slots.has(slot_id):
		return ""
	var removed := String(_slots.get(slot_id, ""))
	_slots[slot_id] = ""
	_slot_modifiers[slot_id] = ""
	if removed != "":
		equipment_changed.emit()
	return removed

## Unequip slot_id and return a full stack dict (includes modifier).
func unequip_as_stack(slot_id: String) -> Dictionary:
	if not _slots.has(slot_id):
		return {"item": "", "count": 0, "stack_cap": 1}
	var stack := get_slot_stack(slot_id)
	_slots[slot_id] = ""
	_slot_modifiers[slot_id] = ""
	if String(stack.get("item", "")) != "":
		equipment_changed.emit()
	return stack

## Unequip by item_id regardless of slot.  Returns true if item was found.
func unequip_item(item_id: String) -> bool:
	var slot_id := find_item_slot(item_id)
	if slot_id == "":
		return false
	_slots[slot_id] = ""
	_slot_modifiers[slot_id] = ""
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
	_slot_modifiers[slot_id] = ""   # string-only swap carries no modifier
	equipment_changed.emit()
	return displaced

## Swap: place incoming_stack into slot_id, preserving its modifier.
## Returns the displaced stack dict; returns incoming_stack unchanged if rejected.
func swap_stack(slot_id: String, incoming_stack: Dictionary) -> Dictionary:
	if not _slots.has(slot_id):
		return incoming_stack.duplicate()

	var incoming_id := String(incoming_stack.get("item", ""))
	if incoming_id == "":
		return unequip_as_stack(slot_id)

	var required_slot := EquipmentCatalog.get_slot_for_item(incoming_id)
	if required_slot != slot_id:
		return incoming_stack.duplicate()   # reject — wrong slot type

	var displaced_stack := get_slot_stack(slot_id)
	_slots[slot_id] = incoming_id
	_slot_modifiers[slot_id] = String(incoming_stack.get("modifier", ""))
	equipment_changed.emit()
	return displaced_stack
