## Story ST-004: typed getters and seam_contrast_scale, no seam access after construction (GDD AC-8).
extends GutTest

const Fx = preload("res://tests/support/settings_fixtures.gd")


func test_getters_never_touch_the_seam_after_construction() -> void:
	var getter: Fx.Spy = Fx.make_get_value_stub(Fx.make_settings_fixture())
	var setter: Fx.Spy = Fx.make_set_value_stub()
	var core: SettingsCore = Fx.make_settings_core(getter, setter, Fx.make_log_spy())
	assert_eq(getter.calls.size(), 5)
	for i: int in 3:
		core.get_haptics_enabled()
		core.get_haptics_intensity()
		core.get_tilt_sensitivity()
		core.get_reduced_motion_enabled()
		core.get_colorblind_safe_enabled()
		core.get_seam_contrast_scale()
	assert_eq(getter.calls.size(), 5)
	assert_eq(setter.calls.size(), 0)


func test_seam_contrast_scale_is_one_for_default_reduced_motion() -> void:
	var core: SettingsCore = Fx.make_settings_core(Fx.make_get_value_stub({}), Fx.make_set_value_stub(), Fx.make_log_spy())
	assert_almost_eq(core.get_seam_contrast_scale(), 1.0, 1e-6)


func test_seam_contrast_scale_is_zero_when_reduced_motion_stored_true() -> void:
	var stored: Dictionary = {"reduced_motion_enabled": true}
	var core: SettingsCore = Fx.make_settings_core(Fx.make_get_value_stub(stored), Fx.make_set_value_stub(), Fx.make_log_spy())
	assert_almost_eq(core.get_seam_contrast_scale(), 0.0, 1e-6)
