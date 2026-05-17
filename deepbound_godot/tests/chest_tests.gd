extends SceneTree

const ChestController = preload("res://scripts/controllers/ChestController.gd")
const MainController = preload("res://scripts/Main.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_chest_open_animation_frames()
	_test_chest_sheet_art_review()
	_test_spawn_area_test_chest()
	if failures.is_empty():
		print("Deepbound Godot chest tests passed.")
		quit(0)
	else:
		print("Deepbound Godot chest tests failed: %d" % failures.size())
		quit(1)

func _test_chest_open_animation_frames() -> void:
	var chest := ChestController.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	chest.add_child(sprite)
	get_root().add_child(chest)
	await process_frame
	_assert(chest.frame == 0, "new chest should start closed")
	chest.open()
	chest._process(ChestController.OPEN_SECONDS * 0.5)
	_assert(chest.frame > 0 and chest.frame < ChestController.FRAME_COUNT - 1, "chest should advance through middle open frames")
	chest._process(ChestController.OPEN_SECONDS)
	_assert(chest.frame == ChestController.FRAME_COUNT - 1, "chest should finish on the open frame")
	_assert(sprite.region_rect.position.x == float((ChestController.FRAME_COUNT - 1) * ChestController.FRAME_SIZE.x), "sprite region should point at the final open frame")
	chest.close()
	_assert(chest.frame == 0, "closing should reset to frame zero")
	chest.free()

func _test_chest_sheet_art_review() -> void:
	var image := Image.new()
	_assert(image.load("res://assets/props/chest_open_sheet.png") == OK, "chest art review should load open sheet")
	_assert(image.get_width() == 256 and image.get_height() == 32, "chest open sheet should remain eight 32x32 frames")
	var first := _frame_signature(image, 0)
	var middle := _frame_signature(image, 3)
	var final := _frame_signature(image, 7)
	_assert(first != middle, "middle chest frame should visibly differ from closed frame")
	_assert(middle != final, "middle chest frame should visibly differ from final open frame")
	_assert(first != final, "final open chest should visibly differ from closed frame")

func _frame_signature(image: Image, frame: int) -> int:
	var total := 0
	for y in range(32):
		for x in range(frame * 32, frame * 32 + 32):
			var color := image.get_pixel(x, y)
			total += roundi(color.r * 255.0 + color.g * 765.0 + color.b * 1275.0 + color.a * 1785.0)
	return total

func _test_spawn_area_test_chest() -> void:
	var main := MainController.new()
	var props := Node2D.new()
	var player := Node2D.new()
	player.global_position = Vector2(-128, 208)
	main.props_node = props
	main.player = player
	main._spawn_test_chest()
	var chest = props.get_node_or_null("TestSpawnChest")
	_assert(chest != null, "main scene should create a named test chest near initial spawn")
	if chest != null:
		_assert(chest.global_position == player.global_position + MainController.TEST_CHEST_OFFSET, "test chest should use the spawn-area offset")
	main._spawn_test_chest()
	_assert(props.get_child_count() == 1, "test chest setup should be idempotent")
	if chest != null:
		chest.global_position = player.global_position + Vector2(10, 0)
		main._update_test_chest()
		_assert(bool(chest.is_open), "test chest should auto-open when the player walks close")
		chest.global_position = player.global_position + Vector2(MainController.TEST_CHEST_OPEN_DISTANCE + 20.0, 0)
		main._update_test_chest()
		_assert(not bool(chest.is_open), "test chest should auto-close when the player walks away")
	props.free()
	player.free()
	main.free()
