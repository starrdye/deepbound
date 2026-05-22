extends RefCounted
class_name DebugSystem

## Lightweight debug-mode flags. All fields are static so any script can
## read or write them without holding an instance.

static var god_mode_enabled := false

static func toggle_god_mode() -> void:
	god_mode_enabled = not god_mode_enabled
