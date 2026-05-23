extends "res://scripts/boss/BossState.gd"

## Boss pursues the player.
## Transitions:
##   → Attack  when within strike range
##   → Idle    when player leaves aggro radius (only if within despawn radius)
##   → Flee    when boss is told to flee (health <= flee threshold or despawn)

func physics_update(delta: float) -> void:
	if boss == null:
		return
	var player = boss.get("player")
	if player == null or not is_instance_valid(player):
		transition_to("Idle")
		return
	var dist: float = boss.global_position.distance_to(player.global_position)
	# Fled too far — trigger despawn flee
	if dist > float(boss.get("max_chase_radius")):
		transition_to("Flee")
		return
	# Close enough to attack
	if dist <= float(boss.get("attack_range")):
		transition_to("Attack")
		return
	# Move toward player
	if boss.has_method("_move_toward_player"):
		boss._move_toward_player(delta)
