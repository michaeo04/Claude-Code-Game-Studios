## Story BM-004: BallCore shell, reset and forward speed/distance integration (AC-21, AC-22, shape).
## Oracles: tools/reference-sim/ball_movement.js (GDD F2 examples).
extends GutTest

const Fixtures = preload("res://tests/support/ball_fixtures.gd")
const SteerTables = preload("res://tests/support/ball_steer_tables.gd")

const TOL: float = 1e-6
const SENSOR: int = BallCore.InputSource.SENSOR


## Steps `core` for `seconds` at `hz` with a constant steer; returns the number of frames.
func _run(core: BallCore, seconds: float, hz: int, steer: float = 0.0, valid: bool = true) -> int:
	var frames: int = int(round(seconds * hz))
	var dt: float = 1.0 / float(hz)
	for _i: int in frames:
		core.step(dt, steer, valid, SENSOR)
	return frames


func _check_distance(seconds: float, hz: int, expected_s: float, expected_speed: float) -> void:
	var core: BallCore = Fixtures.make_core(Fixtures.make_ball_fixture())
	_run(core, seconds, hz, 0.25)
	assert_almost_eq(core.s, expected_s, TOL, "s at %s s, %s Hz" % [seconds, hz])
	assert_almost_eq(core.speed, expected_speed, TOL, "speed at %s s, %s Hz" % [seconds, hz])


func test_distance_45s_30hz_matches_oracle() -> void:
	_check_distance(45.0, 30, 618.75, 17.5)


func test_distance_45s_60hz_matches_oracle() -> void:
	_check_distance(45.0, 60, 618.75, 17.5)


func test_distance_45s_120hz_matches_oracle() -> void:
	_check_distance(45.0, 120, 618.75, 17.5)


func test_distance_90s_30hz_matches_oracle() -> void:
	_check_distance(90.0, 30, 1575.0, 25.0)


func test_distance_90s_60hz_matches_oracle() -> void:
	_check_distance(90.0, 60, 1575.0, 25.0)


func test_distance_90s_120hz_matches_oracle() -> void:
	_check_distance(90.0, 120, 1575.0, 25.0)


func test_distance_120s_30hz_matches_oracle() -> void:
	_check_distance(120.0, 30, 2325.0, 25.0)


func test_distance_120s_60hz_matches_oracle() -> void:
	_check_distance(120.0, 60, 2325.0, 25.0)


func test_distance_120s_120hz_matches_oracle() -> void:
	_check_distance(120.0, 120, 2325.0, 25.0)


func test_first_step_60hz_matches_oracle() -> void:
	var core: BallCore = Fixtures.make_core(Fixtures.make_ball_fixture())
	core.step(1.0 / 60.0, 0.0, true, SENSOR)
	assert_almost_eq(core.s, 0.1666898, TOL)
	assert_almost_eq(core.speed, 10.0027778, TOL)


func test_distance_ignores_steer_table() -> void:
	var rows: Array[Dictionary] = [
		{"steer": 1.0, "valid": true},
		{"steer": -1.0, "valid": true},
		{"steer": 0.0, "valid": true},
		{"steer": NAN, "valid": true},
		{"steer": 1.0, "valid": false},
	]
	var expected: float = BallMath.S(10.0, 10.0, 25.0, 90.0)
	var first_s: float = -1.0
	for row: Dictionary in rows:
		var core: BallCore = Fixtures.make_core(Fixtures.make_ball_fixture())
		_run(core, 10.0, 60, row["steer"] as float, row["valid"] as bool)
		assert_almost_eq(core.s, expected, TOL, "row %s" % [row])
		if first_s < 0.0:
			first_s = core.s
		assert_eq(core.s, first_s, "s identical across rows: %s" % [row])


func test_left_riemann_would_undercount_distance() -> void:
	# Mutation guard: a left-Riemann `speed * dt` misses the exact integral by 0.125 u at 90 s, 60 Hz.
	var riemann: float = 0.0
	var t: float = 0.0
	var dt: float = 1.0 / 60.0
	for _i: int in 5400:
		riemann += BallMath.speed(t, 10.0, 25.0, 90.0) * dt
		t += dt
	var core: BallCore = Fixtures.make_core(Fixtures.make_ball_fixture())
	_run(core, 90.0, 60)
	assert_gt(absf(core.s - riemann), 0.1, "Riemann differs from the core by about 0.125")
	assert_almost_eq(core.s, 1575.0, TOL)


func test_long_run_100k_frames_stays_on_integral() -> void:
	var core: BallCore = Fixtures.make_core(Fixtures.make_ball_fixture())
	var steers: PackedFloat64Array = SteerTables.lcg_steer(1000)
	var dt: float = 1.0 / 60.0
	var summed: float = 0.0
	for i: int in 100000:
		core.step(dt, steers[i % 1000], true, SENSOR)
		summed += dt
	assert_eq(core.t_run, summed, "t_run equals the independently summed dt")
	assert_true(absf(core.s - BallMath.S(core.t_run, 10.0, 25.0, 90.0)) <= TOL, "|s - S(t_run)| <= 1e-6")


func test_sentinel_ramp_gives_v_max_from_start() -> void:
	var cfg: BallConfig = Fixtures.make_ball_fixture()
	cfg.t_ramp = 0.0
	var core: BallCore = Fixtures.make_core(cfg)
	assert_eq(core.speed, 25.0)
	core.step(0.1, 0.0, true, SENSOR)
	assert_almost_eq(core.s, 2.5, TOL)


func test_fresh_core_shape_matches_rule_9() -> void:
	var core: BallCore = Fixtures.make_core(Fixtures.make_ball_fixture())
	assert_eq(core.theta, 0.0)
	assert_eq(core.theta_prev, 0.0)
	assert_eq(core.s, 0.0)
	assert_eq(core.s_prev, 0.0)
	assert_eq(core.omega, 0.0)
	assert_eq(core.phi, 0.0)
	assert_eq(core.phi_anchor, 0.0)
	assert_eq(core.w, 0.0)
	assert_eq(core.t_run, 0.0)
	assert_eq(core.speed, 10.0)
	assert_almost_eq(core.radius, 0.4, TOL)


func test_reset_restores_rule_9_values_after_motion() -> void:
	var core: BallCore = Fixtures.make_core(Fixtures.make_ball_fixture())
	_run(core, 5.0, 60, 1.0)
	core.reset()
	assert_eq(core.theta, 0.0)
	assert_eq(core.theta_prev, 0.0)
	assert_eq(core.s, 0.0)
	assert_eq(core.s_prev, 0.0)
	assert_eq(core.omega, 0.0)
	assert_eq(core.phi, 0.0)
	assert_eq(core.t_run, 0.0)
	assert_eq(core.speed, 10.0)


func test_reset_clears_held_steer() -> void:
	var core: BallCore = Fixtures.make_core(Fixtures.make_ball_fixture())
	core.step(1.0 / 60.0, 1.0, true, SENSOR)
	core.reset()
	core.step(1.0 / 60.0, 0.0, false, SENSOR)
	assert_eq(core.phi, 0.0, "held steer is 0 after reset, so an invalid step does not move")


func test_core_has_no_persistence_api() -> void:
	var core: BallCore = Fixtures.make_core(Fixtures.make_ball_fixture())
	for name: String in ["save", "load", "to_dict", "from_dict", "serialize", "persist"]:
		assert_false(core.has_method(name), "no %s" % name)


func test_bad_dt_max_falls_back_with_one_knob_clamped() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	var core: BallCore = Fixtures.make_core(Fixtures.make_ball_fixture(), NAN, sink)
	assert_eq(sink.call("count_code", BallConfig.LOG_KNOB_CLAMPED), 1)
	core.step(0.5, 0.0, true, SENSOR)
	assert_almost_eq(core.t_run, 0.1, TOL, "dt_max fell back to 0.1")
