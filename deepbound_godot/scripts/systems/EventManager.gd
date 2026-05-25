extends Node
## Global event director — registered in project.godot as autoload "EventManager".
##
## Events are triggered EXCLUSIVELY by console commands (force_start_event /
## force_stop_event).  This node does NOT respond to time, RNG, or any
## automatic trigger — it is entirely console-driven for deterministic testing.
##
## Signals:
##   event_started(event_id: String)  — fired when a new event begins
##   event_stopped(event_id: String)  — fired when the running event ends

signal event_started(event_id: String)
signal event_stopped(event_id: String)

const EventCatalog = preload("res://scripts/catalogs/EventCatalog.gd")

## The currently-running event id, or "" when no event is active.
var active_event_id: String = ""

## Attempt to start the named event.
## Automatically stops any already-running event first.
## Returns false when event_id is not found in the catalog.
func force_start_event(event_id: String) -> bool:
	if not EventCatalog.is_valid(event_id):
		return false
	if not active_event_id.is_empty():
		force_stop_event()
	active_event_id = event_id
	event_started.emit(event_id)
	return true

## Immediately end the currently running event.  No-op when none is active.
func force_stop_event() -> void:
	if active_event_id.is_empty():
		return
	var stopped_id := active_event_id
	active_event_id = ""
	event_stopped.emit(stopped_id)

func is_event_active() -> bool:
	return not active_event_id.is_empty()

## Returns the sky-tint Color for the active event multiplied into CanvasModulate.
## Returns Color.WHITE (no tint effect) when no event is running.
func get_event_sky_tint() -> Color:
	if active_event_id.is_empty():
		return Color.WHITE
	var ev: Dictionary = EventCatalog.get_event(active_event_id)
	if ev.is_empty():
		return Color.WHITE
	return Color(ev.get("sky_tint", Color.WHITE))
