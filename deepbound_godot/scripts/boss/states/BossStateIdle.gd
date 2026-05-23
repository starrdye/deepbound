extends "res://scripts/boss/BossState.gd"

## Boss idles in place.  Transitions to Chase when the player enters the
## aggro radius.

func enter() -> void:
	if boss != null and boss.has_method("_on_state_idle_enter"):
		boss._on_state_idle_enter()

func physics_update(_delta: float) -> void:
	if boss == null:
		return
	var player = boss.get("player")
	if player == null or not is_instance_valid(player):
		return
	var dist: float = boss.global_position.distance_to(player.global_position)
	if dist <= float(boss.get("aggro_radius")):
		transition_to("Chase")
