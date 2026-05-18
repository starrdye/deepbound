extends Node2D
class_name ChestController

const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")
const InventorySystem = preload("res://scripts/systems/InventorySystem.gd")

const FRAME_SIZE := Vector2i(32, 32)
const FRAME_COUNT := 8
const OPEN_SECONDS := 0.36
const VISUAL_SCALE := 0.5

var inventory := InventorySystem.new(18, 99, 0)
var is_open := false
var animation_time := 0.0
var frame := 0
var anchor_tile := Vector2i(999999, 999999)
var seed_default_contents := false

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

func _ready() -> void:
	if seed_default_contents and inventory.count_item("copper_nugget") == 0 and inventory.count_item("stone_chunk") == 0 and inventory.count_item("wooden_sword") == 0 and inventory.count_item("wooden_background_block") == 0:
		inventory.add_item("copper_nugget", 6)
		inventory.add_item("stone_chunk", 12)
		inventory.add_item("wooden_sword", 1)
		inventory.add_item("wooden_background_block", 10)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	sprite.texture = TextureFactory.make_prop_texture("chest_open_sheet")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, FRAME_SIZE.x, FRAME_SIZE.y)
	sprite.centered = true
	sprite.scale = Vector2.ONE * VISUAL_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	if not is_open:
		_set_frame(0)
		return
	animation_time = minf(OPEN_SECONDS, animation_time + delta)
	var next_frame := clampi(floori((animation_time / OPEN_SECONDS) * FRAME_COUNT), 0, FRAME_COUNT - 1)
	_set_frame(next_frame)

func open() -> void:
	if is_open:
		return
	is_open = true
	animation_time = 0.0
	_set_frame(0)

func close() -> void:
	is_open = false
	animation_time = 0.0
	_set_frame(0)

func _set_frame(next_frame: int) -> void:
	frame = clampi(next_frame, 0, FRAME_COUNT - 1)
	if sprite != null:
		sprite.region_rect = Rect2(frame * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
