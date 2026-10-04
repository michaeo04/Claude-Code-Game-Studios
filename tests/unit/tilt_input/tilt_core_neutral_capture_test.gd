## Story TI-005: neutral capture mechanics and pending capture (AC-12 to AC-15, AC-17 to AC-19, AC-21, AC-26, AC-45).
extends GutTest

const Fixture = preload("res://tests/support/tilt_fixture.gd")

const DEG_TOL: float = 1e-3
const STEER_TOL: float = 1e-4


func _poll_at(fx: Fixture, stamp_us: int, pose: float) -> void:
	fx.set_pose(pose)
	fx.clock.now_us = stamp_us
	fx.core.poll()


func test_capture_window_median_ignores_late_pose_ac12() -> void:
	for pair: Array in [[5.0, 30.0], [-5.0, -30.0]]:
		var fx: Fixture = Fixture.new()
		var rest: float = pair[0]
		var late: float = pair[1]
		var end_us: int = 59 * Fixture.STEP_US
		for i: int in 60:
			var stamp: int = i * Fixture.STEP_US
			_poll_at(fx, stamp, rest if stamp <= end_us - 250000 else late)
		fx.core.on_run_reset(TiltCore.PreviousPhase.MENU)
		assert_almost_eq(fx.core.get_phi0(), rest, DEG_TOL, "phi0 for %s" % rest)
		fx.tick(rest, 1)
		assert_eq(fx.core.get_steer(), 0.0, "steer for %s" % rest)


func test_live_core_gives_phi0_pose_and_zero_steer_ac13() -> void:
	for pose: float in [15.0, -15.0]:
		var fx: Fixture = Fixture.new()
		var core: TiltCore = fx.live_core(pose)
		assert_almost_eq(core.get_phi0(), pose, DEG_TOL)
		assert_eq(core.get_steer(), 0.0)
		assert_eq(core.get_phi_f(), 0.0)
		assert_eq(core.get_state(), TiltCore.State.LIVE)
		assert_false(core.get_neutral_pending())
		assert_false(core.get_neutral_stale())


func test_window_ends_are_inclusive_and_one_microsecond_outside_is_excluded_ac14() -> void:
	var t: int = 1000000
	# [ninth stamp, expected phi0]; the early stamps are appended before the 8 window samples, the late ones after.
	var rows: Array[Array] = [
		[t - 550000, 10.0, true], [t - 550001, 5.0, true],
		[t - 250000, 10.0, false], [t - 249999, 5.0, false],
	]
	for row: Array in rows:
		var fx: Fixture = Fixture.new()
		var ninth: int = row[0]
		var first: bool = row[2]
		if first:
			_poll_at(fx, ninth, 10.0)
		for i: int in 4:
			_poll_at(fx, 500000 + i * 10000, 0.0)
		for i: int in 4:
			_poll_at(fx, 540000 + i * 10000, 10.0)
		if not first:
			_poll_at(fx, ninth, 10.0)
		fx.clock.now_us = t
		fx.core.on_run_reset(TiltCore.PreviousPhase.MENU)
		assert_almost_eq(fx.core.get_phi0(), row[1] as float, DEG_TOL, "ninth at %s" % ninth)
		assert_false(fx.core.get_neutral_pending())


func test_rest_pose_is_passed_through_and_unsupported_beyond_l_eff_ac15() -> void:
	# [rest pose, expected phi0, expected errors, steady pose after, expected steady steer]
	var rows: Array[Array] = [
		[35.0, 35.0, 0, 35.0, 0.0],
		[60.0, 60.0, 1, 70.0, 0.361702],
		[-60.0, -60.0, 1, -60.0, 0.0],
		[90.0, 70.0, 1, 90.0, 0.787234],
	]
	for row: Array in rows:
		var fx: Fixture = Fixture.new()
		fx.live_core(row[0] as float)
		fx.tick(row[0] as float, 120)
		if row[0] == 60.0:
			assert_almost_eq(fx.core.get_phi0(), 60.0, DEG_TOL)
			assert_eq(fx.core.get_steer(), 0.0, "steer 0 at rest")
		fx.tick(row[3] as float, 120)
		assert_almost_eq(fx.core.get_phi0(), row[1] as float, DEG_TOL, "phi0 for %s" % row[0])
		assert_eq(fx.count_code(&"POSTURE_UNSUPPORTED"), row[2] as int, "errors for %s" % row[0])
		assert_almost_eq(fx.core.get_steer(), row[4] as float, STEER_TOL, "steer for %s" % row[0])


func test_low_sensitivity_makes_rest_35_unsupported_ac15() -> void:
	var fx: Fixture = Fixture.new(null, 0.5)
	fx.live_core(35.0)
	fx.tick(35.0, 120)
	assert_almost_eq(fx.core.get_phi0(), 35.0, DEG_TOL)
	assert_eq(fx.count_code(&"POSTURE_UNSUPPORTED"), 1)
	assert_eq(fx.core.get_steer(), 0.0)


func _expect_pending_then_median_of_fifth(fx: Fixture, label: String) -> void:
	var core: TiltCore = fx.core
	assert_true(core.get_neutral_pending(), "%s pending" % label)
	assert_eq(core.get_steer(), 0.0)
	fx.tick(7.0, 4)
	assert_true(core.get_neutral_pending(), "%s still pending after 4" % label)
	assert_eq(core.get_steer(), 0.0)
	fx.tick(7.0, 1)
	assert_almost_eq(core.get_phi0(), 7.0, DEG_TOL, "%s phi0" % label)
	assert_eq(core.get_steer(), 0.0)
	assert_false(core.get_neutral_pending(), "%s pending cleared" % label)


func test_too_few_window_samples_set_pending_until_fifth_valid_sample_ac17() -> void:
	# 17a: empty window.
	var fx: Fixture = Fixture.new()
	fx.live_core(5.0)
	fx.clock.advance_us(2000000)
	fx.core.on_run_reset(TiltCore.PreviousPhase.MENU)
	_expect_pending_then_median_of_fifth(fx, "17a")
	# 17b: only samples younger than 0.25 s.
	fx = Fixture.new()
	fx.live_core(5.0)
	fx.clock.advance_us(2000000)
	fx.tick(5.0, 10)
	fx.core.on_run_reset(TiltCore.PreviousPhase.MENU)
	_expect_pending_then_median_of_fifth(fx, "17b")
	# 17c: only samples older than 1.0 s.
	fx = Fixture.new()
	fx.live_core(5.0)
	fx.clock.advance_us(1200000)
	fx.core.on_run_resumed()
	_expect_pending_then_median_of_fifth(fx, "17c")
	# 17d: four samples in the window.
	fx = Fixture.new()
	fx.live_core(5.0)
	var base: int = fx.clock.now_us + 3000000
	for i: int in 4:
		_poll_at(fx, base + i * 10000, 5.0)
	fx.clock.now_us = base + 500000
	fx.core.on_run_reset(TiltCore.PreviousPhase.MENU)
	_expect_pending_then_median_of_fifth(fx, "17d")


func test_outlier_among_pending_samples_is_ignored_ac17e() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(5.0)
	fx.clock.advance_us(2000000)
	fx.core.on_run_reset(TiltCore.PreviousPhase.MENU)
	for pose: float in [7.0, 7.0, 90.0, 7.0, 7.0]:
		fx.tick(pose, 1)
	assert_almost_eq(fx.core.get_phi0(), 7.0, DEG_TOL)


func test_second_capture_event_while_pending_restarts_the_count_ac17f() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(5.0)
	fx.clock.advance_us(2000000)
	fx.core.on_run_reset(TiltCore.PreviousPhase.MENU)
	fx.tick(7.0, 3)
	assert_true(fx.core.get_neutral_pending())
	fx.core.on_run_resumed()
	fx.tick(9.0, 4)
	assert_true(fx.core.get_neutral_pending(), "four samples are not enough after the restart")
	fx.tick(9.0, 1)
	assert_almost_eq(fx.core.get_phi0(), 9.0, DEG_TOL)
	assert_false(fx.core.get_neutral_pending())


func test_capture_in_acquiring_waits_for_n_min_valid_samples_and_signals_once_ac18() -> void:
	var fx: Fixture = Fixture.new()
	watch_signals(fx.core)
	assert_eq(fx.core.get_state(), TiltCore.State.ACQUIRING)
	fx.core.on_run_reset(TiltCore.PreviousPhase.MENU)
	assert_true(fx.core.get_neutral_pending())
	fx.tick(7.0, 4)
	assert_true(fx.core.get_neutral_pending())
	assert_eq(fx.core.get_steer(), 0.0)
	fx.tick(7.0, 1)
	assert_almost_eq(fx.core.get_phi0(), 7.0, DEG_TOL)
	assert_eq(fx.core.get_steer(), 0.0)
	assert_eq(fx.core.get_phi_f(), 0.0)
	assert_signal_emit_count(fx.core, "availability_changed", 1)
	assert_signal_emitted_with_parameters(fx.core, "availability_changed", [true])


func test_fresh_core_is_pending_and_stale_then_first_capture_clears_both_ac45() -> void:
	var fx: Fixture = Fixture.new()
	assert_true(fx.core.get_neutral_stale())
	assert_true(fx.core.get_neutral_pending())
	assert_eq(fx.core.get_steer(), 0.0)
	assert_false(fx.core.get_valid())
	fx.core.on_run_reset(TiltCore.PreviousPhase.BOOT)
	fx.tick(12.0, 5)
	assert_almost_eq(fx.core.get_phi0(), 12.0, DEG_TOL)
	assert_false(fx.core.get_neutral_stale())
	assert_false(fx.core.get_neutral_pending())


func test_filter_oracles_after_one_two_and_three_polls_ac19() -> void:
	var expected: Array[Array] = [[2.8347, 0.056797], [4.8659, 0.143230], [6.3213, 0.205161]]
	for n: int in 3:
		var fx: Fixture = Fixture.new()
		fx.live_core(5.0)
		fx.tick(15.0, n + 1)
		assert_almost_eq(fx.core.get_phi_f(), expected[n][0] as float, DEG_TOL, "phi_f after %d" % (n + 1))
		assert_almost_eq(fx.core.get_steer(), expected[n][1] as float, STEER_TOL, "steer after %d" % (n + 1))


func test_two_resume_events_capture_independently_ac21() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(5.0)
	fx.core.on_run_resumed()
	assert_almost_eq(fx.core.get_phi0(), 5.0, DEG_TOL)
	fx.tick(5.0, 30)
	fx.tick(12.0, 60)
	fx.core.on_run_resumed()
	assert_almost_eq(fx.core.get_phi0(), 12.0, DEG_TOL)
	assert_eq(fx.core.get_phi_f(), 0.0)


func test_two_resume_events_at_the_same_time_give_the_same_neutral_ac21b() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(5.0)
	fx.core.on_run_resumed()
	var first: float = fx.core.get_phi0()
	fx.core.on_run_resumed()
	assert_eq(fx.core.get_phi0(), first)


func test_burst_fills_256_slots_and_capture_uses_newest_samples_ac26() -> void:
	var fx: Fixture = Fixture.new()
	for i: int in 600:
		_poll_at(fx, (i + 1) * 1000, 10.0)
	assert_eq(fx.core.get_sample_count(), 256)
	fx = Fixture.new()
	for i: int in 172:
		_poll_at(fx, (i + 1) * 1000, 10.0)
	for i: int in 300:
		_poll_at(fx, (173 + i) * 1000, 30.0)
	fx.core.on_run_resumed()
	assert_almost_eq(fx.core.get_phi0(), 30.0, DEG_TOL)
