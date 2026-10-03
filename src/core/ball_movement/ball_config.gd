## Tuning data of Ball Movement (GDD Tuning Knobs, Core Rule 13). Every gameplay value lives here, never in code.
##
## `validated(log_sink)` returns a clamped copy; `BallCore` always works on a validated copy and the loaded
## resource is never modified. All fields are `@export` scalars so that `duplicate()` copies them. Field names are
## the snake_case of the GDD knob names (`STEER_ARC` is `steer_arc`, `BALL_DIAMETER` is `ball_diameter`, ...).
class_name BallConfig
extends Resource

## The steer-to-motion mapping (Core Rule 4). Explicit integers: they are stored in `.tres` files.
enum MappingMode { POSITION = 0, RATE = 1 }

## Log codes of Ball Movement (all error level, GDD AC-18). `KNOB_CLAMPED` is the only one this file emits.
const LOG_BAD_DT: StringName = &"BAD_DT"
const LOG_DT_OVER_MAX: StringName = &"DT_OVER_MAX"
const LOG_BAD_STEER: StringName = &"BAD_STEER"
const LOG_KNOB_CLAMPED: StringName = &"KNOB_CLAMPED"

## Ceiling of `T(PI, 0.05)` in seconds (GDD F5a): Tube Track `T_VIS_MIN` 1.5 minus 0.25 reaction minus 0.11 latency.
## Re-derive it if any of those three changes.
const T_DODGE_180_MAX: float = 1.14

## Shortest accepted `T_RAMP` greater than zero; `T_RAMP <= 0` is the "V_MAX from the start" sentinel.
const _T_RAMP_MIN: float = 45.0
const _DT_MAX_DEFAULT: float = 0.1
const _BISECT_TOLERANCE: float = 1e-9
const _BISECT_ITERATIONS: int = 60

@export_group("Steering")
## Radians of ball travel per unit `steer` (safe range 2.09 to PI).
@export_range(2.09, 3.141592653589793) var steer_arc: float = PI
## Lag constant of F1 in seconds; 0 means no lag, cap only (safe range 0 to 0.072).
@export_range(0.0, 0.072) var ball_lag_tau: float = 0.06
## The fastest the ball can turn, rad/s (safe range 2.75 to 4.0).
@export_range(2.75, 4.0) var omega_max: float = 3.0
## POSITION or RATE; an unrecognized value becomes POSITION.
@export var mapping_mode: MappingMode = MappingMode.POSITION

@export_group("Forward speed")
## Speed at the start of a run, u/s (safe range 6 to 14).
@export_range(6.0, 14.0) var v_start: float = 10.0
## Speed ceiling, u/s (safe range 18 to 30).
@export_range(18.0, 30.0) var v_max: float = 25.0
## Seconds to ramp from `v_start` to `v_max`: 0 or less (sentinel) or 45 to 240.
@export var t_ramp: float = 90.0

@export_group("Ball")
## Ball diameter `D` in world units (safe range 0.6 to 1.0); `WorldGeometry` is built from it.
@export_range(0.6, 1.0) var ball_diameter: float = 0.8


## Returns a copy with every value inside its safe range. NaN and infinity are replaced by the default, then each
## value is clamped (one `KNOB_CLAMPED` per value changed), then the derived `T_DODGE_180` check lowers
## `ball_lag_tau` (never `omega_max`) when `T(PI, 0.05)` exceeds `T_DODGE_180_MAX` (one more `KNOB_CLAMPED`).
## `log_sink` is called as `log_sink(level: int, code: StringName, message: String)` with `RateLimitedLog.Level.ERROR`.
## The loaded resource is left untouched.
func validated(log_sink: Callable) -> BallConfig:
	var out: BallConfig = duplicate() as BallConfig
	var defaults: BallConfig = BallConfig.new()

	out.steer_arc = _sane(out.steer_arc, defaults.steer_arc, 2.09, PI, "steer_arc", log_sink)
	out.ball_lag_tau = _sane(out.ball_lag_tau, defaults.ball_lag_tau, 0.0, 0.072, "ball_lag_tau", log_sink)
	out.omega_max = _sane(out.omega_max, defaults.omega_max, 2.75, 4.0, "omega_max", log_sink)
	out.v_start = _sane(out.v_start, defaults.v_start, 6.0, 14.0, "v_start", log_sink)
	out.v_max = _sane(out.v_max, defaults.v_max, 18.0, 30.0, "v_max", log_sink)
	out.ball_diameter = _sane(out.ball_diameter, defaults.ball_diameter, 0.6, 1.0, "ball_diameter", log_sink)

	if int(out.mapping_mode) != MappingMode.POSITION and int(out.mapping_mode) != MappingMode.RATE:
		_log_clamped(log_sink, "mapping_mode=%s is not a MappingMode; using POSITION" % [int(out.mapping_mode)])
		out.mapping_mode = MappingMode.POSITION

	out.t_ramp = _validated_t_ramp(out.t_ramp, defaults.t_ramp, log_sink)

	# Derived check last, on the already clamped pair.
	if BallMath.T(PI, 0.05, out.omega_max, out.ball_lag_tau) > T_DODGE_180_MAX:
		var before: float = out.ball_lag_tau
		out.ball_lag_tau = _tau_at_ceiling(out.omega_max, before)
		_log_clamped(
			log_sink,
			"ball_lag_tau=%s makes T(PI, 0.05) exceed %s s at omega_max=%s; using %s"
			% [before, T_DODGE_180_MAX, out.omega_max, out.ball_lag_tau]
		)
	return out


## Validates the `dt_max` injected into the core (Run State's `DT_MAX`): zero, negative, NaN or infinite becomes
## 0.1 with one `KNOB_CLAMPED`; any other value is returned unchanged.
static func validated_dt_max(dt_max: float, log_sink: Callable) -> float:
	if is_finite(dt_max) and dt_max > 0.0:
		return dt_max
	_log_clamped(log_sink, "dt_max=%s is not a positive finite step; using %s" % [dt_max, _DT_MAX_DEFAULT])
	return _DT_MAX_DEFAULT


## Bisection over `[0, tau_hi]` for the largest `ball_lag_tau` with `T(PI, 0.05) == T_DODGE_180_MAX` (Rule 13):
## stops at `|err| <= 1e-9` or after 60 iterations. `T` is non-decreasing in tau, so this is well posed.
static func _tau_at_ceiling(omega_max: float, tau_hi: float) -> float:
	var lo: float = 0.0
	var hi: float = tau_hi
	for _i: int in _BISECT_ITERATIONS:
		var mid: float = (lo + hi) / 2.0
		var t: float = BallMath.T(PI, 0.05, omega_max, mid)
		if absf(t - T_DODGE_180_MAX) <= _BISECT_TOLERANCE:
			return mid
		if t > T_DODGE_180_MAX:
			hi = mid
		else:
			lo = mid
	return (lo + hi) / 2.0


static func _validated_t_ramp(value: float, default_value: float, log_sink: Callable) -> float:
	if is_nan(value) or is_inf(value):
		_log_clamped(log_sink, "t_ramp=%s is not finite; using %s" % [value, default_value])
		return default_value
	if value <= 0.0:
		return value
	return _sane(value, default_value, _T_RAMP_MIN, 240.0, "t_ramp", log_sink)


static func _sane(value: float, default_value: float, lo: float, hi: float, field: String, log_sink: Callable) -> float:
	var candidate: float = value
	if is_nan(candidate) or is_inf(candidate):
		_log_clamped(log_sink, "%s=%s is not finite; using %s" % [field, value, default_value])
		return clampf(default_value, lo, hi)
	var clamped: float = clampf(candidate, lo, hi)
	if clamped != candidate:
		_log_clamped(log_sink, "%s=%s is outside [%s, %s]; using %s" % [field, value, lo, hi, clamped])
	return clamped


static func _log_clamped(log_sink: Callable, message: String) -> void:
	if log_sink.is_valid():
		log_sink.call(RateLimitedLog.Level.ERROR, LOG_KNOB_CLAMPED, message)
