extends RefCounted
class_name EventCatalog

## Static database of world events that can be triggered through the console.
##
## Each entry contains:
##   name             — display name used in UI and console output
##   message          — centre-screen alert text shown when the event starts
##   sky_tint         — Color multiplied into the CanvasModulate during the event
##   spawn_overrides  — Array of enemy IDs that replace normal band spawns
##                      (empty array = keep normal spawns, only visual tint changes)
##   spawn_multiplier — number of enemies spawned per spawn cycle during the event

const EVENTS: Dictionary = {
	"blood_moon": {
		"name":             "Blood Moon",
		"message":          "The Blood Moon is rising...",
		"sky_tint":         Color(1.0, 0.35, 0.35),
		"spawn_overrides":  ["cave_skitter", "soldier_ant", "mummy_sentry"],
		"spawn_multiplier": 2,
	},
	"goblin_raid": {
		"name":             "Goblin Raid",
		"message":          "The goblins are attacking!",
		"sky_tint":         Color(0.88, 0.82, 0.28),
		"spawn_overrides":  ["cave_skitter", "worker_ant", "cave_skitter"],
		"spawn_multiplier": 3,
	},
	"meteor_shower": {
		"name":             "Meteor Shower",
		"message":          "A meteor shower streaks across the sky...",
		"sky_tint":         Color(0.80, 0.65, 1.0),
		"spawn_overrides":  [],   # no spawn change — purely visual
		"spawn_multiplier": 1,
	},
}

static func is_valid(event_id: String) -> bool:
	return EVENTS.has(event_id)

static func get_event(event_id: String) -> Dictionary:
	return Dictionary(EVENTS.get(event_id, {}))

static func all_ids() -> Array:
	return EVENTS.keys()
