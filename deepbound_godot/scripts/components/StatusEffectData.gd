extends Resource
class_name StatusEffectData

## Serialisable data container for a single status effect / character modifier.
##
## Instances are created by StatusEffectCatalog.make() and held inside a
## StatusManager component.  All runtime state (duration countdown) lives here
## so the StatusManager can hold a plain Array of these resources.

## Unique string identifier, e.g. "swiftness", "slow", "curse".
var effect_id: String = ""

## Human-readable label shown in the BuffUI tooltip.
var display_name: String = ""

## Optional icon texture.  When null the BuffUI renders a coloured square.
var icon: Texture2D = null

## Remaining duration in seconds.  Values <= 0.0 mean the effect is permanent
## (it persists until explicitly removed via StatusManager.remove_effect()).
var duration: float = 0.0

## Flat / fractional stat changes applied while this effect is active.
## Supported keys (same names as StatCalculator totals):
##   "damage"     — int flat bonus/penalty
##   "defense"    — int flat bonus/penalty
##   "health_max" — int bonus max HP
##   "speed"      — float fractional offset (0.15 = +15 %, same scale as
##                  PlayerController.equipment_speed_bonus)
var stat_modifiers: Dictionary = {}

## When true the BuffUI renders this entry with a red/orange border instead of
## the green/blue buff border.
var is_debuff: bool = false
