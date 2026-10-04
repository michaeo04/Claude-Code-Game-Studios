## Story CRF-006: shared tuning values are defined once (code review finding 8).
extends GutTest

const ClockStub = preload("res://tests/support/clock_stub.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")
const Fx = preload("res://tests/support/settings_fixtures.gd")


func _poll_dt(dt_max: float, step_us: int) -> float:
	var clock: ClockStub = ClockStub.new(0)
	var sink: LogSink = LogSink.new()
	var cfg: TiltConfig = TiltConfig.new()
	cfg.sensor_sign = 1
	var source: Callable = func() -> Vector3: return Vector3(0.0, -9.81, 0.0)
	var fallback: Callable = func() -> int: return 0
	var core: TiltCore = TiltCore.new(cfg, source, clock.as_callable(), sink.sink, fallback, 1.0, true, true, true, dt_max)
	core.poll()
	clock.advance_us(step_us)
	core.poll()
	return core.get_last_dt()


func test_run_state_tube_track_and_tilt_share_one_dt_max_default() -> void:
	assert_almost_eq(RunConfig.new().dt_max, TuningLimits.DT_MAX_DEFAULT, 1e-9)
	assert_almost_eq(TubeConfig.new().t_lat, TuningLimits.DT_MAX_DEFAULT, 1e-9)
	assert_almost_eq(TuningLimits.DT_MAX_DEFAULT, 0.1, 1e-9, "shipped default unchanged")


func test_tilt_core_clamps_dt_to_the_injected_dt_max() -> void:
	assert_almost_eq(_poll_dt(0.05, 500000), 0.05, 1e-6)
	assert_almost_eq(_poll_dt(0.25, 500000), 0.25, 1e-6)


func test_tilt_core_default_dt_max_matches_shipped_value() -> void:
	assert_almost_eq(_poll_dt(TuningLimits.DT_MAX_DEFAULT, 500000), 0.1, 1e-6)


func test_tilt_core_bad_dt_max_falls_back_to_default() -> void:
	assert_almost_eq(_poll_dt(-1.0, 500000), TuningLimits.DT_MAX_DEFAULT, 1e-6)
	assert_almost_eq(_poll_dt(NAN, 500000), TuningLimits.DT_MAX_DEFAULT, 1e-6)


func test_tube_config_with_dt_max_copies_without_mutating_source() -> void:
	var src: TubeConfig = TubeConfig.new()
	var out: TubeConfig = src.with_dt_max(0.2)
	assert_almost_eq(out.t_lat, 0.2, 1e-9)
	assert_almost_eq(src.t_lat, TuningLimits.DT_MAX_DEFAULT, 1e-9)


func test_sensitivity_bounds_are_defined_once_and_unchanged() -> void:
	assert_almost_eq(TuningLimits.SENSITIVITY_MIN, 0.5, 1e-9)
	assert_almost_eq(TuningLimits.SENSITIVITY_MAX, 2.0, 1e-9)


func test_tilt_config_and_settings_core_clamp_to_the_same_bounds() -> void:
	var sink: LogSink = LogSink.new()
	assert_almost_eq(TiltConfig.validated_sensitivity(9.0, sink.sink), TuningLimits.SENSITIVITY_MAX, 1e-9)
	assert_almost_eq(TiltConfig.validated_sensitivity(0.1, sink.sink), TuningLimits.SENSITIVITY_MIN, 1e-9)
	var getter: Fx.Spy = Fx.make_get_value_stub({})
	var setter: Fx.Spy = Fx.make_set_value_stub()
	var logs: Fx.LogSpy = Fx.make_log_spy()
	var core: SettingsCore = SettingsCore.new(getter.get_value, setter.set_value, logs.record)
	core.set_value(SettingsCore.KEY_TILT_SENSITIVITY, 9.0)
	assert_almost_eq(core.get_tilt_sensitivity(), TuningLimits.SENSITIVITY_MAX, 1e-9)
	core.set_value(SettingsCore.KEY_TILT_SENSITIVITY, 0.1)
	assert_almost_eq(core.get_tilt_sensitivity(), TuningLimits.SENSITIVITY_MIN, 1e-9)
