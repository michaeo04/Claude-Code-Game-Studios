## Ball Movement core (design/gdd/ball-movement.md Core Rules 1 to 13, F1, F2, F4, F6).
##
## Engine-free `RefCounted`: no clock, no engine delta, no randomness; the same input sequence gives the same
## output. `GameRoot` calls `step(dt_eff, steer, valid, input_source)` once per tick after `RunState.tick`
## (ADR-0002). `s` is a float64 that is never wrapped, capped or re-based (ADR-0013). Not persisted (TR-022).
## Rate mode, the resume anchor and the 2 PI shift belong to later stories (006, 007).
class_name BallCore
extends RefCounted

## Where the steer came from (`input_source` of `step`). Any value other than FALLBACK counts as SENSOR.
enum InputSource { SENSOR = 0, FALLBACK = 1 }

## Published state (Rule 8), read-only for consumers.
var theta: float:
	get:
		return _theta
## `theta` before the latest step (equal to `theta` after a no-op step).
var theta_prev: float:
	get:
		return _theta_prev
## Distance since the run started, float64, never wrapped or capped.
var s: float:
	get:
		return _s
## `s` before the latest step.
var s_prev: float:
	get:
		return _s_prev
## Current forward speed in u/s.
var speed: float:
	get:
		return _speed
## Applied angular step divided by `dt_eff` (F4); 0 when the step moved nothing.
var omega: float:
	get:
		return _omega
## Ball radius `D / 2`.
var radius: float:
	get:
		return _radius
## Test getter: tracked unwrapped angle.
var phi: float:
	get:
		return _phi
## Test getter: anchor of the position mapping.
var phi_anchor: float:
	get:
		return _phi_anchor
## Test getter: rate-mode angular velocity.
var w: float:
	get:
		return _w
## Test getter: accumulated run time in seconds.
var t_run: float:
	get:
		return _t_run

var _cfg: BallConfig
var _dt_max: float
var _log_sink: Callable
var _radius: float

var _phi: float = 0.0
var _phi_anchor: float = 0.0
var _w: float = 0.0
var _t_run: float = 0.0
var _theta: float = 0.0
var _theta_prev: float = 0.0
var _s: float = 0.0
var _s_prev: float = 0.0
var _speed: float = 0.0
var _omega: float = 0.0
var _held_steer: float = 0.0


## `cfg` must already be validated (`BallConfig.validated`). `dt_max` is Run State's `DT_MAX`; a non-positive or
## non-finite value becomes 0.1 with one `KNOB_CLAMPED`. `log_sink` is `Callable(level, code, message)`.
func _init(cfg: BallConfig, dt_max: float, log_sink: Callable) -> void:
	_cfg = cfg
	_log_sink = log_sink
	_dt_max = BallConfig.validated_dt_max(dt_max, log_sink)
	_radius = cfg.ball_diameter / 2.0
	reset()


## Synchronous run reset (Rule 9): pose at the top of the tube, `s` and `t_run` 0, `speed = speed(0)`, held steer 0.
func reset() -> void:
	_phi = 0.0
	_phi_anchor = 0.0
	_w = 0.0
	_t_run = 0.0
	_theta = 0.0
	_theta_prev = 0.0
	_s = 0.0
	_s_prev = 0.0
	_omega = 0.0
	_held_steer = 0.0
	_speed = BallMath.speed(0.0, _cfg.v_start, _cfg.v_max, _cfg.t_ramp)


## One step per tick (Rule 2). `dt_eff <= 0` or non-finite changes nothing but the previous values; a non-finite
## `dt_eff` or a negative one logs `BAD_DT`. `dt_eff > dt_max` is clamped with `DT_OVER_MAX`.
## `steer` is clamped to [-1, 1]; when `valid` is false or `steer` is non-finite the last accepted steer is held.
## Example: `core.step(1.0 / 60.0, 0.5, true, BallCore.InputSource.SENSOR)`.
func step(dt_eff: float, steer: float, valid: bool, _input_source: int) -> void:
	_theta_prev = _theta
	_s_prev = _s
	_omega = 0.0
	if is_nan(dt_eff) or is_inf(dt_eff) or dt_eff < 0.0:
		_log(BallConfig.LOG_BAD_DT, "dt_eff=%s is not a usable step; treated as 0" % [dt_eff])
		return
	if dt_eff == 0.0:
		return

	var dt: float = dt_eff
	if dt > _dt_max:
		_log(BallConfig.LOG_DT_OVER_MAX, "dt_eff=%s exceeds dt_max=%s; clamped" % [dt_eff, _dt_max])
		dt = _dt_max

	_accept_steer(steer, valid)

	# Forward motion: exact integral of the speed curve (F2).
	var t_old: float = _t_run
	_t_run = t_old + dt
	_s += (
		BallMath.S(_t_run, _cfg.v_start, _cfg.v_max, _cfg.t_ramp)
		- BallMath.S(t_old, _cfg.v_start, _cfg.v_max, _cfg.t_ramp)
	)
	_speed = BallMath.speed(_t_run, _cfg.v_start, _cfg.v_max, _cfg.t_ramp)

	# Position mapping (F1).
	var phi_old: float = _phi
	var target: float = _phi_anchor + _cfg.steer_arc * _held_steer
	var raw_error: float = target - _phi
	var e: float = BallMath.wrap_angle(raw_error)
	# Exact half-turn tie: wrap_angle maps +PI to -PI, which would send a full-lock steer the wrong way round
	# (AC-3/AC-7/AC-8 expect +steer to increase phi). The tie resolves toward the sign of the raw error.
	if e == -PI and raw_error > 0.0:
		e = PI
	_phi += BallMath.step(e, dt, _cfg.ball_lag_tau, _cfg.omega_max)
	_omega = (_phi - phi_old) / dt
	_theta = BallMath.wrap_angle(_phi)


func _accept_steer(steer: float, valid: bool) -> void:
	if not valid:
		return
	if is_nan(steer) or is_inf(steer):
		_log(BallConfig.LOG_BAD_STEER, "steer=%s is not finite; holding %s" % [steer, _held_steer])
		return
	_held_steer = clampf(steer, -1.0, 1.0)


func _log(code: StringName, message: String) -> void:
	if _log_sink.is_valid():
		_log_sink.call(RateLimitedLog.Level.ERROR, code, message)
