## Story BM-002 AC-2: the shipped assets/data/ball_config.tres round-trips to the fixture values.
extends GutTest

const Fixtures = preload("res://tests/support/ball_fixtures.gd")

const CONFIG_PATH: String = "res://assets/data/ball_config.tres"
const TOL: float = 1e-12


func test_shipped_resource_equals_the_fixture() -> void:
	var shipped: BallConfig = load(CONFIG_PATH) as BallConfig
	var fixture: BallConfig = Fixtures.make_ball_fixture()
	assert_not_null(shipped)
	assert_almost_eq(shipped.steer_arc, fixture.steer_arc, TOL)
	assert_almost_eq(shipped.ball_lag_tau, fixture.ball_lag_tau, TOL)
	assert_almost_eq(shipped.omega_max, fixture.omega_max, TOL)
	assert_eq(shipped.mapping_mode, fixture.mapping_mode)
	assert_almost_eq(shipped.v_start, fixture.v_start, TOL)
	assert_almost_eq(shipped.v_max, fixture.v_max, TOL)
	assert_almost_eq(shipped.t_ramp, fixture.t_ramp, TOL)
	assert_almost_eq(shipped.ball_diameter, fixture.ball_diameter, TOL)


func test_shipped_steer_arc_keeps_float64_precision() -> void:
	var shipped: BallConfig = load(CONFIG_PATH) as BallConfig
	assert_eq(shipped.steer_arc, PI)
