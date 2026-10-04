## Story OBS-003: effective footprint F1 and swept-rectangle overlap F2 (AC-1 to AC-5).
extends GutTest

const Fixture = preload("res://tests/support/obstacle_fixture.gd")

const TOL: float = 1e-4


func _half() -> float:
	return ObstacleMath.ball_half_angle(Fixture.R, Fixture.D)


func _picket_eff() -> PackedFloat64Array:
	return ObstacleMath.effective_footprint_array(Fixture.worked_hazard(601).pieces, _half(), Fixture.D)


func test_footprint_picket_effective_bounds() -> void:
	var eff: PackedFloat64Array = _picket_eff()

	assert_almost_eq(eff[0], -0.1679, TOL)
	assert_almost_eq(eff[1], 0.1679, TOL)
	assert_almost_eq(eff[2], 199.6, TOL)
	assert_almost_eq(eff[3], 200.7, TOL)


func test_footprint_wall_effective_span_under_two_pi() -> void:
	var wall: PackedFloat64Array = Fixture.worked_hazard(301).pieces
	var eff: PackedFloat64Array = ObstacleMath.effective_footprint_array(wall, _half(), Fixture.D)

	assert_almost_eq(wall[1] - wall[0], 5.4578, TOL)
	assert_almost_eq(eff[1] - eff[0], 5.6936, TOL)
	assert_true(eff[1] - eff[0] < TAU)


func test_footprint_width_codes_for_three_raw_spans() -> void:
	assert_eq(ObstacleMath.width_code(0.0, 6.0, _half()), &"")
	assert_eq(ObstacleMath.width_code(0.0, 6.05, _half()), ObstacleMath.FOOTPRINT_EFF_TOO_WIDE)
	assert_almost_eq(6.05 + 2.0 * _half(), 6.2858, TOL)
	assert_eq(ObstacleMath.width_code(0.0, TAU, _half()), ObstacleMath.FOOTPRINT_TOO_WIDE)


func test_footprint_single_piece_and_array_expansion_agree() -> void:
	var one: PackedFloat64Array = ObstacleMath.effective_footprint(-0.05, 0.05, 200.0, 200.3, _half(), Fixture.D)

	assert_eq(one, _picket_eff())


func test_swept_picket_hits_where_endpoint_only_misses() -> void:
	var eff: PackedFloat64Array = _picket_eff()

	assert_true(ObstacleMath.theta_hit(-0.2, 0.2, eff[0], eff[1]))
	assert_true(ObstacleMath.s_hit(199.0, 202.0, eff[2], eff[3]))
	assert_true(ObstacleMath.swept_hit(-0.2, 0.2, 199.0, 202.0, eff))
	# Endpoint-only mutation: neither endpoint is inside the box on either axis.
	var endpoint_only: bool = (
		(_inside(-0.2, eff[0], eff[1]) or _inside(0.2, eff[0], eff[1]))
		and (_inside(199.0, eff[2], eff[3]) or _inside(202.0, eff[2], eff[3]))
	)
	assert_false(endpoint_only, "the mutation reports no hit, so it fails this row")


func test_swept_clean_miss_on_s_axis() -> void:
	var eff: PackedFloat64Array = _picket_eff()

	assert_true(ObstacleMath.theta_hit(-0.2, 0.2, eff[0], eff[1]))
	assert_false(ObstacleMath.s_hit(150.0, 153.0, eff[2], eff[3]))
	assert_false(ObstacleMath.swept_hit(-0.2, 0.2, 150.0, 153.0, eff))


func test_swept_zero_width_step_is_point_in_box() -> void:
	var eff: PackedFloat64Array = _picket_eff()

	assert_true(ObstacleMath.swept_hit(0.1, 0.1, 200.0, 200.0, eff))
	assert_false(ObstacleMath.swept_hit(0.5, 0.5, 200.0, 200.0, eff))


func test_swept_seam_piece_hit_across_pi() -> void:
	var half: float = _half()
	var eff: PackedFloat64Array = ObstacleMath.effective_footprint(2.9, 3.6, 10.0, 11.0, half, Fixture.D)

	assert_true(ObstacleMath.swept_hit(3.05, -3.05, 9.5, 10.5, eff))


func test_swept_seam_piece_shifted_by_two_pi_classifies_identically() -> void:
	var half: float = _half()
	var eff: PackedFloat64Array = ObstacleMath.effective_footprint(2.9, 3.6, 10.0, 11.0, half, Fixture.D)
	var shifted: PackedFloat64Array = ObstacleMath.effective_footprint(2.9 - TAU, 3.6 - TAU, 10.0, 11.0, half, Fixture.D)

	assert_true(ObstacleMath.swept_hit(3.05, -3.05, 9.5, 10.5, shifted))
	assert_eq(
		ObstacleMath.swept_hit(1.0, 1.2, 9.5, 10.5, eff),
		ObstacleMath.swept_hit(1.0, 1.2, 9.5, 10.5, shifted)
	)
	assert_eq(
		ObstacleMath.swept_hit(-3.05, 3.05, 9.5, 10.5, eff),
		ObstacleMath.swept_hit(-3.05, 3.05, 9.5, 10.5, shifted)
	)


func test_swept_corner_cut_hits_with_true_closest_approach_054() -> void:
	var eff: PackedFloat64Array = _picket_eff()
	var theta_prev: float = -0.3
	var theta: float = 0.3
	var s_prev: float = 199.0
	var s: float = 199.7

	assert_true(ObstacleMath.swept_hit(theta_prev, theta, s_prev, s, eff))
	# True diagonal path: s(t) over the interval where theta(t) is inside theta_eff.
	var t_hi: float = (eff[1] - theta_prev) / (theta - theta_prev)
	var s_at_exit: float = s_prev + (s - s_prev) * t_hi
	var closest: float = eff[2] - s_at_exit
	assert_almost_eq(closest, 0.054, 1e-3)
	assert_true(closest > 0.0, "strictly outside the box")
	assert_true(closest <= s - s_prev)


func test_swept_joint_corner_hits() -> void:
	assert_true(ObstacleMath.swept_hit(-0.5, 0.5, 197.0, 204.5, _picket_eff()))


func _inside(value: float, lo: float, hi: float) -> bool:
	return value >= lo and value <= hi
