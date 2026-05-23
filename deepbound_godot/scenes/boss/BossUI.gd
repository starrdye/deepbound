extends CanvasLayer

## BossUI — top-centre health bar shown during a boss encounter.
##
## This script is attached to the BossUI CanvasLayer scene.  Main.gd
## instantiates it, adds it as a child, and then connects BossEncounterSystem
## signals to the methods below.
##
## The bar is drawn in _draw() on the inner Control node so we stay
## consistent with the rest of the HUD which uses immediate-mode drawing.

const BossEncounterSystem = preload("res://scripts/systems/BossEncounterSystem.gd")

const BAR_W     := 280.0
const BAR_H     := 18.0
const BAR_Y     := 14.0     # distance from top of screen
const BORDER    := 2.0

var _boss_name  := ""
var _current_hp := 0
var _max_hp     := 0
var _visible    := false

var _draw_node: Control = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 30   # above world, below pause menu
	_draw_node = Control.new()
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)
	visible = false
	# Connect to global encounter signals.
	var inst = BossEncounterSystem.get_instance()
	inst.encounter_started.connect(_on_encounter_started)
	inst.boss_hp_changed.connect(_on_boss_hp_changed)
	inst.boss_ended.connect(_on_boss_ended)

func _on_encounter_started(boss_id: String, boss_name: String, max_hp: int) -> void:
	_boss_name  = boss_name
	_current_hp = max_hp
	_max_hp     = max_hp
	_visible    = true
	visible     = true
	_draw_node.queue_redraw()

func _on_boss_hp_changed(current: int, maximum: int) -> void:
	_current_hp = current
	_max_hp     = maximum
	_draw_node.queue_redraw()

func _on_boss_ended() -> void:
	_visible = false
	visible  = false
	_draw_node.queue_redraw()

# ── Draw ──────────────────────────────────────────────────────────────────────

func _on_draw() -> void:
	if not _visible or _max_hp <= 0:
		return
	var vsize: Vector2 = _draw_node.get_viewport_rect().size
	var bar_x: float   = (vsize.x - BAR_W) * 0.5

	# Background
	_draw_node.draw_rect(
		Rect2(bar_x - BORDER, BAR_Y - BORDER, BAR_W + BORDER * 2.0, BAR_H + BORDER * 2.0),
		Color8(10, 5, 15)
	)

	# Empty bar
	_draw_node.draw_rect(Rect2(bar_x, BAR_Y, BAR_W, BAR_H), Color8(60, 20, 20))

	# Filled portion
	var fill_w: float = BAR_W * (float(maxi(_current_hp, 0)) / float(_max_hp))
	if fill_w > 0.0:
		_draw_node.draw_rect(Rect2(bar_x, BAR_Y, fill_w, BAR_H), _hp_color())

	# Boss name label (drawn as string above bar)
	_draw_node.draw_string(
		ThemeDB.fallback_font,
		Vector2(vsize.x * 0.5 - _boss_name.length() * 3.5, BAR_Y - 4.0),
		_boss_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		11,
		Color8(244, 220, 160)
	)

	# HP text centred inside bar
	var hp_text := "%d / %d" % [maxi(_current_hp, 0), _max_hp]
	_draw_node.draw_string(
		ThemeDB.fallback_font,
		Vector2(vsize.x * 0.5 - hp_text.length() * 3.0, BAR_Y + BAR_H - 4.0),
		hp_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		10,
		Color8(210, 200, 200)
	)

func _hp_color() -> Color:
	if _max_hp <= 0:
		return Color8(180, 50, 50)
	var ratio: float = float(_current_hp) / float(_max_hp)
	if ratio > 0.5:
		return Color8(200, 50, 50)
	if ratio > 0.25:
		return Color8(220, 120, 30)
	return Color8(255, 60, 20)
