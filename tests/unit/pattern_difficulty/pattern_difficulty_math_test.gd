extends GutTest

const OMEGA_MAX: float = 3.0
const EPS: float = 0.05


func _a(v: float) -> PackedFloat64Array:
	return PackedFloat64Array([v])


func test_opposing_default_threshold_flags_100_degrees() -> void:
	assert_true(PatternMath.opposing(_a(0.0), _a(deg_to_rad(100.0)), PI / 2.0))


func test_opposing_mutated_thresholds_change_verdict() -> void:
	var d40: float = deg_to_rad(40.0)
	var d140: float = deg_to_rad(140.0)
	assert_false(PatternMath.opposing(_a(0.0), _a(d40), PI / 2.0))
	assert_true(PatternMath.opposing(_a(0.0), _a(d40), PI / 6.0))
	assert_true(PatternMath.opposing(_a(0.0), _a(d140), PI / 2.0))
	assert_false(PatternMath.opposing(_a(0.0), _a(d140), 5.0 * PI / 6.0))


func test_opposing_required_floor_depends_on_classification() -> void:
	var rec: float = PatternMath.dodge_recovery_s(1.064, 25.0)
	var spacing: float = 6.25
	# A 40 deg pair 10 u apart: default needs only spacing (passes), PI/6 would need the recovery floor (fails).
	assert_gte(10.0, spacing)
	assert_lt(10.0, rec)


func test_opposing_strict_at_threshold() -> void:
	assert_false(PatternMath.opposing(_a(0.0), _a(PI / 2.0), PI / 2.0))


func test_opposing_uses_wrapped_delta_across_seam() -> void:
	assert_false(PatternMath.opposing(_a(PI - 0.1), _a(-PI + 0.1), PI / 2.0))
	assert_true(PatternMath.opposing(_a(0.0), _a(PI), PI / 2.0))


func test_opposing_empty_set_false() -> void:
	assert_false(PatternMath.opposing(PackedFloat64Array(), _a(PI), PI / 2.0))
	assert_false(PatternMath.opposing(_a(0.0), PackedFloat64Array(), PI / 2.0))


func test_dodge_recovery_default_is_26_6() -> void:
	assert_almost_eq(PatternMath.dodge_recovery_s(1.064, 25.0), 26.6, 1e-6)
	assert_gte(PatternMath.dodge_recovery_s(1.064, 25.0), 3.76 * 6.25)


func test_cost_ratio_tau_zero_is_0_492() -> void:
	var r: float = PatternMath.cost_ratio(PI / 2.0, EPS, OMEGA_MAX, 0.0)
	assert_almost_eq(r, (1.5708 - 0.05) / (3.1416 - 0.05), 1e-3)
	assert_true(is_finite(r))
	assert_true(absf(r - 0.5) > 1e-3)


func test_cost_ratio_tau_0_015_uses_third_branch() -> void:
	var r: float = PatternMath.cost_ratio(PI / 2.0, EPS, OMEGA_MAX, 0.015)
	# K = 0.045 < eps 0.05: third branch (x - eps) / omega_max, no ln term.
	assert_almost_eq(r, (PI / 2.0 - EPS) / (PI - EPS), 1e-9)
	assert_true(is_finite(r))


func test_cost_ratio_tau_at_boundary_resolves() -> void:
	var tau: float = EPS / OMEGA_MAX
	var r: float = PatternMath.cost_ratio(PI / 2.0, EPS, OMEGA_MAX, tau)
	assert_true(is_finite(r))
	assert_almost_eq(r, (PI / 2.0 - EPS) / (PI - EPS), 1e-6)


func test_cost_ratio_middle_branch_only_restatement_fails() -> void:
	# tau 0.1: K 0.3 > eps, ln branch applies; the third-branch formula gives a different value.
	var r: float = PatternMath.cost_ratio(PI / 2.0, EPS, OMEGA_MAX, 0.1)
	assert_true(absf(r - (PI / 2.0 - EPS) / (PI - EPS)) > 1e-4)
