## Story 006: runtime tilt sensitivity validation and unknown-key rejection.
extends GutTest

const Fx = preload("res://tests/support/settings_fixtures.gd")
const Session = preload("res://tests/support/settings_session.gd")

var _getter: Fx.Spy
var _setter: Fx.Spy
var _logs: Fx.LogSpy
var _core: SettingsCore
var _events: Session.EventLog


func before_each() -> void:
	_getter = Fx.make_get_value_stub({})
	_setter = Fx.make_set_value_stub()
	_logs = Fx.make_log_spy()
	_core = Fx.make_settings_core(_getter, _setter, _logs)
	_events = Session.EventLog.new()
	_core.setting_changed.connect(_events.record)


func _snapshot() -> Array:
	return [
		_core.get_haptics_enabled(), _core.get_haptics_intensity(), _core.get_tilt_sensitivity(),
		_core.get_reduced_motion_enabled(), _core.get_colorblind_safe_enabled(), _core.get_seam_contrast_scale(),
	]


func test_ac12_out_of_range_is_corrected_everywhere() -> void:
	_core.set_value("tilt_sensitivity", 5.0)
	assert_almost_eq(_core.get_tilt_sensitivity(), Fx.FIXTURE_MAX, 1e-6)
	assert_eq(_setter.calls.size(), 1)
	assert_almost_eq(_setter.calls[0][2] as float, Fx.FIXTURE_MAX, 1e-6)
	assert_eq(_logs.entries.size(), 1)
	assert_eq(_logs.entries[0][1], &"SETTING_CLAMPED")
	assert_eq(_events.events.size(), 1)
	assert_almost_eq(_events.events[0][1] as float, Fx.FIXTURE_MAX, 1e-6)


func test_ac12_nan_resolves_to_default_never_written_as_nan() -> void:
	_core.set_value("tilt_sensitivity", 2.0)
	_setter.calls.clear()
	_core.set_value("tilt_sensitivity", NAN)
	assert_almost_eq(_core.get_tilt_sensitivity(), Fx.FIXTURE_DEFAULT, 1e-6)
	assert_eq(_setter.calls.size(), 1)
	assert_false(is_nan(_setter.calls[0][2] as float))


func test_ac13_unknown_keys_rejected_without_effect() -> void:
	var before: Array = _snapshot()
	assert_false(_core.set_value("haptics_enable", true))
	assert_false(_core.set_value("brightness", 0.5))
	assert_eq(_logs.entries.size(), 2)
	assert_eq(_logs.entries[0][0], 1)
	assert_eq(_logs.entries[0][1], &"UNKNOWN_SETTING_KEY")
	assert_eq(_logs.entries[0][2], "haptics_enable")
	assert_eq(_logs.entries[1][1], &"UNKNOWN_SETTING_KEY")
	assert_eq(_logs.entries[1][2], "brightness")
	assert_eq(_setter.calls.size(), 0)
	assert_eq(_events.events.size(), 0)
	assert_eq(_snapshot(), before)


func test_ac13_getter_surface_is_exactly_six_methods() -> void:
	var names: Array[String] = []
	for m: Dictionary in _core.get_script().get_script_method_list():
		var n: String = m["name"] as String
		if n.begins_with("get_"):
			names.append(n)
	names.sort()
	assert_eq(names, [
		"get_colorblind_safe_enabled", "get_haptics_enabled", "get_haptics_intensity",
		"get_reduced_motion_enabled", "get_seam_contrast_scale", "get_tilt_sensitivity",
	])
