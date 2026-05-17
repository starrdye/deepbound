extends SceneTree

const HeartSystem = preload("res://scripts/systems/HeartSystem.gd")
const PlayerController = preload("res://scripts/controllers/PlayerController.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_heart_state_model()
	_test_equipment_health_delta()
	_test_heart_sprite_art_review()
	if failures.is_empty():
		print("Deepbound Godot heart tests passed.")
		quit(0)
	else:
		print("Deepbound Godot heart tests failed: %d" % failures.size())
		quit(1)

func _test_heart_state_model() -> void:
	_assert(HeartSystem.DEFAULT_MAX_HP == 10, "player should default to 10 HP")
	_assert(HeartSystem.HP_PER_HEART == 2, "one heart should represent 2 HP")
	_assert(HeartSystem.heart_count(10) == 5, "10 HP should render five hearts")
	_assert(HeartSystem.heart_states(10, 10) == ["full", "full", "full", "full", "full"], "10/10 HP should render five full hearts")
	_assert(HeartSystem.heart_states(9, 10) == ["full", "full", "full", "full", "half"], "9/10 HP should render four full hearts and one half")
	_assert(HeartSystem.heart_states(1, 10) == ["half", "empty", "empty", "empty", "empty"], "1/10 HP should render one half heart")
	_assert(HeartSystem.heart_states(0, 10) == ["empty", "empty", "empty", "empty", "empty"], "0/10 HP should render empty hearts")
	_assert(HeartSystem.sprite_frame_for_state("full") == 0, "full heart should use sheet frame 0")
	_assert(HeartSystem.sprite_frame_for_state("half") == 1, "half heart should use sheet frame 1")
	_assert(HeartSystem.sprite_frame_for_state("empty") == 2, "empty heart should use sheet frame 2")

func _test_equipment_health_delta() -> void:
	var player := PlayerController.new()
	_assert(player.max_health == 10 and player.health == 10, "player should start at 10/10 HP")
	player.set_equipment_health_delta(4)
	_assert(player.max_health == 14, "equipment can increase max HP")
	player.heal(99)
	_assert(player.health == 14, "healing should clamp to equipment-modified max HP")
	player.set_equipment_health_delta(-8)
	_assert(player.max_health == 2, "equipment can reduce max HP but not below one heart")
	_assert(player.health == 2, "health should clamp downward when equipment lowers max HP")
	player.damage(1, Vector2.ZERO)
	_assert(player.health == 1, "one damage should leave a half heart")
	player.free()

func _test_heart_sprite_art_review() -> void:
	var full := _load_image("res://assets/ui/heart_full.png")
	var half := _load_image("res://assets/ui/heart_half.png")
	var empty := _load_image("res://assets/ui/heart_empty.png")
	_assert(full != null and half != null and empty != null, "heart review should load all heart sprites")
	if full == null or half == null or empty == null:
		return
	for image in [full, empty]:
		_assert(_alpha_at(image, 7, 13) and _alpha_at(image, 8, 13), "heart should keep a visible centered bottom tip")
		_assert(not _alpha_at(image, 7, 14) and not _alpha_at(image, 8, 14), "heart tip should taper cleanly instead of becoming a dangling stem")
		_assert(not _alpha_at(image, 0, 8) and not _alpha_at(image, 15, 8), "heart should not touch the horizontal cell edges")
		for y in range(16):
			for x in range(8):
				_assert(_alpha_at(image, x, y) == _alpha_at(image, 15 - x, y), "heart alpha silhouette should be symmetrical")
	_assert(_alpha_at(half, 7, 13) and _alpha_at(half, 8, 13), "half heart should preserve the same bottom tip silhouette")
	_assert(not _alpha_at(half, 7, 14) and not _alpha_at(half, 8, 14), "half heart should avoid a dangling bottom stem")
	_assert(_pixel_sum(full) > _pixel_sum(half) and _pixel_sum(half) > _pixel_sum(empty), "full, half, and empty hearts should have clearly different brightness")

func _load_image(path: String) -> Image:
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return image

func _alpha_at(image: Image, x: int, y: int) -> bool:
	return image.get_pixel(x, y).a > 0.1

func _pixel_sum(image: Image) -> float:
	var total := 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			total += (color.r + color.g + color.b) * color.a
	return total
