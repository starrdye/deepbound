extends RefCounted
class_name HeartSystem

const HP_PER_HEART := 2
const DEFAULT_MAX_HP := 10
const MIN_MAX_HP := 2

static func resolve_max_hp(base_hp: int = DEFAULT_MAX_HP, equipment_hp_delta: int = 0) -> int:
	var resolved := base_hp + equipment_hp_delta
	if resolved % HP_PER_HEART != 0:
		resolved += 1
	return maxi(MIN_MAX_HP, resolved)

static func clamp_hp(current_hp: int, max_hp: int) -> int:
	return clampi(current_hp, 0, maxi(MIN_MAX_HP, max_hp))

static func heart_count(max_hp: int) -> int:
	return ceili(float(maxi(MIN_MAX_HP, max_hp)) / float(HP_PER_HEART))

static func heart_states(current_hp: int, max_hp: int) -> Array[String]:
	var clamped_max := maxi(MIN_MAX_HP, max_hp)
	var clamped_current := clamp_hp(current_hp, clamped_max)
	var states: Array[String] = []
	for index in range(heart_count(clamped_max)):
		var remaining := clamped_current - index * HP_PER_HEART
		if remaining >= HP_PER_HEART:
			states.append("full")
		elif remaining == 1:
			states.append("half")
		else:
			states.append("empty")
	return states

static func sprite_frame_for_state(state: String) -> int:
	match state:
		"full":
			return 0
		"half":
			return 1
		_:
			return 2
