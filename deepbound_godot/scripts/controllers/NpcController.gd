extends Node2D
class_name NpcController

const NPCCatalog            = preload("res://scripts/catalogs/NPCCatalog.gd")
const InteractableComponent = preload("res://scripts/components/InteractableComponent.gd")
const TextureFactory        = preload("res://scripts/factories/TextureFactory.gd")

## Goblin sprite sheets reused as NPC visuals.
## Sprite sheet layout matches EnemyController: 32×32 frames, 8 cols × 4 rows.
##   Row 0 = idle  Row 1 = walk  Row 2 = attack  Row 3 = hurt
const SPRITE_FRAME_SIZE := Vector2(32.0, 32.0)
const SPRITE_FRAMES     := 8
const ANIM_FPS          := 5.0   # slower than enemies for a relaxed idle feel

## Which goblin sprite sheet each NPC uses.
const NPC_SPRITE_MAP := {
	"wandering_merchant": "goblin_shaman",   # robed, staff — merchant-like
	"old_miner":          "goblin_grunt",    # stocky, armoured — miner-like
	"cave_hermit":        "goblin_slinger",  # lean, hooded — hermit-like
}

## Vertical offset of the name label above the sprite top (sprite origin = feet).
const LABEL_Y := -(SPRITE_FRAME_SIZE.y + 8.0)

var npc_id: String = ""
var npc_def: Dictionary = {}

## Reusable interact component — handles proximity detection, hint label, and
## the `interacted` signal.  Host code (Main.gd) connects to this.
var interactable: InteractableComponent = null

var _name_label: Label = null
var anim_time    := 0.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func setup(id: String) -> void:
	npc_id = id
	npc_def = NPCCatalog.get_npc(id)
	_build_interactable()
	_build_name_label()
	queue_redraw()

func _process(delta: float) -> void:
	if npc_id == "":
		return
	var old_frame := int(floorf(anim_time * ANIM_FPS)) % SPRITE_FRAMES
	anim_time += delta
	var new_frame := int(floorf(anim_time * ANIM_FPS)) % SPRITE_FRAMES
	if old_frame != new_frame:
		queue_redraw()

# ── Nodes ─────────────────────────────────────────────────────────────────────

func _build_interactable() -> void:
	interactable = InteractableComponent.new()
	interactable.interact_radius = float(npc_def.get("interact_radius", 52.0))
	interactable.hint_text = "[T] Talk"
	# Position hint label above the name label
	interactable.label_offset = Vector2(-30.0, LABEL_Y - 16.0)
	add_child(interactable)

func _build_name_label() -> void:
	_name_label = Label.new()
	_name_label.text = String(npc_def.get("name", npc_id))
	_name_label.add_theme_color_override("font_color", Color8(244, 231, 192))
	_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.position = Vector2(-50.0, LABEL_Y - 2.0)
	_name_label.custom_minimum_size = Vector2(100.0, 0.0)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_label)

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if npc_id == "":
		return
	var sprite_id: String = NPC_SPRITE_MAP.get(npc_id, "goblin_grunt")
	var texture := TextureFactory.make_enemy_texture(sprite_id)
	if texture != null:
		var frame := int(floorf(anim_time * ANIM_FPS)) % SPRITE_FRAMES
		# Draw with origin at feet (same convention as EnemyController)
		draw_texture_rect_region(
			texture,
			Rect2(
				Vector2(-SPRITE_FRAME_SIZE.x * 0.5, -SPRITE_FRAME_SIZE.y),
				SPRITE_FRAME_SIZE
			),
			Rect2(
				Vector2(frame * SPRITE_FRAME_SIZE.x, 0.0),   # row 0 = idle
				SPRITE_FRAME_SIZE
			)
		)
		return
	# Fallback capsule when the sprite sheet is not available
	var col := _fallback_color()
	draw_rect(Rect2(-6.0, -20.0, 12.0, 20.0), col, true)
	draw_circle(Vector2(0.0, -27.0), 7.0, col)

func _fallback_color() -> Color:
	match npc_id:
		"wandering_merchant": return Color8(60, 120, 200)
		"old_miner":          return Color8(160, 120, 70)
		"cave_hermit":        return Color8(110, 70, 165)
	return Color8(80, 160, 80)
