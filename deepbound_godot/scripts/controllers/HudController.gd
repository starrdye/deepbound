extends Control
class_name HudController

var health_label: Label
var inventory_label: Label
var depth_label: Label
var target_label: Label
var light_label: Label
var hint_label: Label
var hud_state := {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_label = _make_label(Vector2(20, 18))
	depth_label = _make_label(Vector2(20, 74))
	target_label = _make_label(Vector2(20, 96))
	light_label = _make_label(Vector2(1120, 20))
	inventory_label = _make_label(Vector2(20, 650))
	hint_label = _make_label(Vector2(740, 650))
	hint_label.text = "Mouse/F: drill  E: strike  Q: flare  R: beacon  1/2/3: sprint bands"

func _make_label(pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_color_override("font_color", Color8(244, 231, 192))
	label.add_theme_font_size_override("font_size", 13)
	add_child(label)
	return label

func set_hud_state(state: Dictionary) -> void:
	hud_state = state
	health_label.text = "HP %d/%d  Drill %d%%" % [state.health_current, state.health_max, roundi(float(state.drill_heat) * 100.0)]
	depth_label.text = String(state.depth_label)
	target_label.text = "Target: %s" % String(state.target_name)
	light_label.text = "Light %d%%" % roundi(float(state.light) * 100.0)
	inventory_label.text = "Quick: %s" % String(state.quickbar)
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	var danger := float(hud_state.get("danger", 0.0))
	if danger > 0.05:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.1, 0.08, danger * 0.22), false, 14.0)
	_panel(Rect2(12, 10, 260, 48))
	_panel(Rect2(12, 638, 520, 58))
	_panel(Rect2(size.x - 180, 10, 160, 44))

func _panel(rect: Rect2) -> void:
	draw_rect(rect, Color(0.05, 0.06, 0.09, 0.78), true)
	draw_rect(rect, Color8(91, 100, 107), false, 2.0)

