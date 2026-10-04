## Story TI-011: fallback input (AC-33, AC-34, AC-47b, AC-48) and the state-transition table (AC-32).
extends GutTest

const Fixture = preload("res://tests/support/tilt_fixture.gd")

const S = TiltCore.State
const SRC = TiltCore.InputSource
const DT_US: int = 62500

enum Ev { VALID, INVALID_PAST_HOLD, TIMEOUT_NEVER_LIVE, BACKGROUNDED }


func _debug_fallback() -> Fixture:
	var fx: Fixture = Fixture.new(null, 1.0, true, false, true)
	fx.step_us = DT_US
	fx.tick(0.0)  # priming poll at stamp 0
	return fx


## A release core that reached FALLBACK through the start timeout (never live).
func _timeout_fallback() -> Fixture:
	var fx: Fixture = Fixture.new()
	fx.step_us = 1000000
	fx.tick_invalid(4)  # stamps 0, 1 s, 2 s, 3 s: timeout at 2 s
	fx.step_us = DT_US
	return fx


func _steers(fx: Fixture, value: int, count: int) -> Array[float]:
	fx.fallback_value = value
	var out: Array[float] = []
	for i: int in count:
		fx.tick(0.0)
		out.append(fx.core.get_steer())
	return out


func _assert_seq(got: Array[float], want: Array[float]) -> void:
	assert_eq(got.size(), want.size())
	for i: int in mini(got.size(), want.size()):
		assert_almost_eq(got[i], want[i], 1e-6)


func _assert_slew(fx: Fixture) -> void:
	_assert_seq(_steers(fx, 1, 6), [0.25, 0.5, 0.75, 1.0, 1.0, 1.0] as Array[float])
	assert_true(fx.core.get_valid())
	_assert_seq(_steers(fx, 0, 5), [0.75, 0.5, 0.25, 0.0, 0.0] as Array[float])
	_assert_seq(_steers(fx, -1, 3), [-0.25, -0.5, -0.75] as Array[float])
	assert_true(fx.core.get_valid())


func test_debug_fallback_slews_and_holds_ac33a_b() -> void:
	_assert_slew(_debug_fallback())


func test_release_timeout_fallback_behaves_the_same_ac33c() -> void:
	var fx: Fixture = _timeout_fallback()
	assert_eq(fx.core.get_input_source(), SRC.FALLBACK)
	assert_false(fx.core.get_sensor_ever_live())
	_assert_slew(fx)


func test_value_two_acts_as_plus_one_ac33d() -> void:
	var fx: Fixture = _debug_fallback()
	_assert_seq(_steers(fx, 2, 5), [0.25, 0.5, 0.75, 1.0, 1.0] as Array[float])
	_assert_seq(_steers(fx, -7, 1), [0.75] as Array[float])


func test_priming_poll_leaves_steer_zero_ac33() -> void:
	var fx: Fixture = Fixture.new(null, 1.0, true, false, true)
	fx.fallback_value = 1
	fx.tick(0.0)
	assert_eq(fx.core.get_steer(), 0.0)


func test_sensors_live_ignores_fallback_source_ac34() -> void:
	var fx: Fixture = Fixture.new()
	fx.tick(0.0, 60)
	fx.core.on_run_reset(TiltCore.PreviousPhase.MENU)
	fx.fallback_value = 1
	fx.tick(0.0, 5)
	assert_eq(fx.core.get_input_source(), SRC.SENSOR)
	assert_eq(fx.core.get_steer(), 0.0)


func test_late_valid_sample_does_not_leave_fallback_ac47b() -> void:
	var fx: Fixture = _timeout_fallback()
	var phi_f: float = fx.core.get_phi_f()
	fx.tick(20.0, 5)
	assert_eq(fx.core.get_input_source(), SRC.FALLBACK)
	assert_eq(fx.core.get_state(), S.LIVE)
	assert_eq(fx.core.get_phi_f(), phi_f)
	assert_eq(fx.core.get_sample_count(), 0)


func test_fallback_ignores_capture_events_ac48() -> void:
	var fx: Fixture = _debug_fallback()
	assert_false(fx.core.get_neutral_pending())
	assert_false(fx.core.get_neutral_stale())
	fx.core.on_run_reset(TiltCore.PreviousPhase.MENU)
	fx.core.on_run_resumed()
	fx.fallback_value = 1
	fx.tick(0.0)
	assert_almost_eq(fx.core.get_steer(), 0.25, 1e-6)
	assert_false(fx.core.get_neutral_pending())
	assert_false(fx.core.get_neutral_stale())


func test_timeout_fallback_ignores_capture_events_ac48() -> void:
	var fx: Fixture = _timeout_fallback()
	assert_false(fx.core.get_neutral_pending())
	assert_false(fx.core.get_neutral_stale())
	fx.core.on_run_reset(TiltCore.PreviousPhase.MENU)
	fx.core.on_run_resumed()
	fx.fallback_value = 1
	fx.tick_invalid(1)
	assert_almost_eq(fx.core.get_steer(), 0.25, 1e-6)
	assert_false(fx.core.get_neutral_pending())
	assert_false(fx.core.get_neutral_stale())


# ---- AC-32: pairs outside the transition table change nothing, log no error and emit no signal ----


func _apply(fx: Fixture, ev: Ev) -> void:
	match ev:
		Ev.VALID:
			fx.tick(10.0)
		Ev.INVALID_PAST_HOLD:
			fx.tick_invalid(8)  # 117 ms of invalid polls: past the 0.1 s hold, below the 2 s timeout
		Ev.TIMEOUT_NEVER_LIVE:
			fx.step_us = 1000000
			fx.tick_invalid(3)
			fx.step_us = Fixture.STEP_US
		Ev.BACKGROUNDED:
			fx.core.on_app_backgrounded()


func _live_sensor() -> Fixture:
	var fx: Fixture = Fixture.new()
	fx.tick(10.0, 60)
	fx.core.on_run_reset(TiltCore.PreviousPhase.MENU)
	return fx


func _lost() -> Fixture:
	var fx: Fixture = _live_sensor()
	fx.tick_invalid(10)
	return fx


func _assert_quiet(fx: Fixture, errors_before: int, signals_before: int) -> void:
	assert_eq(fx.sink.count(), errors_before, "no new log line")
	assert_eq(fx.availability.size(), signals_before, "no signal")


func test_live_fallback_ignores_every_event_ac32() -> void:
	for ev: Ev in [Ev.VALID, Ev.INVALID_PAST_HOLD, Ev.TIMEOUT_NEVER_LIVE, Ev.BACKGROUNDED]:
		var fx: Fixture = _debug_fallback()
		var errors: int = fx.sink.count()
		_apply(fx, ev)
		assert_eq(fx.core.get_state(), S.LIVE)
		assert_eq(fx.core.get_input_source(), SRC.FALLBACK)
		assert_true(fx.core.get_valid())
		assert_false(fx.core.get_neutral_pending())
		assert_false(fx.core.get_neutral_stale())
		_assert_quiet(fx, errors, 0)


func test_release_config_error_ignores_every_event_ac32() -> void:
	for ev: Ev in [Ev.VALID, Ev.INVALID_PAST_HOLD, Ev.TIMEOUT_NEVER_LIVE, Ev.BACKGROUNDED]:
		var fx: Fixture = Fixture.new(null, 1.0, true, false, false)
		var errors: int = fx.sink.count()
		_apply(fx, ev)
		assert_eq(fx.core.get_state(), S.UNAVAILABLE)
		assert_false(fx.core.get_valid())
		_assert_quiet(fx, errors, 0)


func test_live_sensor_valid_sample_changes_nothing_ac32() -> void:
	var fx: Fixture = _live_sensor()
	var errors: int = fx.sink.count()
	var signals: int = fx.availability.size()
	_apply(fx, Ev.VALID)
	assert_eq(fx.core.get_state(), S.LIVE)
	assert_eq(fx.core.get_input_source(), SRC.SENSOR)
	_assert_quiet(fx, errors, signals)


func test_live_sensor_has_no_start_timeout_ac32() -> void:
	# In Live the long invalid gaps follow the F6 hold only: Unavailable, never FALLBACK, no timeout log.
	var fx: Fixture = _live_sensor()
	_apply(fx, Ev.TIMEOUT_NEVER_LIVE)
	assert_eq(fx.core.get_input_source(), SRC.SENSOR)
	assert_eq(fx.core.get_state(), S.UNAVAILABLE)
	assert_eq(fx.count_code(TiltCore.LOG_SENSOR_TIMEOUT), 0)


func test_acquiring_invalid_below_timeout_changes_nothing_ac32() -> void:
	var fx: Fixture = Fixture.new()
	_apply(fx, Ev.INVALID_PAST_HOLD)
	assert_eq(fx.core.get_state(), S.ACQUIRING)
	_assert_quiet(fx, 0, 0)


func test_unavailable_lost_invalid_and_timeout_change_nothing_ac32() -> void:
	for ev: Ev in [Ev.INVALID_PAST_HOLD, Ev.TIMEOUT_NEVER_LIVE]:
		var fx: Fixture = _lost()
		assert_eq(fx.core.get_state(), S.UNAVAILABLE)
		var errors: int = fx.sink.count()
		var signals: int = fx.availability.size()
		_apply(fx, ev)
		assert_eq(fx.core.get_state(), S.UNAVAILABLE)
		assert_eq(fx.core.get_input_source(), SRC.SENSOR)
		_assert_quiet(fx, errors, signals)


func test_acquiring_backgrounded_keeps_state_clears_buffer_and_restarts_settle_ac32() -> void:
	var fx: Fixture = Fixture.new()
	fx.core.on_app_backgrounded()
	assert_eq(fx.core.get_state(), S.ACQUIRING)
	assert_eq(fx.core.get_sample_count(), 0)
	assert_true(fx.core.get_neutral_stale())
	_assert_quiet(fx, 0, 0)
	fx.core.on_app_foregrounded()
	fx.tick(10.0)  # inside the settle window: discarded
	assert_eq(fx.core.get_sample_count(), 0)
	assert_eq(fx.core.get_state(), S.ACQUIRING)
