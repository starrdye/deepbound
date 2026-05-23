extends Node
class_name StatusManager

## Node component that tracks active status effects on an actor (player or enemy).
##
## Attach as a child of the Player or Enemy scene.  Call apply_effect() to add
## an effect, remove_effect() to cancel one early, or clear_all() to strip
## everything.  Connect the status_changed signal to trigger a stat recalc.
##
## Duration countdown: effects with duration > 0 tick down in _process().  When
## they expire they are removed automatically and status_changed is emitted.
## Effects with duration <= 0 are permanent — they persist until removed.

const StatusEffectData = preload("res://scripts/components/StatusEffectData.gd")

## Emitted whenever the active effect list changes (add, remove, expire).
signal status_changed

## Internal list of active StatusEffectData resources.
var _active: Array = []

# ── Public API ────────────────────────────────────────────────────────────────

## Add effect to the actor.  If an effect with the same effect_id is already
## active, its duration is refreshed to the new value (or kept if permanent).
## Emits status_changed.
func apply_effect(effect: StatusEffectData) -> void:
	if effect == null or effect.effect_id == "":
		return
	for i in range(_active.size()):
		if _active[i].effect_id == effect.effect_id:
			# Refresh: keep permanent if either is permanent; otherwise max duration.
			if effect.duration <= 0.0 or _active[i].duration <= 0.0:
				_active[i].duration = -1.0  # stays permanent
			else:
				_active[i].duration = maxf(_active[i].duration, effect.duration)
			status_changed.emit()
			return
	_active.append(effect)
	status_changed.emit()

## Remove the effect with the given effect_id.  No-op if not active.
## Emits status_changed only when an effect was actually removed.
func remove_effect(effect_id: String) -> void:
	for i in range(_active.size()):
		if _active[i].effect_id == effect_id:
			_active.remove_at(i)
			status_changed.emit()
			return

## Remove all active effects.  Emits status_changed if any were present.
func clear_all() -> void:
	if _active.is_empty():
		return
	_active.clear()
	status_changed.emit()

## Returns true if the effect_id is currently active.
func has_effect(effect_id: String) -> bool:
	for eff in _active:
		if eff.effect_id == effect_id:
			return true
	return false

## Returns a shallow duplicate of the active effects array (safe to iterate).
func get_active() -> Array:
	return _active.duplicate()

## Sums stat_modifiers across all active effects.
## Returned keys match StatCalculator totals: "damage", "defense",
## "health_max", "speed".
func get_stat_totals() -> Dictionary:
	var totals := {
		"damage":     0,
		"defense":    0,
		"health_max": 0,
		"speed":      0.0,
	}
	for eff in _active:
		var mods: Dictionary = eff.stat_modifiers
		for key in mods:
			if totals.has(key):
				totals[key] = totals[key] + mods[key]
	return totals

# ── Duration tick ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	var changed := false
	var i := 0
	while i < _active.size():
		var eff: StatusEffectData = _active[i]
		if eff.duration > 0.0:
			eff.duration -= delta
			if eff.duration <= 0.0:
				_active.remove_at(i)
				changed = true
				continue  # do not advance i — array shrank
		i += 1
	if changed:
		status_changed.emit()
