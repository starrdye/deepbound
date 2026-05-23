extends Node
class_name BossStateMachine

## Node-based Finite State Machine for boss entities.
##
## Usage
## -----
## 1. Add as a child node of BossEntity ("StateMachine").
## 2. Add concrete BossState nodes as children of this node.
##    Each child's `name` is the state key used in transition_to().
## 3. Call  setup(boss_entity, initial_state_name)  from BossEntity._ready().
##
## On each physics frame BossEntity should call update(delta); this
## forwards to the active state's physics_update().

const BossState = preload("res://scripts/boss/BossState.gd")

var _active_state: BossState = null

func setup(boss: Node2D, initial_state_name: String) -> void:
	# Inject boss + state_machine references into every child state.
	for child in get_children():
		if child is BossState:
			child.boss = boss
			child.state_machine = self
	transition_to(initial_state_name)

func update(delta: float) -> void:
	if _active_state != null:
		_active_state.physics_update(delta)

func transition_to(state_name: String) -> void:
	var target := get_node_or_null(state_name)
	if target == null or not (target is BossState):
		push_warning("BossStateMachine: unknown state '%s'" % state_name)
		return
	if _active_state != null:
		_active_state.exit()
	_active_state = target as BossState
	_active_state.enter()

func current_state_name() -> String:
	if _active_state == null:
		return ""
	return _active_state.name
