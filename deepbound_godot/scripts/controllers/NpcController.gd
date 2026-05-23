extends Node2D
class_name NpcController

const NPCCatalog = preload("res://scripts/catalogs/NPCCatalog.gd")

## NPC body dimensions (drawn in local space, origin at feet).
const BODY_W  := 12.0
const BODY_H  := 20.0
const HEAD_R  :=  7.0
## Vertical offset of the name label above the NPC's head.
const LABEL_Y := -(BODY_H + HEAD_R * 2.0 + 6.0)

var npc_id: String = ""
var npc_def: Dictionary = {}

var _name_label: Label = null
var _hint_label: Label = null

func setup(id: String) -> void:
	npc_id = id
	npc_def = NPCCatalog.get_npc(id)
	_build_labels()
	queue_redraw()

func _build_labels() -> void:
	var display_name := String(npc_def.get("name", npc_id))

	_name_label = Label.new()
	_name_label.text = display_name
	_name_label.add_theme_color_override("font_color", Color8(244, 231, 192))
	_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.position = Vector2(-50.0, LABEL_Y - 2.0)
	_name_label.custom_minimum_size = Vector2(100.0, 0.0)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_label)

	_hint_label = Label.new()
	_hint_label.text = "[T] Talk"
	_hint_label.add_theme_color_override("font_color", Color8(140, 255, 140))
	_hint_label.add_theme_font_size_override("font_size", 10)
	_hint_label.position = Vector2(-30.0, LABEL_Y - 15.0)
	_hint_label.custom_minimum_size = Vector2(60.0, 0.0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.visible = false
	add_child(_hint_label)

## Show or hide the "[T] Talk" prompt based on player proximity.
func set_nearby(is_nearby: bool) -> void:
	if _hint_label != null:
		_hint_label.visible = is_nearby

## True when player_world_pos is within this NPC's interact radius.
func is_player_in_range(player_world_pos: Vector2) -> bool:
	var radius := float(npc_def.get("interact_radius", 52.0))
	return global_position.distance_to(player_world_pos) <= radius

func _draw() -> void:
	if npc_id == "":
		return
	var col := _body_color()
	var half_w := BODY_W * 0.5
	# Body rectangle (feet at local origin)
	draw_rect(Rect2(-half_w, -BODY_H, BODY_W, BODY_H), col, true)
	draw_rect(Rect2(-half_w, -BODY_H, BODY_W, BODY_H), col.lightened(0.3), false, 1.5)
	# Head circle
	var head_y := -(BODY_H + HEAD_R)
	draw_circle(Vector2(0.0, head_y), HEAD_R, col)
	draw_arc(Vector2(0.0, head_y), HEAD_R, 0.0, TAU, 16, col.lightened(0.3), 1.5)

func _body_color() -> Color:
	match npc_id:
		"wandering_merchant": return Color8(60, 120, 200)
		"old_miner":          return Color8(160, 120, 70)
		"cave_hermit":        return Color8(110, 70, 165)
	return Color8(80, 160, 80)
