extends SceneTree

## Headless test suite for the Character Modifiers / Status Effects system.
##
## Tests:
##   1. StatusEffectCatalog  — data integrity, is_valid, make()
##   2. StatusEffectData     — field defaults, stat_modifiers dict
##   3. StatusManager        — apply_effect, remove_effect, clear_all,
##                             duration tick, get_stat_totals, signal emission
##   4. StatCalculator       — compute_with_status: equipment + status layering
##
## Run from project root:
##   godot --headless -s tests/status_effect_tests.gd

const StatusEffectCatalog = preload("res://scripts/catalogs/StatusEffectCatalog.gd")
const StatusEffectData    = preload("res://scripts/components/StatusEffectData.gd")
const StatusManager       = preload("res://scripts/components/StatusManager.gd")
const StatCalculator      = preload("res://scripts/systems/StatCalculator.gd")
const EquipmentSystem     = preload("res://scripts/systems/EquipmentSystem.gd")

var failures: Array[String] = []

# ── Scaffolding ────────────────────────────────────────────────────────────────

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_test_catalog()
	_test_data()
	_test_manager()
	_test_stat_calculator()
	if failures.is_empty():
		print("Deepbound Godot status effect tests passed.")
		quit(0)
	else:
		for f in failures:
			push_error("FAIL: " + f)
		quit(1)

# ── 1. StatusEffectCatalog ────────────────────────────────────────────────────

func _test_catalog() -> void:
	print("  [fx] StatusEffectCatalog...")

	# All required keys present in every entry.
	for fx_id in StatusEffectCatalog.EFFECTS:
		var entry: Dictionary = StatusEffectCatalog.EFFECTS[fx_id]
		_assert(entry.has("display_name"),  "effect '%s' missing 'display_name'" % fx_id)
		_assert(entry.has("duration"),      "effect '%s' missing 'duration'" % fx_id)
		_assert(entry.has("stat_modifiers"), "effect '%s' missing 'stat_modifiers'" % fx_id)
		_assert(entry.has("is_debuff"),     "effect '%s' missing 'is_debuff'" % fx_id)

	# is_valid
	_assert(StatusEffectCatalog.is_valid("swiftness"), "swiftness should be valid")
	_assert(StatusEffectCatalog.is_valid("curse"),     "curse should be valid")
	_assert(not StatusEffectCatalog.is_valid(""),          "empty string should not be valid")
	_assert(not StatusEffectCatalog.is_valid("nonexist"),  "unknown id should not be valid")

	# make() produces correct data
	var swift = StatusEffectCatalog.make("swiftness")
	_assert(swift != null,                          "make('swiftness') should return non-null")
	_assert(swift.effect_id == "swiftness",         "effect_id should be 'swiftness'")
	_assert(not swift.is_debuff,                    "swiftness should not be a debuff")
	_assert(swift.duration > 0.0,                   "swiftness should have positive duration")
	_assert(swift.stat_modifiers.has("speed"),      "swiftness should have speed modifier")
	_assert(float(swift.stat_modifiers.get("speed", 0.0)) > 0.0, "swiftness speed should be positive")

	var curse = StatusEffectCatalog.make("curse")
	_assert(curse != null,                    "make('curse') should return non-null")
	_assert(curse.is_debuff,                  "curse should be a debuff")
	_assert(curse.duration <= 0.0,            "curse should be permanent (duration <= 0)")

	var slow = StatusEffectCatalog.make("slow")
	_assert(slow != null,                      "make('slow') should return non-null")
	_assert(slow.is_debuff,                    "slow should be a debuff")
	_assert(float(slow.stat_modifiers.get("speed", 0.0)) < 0.0, "slow speed should be negative")

	# make() on unknown id returns null
	_assert(StatusEffectCatalog.make("nonexistent_xyz") == null, "make of unknown id should return null")

	# all_ids() returns buffs before debuffs and no duplicates
	var ids := StatusEffectCatalog.all_ids()
	_assert(ids.size() == StatusEffectCatalog.EFFECTS.size(), "all_ids should match EFFECTS count")
	for id in ids:
		_assert(StatusEffectCatalog.is_valid(id), "all_ids entry '%s' should be valid" % id)

# ── 2. StatusEffectData ───────────────────────────────────────────────────────

func _test_data() -> void:
	print("  [fx] StatusEffectData...")

	var eff := StatusEffectData.new()
	_assert(eff.effect_id == "",         "default effect_id should be empty")
	_assert(eff.display_name == "",      "default display_name should be empty")
	_assert(eff.icon == null,            "default icon should be null")
	_assert(eff.duration == 0.0,         "default duration should be 0.0")
	_assert(eff.stat_modifiers.is_empty(), "default stat_modifiers should be empty")
	_assert(not eff.is_debuff,           "default is_debuff should be false")

	# Field assignment roundtrip
	eff.effect_id      = "test_effect"
	eff.display_name   = "Test Effect"
	eff.duration       = 15.0
	eff.stat_modifiers = {"damage": 2, "speed": 0.10}
	eff.is_debuff      = false
	_assert(eff.effect_id == "test_effect",       "effect_id should round-trip")
	_assert(eff.display_name == "Test Effect",    "display_name should round-trip")
	_assert(eff.duration == 15.0,                 "duration should round-trip")
	_assert(int(eff.stat_modifiers.get("damage", 0)) == 2, "damage modifier should round-trip")

# ── 3. StatusManager ─────────────────────────────────────────────────────────

func _test_manager() -> void:
	print("  [fx] StatusManager...")

	var sm := StatusManager.new()
	get_root().add_child(sm)

	# Initially empty
	_assert(sm.get_active().is_empty(),    "active effects should be empty at start")
	_assert(not sm.has_effect("swiftness"), "has_effect should be false at start")
	var totals0 := sm.get_stat_totals()
	_assert(int(totals0.get("damage", 0)) == 0,      "initial damage total should be 0")
	_assert(float(totals0.get("speed", 0.0)) == 0.0, "initial speed total should be 0.0")

	# Track signal emissions
	var signal_count := [0]
	sm.status_changed.connect(func(): signal_count[0] += 1)

	# apply_effect — adds effect, emits signal
	var swift = StatusEffectCatalog.make("swiftness")
	sm.apply_effect(swift)
	_assert(sm.has_effect("swiftness"),         "swiftness should be active after apply")
	_assert(sm.get_active().size() == 1,        "active count should be 1")
	_assert(signal_count[0] == 1,              "status_changed should have fired once")

	# get_stat_totals reflects active effect
	var totals1 := sm.get_stat_totals()
	_assert(float(totals1.get("speed", 0.0)) > 0.0, "speed total should be positive after swiftness")

	# apply_effect — second distinct effect
	var slow_eff = StatusEffectCatalog.make("slow")
	sm.apply_effect(slow_eff)
	_assert(sm.get_active().size() == 2,        "active count should be 2 after adding slow")

	# Both stat contributions
	var totals2 := sm.get_stat_totals()
	# swiftness speed + slow speed — slow should partially cancel swiftness
	_assert(float(totals2.get("speed", 0.0)) < float(totals1.get("speed", 0.0)),
		"combined speed should be less than swiftness alone")

	# apply_effect — duplicate effect refreshes duration, not double-stacked
	var sig_before: int = signal_count[0]
	var swift2 = StatusEffectCatalog.make("swiftness")  # fresh copy
	swift2.duration = 60.0                               # longer duration
	sm.apply_effect(swift2)
	_assert(sm.get_active().size() == 2,        "duplicate effect should not increase count")
	_assert(signal_count[0] == sig_before + 1,  "status_changed should fire on refresh")

	# remove_effect — removes swiftness
	sm.remove_effect("swiftness")
	_assert(not sm.has_effect("swiftness"),     "swiftness should be gone after remove")
	_assert(sm.get_active().size() == 1,        "active count should be 1 after remove")

	# remove_effect — non-existent, no signal
	var sig_before2: int = signal_count[0]
	sm.remove_effect("nonexistent_xyz")
	_assert(signal_count[0] == sig_before2,     "removing unknown effect should not emit signal")

	# clear_all
	sm.clear_all()
	_assert(sm.get_active().is_empty(),         "all effects should be cleared")
	# clear_all when already empty should not emit
	var sig_before3: int = signal_count[0]
	sm.clear_all()
	_assert(signal_count[0] == sig_before3,     "clear_all on empty should not emit signal")

	# Duration tick — apply a 0.1s effect and tick past it
	var fervor = StatusEffectCatalog.make("fervor")
	fervor.duration = 0.1
	sm.apply_effect(fervor)
	_assert(sm.has_effect("fervor"),            "fervor should be active")
	sm._process(0.2)   # tick 200ms — should expire
	_assert(not sm.has_effect("fervor"),        "fervor should have expired after tick")

	# Permanent effect (duration <= 0) survives tick
	var curse = StatusEffectCatalog.make("curse")
	# curse has duration <= 0 by definition
	sm.apply_effect(curse)
	sm._process(1000.0)   # massive tick
	_assert(sm.has_effect("curse"),             "permanent effect should survive any tick")
	sm.clear_all()

	# Multiple stat keys — fervor adds damage
	var fervor2 = StatusEffectCatalog.make("fervor")
	sm.apply_effect(fervor2)
	var totals3 := sm.get_stat_totals()
	_assert(int(totals3.get("damage", 0)) > 0,  "fervor should contribute positive damage")
	sm.clear_all()

	# endurance adds defense
	var endur = StatusEffectCatalog.make("endurance")
	sm.apply_effect(endur)
	var totals4 := sm.get_stat_totals()
	_assert(int(totals4.get("defense", 0)) > 0, "endurance should contribute positive defense")
	sm.clear_all()

	sm.queue_free()

# ── 4. StatCalculator.compute_with_status ────────────────────────────────────

func _test_stat_calculator() -> void:
	print("  [fx] StatCalculator.compute_with_status...")

	var eq := EquipmentSystem.new()
	var sm := StatusManager.new()
	get_root().add_child(sm)

	# No equipment, no status → all zeros
	var base := StatCalculator.compute_with_status(eq, null)
	_assert(int(base.get("damage", 0))     == 0,   "no equipment/status: damage should be 0")
	_assert(int(base.get("defense", 0))    == 0,   "no equipment/status: defense should be 0")
	_assert(float(base.get("speed", 0.0)) == 0.0, "no equipment/status: speed should be 0.0")

	# compute_with_status with null manager == compute()
	var eq_only := StatCalculator.compute(eq)
	var with_null := StatCalculator.compute_with_status(eq, null)
	_assert(int(eq_only.get("damage", 0)) == int(with_null.get("damage", 0)),
		"compute_with_status(null) should match compute()")

	# Apply swiftness and verify speed is added on top
	var swift = StatusEffectCatalog.make("swiftness")
	sm.apply_effect(swift)
	var with_swift := StatCalculator.compute_with_status(eq, sm)
	_assert(float(with_swift.get("speed", 0.0)) > float(base.get("speed", 0.0)),
		"swiftness should increase speed above base")

	# Apply fervor and verify damage is added
	sm.clear_all()
	var fervor = StatusEffectCatalog.make("fervor")
	sm.apply_effect(fervor)
	var with_fervor := StatCalculator.compute_with_status(eq, sm)
	_assert(int(with_fervor.get("damage", 0)) > 0,
		"fervor should produce positive damage bonus")

	# Stack buff + debuff: fervor (+3 dmg) + weakness (-2 dmg) → net +1
	var weakness = StatusEffectCatalog.make("weakness")
	sm.apply_effect(weakness)
	var stacked := StatCalculator.compute_with_status(eq, sm)
	_assert(int(stacked.get("damage", 0)) == int(with_fervor.get("damage", 0)) - 2,
		"weakness should reduce fervor damage by 2")

	sm.queue_free()
