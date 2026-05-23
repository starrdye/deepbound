extends "res://scripts/boss/BossState.gd"

## Boss flees the arena and despawns.
##
## Triggered when:
##   - the player exceeds max_chase_radius  (Terraria-style dynamic despawn), OR
##   - the player has died / is invalid.
##
## The boss moves away from the player's last known position for flee_duration
## seconds, then queue_free()s itself.  BossEncounterSystem.end_encounter()
## is called here so BossUI hides the health bar.

const BossEncounterSystem = preload("res://scripts/systems/BossEncounterSystem.gd")

const FLEE_DURATION := 4.0   # seconds before despawn

var _flee_elapsed := 0.0

func enter() -> void:
	_flee_elapsed = 0.0
	BossEncounterSystem.end_encounter()
	if boss != null and boss.has_method("_on_flee_enter"):
		boss._on_flee_enter()

func physics_update(delta: float) -> void:
	if boss == null:
		return
	_flee_elapsed += delta
	# Keep moving away until despawn
	if boss.has_method("_move_away_from_player"):
		boss._move_away_from_player(delta)
	if _flee_elapsed >= FLEE_DURATION:
		boss.queue_free()
