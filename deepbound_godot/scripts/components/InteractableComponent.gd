extends Node2D
class_name InteractableComponent

## Composition component — drop this child node onto any entity (NPC, chest,
## door, switch …) to give it a standardised proximity + interact interface.
##
## Usage:
##   1. Add InteractableComponent as a child of the host node.
##   2. Set `interact_radius` and `hint_text` via code or @export in the editor.
##   3. Call `update_proximity(player_world_pos)` each frame to refresh the hint.
##   4. Call `try_interact(interactor)` when the player presses the interact key;
##      returns true and emits `interacted` when the player is in range.
##   5. Connect to the `interacted(interactor)` signal to respond.
##
## Because the player uses a custom-AABB collision solver (not Godot physics),
## this component uses a distance check rather than an Area2D body-entered event.
## The node can be upgraded to a real Area2D in the future once the player gains
## a CharacterBody2D.

## Emitted when the player is in range and presses the interact key.
signal interacted(interactor: Node)
## Emitted whenever proximity state changes.
signal proximity_changed(is_nearby: bool)

@export var interact_radius: float = 52.0
@export var hint_text: String = "[T]"
## Position of the hint label relative to this node's origin.
@export var label_offset: Vector2 = Vector2(-30.0, -68.0)

var _hint_label: Label = null
var _is_nearby: bool = false

func _ready() -> void:
	_build_hint_label()

func _build_hint_label() -> void:
	_hint_label = Label.new()
	_hint_label.text = hint_text
	_hint_label.add_theme_color_override("font_color", Color8(140, 255, 140))
	_hint_label.add_theme_font_size_override("font_size", 10)
	_hint_label.custom_minimum_size = Vector2(60.0, 0.0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.position = label_offset
	_hint_label.visible = false
	add_child(_hint_label)

# ── Proximity ─────────────────────────────────────────────────────────────────

## Returns true when `world_pos` is within interact_radius of the host node.
## Uses the parent's global_position when available (host node may have moved).
func is_nearby(world_pos: Vector2) -> bool:
	var par := get_parent()
	var origin: Vector2 = (par as Node2D).global_position if par is Node2D else global_position
	return origin.distance_to(world_pos) <= interact_radius

## Call once per frame with the player's world position.
## Updates the hint label visibility and emits proximity_changed when state flips.
func update_proximity(player_world_pos: Vector2) -> void:
	var now_nearby := is_nearby(player_world_pos)
	if now_nearby != _is_nearby:
		_is_nearby = now_nearby
		if _hint_label != null:
			_hint_label.visible = _is_nearby
		proximity_changed.emit(_is_nearby)

# ── Interaction ───────────────────────────────────────────────────────────────

## Attempt to interact.  Returns true and emits `interacted` if player is in
## range; returns false silently otherwise.
func try_interact(interactor: Node) -> bool:
	if not _is_nearby:
		return false
	interacted.emit(interactor)
	return true

## Force-show or hide the hint label (useful when dialogue is already open).
func set_hint_visible(v: bool) -> void:
	if _hint_label != null:
		_hint_label.visible = v
