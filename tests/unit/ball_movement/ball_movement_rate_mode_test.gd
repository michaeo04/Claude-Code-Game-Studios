## Story BM-007: RATE mapping F3 and the mapping-mode latch (AC-14, AC-15, AC-16).
extends GutTest

const Fixtures = preload("res://tests/support/ball_fixtures.gd")

const SENSOR: int = BallCore.InputSource.SENSOR
const FALLBACK: int = BallCore.InputSource.FALLBACK
const DT60: float = 1.0 / 60.0


func _core(mode: BallConfig.MappingMode, tau: float = 0.06) -> BallCore:
	var cfg: BallConfig = Fixtures.make_ball_fixture()
	cfg.mapping_mode = mode
	cfg.ball_lag_tau = tau
	return Fixtures.make_core(cfg)


func _run(core: BallCore, hz: int, seconds: float, steer: float, source: int = SENSOR) -> void:
	var n: int = int(round(seconds * float(hz)))
	for _i: int in n:
		core.step(1.0 / float(hz), steer, true, source)


# AC-14

func test_rate_first_step_from_rest_matches_oracle() -> void:
	var core: BallCore = _core(BallConfig.MappingMode.RATE)
	core.step(DT60, 1.0, true, SENSOR)
	assert_almost_eq(core.w, 0.727605, 1e-6)
	assert_almost_eq(core.phi, 0.0063437, 1e-7)


func test_rate_tenth_second_is_step_rate_independent() -> void:
	for hz: int in [30, 60, 120]:
		var core: BallCore = _core(BallConfig.MappingMode.RATE)
		_run(core, hz, 0.1, 1.0)
		assert_almost_eq(core.phi, 0.153998, 1e-6, "hz=%d" % hz)


func test_rate_release_coasts_about_tau_times_omega_max() -> void:
	var core: BallCore = _core(BallConfig.MappingMode.RATE)
	_run(core, 60, 1.0, 1.0)
	var phi_release: float = core.phi
	_run(core, 60, 2.0, 0.0)
	assert_almost_eq(core.phi - phi_release, 0.18, 1e-3)


func test_rate_on_resumed_zeroes_velocity() -> void:
	var core: BallCore = _core(BallConfig.MappingMode.RATE)
	_run(core, 60, 0.5, 1.0)
	assert_gt(core.w, 0.0)
	core.on_resumed()
	assert_eq(core.w, 0.0)


func test_rate_tau_zero_gives_omega_max_times_steer() -> void:
	var core: BallCore = _core(BallConfig.MappingMode.RATE, 0.0)
	core.step(DT60, 0.5, true, SENSOR)
	assert_almost_eq(core.w, 1.5, 1e-9)
	assert_almost_eq(core.phi, 1.5 * DT60, 1e-9)


func test_rate_held_half_steer_settles_at_1_5() -> void:
	var core: BallCore = _core(BallConfig.MappingMode.RATE)
	_run(core, 60, 3.0, 0.5)
	assert_almost_eq(core.w, 1.5, 1e-6)


func test_rate_step_never_exceeds_omega_max_dt() -> void:
	var core: BallCore = _core(BallConfig.MappingMode.RATE)
	for i: int in 300:
		core.step(DT60, 1.0 if i < 150 else -1.0, true, SENSOR)
		# omega is the applied step over dt, taken before any 2 PI shift of phi.
		assert_true(absf(core.omega) <= 3.0 + 1e-9, "omega at %d" % i)
		assert_true(absf(core.w) <= 3.0 + 1e-9, "w at %d" % i)


# AC-15

func _discriminator(mode: BallConfig.MappingMode, source: int) -> float:
	var core: BallCore = _core(mode)
	for _i: int in 120:
		core.step(DT60, 0.5, true, source)
	for _i: int in 240:
		core.step(DT60, 0.0, true, source)
	return core.theta


func test_truth_table_only_position_sensor_returns_to_zero() -> void:
	assert_eq(_discriminator(BallConfig.MappingMode.POSITION, SENSOR), 0.0)
	assert_ne(_discriminator(BallConfig.MappingMode.POSITION, FALLBACK), 0.0)
	assert_ne(_discriminator(BallConfig.MappingMode.RATE, SENSOR), 0.0)
	assert_ne(_discriminator(BallConfig.MappingMode.RATE, FALLBACK), 0.0)


# AC-16

func test_noop_fallback_step_does_not_latch() -> void:
	var core: BallCore = _core(BallConfig.MappingMode.POSITION)
	core.step(0.0, 0.5, true, FALLBACK)
	core.step(-1.0, 0.5, true, FALLBACK)
	assert_false(core.mode_latched)
	core.step(DT60, 0.5, true, SENSOR)
	assert_true(core.mode_latched)
	assert_false(core.rate_mode)


func test_mid_run_flip_is_ignored_both_ways() -> void:
	var a: BallCore = _core(BallConfig.MappingMode.POSITION)
	a.step(DT60, 0.5, true, SENSOR)
	a.step(DT60, 0.5, true, FALLBACK)
	assert_false(a.rate_mode)
	var b: BallCore = _core(BallConfig.MappingMode.POSITION)
	b.step(DT60, 0.5, true, FALLBACK)
	b.step(DT60, 0.5, true, SENSOR)
	assert_true(b.rate_mode)


func test_resume_does_not_relatch_and_reset_rearms() -> void:
	var core: BallCore = _core(BallConfig.MappingMode.POSITION)
	core.step(DT60, 0.5, true, FALLBACK)
	core.on_resumed()
	core.step(DT60, 0.5, true, SENSOR)
	assert_true(core.rate_mode)
	core.reset()
	assert_false(core.mode_latched)
	core.step(DT60, 0.5, true, SENSOR)
	assert_false(core.rate_mode)


func test_any_value_other_than_fallback_counts_as_sensor() -> void:
	for source: int in [0, 2, -1, 99]:
		var core: BallCore = _core(BallConfig.MappingMode.POSITION)
		core.step(DT60, 0.5, true, source)
		assert_false(core.rate_mode, "source=%d" % source)
