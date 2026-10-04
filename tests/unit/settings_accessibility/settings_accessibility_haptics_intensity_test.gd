## Story CRF-004: `haptics_intensity` is validated at boot and in `set_value` (range from `HapticsConfig`).
extends GutTest

const Fx = preload("res://tests/support/settings_fixtures.gd")
const Session = preload("res://tests/support/settings_session.gd")


func _boot(stored: Dictionary) -> Array:
	var getter: Fx.Spy = Fx.make_get_value_stub(stored)
	var setter: Fx.Spy = Fx.make_set_value_stub()
	var logs: Fx.LogSpy = Fx.make_log_spy()
	return [Fx.make_settings_core(getter, setter, logs), setter, logs]


func test_boot_out_of_range_is_clamped_with_one_log() -> void:
	var rig: Array = _boot({"haptics_intensity": 3.5})
	var core: SettingsCore = rig[0]
	var logs: Fx.LogSpy = rig[2]
	assert_almost_eq(core.get_haptics_intensity(), HapticsConfig.INTENSITY_RANGE.y, 1e-6)
	assert_eq(logs.entries.size(), 1)
	assert_eq(logs.entries[0][1], &"SETTING_CLAMPED")
	assert_eq(logs.entries[0][2], "haptics_intensity")


func test_boot_negative_is_clamped_to_lower_bound() -> void:
	var rig: Array = _boot({"haptics_intensity": -0.4})
	assert_almost_eq((rig[0] as SettingsCore).get_haptics_intensity(), HapticsConfig.INTENSITY_RANGE.x, 1e-6)
	assert_eq((rig[2] as Fx.LogSpy).entries.size(), 1)


func test_boot_nan_takes_default_with_one_log() -> void:
	var rig: Array = _boot({"haptics_intensity": NAN})
	assert_almost_eq((rig[0] as SettingsCore).get_haptics_intensity(), HapticsConfig.INTENSITY_DEFAULT, 1e-6)
	assert_eq((rig[2] as Fx.LogSpy).entries.size(), 1)
	assert_eq((rig[2] as Fx.LogSpy).entries[0][1], &"SETTING_CLAMPED")


func test_boot_in_range_value_logs_nothing_and_zero_is_valid() -> void:
	var rig: Array = _boot({"haptics_intensity": 0.0})
	assert_almost_eq((rig[0] as SettingsCore).get_haptics_intensity(), 0.0, 1e-6)
	assert_eq((rig[2] as Fx.LogSpy).entries.size(), 0)


func test_set_value_nan_resolves_to_default_and_memory_equals_written() -> void:
	var rig: Array = _boot({"haptics_intensity": 0.6})
	var core: SettingsCore = rig[0]
	var setter: Fx.Spy = rig[1]
	var logs: Fx.LogSpy = rig[2]
	var events: Session.EventLog = Session.EventLog.new()
	core.setting_changed.connect(events.record)
	core.set_value("haptics_intensity", NAN)
	assert_almost_eq(core.get_haptics_intensity(), HapticsConfig.INTENSITY_DEFAULT, 1e-6)
	assert_eq(setter.calls.size(), 1)
	assert_almost_eq(setter.calls[0][2] as float, core.get_haptics_intensity(), 1e-6)
	assert_eq(events.events.size(), 1)
	assert_almost_eq(events.events[0][1] as float, core.get_haptics_intensity(), 1e-6)
	assert_eq(logs.entries.size(), 1)
	assert_eq(logs.entries[0][1], &"SETTING_CLAMPED")


func test_set_value_out_of_range_is_clamped_to_nearest_bound() -> void:
	var rig: Array = _boot({"haptics_intensity": 0.5})
	var core: SettingsCore = rig[0]
	var setter: Fx.Spy = rig[1]
	core.set_value("haptics_intensity", 7.0)
	assert_almost_eq(core.get_haptics_intensity(), HapticsConfig.INTENSITY_RANGE.y, 1e-6)
	assert_almost_eq(setter.calls[0][2] as float, HapticsConfig.INTENSITY_RANGE.y, 1e-6)
	core.set_value("haptics_intensity", -2.0)
	assert_almost_eq(core.get_haptics_intensity(), HapticsConfig.INTENSITY_RANGE.x, 1e-6)
	assert_almost_eq(setter.calls[1][2] as float, HapticsConfig.INTENSITY_RANGE.x, 1e-6)


func test_range_comes_from_haptics_config() -> void:
	assert_eq(HapticsConfig.INTENSITY_RANGE, Vector2(0.0, 1.0))
	assert_eq(HapticsConfig.INTENSITY_DEFAULT, 1.0)
