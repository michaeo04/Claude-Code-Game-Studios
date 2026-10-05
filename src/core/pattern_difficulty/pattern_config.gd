## Tuning data of Pattern & Difficulty (GDD Tuning Knobs). Every gameplay value lives here, never in code.
##
## `validated(log_sink)` returns a clamped copy and logs one stable code per rejected knob through
## `log_sink(level, code, key, message)` (`LogLevel`). A rejected knob falls back to its default in the copy.
## Guard order: duration range guards, then `TIER_ORDER_INVALID`, then `ANGULAR_THRESHOLD_OUT_OF_RANGE`.
class_name PatternConfig
extends Resource

const TIER_DURATION_OUT_OF_RANGE: StringName = &"TIER_DURATION_OUT_OF_RANGE"
const TIER_ORDER_INVALID: StringName = &"TIER_ORDER_INVALID"
const ANGULAR_THRESHOLD_OUT_OF_RANGE: StringName = &"ANGULAR_THRESHOLD_OUT_OF_RANGE"

# Packed arrays keep float64 bounds (Vector2 would round them to float32).
const _INTRO_RANGE: PackedFloat64Array = [8.0, 20.0]
const _RAMP_RANGE: PackedFloat64Array = [45.0, 240.0]
const _THRESHOLD_RANGE: PackedFloat64Array = [PI / 3.0, 2.0 * PI / 3.0]

## Seconds of run time in the INTRO tier (safe range 8 to 20).
@export var tier_intro_duration: float = 15.0
## Run time at which the RAMP tier ends (safe range 45 to 240); must exceed `tier_intro_duration`.
@export var tier_ramp_duration: float = 90.0
## Wrapped angular difference above which two dodge angles oppose (safe range PI/3 to 2*PI/3).
@export var angular_reversal_threshold: float = PI / 2.0
## Largest tolerated share of opposing pairs in a tier pool (clustering advisory, Story 008).
@export var max_opposing_fraction: float = 0.6


## Returns a validated copy; the loaded resource is left untouched.
func validated(log_sink: Callable = Callable()) -> PatternConfig:
	var out: PatternConfig = duplicate() as PatternConfig
	var defaults: PatternConfig = PatternConfig.new()
	var raw_intro: float = out.tier_intro_duration
	var raw_ramp: float = out.tier_ramp_duration
	if not _in_range(out.tier_intro_duration, _INTRO_RANGE):
		_log(log_sink, TIER_DURATION_OUT_OF_RANGE, "tier_intro_duration", out.tier_intro_duration, "8 to 20")
		out.tier_intro_duration = defaults.tier_intro_duration
	if not _in_range(out.tier_ramp_duration, _RAMP_RANGE):
		_log(log_sink, TIER_DURATION_OUT_OF_RANGE, "tier_ramp_duration", out.tier_ramp_duration, "45 to 240")
		out.tier_ramp_duration = defaults.tier_ramp_duration
	# The order guard is independent of the range guards (GDD AC-1 uses 90/90 and 91/90, outside the intro range).
	if not (raw_intro < raw_ramp):
		_log(log_sink, TIER_ORDER_INVALID, "tier_ramp_duration", raw_ramp, "must exceed tier_intro_duration")
		out.tier_intro_duration = defaults.tier_intro_duration
		out.tier_ramp_duration = defaults.tier_ramp_duration
	if not _in_range(out.angular_reversal_threshold, _THRESHOLD_RANGE):
		_log(
			log_sink,
			ANGULAR_THRESHOLD_OUT_OF_RANGE,
			"angular_reversal_threshold",
			out.angular_reversal_threshold,
			"PI/3 to 2*PI/3"
		)
		out.angular_reversal_threshold = defaults.angular_reversal_threshold
	var fraction: float = out.max_opposing_fraction
	out.max_opposing_fraction = clampf(fraction if is_finite(fraction) else defaults.max_opposing_fraction, 0.0, 1.0)
	return out


static func _in_range(value: float, bounds: PackedFloat64Array) -> bool:
	return is_finite(value) and value >= bounds[0] and value <= bounds[1]


static func _log(log_sink: Callable, code: StringName, key: String, value: float, expected: String) -> void:
	if log_sink.is_valid():
		log_sink.call(LogLevel.ERROR, code, key, "%s = %s rejected (%s)" % [key, value, expected])
