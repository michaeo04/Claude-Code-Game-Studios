## Story TI-002: TiltMath pure functions (AC-1, AC-2a, AC-4, AC-6, AC-7, AC-11).
extends GutTest

const DEG_TOL: float = 1e-3
const STEER_TOL: float = 1e-4
const ALPHA_TOL: float = 1e-6
const FS: float = 25.0
const DZ: float = 1.5
## One ulp below 1.0, a ratio that must pass through unchanged.
const JUST_BELOW_ONE: float = 0.9999999999999999

const ROLL_CASES: Array[Array] = [
	[Vector3(6.0, -8.0, 0.0), 36.870, 1e-3],
	[Vector3(3.0, 0.0, -4.0), 36.870, 1e-3],
	[Vector3(0.0, -9.81, 0.0), 0.0, 1e-3],
	[Vector3(9.81, 0.0, 0.0), 90.0, 1e-3],
	[Vector3(-9.81, 0.0, 0.0), -90.0, 1e-3],
	[Vector3(4.248, -7.358, -4.905), 25.66, 1e-2],
]


func test_roll_deg_listed_vectors_match_oracles() -> void:
	for c: Array in ROLL_CASES:
		assert_almost_eq(TiltMath.roll_deg(c[0] as Vector3, 1), c[1] as float, c[2] as float, "g=%s" % [c[0]])


func test_roll_deg_pitch_change_keeps_value() -> void:
	assert_almost_eq(TiltMath.roll_deg(Vector3(3, 0, -4), 1), TiltMath.roll_deg(Vector3(6, -8, 0), 1), 1e-9)


func test_clamp_ratio_above_one_gives_one() -> void:
	assert_eq(TiltMath.clamp_ratio(1.0000001), 1.0)
	assert_eq(TiltMath.clamp_ratio(-1.0000001), -1.0)
	assert_eq(TiltMath.clamp_ratio(JUST_BELOW_ONE), JUST_BELOW_ONE)


func test_roll_deg_rounding_above_one_does_not_produce_nan() -> void:
	assert_false(is_nan(TiltMath.roll_deg(Vector3(9.81000001, 0.0, 0.0), 1)))


func test_roll_deg_sensor_sign_minus_one_negates_every_value() -> void:
	for c: Array in ROLL_CASES:
		assert_almost_eq(TiltMath.roll_deg(c[0] as Vector3, -1), -(c[1] as float), c[2] as float, "g=%s" % [c[0]])


func test_alpha_table() -> void:
	assert_almost_eq(TiltMath.alpha(1.0 / 60.0, 0.05), 0.283469, ALPHA_TOL)
	assert_almost_eq(TiltMath.alpha(0.1, 0.05), 0.864665, ALPHA_TOL)
	assert_eq(TiltMath.alpha(0.0, 0.05), 0.0)


func test_alpha_tau_zero_or_negative_floors_to_tau_floor() -> void:
	assert_almost_eq(TiltMath.alpha(1.0 / 60.0, 0.0), 0.964326, ALPHA_TOL)
	assert_almost_eq(TiltMath.alpha(1.0 / 60.0, -1.0), 0.964326, ALPHA_TOL)


func test_filter_step_moves_by_alpha_fraction() -> void:
	assert_almost_eq(TiltMath.filter_step(0.0, 10.0, 1.0 / 60.0, 0.05), 2.83469, 1e-5)


func test_steer_k1_table() -> void:
	assert_eq(TiltMath.steer(1.5, FS, DZ, 1.0, 1.0), 0.0)
	assert_eq(TiltMath.steer(0.0, FS, DZ, 1.0, 1.0), 0.0)
	assert_almost_eq(TiltMath.steer(14.0, FS, DZ, 1.0, 1.0), 0.531915, STEER_TOL)
	assert_eq(TiltMath.steer(25.0, FS, DZ, 1.0, 1.0), 1.0)
	assert_eq(TiltMath.steer(40.0, FS, DZ, 1.0, 1.0), 1.0)
	assert_almost_eq(TiltMath.steer(-14.0, FS, DZ, 1.0, 1.0), -0.531915, STEER_TOL)
	assert_eq(TiltMath.steer(-40.0, FS, DZ, 1.0, 1.0), -1.0)


func test_steer_k_1_5_is_symmetric() -> void:
	assert_almost_eq(TiltMath.steer(14.0, FS, DZ, 1.5, 1.0), 0.387939, STEER_TOL)
	assert_almost_eq(TiltMath.steer(-14.0, FS, DZ, 1.5, 1.0), -0.387939, STEER_TOL)


func test_steer_7a_sensitivity_2_gives_half() -> void:
	assert_almost_eq(TiltMath.steer(7.0, FS, DZ, 1.0, 2.0), 0.5, STEER_TOL)


func test_steer_7b_sensitivity_half_gives_half() -> void:
	assert_almost_eq(TiltMath.steer(25.75, FS, DZ, 1.0, 0.5), 0.5, STEER_TOL)


func test_steer_7c_dead_zone_scaled_by_fs_eff() -> void:
	assert_almost_eq(TiltMath.steer(3.6, 12.0, 1.8, 1.0, 2.0), 0.5, STEER_TOL)


func test_steer_7d_dead_zone_above_cap_is_capped() -> void:
	assert_almost_eq(TiltMath.steer(3.6, 12.0, 4.0, 1.0, 2.0), 0.5, STEER_TOL)


func test_steer_7e_fs_eff_capped_at_50() -> void:
	assert_almost_eq(TiltMath.steer(25.75, 45.0, DZ, 1.0, 0.5), 0.5, STEER_TOL)


func test_median_outlier_odd_count() -> void:
	assert_eq(TiltMath.median(PackedFloat64Array([7.0, 1.0, 3.0, 80.0, 5.0])), 5.0)


func test_median_even_count_is_mean_of_middle_two() -> void:
	assert_eq(TiltMath.median(PackedFloat64Array([1.0, 2.0, 3.0, 4.0, 5.0, 80.0])), 3.5)


func test_median_two_levels_gives_four() -> void:
	var s: PackedFloat64Array = PackedFloat64Array()
	for i: int in 9:
		s.append(2.0)
	for i: int in 9:
		s.append(6.0)
	assert_eq(TiltMath.median(s), 4.0)


func test_median_does_not_modify_input() -> void:
	var s: PackedFloat64Array = PackedFloat64Array([3.0, 1.0, 2.0])
	TiltMath.median(s)
	assert_eq(s, PackedFloat64Array([3.0, 1.0, 2.0]))
