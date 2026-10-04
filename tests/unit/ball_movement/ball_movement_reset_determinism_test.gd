## Story BM-008: reset conformance, log-code census, bit-identical determinism, reset allocation
## (AC-1, AC-18, AC-24, AC-27 automated part).
extends GutTest

const Fixtures = preload("res://tests/support/ball_fixtures.gd")
const Tables = preload("res://tests/support/ball_steer_tables.gd")

const SENSOR: int = BallCore.InputSource.SENSOR
const FALLBACK: int = BallCore.InputSource.FALLBACK
const DT60: float = 1.0 / 60.0


func _core(sink: RefCounted = null) -> BallCore:
	return Fixtures.make_core(Fixtures.make_ball_fixture(), 0.1, sink)


func _assert_same(a: BallCore, b: BallCore, label: String) -> void:
	assert_eq(a.theta, b.theta, label + " theta")
	assert_eq(a.theta_prev, b.theta_prev, label + " theta_prev")
	assert_eq(a.s, b.s, label + " s")
	assert_eq(a.s_prev, b.s_prev, label + " s_prev")
	assert_eq(a.speed, b.speed, label + " speed")
	assert_eq(a.omega, b.omega, label + " omega")
	assert_eq(a.phi, b.phi, label + " phi")
	assert_eq(a.phi_anchor, b.phi_anchor, label + " phi_anchor")
	assert_eq(a.w, b.w, label + " w")
	assert_eq(a.t_run, b.t_run, label + " t_run")
	assert_eq(a.held_steer, b.held_steer, label + " held_steer")
	assert_eq(a.mode_latched, b.mode_latched, label + " latched")
	assert_eq(a.rate_mode, b.rate_mode, label + " rate_mode")


# AC-1

func test_fresh_core_is_at_rest() -> void:
	var core: BallCore = _core()
	assert_eq(core.theta, 0.0)
	assert_eq(core.theta_prev, 0.0)
	assert_eq(core.s, 0.0)
	assert_eq(core.s_prev, 0.0)
	assert_eq(core.t_run, 0.0)
	assert_eq(core.omega, 0.0)
	assert_eq(core.phi_anchor, 0.0)
	assert_eq(core.w, 0.0)
	assert_eq(core.held_steer, 0.0)
	assert_eq(core.speed, 10.0)
	assert_almost_eq(core.radius, 0.4, 1e-12)
	assert_false(core.mode_latched)


func test_reset_after_use_equals_fresh_core() -> void:
	var used: BallCore = _core()
	var steers: PackedFloat64Array = Tables.lcg_steer(100)
	for i: int in 100:
		used.step(DT60, steers[i], true, FALLBACK if i == 0 else SENSOR)
	used.on_resumed()
	used.reset()
	var fresh: BallCore = _core()
	_assert_same(used, fresh, "after reset")
	# The re-base flag is disarmed: behaviour matches a fresh core on the same drive.
	for i: int in 50:
		used.step(DT60, steers[i], true, SENSOR)
		fresh.step(DT60, steers[i], true, SENSOR)
	_assert_same(used, fresh, "after drive")


# AC-18

func test_log_codes_are_exactly_the_four_codes() -> void:
	assert_eq(BallConfig.LOG_BAD_DT, &"BAD_DT")
	assert_eq(BallConfig.LOG_DT_OVER_MAX, &"DT_OVER_MAX")
	assert_eq(BallConfig.LOG_BAD_STEER, &"BAD_STEER")
	assert_eq(BallConfig.LOG_KNOB_CLAMPED, &"KNOB_CLAMPED")


func test_nan_stream_gives_sixty_unlimited_error_lines() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	var core: BallCore = _core(sink)
	core.step(DT60, 0.2, true, SENSOR)
	for _i: int in 60:
		core.step(DT60, NAN, true, SENSOR)
	assert_eq(sink.count(), 60)
	for i: int in sink.count():
		assert_eq(sink.code_at(i), BallConfig.LOG_BAD_STEER)
		assert_eq(sink.level_at(i), RateLimitedLog.Level.ERROR)


func test_bad_dt_and_over_max_use_their_codes_at_error_level() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	var core: BallCore = _core(sink)
	core.step(NAN, 0.0, true, SENSOR)
	core.step(-0.5, 0.0, true, SENSOR)
	core.step(5.0, 0.0, true, SENSOR)
	assert_eq(sink.count_code(BallConfig.LOG_BAD_DT), 2)
	assert_eq(sink.count_code(BallConfig.LOG_DT_OVER_MAX), 1)
	assert_eq(sink.count(), 3)
	for i: int in sink.count():
		assert_eq(sink.level_at(i), RateLimitedLog.Level.ERROR)


func test_clean_sine_run_logs_nothing() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	var core: BallCore = _core(sink)
	for i: int in 600:
		core.step(DT60, sin(float(i) * 0.05), true, SENSOR)
	assert_eq(sink.count(), 0)


func test_valid_false_and_zero_dt_run_logs_nothing() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	var core: BallCore = _core(sink)
	for i: int in 120:
		core.step(DT60 if i % 2 == 0 else 0.0, NAN if i % 3 == 0 else 0.4, i % 3 != 0, SENSOR)
	assert_eq(sink.count(), 0)


# AC-24

func _drive(core: BallCore, i: int, steers: PackedFloat64Array) -> void:
	var m: int = i % 50
	if m == 7:
		core.step(NAN, steers[i], true, SENSOR)
	elif m == 11:
		core.step(DT60, steers[i], false, SENSOR)
	elif m == 13:
		core.step(0.0, steers[i], true, SENSOR)
	elif m == 17:
		core.on_resumed()
	elif m == 23:
		core.step(DT60, NAN, true, FALLBACK)
	elif m == 29:
		core.step(0.5, steers[i] * 3.0, true, SENSOR)
	elif i % 331 == 330:
		core.reset()
	else:
		core.step(DT60, steers[i], true, FALLBACK if i % 331 == 0 else SENSOR)


func test_replay_is_bit_identical_and_interleaving_changes_nothing() -> void:
	var steers: PackedFloat64Array = Tables.lcg_steer(1000)
	var a: BallCore = _core()
	var b: BallCore = _core()
	var third: BallCore = _core()
	for i: int in 1000:
		_drive(a, i, steers)
		_drive(b, i, steers)
		third.step(0.02, -steers[i], true, FALLBACK)
		if i % 100 == 0:
			third.reset()
		_assert_same(a, b, "step %d" % i)
		if get_fail_count() > 0:
			return


# AC-27 (automated part)

func test_thousand_resets_do_not_allocate_objects() -> void:
	var core: BallCore = _core()
	for _i: int in 50:
		core.step(DT60, 0.5, true, SENSOR)
	var before: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	for _i: int in 1000:
		core.reset()
	var after: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	assert_eq(after, before)
