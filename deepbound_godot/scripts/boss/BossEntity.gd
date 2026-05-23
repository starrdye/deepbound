extends CharacterBody2D
class_name BossEntity

## Base class for all boss enemies.
##
## Composition
## -----------
##   BossEntity (CharacterBody2D)
##   └── StateMachine (BossStateMachine)
##       ├── Idle    (BossStateIdle)
##       ├── Chase   (BossStateChase)
##       ├── Attack  (BossStateAttack)
##       └── Flee    (BossStateFlee)
##
## Concrete bosses (e.g. GiantAntQueen) extend BossEntity, add their own
## sprite/shape nodes, and override _get_boss_id() / _get_boss_name().
## They can optionally override _on_state_idle_enter(), _on_attack_enter(),
## _on_flee_enter(), _move_toward_player(), _move_away_from_player(), and
## _deal_damage() to customise look/feel.
##
## Terraria-style despawn
## ----------------------
## There is NO fixed arena bounding box.  The world is infinite.
## Instead, BossStateChase calls transition_to("Flee") when the player
## distance exceeds max_chase_radius (default 1500 px).  BossStateFlee
## then moves the boss away and calls queue_free() after FLEE_DURATION.
## This mirrors Terraria's night / distance despawn mechanic.

const BossEncounterSystem = preload("res://scripts/systems/BossEncounterSystem.gd")
const BossStateMachine    = preload("res://scripts/boss/BossStateMachine.gd")
const CollisionSystem     = preload("res://scripts/systems/CollisionSystem.gd")

const TILE_SIZE       := 16
const GRAVITY         := 1900.0
const MAX_FALL        := 520.0

# ── Tunable properties (override per-boss) ────────────────────────────────────
## Maximum HP.
var max_health      := 200
## Starting HP.
var health          := 200
## Tile-distance at which boss begins chasing.
var aggro_radius    := 400.0   # px
## Tile-distance at which the boss transitions to Attack.
var attack_range    := 36.0    # px
## Seconds between attacks.
var attack_cooldown := 1.5
## Damage dealt per attack to the player.
var attack_damage   := 8
## If player is farther than this, flee and despawn.
var max_chase_radius := 1500.0  # px  ← Terraria-style dynamic despawn
## Speed when chasing the player (px/s).
var move_speed      := 80.0
## Impulse applied to the player when hit.
var knockback_force := Vector2(200.0, -180.0)

# ── Runtime state ─────────────────────────────────────────────────────────────
var player: Node2D   = null
var world            = null
var alive            := true
var anim_time        := 0.0
var hurt_until       := 0.0
var velocity_boss    := Vector2.ZERO   # separate from CharacterBody2D.velocity

var _state_machine: BossStateMachine = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

## Called by spawning code: Main._spawn_boss() or terminal command.
## Must be called after add_child so _ready() already ran.
func setup(player_node: Node2D, world_node) -> void:
	player = player_node
	world  = world_node
	if BossEncounterSystem.is_defeated(_get_boss_id()):
		queue_free()
		return
	BossEncounterSystem.start_encounter(_get_boss_id(), _get_boss_name(), max_health)

func _ready() -> void:
	_build_state_machine()

func _physics_process(delta: float) -> void:
	if not alive:
		return
	anim_time += delta
	# Apply gravity (concrete bosses that fly can override and skip this).
	velocity_boss.y = minf(MAX_FALL, velocity_boss.y + GRAVITY * delta)
	# Delegate movement to FSM.
	if _state_machine != null:
		_state_machine.update(delta)
	_apply_velocity(delta)
	_check_player_death()
	queue_redraw()

# ── Build state machine ────────────────────────────────────────────────────────

func _build_state_machine() -> void:
	_state_machine = BossStateMachine.new()
	_state_machine.name = "StateMachine"
	add_child(_state_machine)

	var idle   = load("res://scripts/boss/states/BossStateIdle.gd").new()
	idle.name   = "Idle"
	var chase  = load("res://scripts/boss/states/BossStateChase.gd").new()
	chase.name  = "Chase"
	var attack = load("res://scripts/boss/states/BossStateAttack.gd").new()
	attack.name = "Attack"
	var flee   = load("res://scripts/boss/states/BossStateFlee.gd").new()
	flee.name   = "Flee"

	_state_machine.add_child(idle)
	_state_machine.add_child(chase)
	_state_machine.add_child(attack)
	_state_machine.add_child(flee)

	# setup() injects boss + state_machine refs, then enters initial state.
	_state_machine.setup(self, "Idle")

# ── Override in concrete bosses ────────────────────────────────────────────────

func _get_boss_id() -> String:
	return "boss_unknown"

func _get_boss_name() -> String:
	return "Unknown Boss"

# Optional callbacks from state classes (no-op here, override in subclass)
func _on_state_idle_enter() -> void: pass
func _on_attack_enter()     -> void: pass
func _on_flee_enter()       -> void: pass

# ── Movement helpers (called from states) ────────────────────────────────────

func _move_toward_player(delta: float) -> void:
	if player == null:
		return
	var dir: float = signf(player.global_position.x - global_position.x)
	velocity_boss.x = move_toward(velocity_boss.x, dir * move_speed, move_speed * 6.0 * delta)

func _move_away_from_player(delta: float) -> void:
	if player == null:
		velocity_boss.x = move_toward(velocity_boss.x, 0.0, move_speed * 3.0 * delta)
		return
	var dir: float = signf(global_position.x - player.global_position.x)
	if dir == 0.0:
		dir = 1.0
	velocity_boss.x = move_toward(velocity_boss.x, dir * move_speed * 1.4, move_speed * 6.0 * delta)

func _apply_velocity(delta: float) -> void:
	if world == null:
		global_position += velocity_boss * delta
		return
	var collider := _get_collider()
	var collision := CollisionSystem.move_actor(global_position, velocity_boss, delta, collider, world)
	global_position = collision.position
	velocity_boss   = collision.velocity

## Returns the collision box used by CollisionSystem.
## Override in concrete bosses to match their sprite size.
func _get_collider() -> Dictionary:
	return {"half_width": 14.0, "height": 28.0, "bottom_offset": Vector2(0.0, 0.0)}

# ── Damage ────────────────────────────────────────────────────────────────────

## Called from BossStateAttack at the top of each attack cycle.
func _deal_damage() -> void:
	if player == null or not is_instance_valid(player):
		return
	var impulse := Vector2(
		signf(player.global_position.x - global_position.x) * abs(knockback_force.x),
		knockback_force.y
	)
	if player.has_method("damage"):
		player.damage(attack_damage, impulse)

## Called by the player's weapon swing (via Main._strike_nearby_enemy equivalent).
func take_damage(amount: int) -> void:
	if not alive:
		return
	health -= amount
	hurt_until = Time.get_ticks_msec() / 1000.0 + 0.20
	BossEncounterSystem.report_hp(maxi(health, 0), max_health)
	if health <= 0:
		_on_death()

func _on_death() -> void:
	alive  = false
	visible = false
	BossEncounterSystem.end_encounter()
	BossEncounterSystem.defeat(_get_boss_id())
	_drop_loot()
	queue_free()

# ── Loot (override in concrete bosses for custom drops) ───────────────────────

func _drop_loot() -> void:
	pass  # Concrete bosses override to toss reward drops.

# ── Player-death check (Terraria: boss despawns if player dies) ───────────────

func _check_player_death() -> void:
	if player == null or not is_instance_valid(player):
		if _state_machine != null and _state_machine.current_state_name() != "Flee":
			_state_machine.transition_to("Flee")
		return
	var hp = player.get("health")
	if hp != null and int(hp) <= 0:
		if _state_machine != null and _state_machine.current_state_name() != "Flee":
			_state_machine.transition_to("Flee")
