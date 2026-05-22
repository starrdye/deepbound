extends RefCounted
class_name TerminalSystem

## Lightweight static singleton that holds shared state for the in-game debug
## terminal console.  Any script can push output or check is_open without
## holding an instance reference.

static var is_open := false

## Scrollback buffer: last MAX_HISTORY lines (output echoes + responses).
static var history: Array[String] = []
static const MAX_HISTORY := 20

static func push_output(line: String) -> void:
	history.append(line)
	while history.size() > MAX_HISTORY:
		history.pop_front()

static func clear_history() -> void:
	history.clear()
