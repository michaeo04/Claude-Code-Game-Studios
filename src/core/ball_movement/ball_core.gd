## Ball Movement core (design/gdd/ball-movement.md Core Rules 1 to 13, F1, F2, F4, F6).
##
## Engine-free `RefCounted`: no clock, no engine delta, no randomness; the same input sequence gives the same
## output. `GameRoot` calls `step(dt_eff, steer, valid, input_source)` once per tick after `RunState.tick`
## (ADR-0002). `s` is a float64 that is never wrapped, capped or re-based (ADR-0013). Not persisted (TR-022).
## The resume anchor re-base and the 2 PI shift live here (Rule 5); RATE mapping (F3) and the mapping-mode latch
## (Rule 6) too. The MVP driver never passes FALLBACK (a no-sensor device is blocked at HUD/Menus, GDD Rule 6, B9);
## the RATE code is kept for the post-MVP fallback and for the BM-5 comparison.
## Constraint on content, not on this code (TR-ball-movement-023): the segments covering `s` = 0 to 11 u must be
## hazard-free because of the up-to-1.064 s glide after a reset with a non-zero steer (Pattern & Difficulty epic).
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

## Test getter: the last accepted (held) steer.
var held_steer: float:
	get:
		return _held_steer
## Test getter: true once the mapping mode has latched (first step with `dt_eff > 0` after `reset()`).
var mode_latched: bool:
	get:
		return _mode_latched
## Test getter: true when the latched mapping is RATE.
var rate_mode: bool:
	get:
		return _rate_mode

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
var _rebase_armed: bool = false
var _mode_latched: bool = false
var _rate_mode: bool = false


## `cfg` must already be validated (`BallConfig.validated`). `dt_max` is Run State's `DT_MAX`; a non-positive or
## non-finite value becomes 0.1 with one `KNOB_CLAMPED`. `log_sink` is `Callable(level, code, key, message)` (see `LogLevel`).
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
	_rebase_armed = false
	_mode_latched = false
	_rate_mode = false
	_speed = BallMath.speed(0.0, _cfg.v_start, _cfg.v_max, _cfg.t_ramp)


## `run_reset(run_id)` subscriber (ADR-0002 rank 3): same as `reset()`. Example: `rs.run_reset.connect(ball.on_run_reset)`.
func on_run_reset(_run_id: int) -> void:
	reset()


## `run_resumed(run_id)` subscriber: same as `on_resumed()`.
func on_run_resumed(_run_id: int) -> void:
	on_resumed()


## `run_resumed` happened (Rule 5): the first step with `dt_eff > 0` re-bases the anchor so the target equals the
## current pose, and the rate-mode velocity `w` goes to 0 (the mode is not re-latched). A step with `dt_eff = 0`
## does not consume the re-base. Example: `core.on_resumed()`.
func on_resumed() -> void:
	_rebase_armed = true
	_w = 0.0


## One step per tick (Rule 2). `dt_eff <= 0` or non-finite changes nothing but the previous values; a non-finite
## `dt_eff` or a negative one logs `BAD_DT`. `dt_eff > dt_max` is clamped with `DT_OVER_MAX`.
## `steer` is clamped to [-1, 1]; when `valid` is false or `steer` is non-finite the last accepted steer is held.
## Example: `core.step(1.0 / 60.0, 0.5, true, BallCore.InputSource.SENSOR)`.
func step(dt_eff: float, steer: float, valid: bool, input_source: int) -> void:
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

	if not _mode_latched:
		_mode_latched = true
		_rate_mode = _cfg.mapping_mode == BallConfig.MappingMode.RATE or input_source == InputSource.FALLBACK
	_accept_steer(steer, valid)
	if _rebase_armed:
		_rebase_armed = false
		_phi_anchor = _phi - _cfg.steer_arc * _held_steer

	# Forward motion: exact integral of the speed curve (F2).
	var t_old: float = _t_run
	_t_run = t_old + dt
	_s += (
		BallMath.S(_t_run, _cfg.v_start, _cfg.v_max, _cfg.t_ramp)
		- BallMath.S(t_old, _cfg.v_start, _cfg.v_max, _cfg.t_ramp)
	)
	_speed = BallMath.speed(_t_run, _cfg.v_start, _cfg.v_max, _cfg.t_ramp)

	var phi_old: float = _phi
	if _rate_mode:
		_step_rate(dt)
	else:
		_step_position(dt)
	_omega = (_phi - phi_old) / dt
	_theta = BallMath.wrap_angle(_phi)

	# Keep phi bounded: shift phi and the anchor together by whole turns. omega and theta were taken before it.
	if absf(_phi) > TAU:
		var shift: float = float(int(_phi / TAU)) * TAU
		_phi -= shift
		_phi_anchor -= shift


## F3: the held steer sets a target angular velocity `w_ss`; `w` relaxes toward it with the lag.
func _step_rate(dt: float) -> void:
	var w_ss: float = _cfg.omega_max * _held_steer
	var a: float = BallMath.alpha(dt, _cfg.ball_lag_tau)
	_phi += w_ss * dt + (_w - w_ss) * _cfg.ball_lag_tau * a
	_w = w_ss + (_w - w_ss) * (1.0 - a)


## F1: the steer sets a target angle on the anchor; `phi` tracks it by the shortest arc.
func _step_position(dt: float) -> void:
	var target: float = _phi_anchor + _cfg.steer_arc * _held_steer
	var raw_error: float = target - _phi
	var e: float = BallMath.wrap_angle(raw_error)
	# Exact half-turn tie: wrap_angle maps +PI to -PI, which would send a full-lock steer the wrong way round
	# (AC-3/AC-7/AC-8 expect +steer to increase phi). The tie resolves toward the sign of the raw error.
	if e == -PI and raw_error > 0.0:
		e = PI
	_phi += BallMath.step(e, dt, _cfg.ball_lag_tau, _cfg.omega_max)


func _accept_steer(steer: float, valid: bool) -> void:
	if not valid:
		return
	if is_nan(steer) or is_inf(steer):
		_log(BallConfig.LOG_BAD_STEER, "steer=%s is not finite; holding %s" % [steer, _held_steer])
		return
	_held_steer = clampf(steer, -1.0, 1.0)


func _log(code: StringName, message: String) -> void:
	if _log_sink.is_valid():
		_log_sink.call(LogLevel.ERROR, code, "", message)
