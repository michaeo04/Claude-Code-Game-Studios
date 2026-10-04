## Story BM-001: BallMath pure functions (AC-5 F1 step, AC-5b F5a T, AC-20 F2 speed and S).
## Oracles: tools/reference-sim/ball_movement.js.
extends GutTest

const TOL: float = 1e-6
const DT_60: float = 1.0 / 60.0
const TAU_DEFAULT: float = 0.06
const OMEGA_DEFAULT: float = 3.0
const V_START: float = 10.0
const V_MAX: float = 25.0
const T_RAMP: float = 90.0


# ---- wrap_angle ----

func test_wrap_angle_inside_range_is_identity() -> void:
	assert_almost_eq(BallMath.wrap_angle(0.5), 0.5, TOL)
	assert_almost_eq(BallMath.wrap_angle(-PI), -PI, TOL)


func test_wrap_angle_three_half_pi_wraps_to_minus_half_pi() -> void:
	assert_almost_eq(BallMath.wrap_angle(3.0 * PI / 2.0), -PI / 2.0, TOL)


func test_wrap_angle_just_below_pi_does_not_collapse_to_minus_pi() -> void:
	assert_almost_eq(BallMath.wrap_angle(PI - 1e-9), PI - 1e-9, 1e-12)


func test_wrap_angle_range_is_half_open() -> void:
	assert_almost_eq(BallMath.wrap_angle(PI), -PI, TOL)
	assert_almost_eq(BallMath.wrap_angle(-3.0 * TAU + 0.25), 0.25, TOL)


# ---- AC-5: F1 step ----

func test_f1_step_e_one_is_capped_to_0_05() -> void:
	assert_almost_eq(BallMath.step(1.0, DT_60, TAU_DEFAULT, OMEGA_DEFAULT), 0.05, TOL)


func test_f1_step_e_point_one_is_0_0242535() -> void:
	assert_almost_eq(BallMath.step(0.1, DT_60, TAU_DEFAULT, OMEGA_DEFAULT), 0.0242535, TOL)


func test_f1_step_negative_e_is_symmetric() -> void:
	assert_almost_eq(BallMath.step(-1.0, DT_60, TAU_DEFAULT, OMEGA_DEFAULT), -0.05, TOL)


func test_f1_step_tau_zero_small_error_lands_on_target() -> void:
	assert_almost_eq(BallMath.step(0.03, DT_60, 0.0, OMEGA_DEFAULT), 0.03, TOL)


func test_f1_step_tau_zero_large_error_is_rate_limited() -> void:
	assert_almost_eq(BallMath.step(0.1, DT_60, 0.0, OMEGA_DEFAULT), 0.05, TOL)


func test_f1_alpha_guard_tau_just_under_1e_4_is_one() -> void:
	assert_eq(BallMath.alpha(1e-5, 9.99e-5), 1.0)


func test_f1_alpha_guard_tau_at_1e_4_is_0_095163() -> void:
	assert_almost_eq(BallMath.alpha(1e-5, 1e-4), 0.095163, TOL)


func test_f1_alpha_default_60hz_is_0_242535() -> void:
	assert_almost_eq(BallMath.alpha(DT_60, TAU_DEFAULT), 0.242535, TOL)


func test_f1_snap_residual_9_9e_7_lands_exactly_on_target() -> void:
	var e: float = 0.05 + 9.9e-7
	assert_eq(BallMath.step(e, DT_60, 0.0, OMEGA_DEFAULT), e)


func test_f1_snap_residual_1_01e_6_does_not_snap() -> void:
	var e: float = 0.05 + 1.01e-6
	assert_almost_eq(BallMath.step(e, DT_60, 0.0, OMEGA_DEFAULT), 0.05, 1e-12)


# ---- AC-5b: F5a T(X, eps) ----

func test_t_pi_at_eps_0_05_is_t_dodge_180() -> void:
	assert_almost_eq(BallMath.T(PI, 0.05, OMEGA_DEFAULT, TAU_DEFAULT), 1.064054, TOL)


func test_t_half_pi_at_tenth_of_it_is_0_471771() -> void:
	assert_almost_eq(BallMath.T(PI / 2.0, 0.1 * PI / 2.0, OMEGA_DEFAULT, TAU_DEFAULT), 0.471771, TOL)


func test_t_eps_equal_k_both_branches_agree() -> void:
	var k: float = OMEGA_DEFAULT * TAU_DEFAULT
	assert_almost_eq(BallMath.T(PI, k, OMEGA_DEFAULT, TAU_DEFAULT), 0.987198, TOL)
	assert_almost_eq(BallMath.T(PI, k - 1e-9, OMEGA_DEFAULT, TAU_DEFAULT), 0.987198, TOL)
	assert_almost_eq(BallMath.T(PI, k + 1e-9, OMEGA_DEFAULT, TAU_DEFAULT), 0.987198, TOL)


func test_t_zero_x_is_zero() -> void:
	assert_eq(BallMath.T(0.0, 0.1, OMEGA_DEFAULT, TAU_DEFAULT), 0.0)


func test_t_x_equal_eps_is_zero_by_the_guard() -> void:
	assert_eq(BallMath.T(0.1, 0.1, OMEGA_DEFAULT, TAU_DEFAULT), 0.0)


func test_t_x_just_above_eps_is_0_008601() -> void:
	assert_almost_eq(BallMath.T(0.1 + 1e-6, 0.1, OMEGA_DEFAULT, TAU_DEFAULT), 0.008601, TOL)


func test_t_sweep_is_never_negative() -> void:
	for eps: float in [0.01, 0.05, 0.1, 0.5]:
		for i: int in 9:
			var x: float = PI / 8.0 * float(i)
			assert_gte(BallMath.T(x, eps, OMEGA_DEFAULT, TAU_DEFAULT), 0.0, "x=%s eps=%s" % [x, eps])


func test_t_unguarded_formula_is_negative_at_zero_x_so_the_guard_row_kills_the_mutation() -> void:
	var k: float = OMEGA_DEFAULT * TAU_DEFAULT
	var unguarded: float = (0.0 - k) / OMEGA_DEFAULT + TAU_DEFAULT * log(k / 0.1)
	assert_lt(unguarded, 0.0)
	assert_eq(BallMath.T(0.0, 0.1, OMEGA_DEFAULT, TAU_DEFAULT), 0.0)


# ---- AC-20: F2 speed and S ----

func test_s_oracle_rows() -> void:
	assert_almost_eq(BallMath.S(0.0, V_START, V_MAX, T_RAMP), 0.0, TOL)
	assert_almost_eq(BallMath.S(45.0, V_START, V_MAX, T_RAMP), 618.75, TOL)
	assert_almost_eq(BallMath.S(90.0, V_START, V_MAX, T_RAMP), 1575.0, TOL)
	assert_almost_eq(BallMath.S(120.0, V_START, V_MAX, T_RAMP), 2325.0, TOL)


func test_speed_oracle_rows() -> void:
	assert_almost_eq(BallMath.speed(0.0, V_START, V_MAX, T_RAMP), 10.0, TOL)
	assert_almost_eq(BallMath.speed(45.0, V_START, V_MAX, T_RAMP), 17.5, TOL)
	assert_almost_eq(BallMath.speed(90.0, V_START, V_MAX, T_RAMP), 25.0, TOL)
	assert_almost_eq(BallMath.speed(120.0, V_START, V_MAX, T_RAMP), 25.0, TOL)


func test_s_at_682_36_is_the_precision_limit_16384() -> void:
	# The GDD's own oracle tolerance is 1 u (the sim uses 1); 682.36 is rounded to 2 decimals.
	assert_almost_eq(BallMath.S(682.36, V_START, V_MAX, T_RAMP), 16384.0, 1.0)


func test_s_is_continuous_at_t_ramp() -> void:
	var below: float = BallMath.S(T_RAMP - 1e-9, V_START, V_MAX, T_RAMP)
	var above: float = BallMath.S(T_RAMP + 1e-9, V_START, V_MAX, T_RAMP)
	assert_almost_eq(below, above, 1e-6)


func test_speed_is_continuous_at_t_ramp() -> void:
	assert_almost_eq(
		BallMath.speed(T_RAMP - 1e-9, V_START, V_MAX, T_RAMP), BallMath.speed(T_RAMP + 1e-9, V_START, V_MAX, T_RAMP), 1e-6
	)


func test_sentinel_t_ramp_zero_gives_v_max_from_t_zero() -> void:
	assert_eq(BallMath.speed(0.0, V_START, V_MAX, 0.0), V_MAX)
	var s0: float = BallMath.S(0.0, V_START, V_MAX, 0.0)
	assert_false(is_nan(s0))
	assert_eq(s0, 0.0)
	assert_almost_eq(BallMath.S(10.0, V_START, V_MAX, 0.0), 250.0, TOL)


func test_sentinel_t_ramp_negative_gives_v_max_times_t() -> void:
	assert_eq(BallMath.speed(3.0, V_START, V_MAX, -5.0), V_MAX)
	assert_almost_eq(BallMath.S(10.0, V_START, V_MAX, -5.0), 250.0, TOL)


func test_speed_is_monotone_over_0_to_200_s() -> void:
	var previous: float = BallMath.speed(0.0, V_START, V_MAX, T_RAMP)
	for i: int in range(1, 2001):
		var current: float = BallMath.speed(float(i) * 0.1, V_START, V_MAX, T_RAMP)
		assert_gte(current, previous)
		previous = current


## Code review 2026-10-04 finding 6: the result must stay in [-PI, PI) at the edge of the range.
func test_wrap_angle_edge_values_stay_in_half_open_range() -> void:
	var below_minus_pi: float = -3.1415926535897936  # the double just below -PI
	for x: float in [below_minus_pi, -PI, PI, -PI + 1e-12, PI - 1e-12, 3.0 * PI, -3.0 * PI]:
		var r: float = BallMath.wrap_angle(x)
		assert_true(r >= -PI and r < PI, "wrap_angle(%s) = %s must lie in [-PI, PI)" % [x, r])

