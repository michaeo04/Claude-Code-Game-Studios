## Factories of the Ball Movement tests (GDD AC preamble): `make_ball_fixture`, `make_core`, `make_sink`.
##
## Oracle source for the ACs that use numbers: `tools/reference-sim/ball_movement.js` (AC-5, AC-5b, AC-7 to AC-11,
## AC-19b, AC-19c, AC-20); tests never invent oracle logic of their own.
## Framework-free: no GUT call.
extends RefCounted

const BallSink = preload("res://tests/support/platform_log_sink.gd")


## The fixture config: equals the shipped defaults (Tuning Knobs). Tests that depend on a knob override it with
## an asymmetric value (for example `ball_lag_tau` 0.03).
static func make_ball_fixture() -> BallConfig:
	var cfg: BallConfig = BallConfig.new()
	cfg.steer_arc = PI
	cfg.ball_lag_tau = 0.06
	cfg.omega_max = 3.0
	cfg.mapping_mode = BallConfig.MappingMode.POSITION
	cfg.v_start = 10.0
	cfg.v_max = 25.0
	cfg.t_ramp = 90.0
	cfg.ball_diameter = 0.8
	return cfg


## A fresh `BallCore` on a validated copy of `cfg`; `sink` (from `make_sink()`) receives every log line, default none.
static func make_core(cfg: BallConfig, dt_max: float = 0.1, sink: RefCounted = null) -> BallCore:
	var log_sink: Callable = Callable()
	if sink != null:
		log_sink = Callable(sink, "sink")
	return BallCore.new(cfg.validated(log_sink), dt_max, log_sink)


## A fresh recording `log_sink` target; pass `sink.sink` as the Callable.
static func make_sink() -> RefCounted:
	return BallSink.new()
