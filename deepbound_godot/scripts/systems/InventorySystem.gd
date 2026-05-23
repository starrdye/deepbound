extends RefCounted
class_name InventorySystem

var slots: Array[Dictionary] = []
var hotbar: Array[Dictionary] = []
var max_slots := 24
var hotbar_size := 6
var stack_cap := 99

func _init(slot_count := 24, default_stack_cap := 99, hotbar_slot_count := 6) -> void:
	max_slots = slot_count
	stack_cap = default_stack_cap
	hotbar_size = hotbar_slot_count
	for i in max_slots:
		slots.append({"item": "", "count": 0, "stack_cap": stack_cap})
	for i in hotbar_size:
		hotbar.append({"item": "", "count": 0, "stack_cap": stack_cap})

func count_item(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if slot.item == item_id:
			total += int(slot.count)
	for slot in hotbar:
		if slot.item == item_id:
			total += int(slot.count)
	return total

func empty_stack() -> Dictionary:
	return {"item": "", "count": 0, "stack_cap": stack_cap}

func is_empty_stack(stack: Dictionary) -> bool:
	return String(stack.get("item", "")) == "" or int(stack.get("count", 0)) <= 0

func is_valid_slot(index: int) -> bool:
	return index >= 0 and index < slots.size()

func is_valid_hotbar_slot(index: int) -> bool:
	return index >= 0 and index < hotbar.size()

func get_slot(index: int) -> Dictionary:
	if not is_valid_slot(index):
		return empty_stack()
	return slots[index]

func get_hotbar_slot(index: int) -> Dictionary:
	if not is_valid_hotbar_slot(index):
		return empty_stack()
	return hotbar[index]

func set_slot(index: int, item_id: String, count: int, cap := -1) -> void:
	if not is_valid_slot(index):
		return
	_set_stack_in_array(slots, index, item_id, count, cap)

func set_hotbar_slot(index: int, item_id: String, count: int, cap := -1) -> void:
	if not is_valid_hotbar_slot(index):
		return
	_set_stack_in_array(hotbar, index, item_id, count, cap)

func _set_stack_in_array(target: Array[Dictionary], index: int, item_id: String, count: int, cap := -1) -> void:
	if item_id == "" or count <= 0:
		target[index] = empty_stack()
		return
	var resolved_cap := stack_cap if cap <= 0 else cap
	target[index] = {"item": item_id, "count": mini(count, resolved_cap), "stack_cap": resolved_cap}

func clear_slot(index: int) -> void:
	if is_valid_slot(index):
		slots[index] = empty_stack()

func clear_hotbar_slot(index: int) -> void:
	if is_valid_hotbar_slot(index):
		hotbar[index] = empty_stack()

func decrement_hotbar_slot(index: int, amount := 1) -> bool:
	if not is_valid_hotbar_slot(index) or amount <= 0:
		return false
	if is_empty_stack(hotbar[index]) or int(hotbar[index].count) < amount:
		return false
	hotbar[index].count = int(hotbar[index].count) - amount
	if int(hotbar[index].count) <= 0:
		clear_hotbar_slot(index)
	return true

func take_slot(index: int) -> Dictionary:
	if not is_valid_slot(index):
		return empty_stack()
	var stack := slots[index].duplicate()
	clear_slot(index)
	return stack

func take_hotbar_slot(index: int) -> Dictionary:
	if not is_valid_hotbar_slot(index):
		return empty_stack()
	var stack := hotbar[index].duplicate()
	clear_hotbar_slot(index)
	return stack

func available_space_for(item_id: String) -> int:
	var total := 0
	for slot in _all_storage_slots():
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
	remaining = _add_item_to_matching_stacks(hotbar, item_id, remaining)
	remaining = _add_item_to_empty_slots(hotbar, item_id, remaining)
	remaining = _add_item_to_matching_stacks(slots, item_id, remaining)
	remaining = _add_item_to_empty_slots(slots, item_id, remaining)
	return remaining

func _add_item_to_matching_stacks(target: Array[Dictionary], item_id: String, count: int) -> int:
	var remaining := count
	for slot in target:
		if remaining <= 0:
			break
		if slot.item != item_id or int(slot.count) >= int(slot.stack_cap):
			continue
		var moved := mini(remaining, int(slot.stack_cap) - int(slot.count))
		slot.count = int(slot.count) + moved
		remaining -= moved
	return remaining

func _add_item_to_empty_slots(target: Array[Dictionary], item_id: String, count: int) -> int:
	var remaining := count
	for slot in target:
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
	return _place_stack_in_array(slots, slot_index, incoming_stack)

func place_hotbar_stack(slot_index: int, incoming_stack: Dictionary) -> Dictionary:
	if not is_valid_hotbar_slot(slot_index):
		return incoming_stack.duplicate()
	return _place_stack_in_array(hotbar, slot_index, incoming_stack)

func _place_stack_in_array(target: Array[Dictionary], slot_index: int, incoming_stack: Dictionary) -> Dictionary:
	if is_empty_stack(incoming_stack):
		return empty_stack()
	var incoming := {
		"item": String(incoming_stack.get("item", "")),
		"count": int(incoming_stack.get("count", 0)),
		"stack_cap": int(incoming_stack.get("stack_cap", stack_cap)),
	}
	var slot := target[slot_index]
	if String(slot.item) == "":
		target[slot_index] = incoming
		return empty_stack()
	if String(slot.item) == String(incoming.item):
		var space := maxi(0, int(slot.stack_cap) - int(slot.count))
		var moved := mini(space, int(incoming.count))
		slot.count = int(slot.count) + moved
		incoming.count = int(incoming.count) - moved
		if int(incoming.count) <= 0:
			return empty_stack()
		return incoming
	target[slot_index] = incoming
	return slot

func quick_slots(count := 8) -> Array[Dictionary]:
	return slots.slice(0, count)

func hotbar_start_index(cols := 6) -> int:
	return 0

func hotbar_slot_index(hotbar_index: int, cols := 6) -> int:
	return clampi(hotbar_index, 0, maxi(0, mini(cols, hotbar.size()) - 1))

func hotbar_slots(cols := 6) -> Array[Dictionary]:
	return hotbar.slice(0, mini(hotbar.size(), cols))

## Remove up to `count` of `item_id` (hotbar first, then main slots).
## Returns the number actually removed.
func remove_item(item_id: String, count: int) -> int:
	if item_id == "" or count <= 0:
		return 0
	var need := count
	need -= _remove_from_array(hotbar, item_id, need)
	need -= _remove_from_array(slots,  item_id, need)
	return count - need

func _remove_from_array(target: Array[Dictionary], item_id: String, count: int) -> int:
	var removed := 0
	for slot in target:
		if removed >= count:
			break
		if String(slot.item) != item_id:
			continue
		var take := mini(int(slot.count), count - removed)
		slot.count = int(slot.count) - take
		removed += take
		if int(slot.count) <= 0:
			slot.item  = ""
			slot.count = 0
	return removed

func _all_storage_slots() -> Array[Dictionary]:
	var combined: Array[Dictionary] = []
	combined.append_array(slots)
	combined.append_array(hotbar)
	return combined
