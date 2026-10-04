## Story 008: no consumer seams, closed call surface, determinism.
extends GutTest

const Fx = preload("res://tests/support/settings_fixtures.gd")
const Session = preload("res://tests/support/settings_session.gd")


func test_ac15_constructor_has_exactly_six_parameters() -> void:
	var core: SettingsCore = Fx.make_settings_core(Fx.make_get_value_stub({}), Fx.make_set_value_stub(), Fx.make_log_spy())
	var names: Array[String] = []
	for m: Dictionary in core.get_script().get_script_method_list():
		if m["name"] == "_init":
			for a: Dictionary in m["args"]:
				names.append(a["name"] as String)
	assert_eq(names, [
		"get_value_seam", "set_value_seam", "log_sink", "sensitivity_min", "sensitivity_max", "default_sensitivity",
	])


func test_ac16_seam_call_surface() -> void:
	var r: Dictionary = Session.run(false)
	assert_eq((r["get_calls"] as Array).size(), 5)
	# Actual changes: haptics_enabled, reduced_motion, tilt (clamped), haptics_intensity.
	var sets: Array = r["set_calls"]
	assert_eq(sets.size(), 4)
	for c: Array in sets:
		assert_eq(c[0], "settings")
	for c: Array in r["get_calls"]:
		assert_eq(c[0], "settings")
	var codes: Array[StringName] = []
	for e: Array in r["logs"]:
		codes.append(e[1] as StringName)
	assert_eq(codes, [&"UNKNOWN_SETTING_KEY", &"SETTING_CLAMPED", &"SETTING_CLAMPED"] as Array[StringName])
	assert_eq((r["events"] as Array).size(), 4)


func test_ac17_identical_sessions_are_identical() -> void:
	var a: Dictionary = Session.run()
	var b: Dictionary = Session.run()
	assert_eq(a, b)
