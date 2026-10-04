## Story SA-010 AC-21 (ADVISORY): shipped defaults match Core Rule 1 and the sensitivity range.
extends GutTest

const SinkStub = preload("res://tests/support/platform_log_sink.gd")


func _defaulting_get(_section: String, _key: String, default: Variant) -> Variant:
	return default


func test_shipped_defaults_match_core_rule_1() -> void:
	var sink: SinkStub = SinkStub.new()
	var core: SettingsCore = SettingsCore.new(
		_defaulting_get, func(_s: String, _k: String, _v: Variant) -> bool: return true, sink.sink
	)
	assert_eq(core.get_haptics_enabled(), true)
	assert_almost_eq(core.get_haptics_intensity(), 1.0, 1e-6)
	assert_almost_eq(core.get_tilt_sensitivity(), 1.0, 1e-6)
	assert_eq(core.get_reduced_motion_enabled(), false)
	assert_eq(core.get_colorblind_safe_enabled(), false)
	assert_eq(sink.count(), 0)


func test_shipped_sensitivity_range_is_half_to_double() -> void:
	assert_almost_eq(TuningLimits.SENSITIVITY_MIN, 0.5, 1e-6)
	assert_almost_eq(TuningLimits.SENSITIVITY_MAX, 2.0, 1e-6)
