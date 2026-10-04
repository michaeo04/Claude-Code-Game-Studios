## Tuning data of Tilt Input (GDD Tuning Knobs, rule 14). Every gameplay value lives here, never in code.
##
## `validated(log_sink)` returns a clamped copy and never modifies the loaded resource. Durations are in seconds,
## angles in degrees. Field names are the snake_case of the GDD knob names. Logging goes through
## `log_sink(level: int, code: StringName, key: String, message: String)` (see `LogLevel`).
class_name TiltConfig
extends Resource

## The only log code this file emits (error level).
const LOG_KNOB_CLAMPED: StringName = &"KNOB_CLAMPED"
## Fixed range of the Settings `sensitivity` hook.
const SENSITIVITY_MIN: float = 0.5
const SENSITIVITY_MAX: float = 2.0
## Lowest supported frame rate (Hz), a fixed constant that bounds `neutral_min_samples`.
const F_MIN: int = 20
## `neutral_guard + neutral_window` ceiling, and `settle + guard + window` ceiling, in seconds.
const _GW_MAX_US: int = 900000
const _SETTLE_TOTAL_US: int = 1000000
const _US: float = 1e6

@export_group("Mapping")
## Wrist range for full lock in degrees (safe range 12 to 45).
@export var tilt_full_scale: float = 25.0
## Dead zone in degrees (0 to 4, at most 0.15 * `tilt_full_scale`).
@export var dead_zone: float = 1.5
## Filter time constant in seconds (0.02 to 0.10).
@export var filter_tau: float = 0.05
## Mid-range curve exponent (1 to 2).
@export var curve_exp: float = 1.0
## Sign of the roll (+1 or -1); -1 is the expected value on Android.
@export var sensor_sign: int = -1

@export_group("Neutral capture")
## Neutral window in seconds (0.15 to 0.6, with guard + window <= 0.9).
@export var neutral_window: float = 0.3
## Guard before the window in seconds (0.05 to 0.35).
@export var neutral_guard: float = 0.25
## Minimum samples in the window (3 to 6, at most floor(window * F_MIN)).
@export var neutral_min_samples: int = 5
## Re-anchor offset in degrees (8 to 16).
@export var reanchor_offset: float = 12.0
## Re-anchor spread in degrees (1 to 6).
@export var reanchor_spread: float = 3.0

@export_group("Sensor")
## Minimum valid gravity magnitude in m/s^2 (1 to 7).
@export var g_min: float = 3.0
## Seconds before Acquiring falls back (0.5 to 5).
@export var sensor_start_timeout: float = 2.0
## Seconds discarded after an app foreground (0.1 to 1.0, at most 1 - guard - window).
@export var sensor_resume_settle: float = 0.3
## Accumulated invalid-poll time before Unavailable, in seconds (0 to 0.3).
@export var dropout_hold: float = 0.1
## Fallback response per second (1 to 20).
@export var fallback_slew: float = 4.0


## Test-only: returns an unvalidated copy of this config. Never call it from `src/`.
func unvalidated() -> TiltConfig:
	return duplicate() as TiltConfig


## Returns a copy with every value inside its safe range (rule 14 order): each knob to its own range (a non-finite
## value takes the default), then `guard + window <= 0.9` (window lowered), `settle <= 1 - guard - window`,
## `neutral_min_samples <= floor(window * F_MIN)`, `dead_zone <= 0.15 * tilt_full_scale`.
## One `KNOB_CLAMPED` per knob change. The loaded resource is left untouched.
func validated(log_sink: Callable) -> TiltConfig:
	var out: TiltConfig = duplicate() as TiltConfig
	var d: TiltConfig = TiltConfig.new()

	out.tilt_full_scale = _sane(out.tilt_full_scale, d.tilt_full_scale, 12.0, 45.0, "tilt_full_scale", log_sink)
	out.dead_zone = _sane(out.dead_zone, d.dead_zone, 0.0, 4.0, "dead_zone", log_sink)
	out.filter_tau = _sane(out.filter_tau, d.filter_tau, 0.02, 0.10, "filter_tau", log_sink)
	out.curve_exp = _sane(out.curve_exp, d.curve_exp, 1.0, 2.0, "curve_exp", log_sink)
	if out.sensor_sign != 1 and out.sensor_sign != -1:
		_log_clamped(log_sink, "sensor_sign=%s is not +1 or -1; using %s" % [out.sensor_sign, d.sensor_sign])
		out.sensor_sign = d.sensor_sign
	out.neutral_window = _sane(out.neutral_window, d.neutral_window, 0.15, 0.6, "neutral_window", log_sink)
	out.neutral_guard = _sane(out.neutral_guard, d.neutral_guard, 0.05, 0.35, "neutral_guard", log_sink)
	out.neutral_min_samples = _sane_int(out.neutral_min_samples, 3, 6, "neutral_min_samples", log_sink)
	out.reanchor_offset = _sane(out.reanchor_offset, d.reanchor_offset, 8.0, 16.0, "reanchor_offset", log_sink)
	out.reanchor_spread = _sane(out.reanchor_spread, d.reanchor_spread, 1.0, 6.0, "reanchor_spread", log_sink)
	out.g_min = _sane(out.g_min, d.g_min, 1.0, 7.0, "g_min", log_sink)
	out.sensor_start_timeout = _sane(out.sensor_start_timeout, d.sensor_start_timeout, 0.5, 5.0, "sensor_start_timeout", log_sink)
	out.sensor_resume_settle = _sane(out.sensor_resume_settle, d.sensor_resume_settle, 0.1, 1.0, "sensor_resume_settle", log_sink)
	out.dropout_hold = _sane(out.dropout_hold, d.dropout_hold, 0.0, 0.3, "dropout_hold", log_sink)
	out.fallback_slew = _sane(out.fallback_slew, d.fallback_slew, 1.0, 20.0, "fallback_slew", log_sink)

	# Rule 14, cross-knob steps, durations compared in integer microseconds.
	var guard_us: int = roundi(out.neutral_guard * _US)
	var window_us: int = roundi(out.neutral_window * _US)
	if guard_us + window_us > _GW_MAX_US:
		var fixed_window: float = float(_GW_MAX_US - guard_us) / _US
		_log_clamped(log_sink, "neutral_window=%s with guard %s exceeds 0.9 s; using %s" % [out.neutral_window, out.neutral_guard, fixed_window])
		out.neutral_window = fixed_window
		window_us = _GW_MAX_US - guard_us
	var settle_max_us: int = _SETTLE_TOTAL_US - guard_us - window_us
	if roundi(out.sensor_resume_settle * _US) > settle_max_us:
		var fixed_settle: float = float(settle_max_us) / _US
		_log_clamped(log_sink, "sensor_resume_settle=%s exceeds %s; using it" % [out.sensor_resume_settle, fixed_settle])
		out.sensor_resume_settle = fixed_settle
	var n_max: int = window_us * F_MIN / 1000000
	if out.neutral_min_samples > n_max:
		_log_clamped(log_sink, "neutral_min_samples=%s exceeds floor(window * F_MIN)=%s; using it" % [out.neutral_min_samples, n_max])
		out.neutral_min_samples = n_max
	var dz_max: float = 0.15 * out.tilt_full_scale
	if out.dead_zone > dz_max:
		_log_clamped(log_sink, "dead_zone=%s exceeds 0.15 * tilt_full_scale; using %s" % [out.dead_zone, dz_max])
		out.dead_zone = dz_max
	return out


## The Settings `sensitivity` hook: NaN, infinity or a value <= 0 becomes 1; a finite value is clamped to
## `[SENSITIVITY_MIN, SENSITIVITY_MAX]`. One `KNOB_CLAMPED` per value changed.
## Example: `validated_sensitivity(3.0, sink)` is `2.0`.
static func validated_sensitivity(value: float, log_sink: Callable) -> float:
	if is_nan(value) or is_inf(value) or value <= 0.0:
		_log_clamped(log_sink, "sensitivity=%s is not a positive finite value; using 1" % [value])
		return 1.0
	var clamped: float = clampf(value, SENSITIVITY_MIN, SENSITIVITY_MAX)
	if clamped != value:
		_log_clamped(log_sink, "sensitivity=%s is outside [%s, %s]; using %s" % [value, SENSITIVITY_MIN, SENSITIVITY_MAX, clamped])
	return clamped


static func _sane(value: float, default_value: float, lo: float, hi: float, field: String, log_sink: Callable) -> float:
	if is_nan(value) or is_inf(value):
		_log_clamped(log_sink, "%s=%s is not finite; using %s" % [field, value, default_value])
		return clampf(default_value, lo, hi)
	var clamped: float = clampf(value, lo, hi)
	if clamped != value:
		_log_clamped(log_sink, "%s=%s is outside [%s, %s]; using %s" % [field, value, lo, hi, clamped])
	return clamped


static func _sane_int(value: int, lo: int, hi: int, field: String, log_sink: Callable) -> int:
	var clamped: int = clampi(value, lo, hi)
	if clamped != value:
		_log_clamped(log_sink, "%s=%s is outside [%s, %s]; using %s" % [field, value, lo, hi, clamped])
	return clamped


static func _log_clamped(log_sink: Callable, message: String) -> void:
	if log_sink.is_valid():
		log_sink.call(LogLevel.ERROR, LOG_KNOB_CLAMPED, "", message)
