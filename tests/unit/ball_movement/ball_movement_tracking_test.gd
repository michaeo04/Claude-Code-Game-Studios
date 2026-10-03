## Story BM-005: position-mode tracking, dt_eff guards and held-steer semantics
## (AC-2, AC-3, AC-6, AC-7, AC-8, AC-9, AC-17). Oracles: tools/reference-sim/ball_movement.js.
extends GutTest

const Fixtures = preload("res://tests/support/ball_fixtures.gd")

const TOL: float = 1e-6
const SENSOR: int = BallCore.InputSource.SENSOR
const DT60: float = 1.0 / 60.0


func _core(sink: RefCounted = null, dt_max: float = 0.1) -> BallCore:
	return Fixtures.make_core(Fixtures.make_ball_fixture(), dt_max, sink)


## A core after one moving step (1/60, steer 0.5) with a recording sink.
func _moved_core(sink: RefCounted) -> BallCore:
	var core: BallCore = _core(sink)
	core.step(DT60, 0.5, true, SENSOR)
	return core


func _assert_noop(dt_eff: float, expected_bad_dt: int) -> void:
	var sink: RefCounted = Fixtures.make_sink()
	var core: BallCore = _moved_core(sink)
	var theta: float = core.theta
	var s: float = core.s
	var speed: float = core.speed
	var t_run: float = core.t_run
	var phi: float = core.phi
	core.step(dt_eff, 0.5, true, SENSOR)
	assert_eq(core.theta, theta)
	assert_eq(core.s, s)
	assert_eq(core.speed, speed)
	assert_eq(core.t_run, t_run)
	assert_eq(core.phi, phi)
	assert_eq(core.theta_prev, core.theta)
	assert_eq(core.s_prev, core.s)
	assert_eq(core.omega, 0.0)
	assert_eq(sink.call("count_code", BallConfig.LOG_BAD_DT), expected_bad_dt)
	assert_eq(sink.call("count") as int, expected_bad_dt, "nothing else logged")


func test_noop_dt_zero_changes_nothing_and_logs_nothing() -> void:
	_assert_noop(0.0, 0)


func test_noop_dt_negative_logs_bad_dt() -> void:
	_assert_noop(-0.001, 1)


func test_noop_dt_negative_inf_logs_bad_dt() -> void:
	_assert_noop(-INF, 1)


func test_noop_dt_nan_logs_bad_dt() -> void:
	_assert_noop(NAN, 1)


func test_noop_dt_positive_inf_logs_bad_dt_not_over_max() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	var core: BallCore = _moved_core(sink)
	core.step(INF, 0.5, true, SENSOR)
	assert_eq(sink.call("count_code", BallConfig.LOG_BAD_DT), 1)
	assert_eq(sink.call("count_code", BallConfig.LOG_DT_OVER_MAX), 0)
	_assert_noop(INF, 1)


func test_noop_step_with_nan_steer_logs_no_bad_steer() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	var core: BallCore = _moved_core(sink)
	core.step(0.0, NAN, true, SENSOR)
	core.step(NAN, NAN, true, SENSOR)
	assert_eq(sink.call("count_code", BallConfig.LOG_BAD_STEER), 0)


func test_noop_never_updates_held_steer() -> void:
	var core: BallCore = _core()
	core.step(DT60, 0.5, true, SENSOR)
	core.step(0.0, -1.0, true, SENSOR)
	var reference: BallCore = _core()
	reference.step(DT60, 0.5, true, SENSOR)
	core.step(DT60, 0.0, false, SENSOR)
	reference.step(DT60, 0.5, true, SENSOR)
	assert_eq(core.phi, reference.phi, "invalid step after the no-op still holds 0.5")


func test_dt_at_dt_max_moves_without_log() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	var core: BallCore = _core(sink, 0.1)
	core.step(0.1, 1.0, true, SENSOR)
	assert_almost_eq(core.phi, 0.3, TOL)
	assert_almost_eq(core.omega, 3.0, TOL)
	assert_almost_eq(core.s, 1.0008333, TOL)
	assert_eq(sink.call("count") as int, 0)


func test_dt_over_max_clamps_with_one_log_and_same_state() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	var core: BallCore = _core(sink, 0.1)
	var reference: BallCore = _core(null, 0.1)
	core.step(0.5, 1.0, true, SENSOR)
	reference.step(0.1, 1.0, true, SENSOR)
	assert_eq(core.phi, reference.phi)
	assert_eq(core.omega, reference.omega)
	assert_eq(core.s, reference.s)
	assert_eq(core.t_run, reference.t_run)
	assert_eq(sink.call("count_code", BallConfig.LOG_DT_OVER_MAX), 1)
	assert_eq(sink.call("count") as int, 1)


func test_tiny_dt_still_moves_the_ball() -> void:
	var core: BallCore = _core()
	core.step(1e-9, 1.0, true, SENSOR)
	assert_gt(core.phi, 0.0)
	assert_gt(core.t_run, 0.0)


func test_steer_positive_half_increases_theta_strictly() -> void:
	var core: BallCore = _core()
	var previous: float = 0.0
	for _i: int in 60:
		core.step(DT60, 0.5, true, SENSOR)
		assert_gt(core.theta, previous)
		previous = core.theta
	assert_gt(core.theta, 0.0)


func test_steer_negative_half_is_exact_negation() -> void:
	var pos: BallCore = _core()
	var neg: BallCore = _core()
	for _i: int in 60:
		pos.step(DT60, 0.5, true, SENSOR)
		neg.step(DT60, -0.5, true, SENSOR)
		assert_eq(neg.theta, -pos.theta)


func test_first_frame_from_rest_is_capped_at_omega_max() -> void:
	var core: BallCore = _core()
	core.step(DT60, 1.0, true, SENSOR)
	assert_almost_eq(core.phi, 0.05, TOL)
	assert_almost_eq(core.omega, 3.0, TOL)


func test_sweep_table_respects_cap_without_overshoot_or_reversal() -> void:
	var core: BallCore = _core()
	var cap: float = 3.0 * DT60 + 1e-9
	var phi_old: float = 0.0
	for i: int in 600:
		var steer: float = 1.0 if (i / 150) % 2 == 0 else -1.0
		steer *= 0.9 if (i / 300) % 2 == 0 else 0.4
		var target: float = PI * steer
		var e_before: float = BallMath.wrap_angle(target - core.phi)
		core.step(DT60, steer, true, SENSOR)
		var applied: float = core.phi - phi_old
		assert_true(absf(applied) <= cap, "|step| <= OMEGA_MAX * dt at frame %s" % i)
		assert_true(absf(applied) <= absf(e_before) + 1e-9, "no overshoot at frame %s" % i)
		assert_true(applied * e_before >= -1e-12, "no reversal at frame %s" % i)
		phi_old = core.phi


func _frames_to_arrive(hz: int) -> int:
	var core: BallCore = _core()
	var dt: float = 1.0 / float(hz)
	var frames: int = 0
	var previous_above: bool = true
	while frames < 1000:
		core.step(dt, 1.0, true, SENSOR)
		frames += 1
		if absf(BallMath.wrap_angle(PI - core.phi)) <= 0.05:
			previous_above = false
			break
	assert_false(previous_above, "arrived")
	return frames


func test_arrival_frame_30hz_is_32() -> void:
	assert_eq(_frames_to_arrive(30), 32)


func test_arrival_frame_60hz_is_64() -> void:
	assert_eq(_frames_to_arrive(60), 64)


func test_arrival_frame_120hz_is_128() -> void:
	assert_eq(_frames_to_arrive(120), 128)


func _small_target_phi(hz: int) -> float:
	var core: BallCore = _core()
	var frames: int = int(round(0.1 * hz))
	for _i: int in frames:
		core.step(1.0 / float(hz), 0.1 / PI, true, SENSOR)
	return core.phi


func test_small_target_held_tenth_of_second_30hz() -> void:
	assert_almost_eq(_small_target_phi(30), 0.0811124, TOL)


func test_small_target_held_tenth_of_second_60hz() -> void:
	assert_almost_eq(_small_target_phi(60), 0.0811124, TOL)


func test_small_target_held_tenth_of_second_120hz() -> void:
	assert_almost_eq(_small_target_phi(120), 0.0811124, TOL)


func test_fixed_alpha_per_frame_mutation_fails_rate_independence() -> void:
	# Mutation guard: with alpha fixed at its 60 Hz value the small-target result drifts across rates.
	var alpha60: float = BallMath.alpha(DT60, 0.06)
	var results: Array[float] = []
	for hz: int in [30, 60, 120]:
		var phi: float = 0.0
		for _i: int in int(round(0.1 * hz)):
			phi += 0.1 - (0.1 - phi) * (1.0 - alpha60) - phi
		results.append(phi)
	assert_gt(absf(results[0] - results[2]), 0.01, "fixed alpha is not frame-rate independent")


## phi samples at multiples of 1/30 s for the 5 s sine of AC-9.
func _sine_samples(hz: int) -> PackedFloat64Array:
	var core: BallCore = _core()
	var out: PackedFloat64Array = PackedFloat64Array()
	var dt: float = 1.0 / float(hz)
	var per_sample: int = hz / 30
	var frames: int = hz * 5
	for k: int in range(1, frames + 1):
		var t_k: float = float(k) * dt
		core.step(dt, (0.5 / PI) * sin(TAU * t_k), true, SENSOR)
		if k % per_sample == 0:
			out.append(core.phi)
	return out


func test_sine_tracking_agrees_across_rates_within_tolerance() -> void:
	var a: PackedFloat64Array = _sine_samples(30)
	var b: PackedFloat64Array = _sine_samples(60)
	var c: PackedFloat64Array = _sine_samples(120)
	assert_eq(a.size(), 150)
	assert_eq(b.size(), 150)
	assert_eq(c.size(), 150)
	var worst: float = 0.0
	for i: int in 150:
		worst = maxf(worst, maxf(absf(a[i] - b[i]), maxf(absf(a[i] - c[i]), absf(b[i] - c[i]))))
	assert_true(worst <= 0.05, "max pairwise |delta phi| %s <= 0.05" % worst)


func _accepted_then(steer: float, valid: bool, sink: RefCounted) -> BallCore:
	var core: BallCore = _core(sink)
	core.step(DT60, 0.5, true, SENSOR)
	for _i: int in 60:
		core.step(DT60, steer, valid, SENSOR)
	return core


func _held_reference() -> BallCore:
	var core: BallCore = _core()
	core.step(DT60, 0.5, true, SENSOR)
	for _i: int in 60:
		core.step(DT60, 0.5, true, SENSOR)
	return core


func test_invalid_with_zero_steer_holds_target_without_log() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	var core: BallCore = _accepted_then(0.0, false, sink)
	assert_eq(core.phi, _held_reference().phi)
	assert_eq(sink.call("count") as int, 0)


func test_nan_steer_holds_last_with_one_bad_steer() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	var core: BallCore = _core(sink)
	core.step(DT60, 0.5, true, SENSOR)
	core.step(DT60, NAN, true, SENSOR)
	assert_eq(sink.call("count_code", BallConfig.LOG_BAD_STEER), 1)
	assert_eq(core.phi, _held_n(2).phi)


func test_positive_inf_steer_holds_last_with_one_bad_steer() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	var core: BallCore = _core(sink)
	core.step(DT60, 0.5, true, SENSOR)
	core.step(DT60, INF, true, SENSOR)
	assert_eq(sink.call("count_code", BallConfig.LOG_BAD_STEER), 1)
	assert_eq(core.phi, _held_n(2).phi)


func test_negative_inf_steer_holds_last_with_one_bad_steer() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	var core: BallCore = _core(sink)
	core.step(DT60, 0.5, true, SENSOR)
	core.step(DT60, -INF, true, SENSOR)
	assert_eq(sink.call("count_code", BallConfig.LOG_BAD_STEER), 1)
	assert_eq(core.phi, _held_n(2).phi)


func _held_n(frames: int) -> BallCore:
	var core: BallCore = _core()
	for _i: int in frames:
		core.step(DT60, 0.5, true, SENSOR)
	return core


func test_out_of_range_steer_is_clamped_without_log() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	var high: BallCore = _core(sink)
	var low: BallCore = _core(sink)
	var one: BallCore = _core()
	var minus_one: BallCore = _core()
	for _i: int in 30:
		high.step(DT60, 5.0, true, SENSOR)
		low.step(DT60, -5.0, true, SENSOR)
		one.step(DT60, 1.0, true, SENSOR)
		minus_one.step(DT60, -1.0, true, SENSOR)
	assert_eq(high.phi, one.phi)
	assert_eq(low.phi, minus_one.phi)
	assert_eq(sink.call("count") as int, 0)


func test_nan_on_first_moving_step_holds_zero() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	var core: BallCore = _core(sink)
	core.step(DT60, NAN, true, SENSOR)
	assert_eq(core.phi, 0.0)
	assert_eq(sink.call("count_code", BallConfig.LOG_BAD_STEER), 1)


func test_invalid_with_nan_steer_logs_nothing() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	var core: BallCore = _core(sink)
	core.step(DT60, 0.5, true, SENSOR)
	core.step(DT60, NAN, false, SENSOR)
	assert_eq(sink.call("count") as int, 0)
	assert_eq(core.phi, _held_n(2).phi)
