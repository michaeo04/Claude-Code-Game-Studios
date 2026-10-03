## Fixture factories for Settings & Accessibility tests. Framework-free (ADR-0009): no GUT call.
## Usage: `const Fx = preload("res://tests/support/settings_fixtures.gd")`.
extends RefCounted

## Fixture-distinct sensitivity range and default (the shipped values are 0.5 / 2.0 / 1.0).
const FIXTURE_MIN: float = 0.4
const FIXTURE_MAX: float = 2.6
const FIXTURE_DEFAULT: float = 1.3


## Records `(section, key, default)` of every get call and `(section, key, value)` of every set call.
class Spy:
	extends RefCounted
	var calls: Array[Array] = []
	var stored: Dictionary = {}
	var succeeds: bool = true

	func get_value(section: String, key: String, default_value: Variant) -> Variant:
		calls.append([section, key, default_value])
		return stored.get(key, default_value)

	func set_value(section: String, key: String, value: Variant) -> bool:
		calls.append([section, key, value])
		return succeeds


## Records `(level, code, key, message)` of every log call.
class LogSpy:
	extends RefCounted
	var entries: Array[Array] = []

	func record(level: int, code: StringName, key: String, message: String) -> void:
		entries.append([level, code, key, message])


## The fully populated stored values: false, 0.6, 1.75, true, true.
static func make_settings_fixture() -> Dictionary:
	return {
		"haptics_enabled": false,
		"haptics_intensity": 0.6,
		"tilt_sensitivity": 1.75,
		"reduced_motion_enabled": true,
		"colorblind_safe_enabled": true,
	}


## A get stub over `stored` (keys absent from it return the caller's default); read the spy for the calls.
static func make_get_value_stub(stored: Dictionary) -> Spy:
	var spy: Spy = Spy.new()
	spy.stored = stored
	return spy


## A set stub that returns `succeeds`.
static func make_set_value_stub(succeeds: bool = true) -> Spy:
	var spy: Spy = Spy.new()
	spy.succeeds = succeeds
	return spy


## A log recorder.
static func make_log_spy() -> LogSpy:
	return LogSpy.new()


## Builds a core over the given spies using the fixture range 0.4 / 2.6 / 1.3.
static func make_settings_core(getter: Spy, setter: Spy, log_spy: LogSpy) -> SettingsCore:
	return SettingsCore.new(getter.get_value, setter.set_value, log_spy.record, FIXTURE_MIN, FIXTURE_MAX, FIXTURE_DEFAULT)
