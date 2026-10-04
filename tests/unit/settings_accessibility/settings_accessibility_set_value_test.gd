## Story 005: set_value writes on change, no-ops on equal, emits setting_changed once.
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
	_getter.calls.clear()
	_events = Session.EventLog.new()
	_core.setting_changed.connect(_events.record)


func test_ac9_change_writes_once_and_updates_getter() -> void:
	assert_true(_core.set_value("haptics_enabled", false))
	assert_eq(_setter.calls.size(), 1)
	assert_eq(_setter.calls[0], ["settings", "haptics_enabled", false])
	assert_false(_core.get_haptics_enabled())


func test_ac10_equal_value_is_noop_for_all_five_keys() -> void:
	var rows: Array[Array] = [
		["haptics_enabled", true], ["haptics_intensity", 1.0], ["tilt_sensitivity", Fx.FIXTURE_DEFAULT],
		["reduced_motion_enabled", false], ["colorblind_safe_enabled", false],
	]
	for row: Array in rows:
		assert_true(_core.set_value(row[0] as String, row[1]))
		assert_true(_core.set_value(row[0] as String, row[1]))
	assert_eq(_setter.calls.size(), 0)
	assert_eq(_events.events.size(), 0)


func test_ac11_three_changes_emit_three_events_and_noop_none() -> void:
	_core.set_value("haptics_enabled", false)
	_core.set_value("haptics_intensity", 0.5)
	_core.set_value("colorblind_safe_enabled", true)
	_core.set_value("colorblind_safe_enabled", true)
	assert_eq(_events.events.size(), 3)
	assert_eq(_events.events[0], ["haptics_enabled", false])
	assert_eq(_events.events[1], ["haptics_intensity", 0.5])
	assert_eq(_events.events[2], ["colorblind_safe_enabled", true])
	assert_eq(_setter.calls.size(), 3)
