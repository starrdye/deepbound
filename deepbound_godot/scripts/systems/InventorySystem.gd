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

func quick_slots(count := 8) -> Array[Dictionary]:
	return slots.slice(0, count)

