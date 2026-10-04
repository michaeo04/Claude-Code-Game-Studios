extends GutTest

const Fixture = preload("res://tests/support/near_miss_fixture.gd")

var _half: float = ObstacleMath.ball_half_angle(Fixture.R, Fixture.D)


## Hazard with one piece whose EFFECTIVE theta span is `[eff_lo, eff_hi]`, raw s `[100, 101]`.
func _piece(hazard_id: int, eff_lo: float, eff_hi: float, s0: float = 100.0) -> PreflightHazard:
	return PreflightHazard.new(hazard_id, 0, PackedFloat64Array([eff_lo + _half, eff_hi - _half, s0, s0 + 1.0]))


func _run(hazards: Array[PreflightHazard], k: float = 1.0) -> Array[PreflightRecord]:
	var cfg: NearMissConfig = NearMissConfig.new()
	cfg.near_miss_angle_coeff = k
	return NearMissMath.validate_near_zone_overlap(hazards, Fixture.R, Fixture.D, cfg)


## Two single-ball-width pieces whose hit zones are separated by exactly `gap`.
func _two_with_gap(gap: float) -> Array[PreflightHazard]:
	var w: float = 2.0 * _half
	return [_piece(1, -_half, _half), _piece(2, _half + gap, _half + gap + w)]


func test_gap_min_default_row_is_accepted() -> void:
	var gap_min: float = ObstacleMath.gap_min(Fixture.R, Fixture.D, 2.5)
	assert_almost_eq(gap_min, 0.5896, 1e-4)
	assert_eq(_run(_two_with_gap(gap_min)).size(), 0)


func test_joint_corner_row_is_accepted() -> void:
	var gap_min: float = ObstacleMath.gap_min(Fixture.R, Fixture.D, 2.0)
	assert_eq(_run(_two_with_gap(gap_min), 1.5).size(), 0)


func test_illegal_row_is_rejected() -> void:
	var gap_min: float = ObstacleMath.gap_min(Fixture.R, Fixture.D, 2.0)
	var recs: Array[PreflightRecord] = _run(_two_with_gap(gap_min), 3.0)
	assert_eq(recs.size(), 1)
	assert_eq(recs[0].code, NearMissMath.NEAR_ZONE_OVERLAP)
	assert_eq(recs[0].pieces, [Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])


func test_three_pieces_one_shared_s0_reports_only_the_close_pair() -> void:
	var hazards: Array[PreflightHazard] = [_piece(1, 0.0, 2.0), _piece(2, 2.01, 4.0), _piece(3, 4.30, 6.0)]
	var occupied: float = 2.0 + 1.99 + 1.7
	assert_gte(TAU - occupied, ObstacleMath.gap_min(Fixture.R, Fixture.D, 2.5))
	var recs: Array[PreflightRecord] = _run(hazards)
	assert_eq(recs.size(), 1)
	assert_eq(recs[0].code, NearMissMath.NEAR_ZONE_OVERLAP)
	assert_almost_eq(recs[0].s0, 100.0 - Fixture.D / 2.0, 1e-9)
	assert_eq(recs[0].pieces, [Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])


func test_wraparound_pair_is_examined_and_flagged_when_close() -> void:
	# C ends at 6.2 and A starts at 0.0: wrap gap 0.0832 < 0.2358.
	var hazards: Array[PreflightHazard] = [_piece(1, 0.0, 2.0), _piece(2, 3.0, 4.0), _piece(3, 4.5, 6.2)]
	var recs: Array[PreflightRecord] = _run(hazards)
	assert_eq(recs.size(), 1)
	assert_eq(recs[0].pieces, [Vector2i(1, 0), Vector2i(3, 0)] as Array[Vector2i])


func test_far_apart_pieces_sharing_s0_are_clean() -> void:
	var hazards: Array[PreflightHazard] = [_piece(1, -_half, _half), _piece(2, PI - _half, PI + _half)]
	assert_eq(_run(hazards).size(), 0)


func test_co_presence_mutant_would_differ_from_close_pair() -> void:
	# The same two pieces made close do fire: the verdict follows the gap, not the shared s0.
	var hazards: Array[PreflightHazard] = [_piece(1, -_half, _half), _piece(2, _half + 0.01, 3.0 * _half + 0.01)]
	assert_eq(_run(hazards).size(), 1)


func test_close_pieces_without_a_shared_s0_are_out_of_scope() -> void:
	var hazards: Array[PreflightHazard] = [_piece(1, 0.0, 1.0, 100.0), _piece(2, 1.01, 2.0, 200.0)]
	assert_eq(_run(hazards).size(), 0)


func test_single_piece_and_empty_library_are_clean() -> void:
	assert_eq(_run([_piece(1, 0.0, 5.0)] as Array[PreflightHazard]).size(), 0)
	assert_eq(_run([] as Array[PreflightHazard]).size(), 0)


func test_non_finite_piece_is_skipped() -> void:
	var bad: PreflightHazard = PreflightHazard.new(9, 0, PackedFloat64Array([NAN, 0.0, 100.0, 101.0]))
	var hazards: Array[PreflightHazard] = [_piece(1, -_half, _half), bad]
	assert_eq(_run(hazards).size(), 0)
