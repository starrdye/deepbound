extends SceneTree

## Headless test suite for the Boss Encounter system.
##
## Tests:
##   1. BossEncounterSystem  — static singleton: signals, defeated flags, API
##   2. BossStateMachine     — FSM transitions (Idle→Chase→Attack→Flee)
##   3. BossEntity           — take_damage, death, flee trigger, HP reporting
##   4. SaveGameSystem       — schema v3 round-trip with defeated_bosses
##
## Run from project root:
##   godot --headless -s tests/boss_tests.gd

const BossEncounterSystem = preload("res://scripts/systems/BossEncounterSystem.gd")
const BossStateMachine    = preload("res://scripts/boss/BossStateMachine.gd")
const BossState           = preload("res://scripts/boss/BossState.gd")
const BossEntity          = preload("res://scripts/boss/BossEntity.gd")
const GiantAntQueenScript = preload("res://scripts/boss/GiantAntQueen.gd")
const SaveGameSystem      = preload("res://scripts/systems/SaveGameSystem.gd")

var failures: Array[String] = []

# ── Scaffolding ───────────────────────────────────────────────────────────────

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_boss_encounter_system()
	_test_boss_state_machine()
	_test_boss_entity()
	_test_save_schema()
	if failures.is_empty():
		print("Deepbound Godot boss tests passed.")
		quit(0)
	else:
		for f in failures:
			push_error("FAIL: " + f)
		quit(1)

# ── 1. BossEncounterSystem ────────────────────────────────────────────────────

func _test_boss_encounter_system() -> void:
	print("  [boss] BossEncounterSystem...")

	# Fresh state
	BossEncounterSystem.reset_defeated_bosses()
	_assert(BossEncounterSystem.defeated_bosses.is_empty(), "defeated_bosses should start empty")
	_assert(not BossEncounterSystem.is_defeated("giant_ant_queen"), "queen not defeated initially")

	# Mark defeated
	BossEncounterSystem.mark_defeated("giant_ant_queen")
	_assert(BossEncounterSystem.is_defeated("giant_ant_queen"), "queen should be marked defeated")

	# Reset clears all
	BossEncounterSystem.reset_defeated_bosses()
	_assert(not BossEncounterSystem.is_defeated("giant_ant_queen"), "defeat cleared by reset")

	# Singleton instance is stable
	var inst1 = BossEncounterSystem.get_instance()
	var inst2 = BossEncounterSystem.get_instance()
	_assert(inst1 == inst2, "get_instance should return the same object")

	# encounter_active toggling
	_assert(not BossEncounterSystem.encounter_active, "encounter_active starts false")
	BossEncounterSystem.start_encounter("test_boss", "Test Boss", 100)
	_assert(BossEncounterSystem.encounter_active, "encounter_active should be true after start")
	BossEncounterSystem.end_encounter()
	_assert(not BossEncounterSystem.encounter_active, "encounter_active should be false after end")

	# Signals: use Array container for lambda closure; store callables for cleanup
	var started_count := [0]
	var ended_count   := [0]
	var hp_reports    := [[0, 0]]   # [current, maximum]
	var defeated_ids  := [""]
	# Force a fresh instance so previous test-run state does not bleed in.
	BossEncounterSystem._instance = null
	var inst = BossEncounterSystem.get_instance()
	var cb_started  := func(_id, _name, _max): started_count[0] += 1
	var cb_ended    := func(): ended_count[0] += 1
	var cb_hp       := func(c, m): hp_reports[0] = [c, m]
	var cb_defeated := func(bid): defeated_ids[0] = bid
	inst.encounter_started.connect(cb_started)
	inst.boss_ended.connect(cb_ended)
	inst.boss_hp_changed.connect(cb_hp)
	inst.boss_defeated.connect(cb_defeated)

	BossEncounterSystem.start_encounter("giant_ant_queen", "Giant Ant Queen", 300)
	_assert(started_count[0] == 1, "encounter_started emitted once")

	BossEncounterSystem.report_hp(250, 300)
	_assert(hp_reports[0][0] == 250, "hp_changed current=250")
	_assert(hp_reports[0][1] == 300, "hp_changed maximum=300")

	BossEncounterSystem.defeat("giant_ant_queen")
	_assert(defeated_ids[0] == "giant_ant_queen", "boss_defeated emitted with correct id")
	_assert(BossEncounterSystem.is_defeated("giant_ant_queen"), "defeat marks boss as defeated")

	BossEncounterSystem.end_encounter()
	_assert(ended_count[0] == 1, "boss_ended emitted once")

	# Disconnect saved callables
	inst.encounter_started.disconnect(cb_started)
	inst.boss_ended.disconnect(cb_ended)
	inst.boss_hp_changed.disconnect(cb_hp)
	inst.boss_defeated.disconnect(cb_defeated)
	BossEncounterSystem.reset_defeated_bosses()

# ── 2. BossStateMachine ───────────────────────────────────────────────────────

func _test_boss_state_machine() -> void:
	print("  [boss] BossStateMachine transitions...")

	var fsm := BossStateMachine.new()
	fsm.name = "StateMachine"
	get_root().add_child(fsm)

	# Create minimal stub states
	var idle   := BossState.new(); idle.name   = "Idle"
	var chase  := BossState.new(); chase.name  = "Chase"
	var attack := BossState.new(); attack.name = "Attack"
	var flee   := BossState.new(); flee.name   = "Flee"

	for s in [idle, chase, attack, flee]:
		fsm.add_child(s)

	# Inject a minimal boss stub (just a Node2D)
	var stub := Node2D.new()
	fsm.setup(stub, "Idle")

	_assert(fsm.current_state_name() == "Idle", "initial state should be Idle")

	fsm.transition_to("Chase")
	_assert(fsm.current_state_name() == "Chase", "should transition to Chase")

	fsm.transition_to("Attack")
	_assert(fsm.current_state_name() == "Attack", "should transition to Attack")

	fsm.transition_to("Flee")
	_assert(fsm.current_state_name() == "Flee", "should transition to Flee")

	fsm.transition_to("Idle")
	_assert(fsm.current_state_name() == "Idle", "should return to Idle")

	# Unknown state — should not crash, state should remain
	fsm.transition_to("NonExistent")
	_assert(fsm.current_state_name() == "Idle", "unknown transition should leave state unchanged")

	# State refs are injected
	_assert(idle.boss == stub,          "idle.boss should be stub")
	_assert(idle.state_machine == fsm,  "idle.state_machine should be fsm")

	stub.queue_free()
	fsm.queue_free()

# ── 3. BossEntity ─────────────────────────────────────────────────────────────

func _test_boss_entity() -> void:
	print("  [boss] BossEntity damage and death...")

	# Reset global state
	BossEncounterSystem.reset_defeated_bosses()
	BossEncounterSystem.end_encounter()

	# Instantiate a GiantAntQueen directly (no world/player needed for unit tests)
	var queen := GiantAntQueenScript.new()
	get_root().add_child(queen)
	# Don't call setup() — that requires a player and triggers start_encounter.
	# Manually prime the state so we can test take_damage.
	queen.health     = 300
	queen.max_health = 300
	queen.alive      = true

	# HP reports via signal
	var hp_log := [[300, 300]]
	BossEncounterSystem._instance = null
	var inst = BossEncounterSystem.get_instance()
	var cb_hp2 := func(c, m): hp_log[0] = [c, m]
	inst.boss_hp_changed.connect(cb_hp2)

	queen.take_damage(50)
	_assert(queen.health == 250, "health should decrease by damage amount")
	_assert(hp_log[0][0] == 250, "boss_hp_changed emitted with correct current hp")

	# Defeat threshold
	var defeated_flag := [""]
	var cb_def2 := func(bid): defeated_flag[0] = bid
	inst.boss_defeated.connect(cb_def2)

	# Kill the queen
	queen.take_damage(250)
	_assert(not queen.alive, "queen should be dead")
	_assert(defeated_flag[0] == "giant_ant_queen", "boss_defeated emitted on death")
	_assert(BossEncounterSystem.is_defeated("giant_ant_queen"), "queen marked defeated in system")

	inst.boss_hp_changed.disconnect(cb_hp2)
	inst.boss_defeated.disconnect(cb_def2)

	# queen.queue_free already called internally; don't double free.
	BossEncounterSystem.reset_defeated_bosses()

	# Dead boss should not take further damage (no crash, health stays at 0)
	var queen2 := GiantAntQueenScript.new()
	get_root().add_child(queen2)
	queen2.health     = 0
	queen2.max_health = 300
	queen2.alive      = false
	queen2.take_damage(100)   # should be a no-op
	_assert(queen2.health == 0, "dead boss takes no further damage")
	queen2.queue_free()

	# Flee triggered when max_chase_radius exceeded — guard via state_machine
	var queen3 := GiantAntQueenScript.new()
	get_root().add_child(queen3)
	queen3.health     = 300
	queen3.max_health = 300
	queen3.alive      = true
	queen3.max_chase_radius = 1500.0
	# state machine is built in _ready (already ran)
	if queen3.get_node_or_null("StateMachine") != null:
		queen3.get_node("StateMachine").transition_to("Flee")
		var state_name: String = queen3.get_node("StateMachine").current_state_name()
		_assert(state_name == "Flee", "boss should enter Flee state")
	queen3.queue_free()

# ── 4. SaveGameSystem schema v3 ───────────────────────────────────────────────

func _test_save_schema() -> void:
	print("  [boss] SaveGameSystem v3 defeated_bosses round-trip...")

	# normalize_save_data should include defeated_bosses key
	BossEncounterSystem.reset_defeated_bosses()
	BossEncounterSystem.mark_defeated("giant_ant_queen")

	var raw := {
		"schema_version": 3,
		"world": {},
		"player": {},
		"inventory": {},
		"selected_hotbar_index": 0,
		"containers": [],
		"drops": [],
		"beacons": [],
		"flares": [],
		"defeated_bosses": {"giant_ant_queen": true},
	}
	var normalized := SaveGameSystem.normalize_save_data(raw)
	_assert(normalized.has("defeated_bosses"), "normalized save should have defeated_bosses key")
	_assert(normalized.schema_version == 3, "schema version should be 3")
	var db: Dictionary = Dictionary(normalized.get("defeated_bosses", {}))
	_assert(db.has("giant_ant_queen"), "giant_ant_queen should be in defeated_bosses after normalise")

	# _defeated_bosses_from_data strips non-bool values, keeps known keys
	var from_data := SaveGameSystem._defeated_bosses_from_data({"giant_ant_queen": true, "bad_key": false})
	_assert(from_data.has("giant_ant_queen"), "_defeated_bosses_from_data keeps valid entries")

	# Schema version mismatch detected
	var old_save := {
		"schema_version": 2,
		"world": {}, "player": {}, "inventory": {},
		"selected_hotbar_index": 0, "containers": [], "drops": [],
		"beacons": [], "flares": [],
	}
	var old_norm := SaveGameSystem.normalize_save_data(old_save)
	# v2 saves don't have defeated_bosses — validate should report mismatch
	var err := SaveGameSystem._validate_save_data(old_norm)
	_assert(err != "", "v2 save should fail v3 validation (missing defeated_bosses)")

	BossEncounterSystem.reset_defeated_bosses()
