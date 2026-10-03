## Story ST-002: SettingsCore construction and boot read (GDD AC-4, AC-5, AC-6).
extends GutTest

const Fx = preload("res://tests/support/settings_fixtures.gd")


func test_boot_read_calls_get_value_seam_five_times_with_each_default() -> void:
	var getter: Fx.Spy = Fx.make_get_value_stub(Fx.make_settings_fixture())
	Fx.make_settings_core(getter, Fx.make_set_value_stub(), Fx.make_log_spy())
	assert_eq(getter.calls.size(), 5)
	assert_true(getter.calls.has(["settings", "haptics_enabled", true]))
	assert_true(getter.calls.has(["settings", "haptics_intensity", 1.0]))
	assert_true(getter.calls.has(["settings", "tilt_sensitivity", Fx.FIXTURE_DEFAULT]))
	assert_true(getter.calls.has(["settings", "reduced_motion_enabled", false]))
	assert_true(getter.calls.has(["settings", "colorblind_safe_enabled", false]))


func test_boot_read_float_defaults_are_floats() -> void:
	var getter: Fx.Spy = Fx.make_get_value_stub({})
	Fx.make_settings_core(getter, Fx.make_set_value_stub(), Fx.make_log_spy())
	for call: Array in getter.calls:
		if call[1] == "haptics_intensity" or call[1] == "tilt_sensitivity":
			assert_eq(typeof(call[2]), TYPE_FLOAT)


func test_boot_read_stored_values_are_returned_by_every_getter() -> void:
	var getter: Fx.Spy = Fx.make_get_value_stub(Fx.make_settings_fixture())
	var core: SettingsCore = Fx.make_settings_core(getter, Fx.make_set_value_stub(), Fx.make_log_spy())
	assert_eq(core.get_haptics_enabled(), false)
	assert_almost_eq(core.get_haptics_intensity(), 0.6, 1e-6)
	assert_almost_eq(core.get_tilt_sensitivity(), 1.75, 1e-6)
	assert_eq(core.get_reduced_motion_enabled(), true)
	assert_eq(core.get_colorblind_safe_enabled(), true)


func test_boot_read_one_defaulted_key_does_not_touch_the_others() -> void:
	var stored: Dictionary = Fx.make_settings_fixture()
	stored.erase("haptics_enabled")
	var getter: Fx.Spy = Fx.make_get_value_stub(stored)
	var core: SettingsCore = Fx.make_settings_core(getter, Fx.make_set_value_stub(), Fx.make_log_spy())
	assert_eq(core.get_haptics_enabled(), true)
	assert_almost_eq(core.get_haptics_intensity(), 0.6, 1e-6)
	assert_almost_eq(core.get_tilt_sensitivity(), 1.75, 1e-6)
	assert_eq(core.get_reduced_motion_enabled(), true)
	assert_eq(core.get_colorblind_safe_enabled(), true)


func test_boot_read_all_keys_defaulted_reads_core_rule_defaults_without_error() -> void:
	var getter: Fx.Spy = Fx.make_get_value_stub({})
	var log_spy: Fx.LogSpy = Fx.make_log_spy()
	var core: SettingsCore = Fx.make_settings_core(getter, Fx.make_set_value_stub(), log_spy)
	assert_eq(core.get_haptics_enabled(), true)
	assert_almost_eq(core.get_haptics_intensity(), 1.0, 1e-6)
	assert_almost_eq(core.get_tilt_sensitivity(), Fx.FIXTURE_DEFAULT, 1e-6)
	assert_eq(core.get_reduced_motion_enabled(), false)
	assert_eq(core.get_colorblind_safe_enabled(), false)
	assert_eq(log_spy.entries.size(), 0)


func test_boot_read_shipped_range_defaults_tilt_sensitivity_to_one() -> void:
	var getter: Fx.Spy = Fx.make_get_value_stub({})
	var core: SettingsCore = SettingsCore.new(getter.get_value, Fx.make_set_value_stub().set_value, Fx.make_log_spy().record)
	assert_almost_eq(core.get_tilt_sensitivity(), 1.0, 1e-6)
	assert_true(getter.calls.has(["settings", "tilt_sensitivity", 1.0]))
