extends RefCounted
class_name BossEncounterSystem

## Global static singleton for boss encounter state.
##
## Any script can emit or listen to boss signals without holding a node
## reference.  BossUI subscribes to these signals to show / hide the
## health bar.  SaveGameSystem persists defeated_bosses so cleared bosses
## never respawn after reload.
##
## Pattern mirrors TerminalSystem / DebugSystem: pure static vars + static
## methods — no instantiation required.

# ── Signals ───────────────────────────────────────────────────────────────────
## Emitted when a boss fight starts.
##   boss_id   : String  — catalog key, e.g. "giant_ant_queen"
##   boss_name : String  — display name shown on the health bar
##   max_hp    : int
signal encounter_started(boss_id: String, boss_name: String, max_hp: int)

## Emitted every time the boss takes damage.
##   current : int
##   maximum : int
signal boss_hp_changed(current: int, maximum: int)

## Emitted when the encounter ends (boss dies OR flees).
signal boss_ended()

## Emitted only on boss death (after boss_ended).
##   boss_id : String
signal boss_defeated(boss_id: String)

# ── Persistent state ──────────────────────────────────────────────────────────
## { "giant_ant_queen": true, ... } — persisted to SaveGameSystem schema v3.
static var defeated_bosses: Dictionary = {}

## True while a boss fight is in progress.
static var encounter_active := false

## The BossEncounterSystem instance used for signal emission.
## One canonical instance is created lazily and held here so signals work
## without Autoload.
## NOTE: intentionally untyped — self-typed class_name annotations fail under
## GDScript 4.6 headless (--headless -s) because the class registry is not
## populated.  Using `var` (Variant) avoids the parse error.
static var _instance = null

# ── Public API ────────────────────────────────────────────────────────────────

static func get_instance():
	if _instance == null:
		# NOTE: class_name self-reference does not resolve in headless mode
		# (GDScript 4.6 --headless -s).  Use load() to avoid the compile error.
		_instance = load("res://scripts/systems/BossEncounterSystem.gd").new()
	return _instance

static func is_defeated(boss_id: String) -> bool:
	return defeated_bosses.get(boss_id, false)

static func mark_defeated(boss_id: String) -> void:
	defeated_bosses[boss_id] = true

## Call from BossEntity when it becomes active.
static func start_encounter(boss_id: String, boss_name: String, max_hp: int) -> void:
	encounter_active = true
	get_instance().encounter_started.emit(boss_id, boss_name, max_hp)

## Call from BossEntity whenever HP changes.
static func report_hp(current: int, maximum: int) -> void:
	get_instance().boss_hp_changed.emit(current, maximum)

## Call from BossEntity when the encounter is over (flee or death).
static func end_encounter() -> void:
	encounter_active = false
	get_instance().boss_ended.emit()

## Call from BossEntity specifically on death.
static func defeat(boss_id: String) -> void:
	mark_defeated(boss_id)
	get_instance().boss_defeated.emit(boss_id)

## Reset defeated flags (used by SaveGameSystem when loading a fresh world).
static func reset_defeated_bosses() -> void:
	defeated_bosses.clear()
