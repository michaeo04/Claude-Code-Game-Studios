## Story SA-001: SettingsMath F1 seam contrast and F2 tilt sensitivity validation.
extends GutTest

const EPS: float = 1e-6
const SENS_MIN: float = 0.4
const SENS_MAX: float = 2.6
const SENS_DEFAULT: float = 1.3


func _check(raw: float, want: float, want_corrected: bool) -> void:
	var out: Dictionary = SettingsMath.tilt_sensitivity_validate(raw, SENS_MIN, SENS_MAX, SENS_DEFAULT)
	assert_almost_eq(out["value"] as float, want, EPS, "value for %s" % raw)
	assert_eq(out["was_corrected"] as bool, want_corrected, "was_corrected for %s" % raw)


func test_seam_contrast_full_when_motion_allowed() -> void:
	assert_eq(SettingsMath.seam_contrast_scale(false), 1.0)


func test_seam_contrast_zero_when_reduced_motion() -> void:
	assert_eq(SettingsMath.seam_contrast_scale(true), 0.0)


func test_seam_contrast_outputs_are_binary() -> void:
	for flag: bool in [false, true]:
		var s: float = SettingsMath.seam_contrast_scale(flag)
		assert_true(s == 0.0 or s == 1.0, "scale %s is not in {0.0, 1.0}" % s)


func test_validate_in_range_value_unchanged() -> void:
	_check(1.5, 1.5, false)


func test_validate_min_bound_not_corrected() -> void:
	_check(0.4, 0.4, false)


func test_validate_max_bound_not_corrected() -> void:
	_check(2.6, 2.6, false)


func test_validate_above_max_clamps_to_max() -> void:
	_check(5.0, 2.6, true)


func test_validate_below_min_clamps_to_min_not_default() -> void:
	_check(0.1, 0.4, true)


func test_validate_zero_falls_back_to_default() -> void:
	_check(0.0, 1.3, true)


func test_validate_negative_falls_back_to_default() -> void:
	_check(-2.0, 1.3, true)


func test_validate_nan_falls_back_to_default() -> void:
	_check(NAN, 1.3, true)


func test_validate_inf_falls_back_to_default() -> void:
	_check(INF, 1.3, true)


func test_validate_negative_inf_falls_back_to_default() -> void:
	_check(-INF, 1.3, true)
