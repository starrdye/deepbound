extends Node
class_name BossState

## Abstract base class for all boss FSM states.
##
## Each concrete state is added as a named child of BossStateMachine.
## BossStateMachine calls enter(), exit(), and physics_update(delta) on
## the active state.  States request transitions by calling
## state_machine.transition_to("StateName").
##
## The `boss` property is injected by BossStateMachine.setup() before the
## first enter() call.

var boss: Node2D = null          ## Reference to the owning BossEntity.
var state_machine: Node = null   ## Reference to the BossStateMachine parent.

# ── Lifecycle (override in concrete states) ───────────────────────────────────

## Called when this state becomes active.
func enter() -> void:
	pass

## Called when this state is replaced by another.
func exit() -> void:
	pass

## Called every physics frame while this state is active.
func physics_update(_delta: float) -> void:
	pass

# ── Helpers ───────────────────────────────────────────────────────────────────

## Shorthand — request a transition from within a state.
func transition_to(state_name: String) -> void:
	if state_machine != null and state_machine.has_method("transition_to"):
		state_machine.transition_to(state_name)
