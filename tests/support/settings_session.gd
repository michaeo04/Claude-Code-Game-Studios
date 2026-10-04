## Scripted Settings session shared by the isolation and determinism tests. Framework-free (ADR-0009).
extends RefCounted

const Fx = preload("res://tests/support/settings_fixtures.gd")


## Records `setting_changed` emissions as `[key, value]`.
class EventLog:
	extends RefCounted
	var events: Array[Array] = []

	func record(key: String, value: Variant) -> void:
		events.append([key, value])


## Runs the fixed session on a fresh core and returns the recorded get/set/log/event sequences,
## the `set_value` results and the final getter values.
static func run(set_succeeds: bool = true) -> Dictionary:
	var getter: Fx.Spy = Fx.make_get_value_stub({})
	var setter: Fx.Spy = Fx.make_set_value_stub(set_succeeds)
	var log_spy: Fx.LogSpy = Fx.make_log_spy()
	var core: SettingsCore = Fx.make_settings_core(getter, setter, log_spy)
	var events: EventLog = EventLog.new()
	core.setting_changed.connect(events.record)
	var results: Array[bool] = []
	results.append(core.set_value("haptics_enabled", false))
	results.append(core.set_value("haptics_enabled", false))
	results.append(core.set_value("reduced_motion_enabled", true))
	results.append(core.set_value("brightness", 0.5))
	results.append(core.set_value("tilt_sensitivity", 5.0))
	results.append(core.set_value("tilt_sensitivity", 5.0))
	results.append(core.set_value("haptics_intensity", 0.25))
	return {
		"get_calls": getter.calls,
		"set_calls": setter.calls,
		"logs": log_spy.entries,
		"events": events.events,
		"results": results,
		"getters": [
			core.get_haptics_enabled(), core.get_haptics_intensity(), core.get_tilt_sensitivity(),
			core.get_reduced_motion_enabled(), core.get_colorblind_safe_enabled(), core.get_seam_contrast_scale(),
		],
	}
