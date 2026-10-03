## Story BM-003 AC-28 (ADVISORY): the shipped ball_config.tres validates with zero KNOB_CLAMPED.
extends GutTest

const Fixtures = preload("res://tests/support/ball_fixtures.gd")

const CONFIG_PATH: String = "res://assets/data/ball_config.tres"


func test_shipped_config_validates_with_zero_knob_clamped() -> void:
	var shipped: BallConfig = load(CONFIG_PATH) as BallConfig
	var sink: RefCounted = Fixtures.make_sink()
	var out: BallConfig = shipped.validated(sink.sink)
	assert_eq(sink.count_code(BallConfig.LOG_KNOB_CLAMPED), 0)
	assert_eq(out.steer_arc, 3.141592653589793)
	assert_eq(out.ball_lag_tau, 0.06)
	assert_eq(out.omega_max, 3.0)
	assert_eq(out.v_start, 10.0)
	assert_eq(out.v_max, 25.0)
	assert_eq(out.t_ramp, 90.0)
	assert_eq(out.ball_diameter, 0.8)
