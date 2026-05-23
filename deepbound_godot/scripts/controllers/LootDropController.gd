extends Node2D
class_name LootDropController

## Physics-driven loot pop for enemy kills, boss drops, and mining rewards.
##
## Differences from DroppedItemController
## ──────────────────────────────────────
## DroppedItemController  — inventory-drag / chest-spill drops; click-to-collect;
##                          manual drag support; used for player-thrown items.
## LootDropController     — "juicy" enemy/boss/mining drops; physics bounce;
##                          spinning flight arc; pickup delay timer; rarity glow;
##                          magnetic auto-collect when player is close enough.
##
## Physics model
## ─────────────
## The Godot physics engine (RigidBody2D) cannot collide with this game's
## custom tile world because the world has no StaticBody2D nodes — all terrain
## collision is handled by CollisionSystem.move_actor().  LootDropController
## therefore uses the same custom swept-AABB physics used by PlayerController
## and EnemyController, but adds:
##   • BOUNCE coefficient  — Y velocity is reflected × BOUNCE on ground landing
##   • SPIN                — angular_rotation is a visual-only accumulator
##   • PhysicsMaterial API parity — expose `bounce` and `friction` as vars so
##     behaviour can be tuned per-spawner just as a PhysicsMaterial would be

const TextureFactory  = preload("res://scripts/factories/TextureFactory.gd")
const CollisionSystem = preload("res://scripts/systems/CollisionSystem.gd")
const ItemCatalog     = preload("res://scripts/catalogs/ItemCatalog.gd")

# ── Physics constants ────────────────────────────────────────────────────────
## Gravity acceleration (px/s²).  Matches EnemyController so drops feel consistent.
const GRAVITY        := 900.0
const MAX_FALL_SPEED := 420.0
## Horizontal drag while airborne (px/s²).
const AIR_DRAG       := 40.0
## Horizontal deceleration on the ground (px/s²).

# ── Pickup constants ─────────────────────────────────────────────────────────
## Radius at which the drop starts magnetically flying toward the player.
const MAGNET_RADIUS  := 90.0
## Radius at which the drop is actually collected.
const COLLECT_RADIUS := 14.0
## Click/hit-test half-size.
const CLICK_HALF     := Vector2(9.0, 9.0)

# ── Juicy visual constants ───────────────────────────────────────────────────
## Glow ring thickness (px).
const GLOW_WIDTH     := 2.0
## Scale pulse amplitude.
const PULSE_AMP      := 0.06
## Scale pulse frequency (Hz).
const PULSE_FREQ     := 1.8
## Spin deceleration (rad/s²).
const SPIN_DRAG      := 3.5
## Maximum item scale (sprite is drawn 12×12, items are 16×16 — scaled to fit).
const DRAW_HALF      := 8.0

# ── Tunable physics material (parity with PhysicsMaterial) ──────────────────
## Energy retained on a bounce (0 = no bounce, 1 = perfect elastic).
var bounce   := 0.4
## Ground friction multiplier (0 = ice, 1 = full stop).
var friction := 0.8

# ── Item state ───────────────────────────────────────────────────────────────
var item_id  : String = ""
var count    : int    = 0
## Optional modifier_id (empty string = no modifier).
## Set by the spawner (e.g. Main._spawn_loot_drop) before or after setup().
var modifier : String = ""

# ── Physics state ────────────────────────────────────────────────────────────
var velocity         := Vector2.ZERO
var angular_rotation := 0.0    # visual rotation accumulator (radians)
var _angular_vel     := 0.0    # spin speed (rad/s) — decays over time
var _on_ground       := false
var _ground_friction := 0.0    # resolved per-frame from friction var

# ── Pickup state ─────────────────────────────────────────────────────────────
var can_be_picked_up := false

# ── References ───────────────────────────────────────────────────────────────
var player    = null
var inventory = null
var world     = null

# ── Internal ─────────────────────────────────────────────────────────────────
var _pickup_timer  : Timer = null
var _rarity_color  : Color = Color.TRANSPARENT   # glow ring colour; TRANSPARENT = no glow
var _anim_time     := 0.0
var _magnet_speed  := 0.0   # current magnet pull speed (smoothed)

# ── Collider box ─────────────────────────────────────────────────────────────
## Must match CollisionSystem format.  Kept small so drops slip into narrow gaps.
const _COLLIDER := {"width": 8.0, "height": 10.0, "bottom_offset": Vector2(0.0, 5.0)}

# ── Lifecycle ────────────────────────────────────────────────────────────────

## Call immediately after add_child() to initialise the drop.
##
## Parameters:
##   id              — ItemCatalog item id
##   amount          — stack count
##   player_node     — PlayerController reference (for magnet & collect)
##   inventory_ref   — InventorySystem reference (for add_item)
##   world_ref       — World node (for CollisionSystem)
##   pop_impulse     — initial velocity; if ZERO a random upward pop is generated
func setup(
	id            : String,
	amount        : int,
	player_node,
	inventory_ref,
	world_ref,
	pop_impulse   := Vector2.ZERO
) -> void:
	item_id   = id
	count     = amount
	player    = player_node
	inventory = inventory_ref
	world     = world_ref

	_resolve_rarity_color()
	_build_pickup_timer()
	_apply_pop_impulse(pop_impulse)
	_ground_friction = friction * 320.0
	queue_redraw()

func _ready() -> void:
	# _ready fires before setup() when instantiated via .new().
	# All real initialisation happens in setup() — nothing to do here.
	pass

func _process(delta: float) -> void:
	if item_id == "" or count <= 0:
		queue_free()
		return

	_anim_time += delta

	# ── Physics ──────────────────────────────────────────────────────────────
	var magnetizing := false
	if can_be_picked_up:
		magnetizing = _update_magnet(delta)
		if is_queued_for_deletion():
			return

	if not magnetizing:
		velocity.y = minf(MAX_FALL_SPEED, velocity.y + GRAVITY * delta)

	_move(delta, magnetizing)

	# ── Spin ──────────────────────────────────────────────────────────────────
	_angular_vel = move_toward(_angular_vel, 0.0, SPIN_DRAG * delta)
	angular_rotation += _angular_vel * delta

	queue_redraw()

# ── Physics movement ─────────────────────────────────────────────────────────

func _move(delta: float, magnetizing: bool) -> void:
	if world == null or not is_instance_valid(world):
		global_position += velocity * delta
		if not magnetizing:
			velocity.x = move_toward(velocity.x, 0.0, AIR_DRAG * delta)
		return

	var collision := CollisionSystem.move_actor(global_position, velocity, delta, _COLLIDER, world)
	global_position = collision.position

	# Bounce on ground landing
	if bool(collision.blocked_y) and velocity.y >= 0.0:
		# Reflect Y with bounce coefficient
		velocity.y = -velocity.y * bounce
		# Kill tiny bounces to avoid infinite jitter
		if absf(velocity.y) < 12.0:
			velocity.y = 0.0
		_on_ground = (velocity.y == 0.0)
	else:
		_on_ground = false

	# Wall bounce (smaller coefficient)
	if bool(collision.blocked_x):
		velocity.x = -velocity.x * (bounce * 0.5)

	velocity.x = collision.velocity.x if not bool(collision.blocked_x) else velocity.x

	# Apply friction when on the ground, air drag otherwise
	if _on_ground:
		velocity.x = move_toward(velocity.x, 0.0, _ground_friction * delta)
	elif not magnetizing:
		velocity.x = move_toward(velocity.x, 0.0, AIR_DRAG * delta)

# ── Pop impulse ───────────────────────────────────────────────────────────────

func _apply_pop_impulse(impulse: Vector2) -> void:
	if impulse != Vector2.ZERO:
		velocity = impulse
	else:
		# Random upward pop: horizontal ±60–130 px/s, vertical -180–-310 px/s
		var rand_x := randf_range(-130.0, 130.0)
		if absf(rand_x) < 60.0:
			rand_x = 60.0 * signf(rand_x) if rand_x != 0.0 else 60.0
		var rand_y := randf_range(-310.0, -180.0)
		velocity = Vector2(rand_x, rand_y)

	# Apply spin — randomise direction and strength
	_angular_vel = randf_range(-TAU * 1.2, TAU * 1.2)

# ── Pickup delay Timer ────────────────────────────────────────────────────────

func _build_pickup_timer() -> void:
	_pickup_timer = Timer.new()
	_pickup_timer.name       = "PickupDelay"
	_pickup_timer.wait_time  = 0.5
	_pickup_timer.one_shot   = true
	_pickup_timer.autostart  = true
	_pickup_timer.timeout.connect(_on_pickup_delay_timeout)
	add_child(_pickup_timer)

func _on_pickup_delay_timeout() -> void:
	can_be_picked_up = true

# ── Magnet / collect ──────────────────────────────────────────────────────────

func _update_magnet(delta: float) -> bool:
	if player == null or inventory == null or not is_instance_valid(player):
		return false
	var target     : Vector2 = player.global_position + Vector2(0.0, -12.0)
	var distance   : float   = global_position.distance_to(target)
	if distance > MAGNET_RADIUS or not inventory.can_accept_item(item_id, count):
		_magnet_speed = 0.0
		return false

	# Collect when close enough
	if distance <= COLLECT_RADIUS:
		var remaining: int
		if modifier != "" and inventory.has_method("add_stack"):
			remaining = inventory.add_stack({"item": item_id, "count": count, "stack_cap": 1, "modifier": modifier})
		else:
			remaining = inventory.add_item(item_id, count)
		if remaining <= 0:
			queue_free()
		else:
			count = remaining
		return true

	# Smoothly ramp magnet pull speed (faster as it gets closer)
	var pull_ratio    : float = 1.0 - (distance / MAGNET_RADIUS)
	var target_speed  : float = lerp(80.0, 260.0, pull_ratio * pull_ratio)
	_magnet_speed = move_toward(_magnet_speed, target_speed, 300.0 * delta)

	var direction : Vector2 = (target - global_position).normalized()
	velocity = direction * _magnet_speed
	return true

# ── Click collect ─────────────────────────────────────────────────────────────

func contains_world_point(point: Vector2) -> bool:
	return Rect2(global_position - CLICK_HALF, CLICK_HALF * 2.0).has_point(point)

func try_collect(target_inventory = null) -> bool:
	if not can_be_picked_up:
		return false
	var destination = inventory if target_inventory == null else target_inventory
	if destination == null or item_id == "" or count <= 0:
		return false
	if not destination.can_accept_item(item_id, count):
		return false
	var remaining: int
	if modifier != "" and destination.has_method("add_stack"):
		remaining = destination.add_stack({"item": item_id, "count": count, "stack_cap": 1, "modifier": modifier})
	else:
		remaining = destination.add_item(item_id, count)
	if remaining <= 0:
		count = 0
		queue_free()
	else:
		count = remaining
	return true

# ── Rarity glow ───────────────────────────────────────────────────────────────

func _resolve_rarity_color() -> void:
	var item_def : Dictionary = ItemCatalog.get_item(item_id)
	match String(item_def.get("rarity", "common")):
		"uncommon":  _rarity_color = Color8(80,  210, 100)   # green
		"rare":      _rarity_color = Color8(80,  140, 255)   # blue
		"epic":      _rarity_color = Color8(180, 80,  255)   # purple
		"legendary": _rarity_color = Color8(255, 200, 40)    # gold
		_:           _rarity_color = Color.TRANSPARENT        # common — no glow

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	var scale_factor := 1.0 + sin(_anim_time * TAU * PULSE_FREQ) * PULSE_AMP
	# Pickup delay: fade in from half-alpha to full
	var alpha := 1.0
	if _pickup_timer != null and not _pickup_timer.is_stopped():
		alpha = 0.5 + 0.5 * (1.0 - _pickup_timer.time_left / _pickup_timer.wait_time)

	# Rarity glow ring (drawn first, behind item)
	if _rarity_color != Color.TRANSPARENT:
		var glow_alpha := _rarity_color
		glow_alpha.a = alpha * (0.55 + sin(_anim_time * TAU * 1.1) * 0.20)
		draw_arc(Vector2.ZERO, DRAW_HALF * scale_factor + 3.0, 0.0, TAU, 20, glow_alpha, GLOW_WIDTH)

	# Drop shadow (shows depth above terrain)
	draw_ellipse_shadow(scale_factor, alpha)

	# Sprite — rotated by angular_rotation
	var saved_transform := get_canvas_transform()   # not modifiable; use draw_set_transform
	draw_set_transform(Vector2.ZERO, angular_rotation, Vector2(scale_factor, scale_factor))

	var texture := TextureFactory.make_item_texture(item_id)
	if texture != null:
		var half := DRAW_HALF
		var col := Color(1.0, 1.0, 1.0, alpha)
		draw_texture_rect(texture, Rect2(Vector2(-half, -half), Vector2(half * 2.0, half * 2.0)), false, col)
	else:
		# Fallback coloured square
		var fb_col := Color(1.0, 0.84, 0.42, alpha)
		draw_rect(Rect2(Vector2(-6.0, -6.0), Vector2(12.0, 12.0)), fb_col)

	# Reset transform so the stack count label is upright
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Stack count label (only if > 1)
	if count > 1:
		var label := "%d" % count
		draw_string(
			ThemeDB.fallback_font,
			Vector2(DRAW_HALF * 0.5 + 1.0, DRAW_HALF + 7.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1, 9,
			Color(0.0, 0.0, 0.0, alpha * 0.75)
		)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(DRAW_HALF * 0.5, DRAW_HALF + 6.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1, 9,
			Color(1.0, 1.0, 1.0, alpha)
		)

func draw_ellipse_shadow(scale_f: float, alpha: float) -> void:
	# A subtle oval shadow beneath the item indicates height above the ground.
	# Squish it vertically more as the item rises (velocity.y < 0).
	var height_factor : float = clampf(1.0 - velocity.y / MAX_FALL_SPEED, 0.2, 1.0)
	var shadow_col := Color(0.0, 0.0, 0.0, alpha * 0.22 * height_factor)
	draw_ellipse_approx(
		Vector2(0.0, DRAW_HALF * scale_f * 0.85),
		Vector2(DRAW_HALF * scale_f * 0.8, 2.5 * height_factor),
		shadow_col, 10
	)

func draw_ellipse_approx(center: Vector2, radii: Vector2, color: Color, segments := 10) -> void:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
