## Story 007: a failed write keeps the in-memory value.
extends GutTest

const Fx = preload("res://tests/support/settings_fixtures.gd")
const Session = preload("res://tests/support/settings_session.gd")


func test_ac14_failed_write_keeps_memory_and_emits_once() -> void:
	var getter: Fx.Spy = Fx.make_get_value_stub({})
	var setter: Fx.Spy = Fx.make_set_value_stub(false)
	var logs: Fx.LogSpy = Fx.make_log_spy()
	var core: SettingsCore = Fx.make_settings_core(getter, setter, logs)
	var events: Session.EventLog = Session.EventLog.new()
	core.setting_changed.connect(events.record)
	assert_true(core.set_value("reduced_motion_enabled", true))
	assert_eq(setter.calls.size(), 1)
	assert_true(core.get_reduced_motion_enabled())
	assert_eq(events.events.size(), 1)
	assert_eq(logs.entries.size(), 0)
	core.set_value("reduced_motion_enabled", true)
	assert_eq(setter.calls.size(), 1)
	assert_eq(events.events.size(), 1)
