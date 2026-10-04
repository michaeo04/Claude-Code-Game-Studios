## Story OBS-004: safe-gap sweep-line F3 (AC-6, AC-10, AC-38) and HAZARD_OVERLAP (AC-11).
extends GutTest

const Fixture = preload("res://tests/support/obstacle_fixture.gd")

const R: float = 3.0
const D: float = 0.8
const MARGIN: float = 2.5
const TOL: float = 1e-4


## A hazard whose single piece occupies `[0, TAU - raw_gap]`, i.e. leaves a raw gap of `raw_gap`.
func _gap_hazard(id: int, raw_gap: float, s_start: float, s_end: float) -> PreflightHazard:
	return PreflightHazard.new(id, 0,PackedFloat64Array([0.0, TAU - raw_gap, s_start, s_end]))


func _one(hz: PreflightHazard) -> Array[PreflightHazard]:
	var arr: Array[PreflightHazard] = [hz]
	return arr


func _gaps(hazards: Array[PreflightHazard], r: float = R, d: float = D, margin: float = MARGIN) -> Array[PreflightRecord]:
	return ObstacleMath.validate_gaps(hazards, r, d, margin)


func test_gap_wall_boundary_rows_accept_and_reject() -> void:
	assert_eq(_gaps(_one(_gap_hazard(301, 0.8254, 200.0, 201.0))).size(), 0)
	assert_eq(_gaps(_one(_gap_hazard(301, 0.8255, 200.0, 201.0))).size(), 0)
	var recs: Array[PreflightRecord] = _gaps(_one(_gap_hazard(301, 0.8253, 200.0, 201.0)))
	assert_gt(recs.size(), 0)
	assert_eq(recs[0].code, ObstacleMath.NO_SAFE_GAP)


func test_gap_wall_open_equals_gap_min_within_tolerance() -> void:
	var half: float = ObstacleMath.ball_half_angle(R, D)
	var open: float = 0.8254 - 2.0 * half

	assert_almost_eq(open, ObstacleMath.gap_min(R, D, MARGIN), TOL)


func test_gap_near_ring_forty_degrees_rejected_fifty_accepted() -> void:
	assert_gt(_gaps(_one(_gap_hazard(401, deg_to_rad(40.0), 300.0, 301.2))).size(), 0)
	assert_eq(_gaps(_one(_gap_hazard(401, deg_to_rad(50.0), 300.0, 301.2))).size(), 0)


func test_gap_second_piece_consuming_0_001_rejected_with_structured_record() -> void:
	# Arrange: A leaves exactly GAP_MIN once B (zero width raw, effective width w) is added.
	var half: float = ObstacleMath.ball_half_angle(R, D)
	var a_raw_width: float = TAU - ObstacleMath.gap_min(R, D, MARGIN) - 2.0 * half - 2.0 * half
	var a: PreflightHazard = PreflightHazard.new(301, 16, PackedFloat64Array([0.0, a_raw_width, 200.0, 201.0]))
	var b_ok: PreflightHazard = PreflightHazard.new(302, 16, PackedFloat64Array([3.0, 3.0, 200.4, 200.6]))
	var b_bad: PreflightHazard = PreflightHazard.new(302, 16, PackedFloat64Array([3.0, 3.001, 200.4, 200.6]))

	var ok_hazards: Array[PreflightHazard] = [a, b_ok]
	var bad_hazards: Array[PreflightHazard] = [a, b_bad]
	var ok: Array[PreflightRecord] = _gaps(ok_hazards)
	var bad: Array[PreflightRecord] = _gaps(bad_hazards)

	assert_eq(ok.size(), 0)
	assert_gt(bad.size(), 0)
	assert_eq(bad[0].code, ObstacleMath.NO_SAFE_GAP)
	assert_almost_eq(bad[0].s0, 200.0, 1e-9)
	var active: Array[Vector2i] = [Vector2i(301, 0), Vector2i(302, 0)]
	assert_eq(bad[0].pieces.size(), 2)
	assert_true(bad[0].pieces.has(active[0]))
	assert_true(bad[0].pieces.has(active[1]))


func test_gap_wall_alone_at_s0_200_5_is_active_and_accepted() -> void:
	var wall: PreflightHazard = _gap_hazard(301, 0.8254, 200.0, 201.0)

	assert_eq(_gaps(_one(wall)).size(), 0)


func test_gap_joint_extreme_corner_derived_values() -> void:
	assert_almost_eq(ObstacleMath.ball_half_angle(2.5, 1.0), 0.1674, TOL)
	assert_almost_eq(ObstacleMath.ball_width(2.5, 1.0), 0.3349, TOL)
	assert_almost_eq(ObstacleMath.gap_min(2.5, 1.0, 3.5), 1.1722, TOL)


func test_gap_joint_extreme_corner_near_ring_boundary() -> void:
	assert_eq(_gaps(_one(_gap_hazard(401, 1.507, 300.0, 301.0)), 2.5, 1.0, 3.5).size(), 0)
	assert_gt(_gaps(_one(_gap_hazard(401, 1.497, 300.0, 301.0)), 2.5, 1.0, 3.5).size(), 0)


func test_gap_defaults_would_not_pass_the_corner_gap() -> void:
	# Mutation guard: a gap valid at the default constants (0.8254) must fail at the corner.
	assert_gt(_gaps(_one(_gap_hazard(401, 0.8254, 300.0, 301.0)), 2.5, 1.0, 3.5).size(), 0)


func test_gap_records_are_deterministic_and_sorted_by_s0() -> void:
	var a: Array[PreflightHazard] = [_gap_hazard(2, 0.3, 50.0, 51.0), _gap_hazard(1, 0.3, 10.0, 11.0)]
	var b: Array[PreflightHazard] = [_gap_hazard(1, 0.3, 10.0, 11.0), _gap_hazard(2, 0.3, 50.0, 51.0)]

	var ra: Array[PreflightRecord] = _gaps(a)
	var rb: Array[PreflightRecord] = _gaps(b)

	assert_eq(ra.size(), rb.size())
	for i: int in range(ra.size()):
		assert_eq(ra[i].s0, rb[i].s0)
		assert_eq(ra[i].pieces, rb[i].pieces)
		if i > 0:
			assert_gt(ra[i].s0, ra[i - 1].s0)


func test_overlap_501_502_rejected_once() -> void:
	var hz: Array[PreflightHazard] = [
		PreflightHazard.new(501, 33, Fixture.worked_hazard(501).pieces),
		PreflightHazard.new(502, 33, Fixture.worked_hazard(502).pieces),
	]

	var recs: Array[PreflightRecord] = ObstacleMath.validate_overlaps(hz, R, D)

	assert_eq(recs.size(), 1)
	assert_eq(recs[0].code, ObstacleMath.HAZARD_OVERLAP)
	assert_eq(recs[0].pieces, [Vector2i(501, 0), Vector2i(502, 0)] as Array[Vector2i])


func test_overlap_502_moved_half_ball_width_further_accepted() -> void:
	var hz: Array[PreflightHazard] = [
		PreflightHazard.new(501, 33, Fixture.worked_hazard(501).pieces),
		PreflightHazard.new(502, 33, PackedFloat64Array([-0.03, 0.07, 401.6, 402.6])),
	]

	assert_eq(ObstacleMath.validate_overlaps(hz, R, D).size(), 0)


func test_overlap_fires_across_adjacent_segment_boundary() -> void:
	# 501 ends in segment 33 (396..408), 502 starts in segment 34.
	var hz: Array[PreflightHazard] = [
		PreflightHazard.new(501, 33, PackedFloat64Array([-0.05, 0.05, 407.0, 407.9])),
		PreflightHazard.new(502, 34, PackedFloat64Array([-0.03, 0.07, 408.1, 409.0])),
	]

	var recs: Array[PreflightRecord] = ObstacleMath.validate_overlaps(hz, R, D)

	assert_eq(recs.size(), 1)
	assert_eq(recs[0].code, ObstacleMath.HAZARD_OVERLAP)


func test_overlap_far_apart_in_theta_not_flagged() -> void:
	var hz: Array[PreflightHazard] = [
		PreflightHazard.new(1, 0, PackedFloat64Array([-0.05, 0.05, 20.0, 21.0])),
		PreflightHazard.new(2, 0, PackedFloat64Array([3.0, 3.1, 20.0, 21.0])),
	]

	assert_eq(ObstacleMath.validate_overlaps(hz, R, D).size(), 0)
