extends "res://scripts/boss/BossEntity.gd"

## Giant Ant Queen — the Band 2 (Colossal Ant Chambers) boss.
##
## Stats
## -----
##   HP           300
##   Damage       12  per strike
##   Speed        60  px/s  (slower but hits hard)
##   Attack range 44  px
##   Aggro radius 360 px
##   Max chase    1500 px  (Terraria despawn)
##
## Visual: draws a large ant queen using primitive draw calls (no external
## sprite sheet required for the prototype).  Replace _draw() in a later
## sprint with an animated sprite sheet.

const TextureFactory = preload("res://scripts/factories/TextureFactory.gd")

# ── Boss identity ─────────────────────────────────────────────────────────────

func _get_boss_id() -> String:
	return "giant_ant_queen"

func _get_boss_name() -> String:
	return "Giant Ant Queen"

# ── Tuned stats ───────────────────────────────────────────────────────────────

func _ready() -> void:
	max_health      = 300
	health          = 300
	aggro_radius    = 360.0
	attack_range    = 44.0
	attack_cooldown = 1.2
	attack_damage   = 12
	move_speed      = 60.0
	max_chase_radius = 1500.0
	knockback_force  = Vector2(240.0, -200.0)
	super._ready()   # build FSM after stats are set

# ── Collider ──────────────────────────────────────────────────────────────────

func _get_collider() -> Dictionary:
	return {"half_width": 18.0, "height": 36.0, "bottom_offset": Vector2(0.0, 0.0)}

# ── Loot drops ────────────────────────────────────────────────────────────────

func _drop_loot() -> void:
	# Emit loot drop signal upward; Main.gd listens and spawns world items.
	# Pattern: emit on self; Main connects via group or direct reference.
	emit_signal("loot_dropped", global_position, [
		{"item": "copper_nugget",  "count": 12},
		{"item": "stone_chunk",    "count": 8},
		{"item": "resin_shard",    "count": 4},
	])

signal loot_dropped(pos: Vector2, drops: Array)

# ── Visuals ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var is_hurt: bool = now < hurt_until

	var body_col := Color8(180, 90, 20) if not is_hurt else Color8(255, 180, 120)
	var dark_col := Color8(80, 30, 10)
	var eye_col  := Color8(255, 60, 40)
	var facing: float = 1.0
	if player != null and is_instance_valid(player):
		facing = signf(player.global_position.x - global_position.x)
		if facing == 0.0:
			facing = 1.0

	# Abdomen (large oval behind)
	draw_ellipse_approx(Vector2(-facing * 22.0, -14.0), Vector2(20.0, 14.0), dark_col)
	draw_ellipse_approx(Vector2(-facing * 22.0, -16.0), Vector2(18.0, 12.0), body_col)

	# Thorax
	draw_ellipse_approx(Vector2(0.0, -20.0), Vector2(12.0, 10.0), dark_col)
	draw_ellipse_approx(Vector2(0.0, -21.0), Vector2(10.0, 9.0),  body_col)

	# Head
	draw_ellipse_approx(Vector2(facing * 16.0, -26.0), Vector2(10.0, 9.0), dark_col)
	draw_ellipse_approx(Vector2(facing * 16.0, -27.0), Vector2(9.0, 8.0),  body_col)

	# Eyes
	draw_circle(Vector2(facing * 20.0, -28.0), 3.0, eye_col)

	# Mandibles
	draw_line(
		Vector2(facing * 24.0, -27.0),
		Vector2(facing * 32.0, -22.0),
		dark_col, 2.0
	)
	draw_line(
		Vector2(facing * 24.0, -25.0),
		Vector2(facing * 30.0, -18.0),
		dark_col, 2.0
	)

	# Antennae (animated)
	var wiggle: float = sin(anim_time * 4.0) * 4.0
	draw_line(
		Vector2(facing * 18.0, -35.0),
		Vector2(facing * 26.0 + wiggle, -46.0),
		dark_col, 1.5
	)

	# Legs (3 pairs, static for now)
	for i in range(3):
		var lx := float(i - 1) * 8.0
		draw_line(Vector2(lx, -12.0), Vector2(lx - 10.0, -2.0), dark_col, 1.5)
		draw_line(Vector2(lx, -12.0), Vector2(lx + 10.0, -2.0), dark_col, 1.5)

# ── Ellipse helper (no built-in in Godot 4 immediate draw) ───────────────────

func draw_ellipse_approx(center: Vector2, radii: Vector2, color: Color, segments := 12) -> void:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
