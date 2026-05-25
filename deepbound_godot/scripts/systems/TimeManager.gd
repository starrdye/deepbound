extends Node
## Global time manager — registered in project.godot as autoload "TimeManager".
##
## Drives an in-game 24-hour clock.  One in-game minute = TICK_SPEED real seconds.
## Default: 0.5 s/min → full day cycle ≈ 12 real minutes.
##
## Signals:
##   hour_changed(new_hour: int)  — emitted each time the clock hour increments
##   day_advanced(new_day: int)   — emitted each time midnight rolls over

signal hour_changed(new_hour: int)
signal day_advanced(new_day: int)

## Real seconds per in-game minute.  Lower = faster day cycle.
const TICK_SPEED := 0.5

## 24-entry ambient sky colour table.
## Each index is the sky colour at the *start* of that hour.
## Colours are smoothly lerped between consecutive entries.
const SKY_COLORS: Array = [
	Color8( 35,  35,  65),   #  0  — midnight
	Color8( 35,  35,  65),   #  1
	Color8( 40,  38,  68),   #  2
	Color8( 48,  44,  74),   #  3
	Color8( 70,  58,  88),   #  4  — pre-dawn
	Color8(115,  82,  98),   #  5
	Color8(180, 125, 115),   #  6  — dawn
	Color8(225, 180, 158),   #  7
	Color8(248, 225, 205),   #  8  — morning
	Color8(255, 250, 242),   #  9
	Color8(255, 254, 250),   # 10
	Color8(255, 255, 255),   # 11
	Color8(255, 255, 255),   # 12 — noon
	Color8(255, 255, 255),   # 13
	Color8(255, 253, 248),   # 14
	Color8(254, 242, 228),   # 15
	Color8(242, 212, 188),   # 16
	Color8(215, 158, 118),   # 17 — dusk
	Color8(162, 114, 125),   # 18
	Color8(102,  82, 115),   # 19 — evening
	Color8( 64,  56,  90),   # 20
	Color8( 50,  46,  76),   # 21 — night
	Color8( 42,  40,  70),   # 22
	Color8( 37,  36,  66),   # 23
]

var current_hour   := 8    # game starts at 8 am
var current_minute := 0
var current_day    := 1
## Speed multiplier.  Set >1 to fast-forward; 0.0 pauses time.
var time_scale     := 1.0

var _accumulator   := 0.0

func _process(delta: float) -> void:
	_accumulator += delta * time_scale
	while _accumulator >= TICK_SPEED:
		_accumulator -= TICK_SPEED
		_tick_minute()

func _tick_minute() -> void:
	current_minute += 1
	if current_minute < 60:
		return
	current_minute = 0
	current_hour   = (current_hour + 1) % 24
	hour_changed.emit(current_hour)
	if current_hour == 0:
		current_day += 1
		day_advanced.emit(current_day)

## Jump directly to a given hour (0–23) and reset minutes + accumulator.
## Always emits hour_changed so all listeners update their visuals immediately.
func set_hour(h: int) -> void:
	current_hour   = clampi(h, 0, 23)
	current_minute = 0
	_accumulator   = 0.0
	hour_changed.emit(current_hour)

## Fast-advance by the given number of in-game minutes.
## Capped at 1440 (one full day) to prevent UI freezes.
func add_minutes(mins: int) -> void:
	var cap := mini(absi(mins), 1440)
	for _i in range(cap):
		_tick_minute()

## Returns the current time as a float in [0, 24), *including* the fractional
## position within the current minute from the accumulator.  This gives a
## continuously-changing value suitable for smooth colour gradient sampling.
func get_normalized_time() -> float:
	var frac_min := clampf(_accumulator / TICK_SPEED, 0.0, 1.0)
	var total_minutes := float(current_hour * 60 + current_minute) + frac_min
	return total_minutes / (24.0 * 60.0)

## Human-readable time string, e.g. "08:30".
func get_time_string() -> String:
	return "%02d:%02d" % [current_hour, current_minute]

## Returns the ambient sky Color for a normalized time value (0.0 = 0:00, 1.0 = 24:00).
## Smoothly lerps between the two nearest SKY_COLORS entries.
func sky_color_for_normalized(t: float) -> Color:
	var hours: float = clampf(t, 0.0, 1.0) * 24.0
	var idx: int     = floori(hours) % 24
	var frac: float  = hours - floorf(hours)
	var c0: Color    = SKY_COLORS[idx]
	var c1: Color    = SKY_COLORS[(idx + 1) % 24]
	return c0.lerp(c1, frac)
