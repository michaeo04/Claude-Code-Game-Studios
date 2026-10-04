## Story TI-006: pipeline order and the published output contract (AC-2b, AC-5, AC-9, AC-10, AC-20, AC-25, AC-35, AC-46).
extends GutTest

const Fixture = preload("res://tests/support/tilt_fixture.gd")

const DEG_TOL: float = 1e-3
const STEER_TOL: float = 1e-4


func test_steer_sign_follows_sensor_sign_ac2b() -> void:
	for sensor_sign: int in [1, -1]:
		var cfg: TiltConfig = TiltConfig.new()
		cfg.sensor_sign = sensor_sign
		var fx: Fixture = Fixture.new(cfg)
		fx.live_core(0.0)
		fx.tick(10.0, 30)
		if sensor_sign == 1:
			assert_gt(fx.core.get_steer(), 0.0, "sign +1")
		else:
			assert_lt(fx.core.get_steer(), 0.0, "sign -1")


func test_filter_step_response_oracles_ac5() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(0.0)
	var done: int = 0
	for row: Array in [[1, 2.8347], [3, 6.3213], [6, 8.6467], [12, 9.8169]]:
		fx.tick(10.0, (row[0] as int) - done)
		done = row[0]
		assert_almost_eq(fx.core.get_phi_f(), row[1] as float, DEG_TOL, "phi_f after %d" % done)


func test_alternating_noise_inside_dead_zone_gives_exact_zero_ac9() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(0.0)
	var peak: float = 0.0
	for i: int in 120:
		fx.tick(4.0 if i % 2 == 0 else -4.0, 1)
		assert_eq(fx.core.get_steer(), 0.0, "tick %d" % i)
		peak = maxf(peak, absf(fx.core.get_phi_f()))
	assert_almost_eq(peak, 1.1339, DEG_TOL)


func test_held_pose_gives_steady_steer_and_zero_when_not_live_ac10a() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(0.0)
	fx.tick(10.0, 60)
	assert_almost_eq(fx.core.get_steer(), 0.361702, STEER_TOL)
	assert_true(fx.core.get_valid())
	var acquiring: Fixture = Fixture.new()
	assert_eq(acquiring.core.get_steer(), 0.0)
	assert_false(acquiring.core.get_valid())
	var unavailable: TiltCore = TiltCore.new(TiltConfig.new(), Callable(), fx.clock.as_callable(), fx.sink.sink, Callable())
	assert_eq(unavailable.get_state(), TiltCore.State.UNAVAILABLE)
	assert_eq(unavailable.get_steer(), 0.0)
	assert_false(unavailable.get_valid())


func test_non_finite_quotient_gives_zero_and_one_bad_output_ac10b() -> void:
	var cfg: TiltConfig = TiltConfig.new().unvalidated()
	cfg.sensor_sign = 1
	cfg.tilt_full_scale = 0.0
	var fx: Fixture = Fixture.new(cfg)
	fx.live_core(0.0)
	fx.tick(0.0, 1)
	assert_eq(fx.core.get_steer(), 0.0)
	assert_eq(fx.core.get_phi_f(), 0.0)
	assert_eq(fx.count_code(&"BAD_OUTPUT"), 1)
	var calm: Fixture = Fixture.new(cfg)
	calm.live_core(0.0)
	calm.tick(5.0, 200)
	assert_eq(calm.core.get_steer(), 1.0)
	assert_almost_eq(calm.core.get_phi_f(), 5.0, DEG_TOL)
	assert_eq(calm.count_code(&"BAD_OUTPUT"), 0)


func test_no_recentering_over_a_long_hold_ac20() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(0.0)
	fx.tick(12.0, 120)
	var early: float = fx.core.get_steer()
	assert_almost_eq(early, 0.446809, STEER_TOL)
	fx.tick(12.0, 1680)
	assert_almost_eq(fx.core.get_steer(), early, STEER_TOL)


func test_dt_is_clamped_and_equal_or_backwards_stamps_hold_the_filter_ac25() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(0.0)
	fx.set_pose(10.0)
	fx.clock.advance_us(500000)
	fx.core.poll()
	assert_almost_eq(fx.core.get_phi_f(), 8.6466, DEG_TOL)
	assert_eq(fx.core.get_last_dt(), 0.1)
	var held: float = fx.core.get_phi_f()
	var count: int = fx.core.get_sample_count()
	fx.core.poll()
	assert_eq(fx.core.get_phi_f(), held, "same stamp leaves phi_f unchanged")
	assert_eq(fx.core.get_sample_count(), count)


func test_stamp_sequence_gives_the_listed_dt_values_ac25() -> void:
	var fx: Fixture = Fixture.new()
	var expected: Array[float] = [0.0, 0.0001, 0.0, 0.00005]
	var stamps: Array[int] = [100, 200, 150, 250]
	for i: int in 4:
		fx.clock.now_us = stamps[i]
		fx.core.poll()
		assert_almost_eq(fx.core.get_last_dt(), expected[i], 1e-9, "dt at %d" % stamps[i])
	assert_eq(fx.core.get_sample_count(), 3, "the backwards stamp appended nothing")


func test_non_portrait_logs_once_and_does_not_change_steer_ac35() -> void:
	var off: Fixture = Fixture.new(null, 1.0, false)
	assert_eq(off.sink.count(), 1)
	assert_eq(off.sink.code_at(0), TiltCore.LOG_NOT_PORTRAIT)
	var on: Fixture = Fixture.new(null, 1.0, true)
	assert_eq(on.sink.count(), 0)
	for fx: Fixture in [off, on]:
		fx.live_core(0.0)
		fx.tick(10.0, 5)
	assert_eq(off.core.get_steer(), on.core.get_steer())
	assert_gt(on.core.get_steer(), 0.0)


func test_getter_reads_are_stable_and_signal_free_ac46a() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(0.0)
	fx.tick(10.0, 20)
	watch_signals(fx.core)
	var first: float = fx.core.get_steer()
	var second: float = fx.core.get_steer()
	assert_eq(first, second)
	assert_signal_not_emitted(fx.core, "availability_changed")


func test_huge_finite_vector_gives_finite_steer_without_error_ac46b() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(0.0)
	fx.gravity = Vector3(1e30, 0.0, 0.0)
	fx.clock.advance_us(Fixture.STEP_US)
	fx.core.poll()
	assert_true(is_finite(fx.core.get_steer()))
	assert_eq(fx.sink.count(), 0)


func test_vector_overflowing_to_infinity_is_an_invalid_sample_ac46c() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(0.0)
	var count: int = fx.core.get_sample_count()
	fx.gravity = Vector3(1e200, 0.0, 0.0)
	fx.clock.advance_us(Fixture.STEP_US)
	fx.core.poll()
	assert_false(fx.gravity.is_finite())
	assert_eq(fx.core.get_sample_count(), count)
	assert_eq(fx.core.get_steer(), 0.0)
