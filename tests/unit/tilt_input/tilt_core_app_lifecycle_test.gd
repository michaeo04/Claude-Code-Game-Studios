## Story TI-010: app lifecycle handling, background and resume settle (AC-24, AC-49, and AC-16e of Story 007).
extends GutTest

const Fixture = preload("res://tests/support/tilt_fixture.gd")

const S = TiltCore.State
const SETTLE_US: int = 300000
const TIMEOUT_US: int = 2000000
const F_US: int = 5000000
const DEG_TOL: float = 1e-3


func _poll_at(fx: Fixture, stamp_us: int) -> void:
	fx.clock.now_us = stamp_us
	fx.core.poll()


## Live core, backgrounded, foregrounded at `F_US`.
func _returned() -> Fixture:
	var fx: Fixture = Fixture.new()
	fx.live_core(0.0)
	fx.core.on_app_backgrounded()
	fx.clock.now_us = F_US
	fx.core.on_app_foregrounded()
	return fx


func test_background_from_live_clears_and_leaves_ac24a() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(0.0)
	fx.tick(10.0, 20)
	assert_gt(fx.core.get_sample_count(), 0)
	fx.availability.clear()
	fx.core.on_app_backgrounded()
	assert_eq(fx.core.get_sample_count(), 0)
	assert_true(fx.core.get_neutral_stale())
	assert_eq(fx.core.get_state(), S.ACQUIRING)
	assert_false(fx.core.get_valid())
	assert_eq(fx.core.get_steer(), 0.0)
	assert_eq(fx.availability, [false] as Array[bool])


func test_background_from_unavailable_is_silent_ac24b() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(0.0)
	fx.tick_invalid(8)
	assert_eq(fx.core.get_state(), S.UNAVAILABLE)
	fx.availability.clear()
	fx.core.on_app_backgrounded()
	assert_eq(fx.core.get_state(), S.ACQUIRING)
	assert_eq(fx.availability.size(), 0)


func test_background_in_acquiring_restarts_the_settle_silently_ac24c() -> void:
	var fx: Fixture = Fixture.new()
	fx.core.on_app_backgrounded()
	assert_eq(fx.core.get_state(), S.ACQUIRING)
	assert_eq(fx.core.get_sample_count(), 0)
	fx.clock.now_us = 1000000
	fx.core.on_app_foregrounded()
	fx.core.on_app_backgrounded()
	fx.clock.now_us = F_US
	fx.core.on_app_foregrounded()
	_poll_at(fx, F_US + SETTLE_US - 1)
	assert_eq(fx.core.get_sample_count(), 0, "second settle runs from the second foreground")
	assert_eq(fx.core.get_state(), S.ACQUIRING)
	assert_eq(fx.availability.size(), 0)


func test_settle_boundary_and_first_accepted_poll_ac24d() -> void:
	var fx: Fixture = _returned()
	fx.availability.clear()
	fx.set_pose(10.0)
	_poll_at(fx, F_US + SETTLE_US - 1)
	assert_eq(fx.core.get_sample_count(), 0)
	assert_eq(fx.core.get_state(), S.ACQUIRING)
	_poll_at(fx, F_US + SETTLE_US)
	assert_eq(fx.core.get_state(), S.LIVE)
	assert_eq(fx.core.get_sample_count(), 1)
	assert_eq(fx.availability, [true] as Array[bool])
	assert_almost_eq(fx.core.get_phi_f(), 10.0, DEG_TOL)


func test_start_timeout_counts_from_the_first_post_settle_poll_ac24d() -> void:
	var fx: Fixture = Fixture.new()
	fx.tick_invalid(1)
	fx.core.on_app_backgrounded()
	fx.clock.now_us = F_US
	fx.core.on_app_foregrounded()
	var first: int = F_US + SETTLE_US
	_poll_at(fx, first)
	_poll_at(fx, first + TIMEOUT_US - 1)
	assert_eq(fx.core.get_state(), S.ACQUIRING)
	_poll_at(fx, first + TIMEOUT_US)
	assert_eq(fx.core.get_input_source(), TiltCore.InputSource.FALLBACK)
	assert_eq(fx.count_code(TiltCore.LOG_SENSOR_TIMEOUT), 1)


func test_window_after_resume_holds_post_settle_samples_ac24e() -> void:
	var fx: Fixture = _returned()
	fx.tick(12.0, 60)
	assert_eq(fx.clock.now_us, F_US + 60 * Fixture.STEP_US)
	fx.core.on_run_resumed()
	assert_false(fx.core.get_neutral_pending())
	assert_almost_eq(fx.core.get_phi0(), 12.0, DEG_TOL)
	assert_false(fx.core.get_neutral_stale())


func test_hit_and_paused_resets_capture_after_a_background_ac16e() -> void:
	for phase: TiltCore.PreviousPhase in [TiltCore.PreviousPhase.HIT, TiltCore.PreviousPhase.PAUSED]:
		var fx: Fixture = Fixture.new()
		fx.live_core(5.0)
		fx.tick(5.0, 5)
		fx.core.on_run_stopped()
		fx.core.on_app_backgrounded()
		fx.clock.now_us = F_US
		fx.core.on_app_foregrounded()
		fx.tick(12.0, 60)
		assert_true(fx.core.get_neutral_stale())
		fx.core.on_run_reset(phase)
		assert_almost_eq(fx.core.get_phi0(), 12.0, DEG_TOL)
		assert_false(fx.core.get_neutral_pending())
		assert_false(fx.core.get_neutral_stale())


func test_foreground_without_background_changes_nothing_ac24f() -> void:
	var fx: Fixture = Fixture.new()
	fx.tick(0.0, 10)
	var count: int = fx.core.get_sample_count()
	fx.availability.clear()
	fx.core.on_app_foregrounded()
	assert_eq(fx.core.get_state(), S.LIVE)
	assert_eq(fx.core.get_sample_count(), count)
	assert_eq(fx.availability.size(), 0)
	fx.tick(0.0, 1)
	assert_eq(fx.core.get_sample_count(), count + 1, "no settle")


func test_double_background_equals_one_ac24g() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(0.0)
	fx.availability.clear()
	fx.core.on_app_backgrounded()
	fx.core.on_app_backgrounded()
	assert_eq(fx.availability, [false] as Array[bool])
	assert_eq(fx.core.get_state(), S.ACQUIRING)
	assert_eq(fx.core.get_sample_count(), 0)


func test_events_change_nothing_in_fallback_and_release_config_ac24g() -> void:
	for is_debug: bool in [true, false]:
		var fx: Fixture = Fixture.new(null, 1.0, true, false, is_debug)
		var state: S = fx.core.get_state()
		fx.core.on_app_backgrounded()
		fx.core.on_app_foregrounded()
		assert_eq(fx.core.get_state(), state)
		assert_eq(fx.availability.size(), 0)
		assert_eq(fx.core.get_valid(), is_debug)
		assert_eq(fx.core.get_neutral_stale(), not is_debug)


func test_sensor_that_does_not_return_leaves_acquiring_for_unavailable_ac49() -> void:
	var fx: Fixture = _returned()
	fx.availability.clear()
	fx.gravity = Vector3.ZERO
	var first: int = F_US + SETTLE_US
	_poll_at(fx, first)
	_poll_at(fx, first + TIMEOUT_US - 1)
	assert_eq(fx.core.get_state(), S.ACQUIRING)
	_poll_at(fx, first + TIMEOUT_US)
	assert_eq(fx.core.get_state(), S.UNAVAILABLE)
	assert_eq(fx.count_code(TiltCore.LOG_SENSOR_TIMEOUT), 1)
	assert_eq(fx.core.get_input_source(), TiltCore.InputSource.SENSOR)
	assert_eq(fx.core.get_steer(), 0.0)
	assert_eq(fx.availability.size(), 0, "valid stayed false")
	fx.set_pose(4.0)
	_poll_at(fx, first + TIMEOUT_US + 20000)
	assert_eq(fx.core.get_state(), S.LIVE)
	assert_eq(fx.availability, [true] as Array[bool])
	assert_true(fx.core.get_neutral_stale())
	assert_eq(fx.count_code(TiltCore.LOG_SENSOR_TIMEOUT), 1)
