extends RefCounted
class_name TerminalSystem

## Lightweight static singleton that holds shared state for the in-game debug
## terminal console.  Any script can push output or check is_open without
## holding an instance reference.
##
## NOTE: GDScript 4 has NO `static const` keyword — it caused a parse error
## that cascaded through every script preloading this file (HudController,
## Main), which is why all UI and input were dead.  Plain `const` is already
## class-level / shared.  Likewise, typed `Array[String]` as the initialiser
## for a static var has version-dependent behaviour, so we use an untyped
## Array here for maximum Godot 4.x compatibility.

static var is_open := false
static var history := []

const MAX_HISTORY := 20

static func push_output(line: String) -> void:
	history.append(line)
	while history.size() > MAX_HISTORY:
		history.pop_front()

static func clear_history() -> void:
	history.clear()
