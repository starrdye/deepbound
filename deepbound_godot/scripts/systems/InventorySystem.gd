extends RefCounted
class_name InventorySystem

var slots: Array[Dictionary] = []
var max_slots := 24
var stack_cap := 99

func _init(slot_count := 24, default_stack_cap := 99) -> void:
	max_slots = slot_count
	stack_cap = default_stack_cap
	for i in max_slots:
		slots.append({"item": "", "count": 0, "stack_cap": stack_cap})

func count_item(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if slot.item == item_id:
			total += int(slot.count)
	return total

func empty_stack() -> Dictionary:
	return {"item": "", "count": 0, "stack_cap": stack_cap}

func is_empty_stack(stack: Dictionary) -> bool:
	return String(stack.get("item", "")) == "" or int(stack.get("count", 0)) <= 0

func is_valid_slot(index: int) -> bool:
	return index >= 0 and index < slots.size()

func get_slot(index: int) -> Dictionary:
	if not is_valid_slot(index):
		return empty_stack()
	return slots[index]

func set_slot(index: int, item_id: String, count: int, cap := -1) -> void:
	if not is_valid_slot(index):
		return
	if item_id == "" or count <= 0:
		clear_slot(index)
		return
	var resolved_cap := stack_cap if cap <= 0 else cap
	slots[index] = {"item": item_id, "count": mini(count, resolved_cap), "stack_cap": resolved_cap}

func clear_slot(index: int) -> void:
	if is_valid_slot(index):
		slots[index] = empty_stack()

func take_slot(index: int) -> Dictionary:
	if not is_valid_slot(index):
		return empty_stack()
	var stack := slots[index].duplicate()
	clear_slot(index)
	return stack

func available_space_for(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if slot.item == item_id:
			total += maxi(0, int(slot.stack_cap) - int(slot.count))
		elif slot.item == "":
			total += stack_cap
	return total

func can_accept_item(item_id: String, count := 1) -> bool:
	if item_id == "" or count <= 0:
		return false
	return available_space_for(item_id) > 0

func add_item(item_id: String, count: int) -> int:
	var remaining := count
	for slot in slots:
		if remaining <= 0:
			break
		if slot.item != item_id or int(slot.count) >= int(slot.stack_cap):
			continue
		var moved := mini(remaining, int(slot.stack_cap) - int(slot.count))
		slot.count = int(slot.count) + moved
		remaining -= moved
	for slot in slots:
		if remaining <= 0:
			break
		if slot.item != "":
			continue
		var moved := mini(remaining, stack_cap)
		slot.item = item_id
		slot.count = moved
		remaining -= moved
	return remaining

func place_stack(slot_index: int, incoming_stack: Dictionary) -> Dictionary:
	if not is_valid_slot(slot_index):
		return incoming_stack.duplicate()
	if is_empty_stack(incoming_stack):
		return empty_stack()
	var incoming := {
		"item": String(incoming_stack.get("item", "")),
		"count": int(incoming_stack.get("count", 0)),
		"stack_cap": int(incoming_stack.get("stack_cap", stack_cap)),
	}
	var slot := slots[slot_index]
	if String(slot.item) == "":
		slots[slot_index] = incoming
		return empty_stack()
	if String(slot.item) == String(incoming.item):
		var space := maxi(0, int(slot.stack_cap) - int(slot.count))
		var moved := mini(space, int(incoming.count))
		slot.count = int(slot.count) + moved
		incoming.count = int(incoming.count) - moved
		if int(incoming.count) <= 0:
			return empty_stack()
		return incoming
	slots[slot_index] = incoming
	return slot

func quick_slots(count := 8) -> Array[Dictionary]:
	return slots.slice(0, count)
