## Tuning data of Run State & Restart (GDD Tuning Knobs, F4). Every gameplay value lives here, never in code.
##
## `validated(log_sink)` returns a clamped copy; the core always works on a validated copy and the
## original resource is never modified. All fields are `@export` so that `duplicate()` copies them.
class_name RunConfig
extends Resource

## Tolerance of the lock-versus-read-time invariant of F4 (float noise in `0.45 - 0.20`).
const _READ_EPSILON: float = 1e-9

@export_group("Restart")
## Seconds after a hit during which restart and menu presses are ignored (safe range LOCK_MIN to LOCK_MAX).
@export var restart_lock: float = 0.5
## Seconds after entering Paused during which restart and menu presses are ignored (safe range 0.2 to 0.5).
@export var pause_input_guard: float = 0.3

@export_group("Resume")
## Seconds of the resume countdown (safe range 1.0 to 3.0).
@export var resume_countdown: float = 2.0

@export_group("Clock")
## Clamp on the run clock step, shared with Tube Track's `t_lat` (safe range 0.05 to 0.25).
@export var dt_max: float = TuningLimits.DT_MAX_DEFAULT
## A frame this long while Running or Resuming is treated as an interruption (safe range 0.5 to 3.0).
@export var stall_pause_threshold: float = 0.5

@export_group("Lock bounds (F4)")
## The real hitstop length, injected by the composition root; Run State never calls Juice.
@export var hitstop_actual: float = 0.2
## Longest hitstop of the art bible (mood state 5).
@export var hitstop_max: float = 0.2
## Time to read the isolated killer after the grey-out.
@export var t_read: float = 0.25
## Simple visual reaction time.
@export var t_react: float = 0.25
## One panic tap at about 6 to 7 taps per second.
@export var t_stop: float = 0.15
## Above this lock the wait reads as waiting.
@export var friction_max: float = 0.6
## The restart budget fixed by the art bible.
@export var restart_budget: float = 1.0
## `T_restart` sum at 30 fps (F2); a field so that the `LOCK_MIN > LOCK_MAX` case is reachable through the seam.
@export var t_restart_30fps: float = 0.266


## `LOCK_MIN` of F4 for this config.
func lock_min() -> float:
	return RunStateMath.lock_min(hitstop_max, t_read, t_react, t_stop)


## `LOCK_MAX` of F4 for this config.
func lock_max() -> float:
	return RunStateMath.lock_max(friction_max, restart_budget, t_restart_30fps)


## `RESTART_LOCK_us = round(RESTART_LOCK * 1e6)`.
func restart_lock_us() -> int:
	return RunStateMath.seconds_to_us(restart_lock)


## `PAUSE_INPUT_GUARD_us = round(PAUSE_INPUT_GUARD * 1e6)`.
func pause_input_guard_us() -> int:
	return RunStateMath.seconds_to_us(pause_input_guard)


## The resume countdown in microseconds.
func resume_countdown_us() -> int:
	return RunStateMath.seconds_to_us(resume_countdown)


## The resume countdown in milliseconds, as carried by `run_resuming(duration_ms)`.
func resume_countdown_ms() -> int:
	return RunStateMath.seconds_to_ms(resume_countdown)


## Returns a copy with every value inside its safe range. NaN and infinity are replaced by the default,
## then each value is clamped; one error is logged through `log_sink(level, code, key, message)` (see `LogLevel`) per corrected value
## (GDD Tuning Knobs, "Interactions between knobs"). Run State never runs with an unsafe value.
func validated(log_sink: Callable) -> RunConfig:
	var out: RunConfig = duplicate() as RunConfig
	var defaults: RunConfig = RunConfig.new()

	# Derivation constants first: the lock bounds depend on them.
	out.hitstop_actual = _sane(out.hitstop_actual, defaults.hitstop_actual, 0.0, INF, "hitstop_actual", log_sink)
	out.hitstop_max = _sane(out.hitstop_max, defaults.hitstop_max, 0.0, INF, "hitstop_max", log_sink)
	out.t_read = _sane(out.t_read, defaults.t_read, 0.0, INF, "t_read", log_sink)
	out.t_react = _sane(out.t_react, defaults.t_react, 0.0, INF, "t_react", log_sink)
	out.t_stop = _sane(out.t_stop, defaults.t_stop, 0.0, INF, "t_stop", log_sink)
	out.friction_max = _sane(out.friction_max, defaults.friction_max, 0.0, INF, "friction_max", log_sink)
	out.restart_budget = _sane(out.restart_budget, defaults.restart_budget, 0.0, INF, "restart_budget", log_sink)
	out.t_restart_30fps = _sane(out.t_restart_30fps, defaults.t_restart_30fps, 0.0, INF, "t_restart_30fps", log_sink)

	out.resume_countdown = _sane(out.resume_countdown, defaults.resume_countdown, 1.0, 3.0, "resume_countdown", log_sink)
	out.dt_max = _sane(out.dt_max, defaults.dt_max, 0.05, 0.25, "dt_max", log_sink)
	out.stall_pause_threshold = _sane(
		out.stall_pause_threshold, defaults.stall_pause_threshold, 0.5, 3.0, "stall_pause_threshold", log_sink
	)
	out.pause_input_guard = _sane(
		out.pause_input_guard, defaults.pause_input_guard, 0.2, 0.5, "pause_input_guard", log_sink
	)

	var lower: float = out.lock_min()
	var upper: float = out.lock_max()
	if lower > upper:
		_log_error(log_sink, RunStateMath.LOG_CONFIG_LOCK_BOUNDS, "LOCK_MIN %s > LOCK_MAX %s; LOCK_MIN wins" % [lower, upper])
		upper = lower
	out.restart_lock = _sane(out.restart_lock, defaults.restart_lock, lower, upper, "restart_lock", log_sink)

	# RESTART_LOCK - hitstop_actual >= T_READ, else raise the lock, capped at LOCK_MAX.
	if out.restart_lock - out.hitstop_actual + _READ_EPSILON < out.t_read:
		var raised: float = minf(out.hitstop_actual + out.t_read, upper)
		_log_error(
			log_sink,
			RunStateMath.LOG_CONFIG_LOCK_READ,
			"restart_lock %s leaves less than t_read %s after hitstop %s; raised to %s"
			% [out.restart_lock, out.t_read, out.hitstop_actual, raised]
		)
		out.restart_lock = raised
	return out


static func _sane(value: float, default_value: float, lo: float, hi: float, field: String, log_sink: Callable) -> float:
	var candidate: float = value
	var replaced: bool = false
	if is_nan(candidate) or is_inf(candidate):
		candidate = default_value
		replaced = true
	var clamped: float = clampf(candidate, lo, hi)
	if replaced or clamped != candidate:
		_log_error(
			log_sink, RunStateMath.LOG_CONFIG_CLAMPED, "%s=%s is outside [%s, %s]; using %s" % [field, value, lo, hi, clamped]
		)
	return clamped


static func _log_error(log_sink: Callable, code: StringName, detail: String) -> void:
	if log_sink.is_valid():
		log_sink.call(LogLevel.ERROR, code, "", detail)
