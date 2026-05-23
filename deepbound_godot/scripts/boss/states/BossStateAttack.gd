extends "res://scripts/boss/BossState.gd"

## Boss executes an attack when within strike range.
## After the attack animation / cooldown, transitions back to Chase.

var _attack_elapsed := 0.0

func enter() -> void:
	_attack_elapsed = 0.0
	if boss != null and boss.has_method("_on_attack_enter"):
		boss._on_attack_enter()

func exit() -> void:
	_attack_elapsed = 0.0

func physics_update(delta: float) -> void:
	if boss == null:
		return
	var player = boss.get("player")
	if player == null or not is_instance_valid(player):
		transition_to("Idle")
		return
	_attack_elapsed += delta
	# Damage is dealt once at the top of each attack cycle.
	var attack_cooldown: float = float(boss.get("attack_cooldown"))
	if _attack_elapsed >= attack_cooldown:
		_attack_elapsed -= attack_cooldown
		var dist: float = boss.global_position.distance_to(player.global_position)
		if dist <= float(boss.get("attack_range")):
			if boss.has_method("_deal_damage"):
				boss._deal_damage()
		else:
			# Player moved away — return to chase
			transition_to("Chase")
