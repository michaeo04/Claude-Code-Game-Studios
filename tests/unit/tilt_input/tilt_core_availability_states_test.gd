## Story TI-008: availability states, start timeout and availability signal (AC-28, AC-29, AC-38, AC-47a).
extends GutTest

const Fixture = preload("res://tests/support/tilt_fixture.gd")

const S = TiltCore.State


func _poll_at(fx: Fixture, stamp_us: int) -> void:
	fx.clock.now_us = stamp_us
	fx.core.poll()


func test_sensors_disabled_debug_is_live_fallback_with_one_error_ac28() -> void:
	var fx: Fixture = Fixture.new(null, 1.0, true, false, true)
	assert_eq(fx.core.get_state(), S.LIVE)
	assert_eq(fx.core.get_input_source(), TiltCore.InputSource.FALLBACK)
	assert_true(fx.core.get_valid())
	assert_eq(fx.count_code(TiltCore.LOG_SENSORS_DISABLED), 1)
	assert_eq(fx.sink.count(), 1)
	assert_eq(fx.availability.size(), 0)
	assert_false(fx.core.get_neutral_pending())
	assert_false(fx.core.get_neutral_stale())


func test_sensors_disabled_release_is_unavailable_with_one_error_ac28() -> void:
	var fx: Fixture = Fixture.new(null, 1.0, true, false, false)
	assert_eq(fx.core.get_state(), S.UNAVAILABLE)
	assert_false(fx.core.get_valid())
	assert_eq(fx.count_code(TiltCore.LOG_SENSORS_DISABLED), 1)
	assert_eq(fx.sink.count(), 1)
	assert_eq(fx.availability.size(), 0)


func test_sensors_enabled_is_acquiring_without_error_ac28() -> void:
	var fx: Fixture = Fixture.new(null, 1.0, true, true, false)
	assert_eq(fx.core.get_state(), S.ACQUIRING)
	assert_eq(fx.sink.count(), 0)
	assert_eq(fx.availability.size(), 0)


func test_timeout_boundary_without_sample_enters_live_fallback_ac29() -> void:
	var fx: Fixture = Fixture.new()
	fx.tick_invalid(1)
	assert_eq(fx.clock.now_us, 0)
	_poll_at(fx, 1999999)
	assert_eq(fx.core.get_state(), S.ACQUIRING)
	assert_false(fx.core.get_valid())
	assert_eq(fx.core.get_steer(), 0.0)
	assert_eq(fx.sink.count(), 0)
	_poll_at(fx, 2000000)
	assert_eq(fx.core.get_state(), S.LIVE)
	assert_eq(fx.core.get_input_source(), TiltCore.InputSource.FALLBACK)
	assert_eq(fx.count_code(TiltCore.LOG_SENSOR_TIMEOUT), 1)
	assert_eq(fx.availability, [true] as Array[bool])
	_poll_at(fx, 2100000)
	assert_eq(fx.count_code(TiltCore.LOG_SENSOR_TIMEOUT), 1, "one error only")
	assert_eq(fx.availability.size(), 1)


func test_valid_sample_at_the_timeout_boundary_wins_ac29() -> void:
	var fx: Fixture = Fixture.new()
	fx.tick_invalid(1)
	_poll_at(fx, 1999999)
	fx.set_pose(3.0)
	_poll_at(fx, 2000000)
	assert_eq(fx.core.get_state(), S.LIVE)
	assert_eq(fx.core.get_input_source(), TiltCore.InputSource.SENSOR)
	assert_eq(fx.count_code(TiltCore.LOG_SENSOR_TIMEOUT), 0)
	assert_eq(fx.availability, [true] as Array[bool])


func test_g_unit_vector_every_poll_ends_like_no_sample_ac29() -> void:
	var fx: Fixture = Fixture.new()
	fx.gravity = Vector3(0.0, -1.0, 0.0)
	fx.core.poll()
	_poll_at(fx, 1999999)
	assert_eq(fx.core.get_state(), S.ACQUIRING)
	_poll_at(fx, 2000000)
	assert_eq(fx.core.get_state(), S.LIVE)
	assert_eq(fx.core.get_input_source(), TiltCore.InputSource.FALLBACK)
	assert_eq(fx.count_code(TiltCore.LOG_SENSOR_TIMEOUT), 1)
	assert_eq(fx.availability, [true] as Array[bool])


func test_timeout_fallback_clears_pending_and_stale_ac29() -> void:
	var fx: Fixture = Fixture.new()
	fx.tick_invalid(1)
	_poll_at(fx, 2000000)
	assert_false(fx.core.get_neutral_pending())
	assert_false(fx.core.get_neutral_stale())


func test_no_signal_at_construction_in_any_mode_ac38() -> void:
	var modes: Array[Array] = [[true, true], [false, true], [false, false]]
	for mode: Array in modes:
		var fx: Fixture = Fixture.new(null, 1.0, true, mode[0] as bool, mode[1] as bool)
		assert_eq(fx.availability.size(), 0, "no signal at construction %s" % [mode])


func test_signal_around_loss_and_return_ac38() -> void:
	var fx: Fixture = Fixture.new()
	fx.tick(0.0, 1)
	assert_eq(fx.availability, [true] as Array[bool])
	fx.tick(0.0, 3)
	assert_eq(fx.availability.size(), 1, "no signal while Live and valid")
	fx.tick_invalid(8)
	assert_eq(fx.availability, [true, false] as Array[bool])
	fx.tick(0.0, 1)
	assert_eq(fx.availability, [true, false, true] as Array[bool])


func test_release_config_error_ignores_every_event_ac47a() -> void:
	var fx: Fixture = Fixture.new(null, 1.0, true, false, false)
	fx.fallback_value = 1
	fx.core.on_app_backgrounded()
	fx.core.on_app_foregrounded()
	fx.core.on_run_reset(TiltCore.PreviousPhase.MENU)
	fx.core.on_run_resumed()
	fx.tick(5.0, 10)
	fx.clock.now_us = 5000000
	fx.core.poll()
	assert_eq(fx.core.get_state(), S.UNAVAILABLE)
	assert_eq(fx.core.get_input_source(), TiltCore.InputSource.SENSOR)
	assert_eq(fx.core.get_steer(), 0.0)
	assert_eq(fx.availability.size(), 0)
	assert_eq(fx.count_code(TiltCore.LOG_SENSOR_TIMEOUT), 0)
