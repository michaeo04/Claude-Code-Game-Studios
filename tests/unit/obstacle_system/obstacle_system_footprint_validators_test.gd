## Story OBS-005: footprint, home-segment, grace-zone, piece-count and spacing validators
## (AC-7, AC-8, AC-9, AC-12, AC-31, AC-35).
extends GutTest

const Fixture = preload("res://tests/support/obstacle_fixture.gd")

const L: float = 12.0


func _hz(id: int, seg: int, pieces: Array) -> PreflightHazard:
	return PreflightHazard.new(id, seg, PackedFloat64Array(pieces))


func _list(items: Array[PreflightHazard]) -> Array[PreflightHazard]:
	return items


func _codes(recs: Array[PreflightRecord]) -> Array[StringName]:
	var out: Array[StringName] = []
	for rec: PreflightRecord in recs:
		out.append(rec.code)
	return out


func test_footprint_not_finite_one_code_per_field_and_value() -> void:
	var bad_values: Array[float] = [NAN, INF, -INF]
	for field: int in range(4):
		for bad: float in bad_values:
			var p: Array = [-0.1, 0.1, 20.0, 21.0]
			p[field] = bad

			var recs: Array[PreflightRecord] = ObstacleMath.validate_footprints(_list([_hz(7, 1, p)]))

			assert_eq(recs.size(), 1, "field %d value %s" % [field, bad])
			assert_eq(recs[0].code, ObstacleMath.FOOTPRINT_NOT_FINITE)
			assert_eq(recs[0].segment_index, 1)


func test_footprint_not_finite_segment_is_rejected_whole_by_record_segment() -> void:
	var good: PreflightHazard = _hz(1, 1, [-0.1, 0.1, 20.0, 21.0])
	var bad: PreflightHazard = _hz(2, 1, [NAN, 0.1, 22.0, 23.0])

	var recs: Array[PreflightRecord] = ObstacleMath.validate_footprints(_list([good, bad]))

	assert_eq(recs.size(), 1)
	assert_eq(recs[0].segment_index, 1)
	assert_eq(recs[0].pieces, [Vector2i(2, 0)] as Array[Vector2i])


func test_footprint_invalid_order_theta_and_s_each_one_code() -> void:
	var theta_rev: Array[PreflightRecord] = ObstacleMath.validate_footprints(_list([_hz(1, 8, [0.1, -0.1, 100.0, 101.0])]))
	var s_rev: Array[PreflightRecord] = ObstacleMath.validate_footprints(_list([_hz(1, 8, [-0.1, 0.1, 101.0, 100.0])]))

	assert_eq(_codes(theta_rev), [ObstacleMath.FOOTPRINT_INVALID_ORDER] as Array[StringName])
	assert_eq(_codes(s_rev), [ObstacleMath.FOOTPRINT_INVALID_ORDER] as Array[StringName])


func test_footprint_equal_bounds_pass() -> void:
	assert_eq(ObstacleMath.validate_footprints(_list([_hz(1, 8, [0.2, 0.2, 100.0, 100.0])])).size(), 0)


func test_home_segment_mismatch_for_16_not_for_clean_piece_in_15() -> void:
	var for16: Array[PreflightRecord] = ObstacleMath.validate_home_segments(_list([_hz(1, 16, [0.0, 0.1, 190.0, 193.0])]), L)
	var inside15: Array[PreflightRecord] = ObstacleMath.validate_home_segments(_list([_hz(1, 15, [0.0, 0.1, 190.0, 191.5])]), L)

	assert_eq(_codes(for16), [ObstacleMath.HOME_SEGMENT_MISMATCH] as Array[StringName])
	assert_eq(inside15.size(), 0)


func test_home_segment_straddling_piece_190_to_193_also_rejected_for_15() -> void:
	# GDD Edge Cases demand full containment; AC-9's "passes for 15" row contradicts it (see the story record).
	var recs: Array[PreflightRecord] = ObstacleMath.validate_home_segments(_list([_hz(1, 15, [0.0, 0.1, 190.0, 193.0])]), L)

	assert_eq(recs.size(), 1)


func test_home_segment_upper_bound_is_half_open() -> void:
	assert_eq(ObstacleMath.validate_home_segments(_list([_hz(1, 1, [0.0, 0.1, 12.0, 23.999])]), L).size(), 0)
	assert_eq(ObstacleMath.validate_home_segments(_list([_hz(1, 1, [0.0, 0.1, 12.0, 24.0])]), L).size(), 1)


func test_grace_zone_10_999_rejected_11_accepted() -> void:
	var grace: float = Fixture.make_config().grace_zone_length

	var bad: Array[PreflightRecord] = ObstacleMath.validate_grace_zone(_list([_hz(1, 0, [0.0, 0.1, 10.999, 11.5])]), grace)
	var ok: Array[PreflightRecord] = ObstacleMath.validate_grace_zone(_list([_hz(1, 0, [0.0, 0.1, 11.0, 11.5])]), grace)

	assert_eq(_codes(bad), [ObstacleMath.GRACE_ZONE_VIOLATION] as Array[StringName])
	assert_eq(ok.size(), 0)


func test_grace_zone_ignores_other_segments() -> void:
	assert_eq(ObstacleMath.validate_grace_zone(_list([_hz(1, 1, [0.0, 0.1, 12.5, 13.0])]), 11.0).size(), 0)


func _pieces(n: int) -> Array:
	var p: Array = []
	for i: int in range(n):
		p.append_array([0.0, 0.1, 20.0 + i * 0.01, 20.5])
	return p


func test_piece_count_twelve_accepted_thirteen_rejected() -> void:
	var cap: int = Fixture.make_config().max_pieces_per_segment

	assert_eq(ObstacleMath.validate_piece_counts(_list([_hz(1, 1, _pieces(12))]), cap).size(), 0)
	var recs: Array[PreflightRecord] = ObstacleMath.validate_piece_counts(_list([_hz(1, 1, _pieces(13))]), cap)
	assert_eq(_codes(recs), [ObstacleMath.TOO_MANY_PIECES] as Array[StringName])
	assert_eq(recs[0].count, 13)
	assert_eq(recs[0].segment_index, 1)


func test_piece_count_sums_across_hazards() -> void:
	var four: Array[PreflightHazard] = []
	for i: int in range(4):
		four.append(_hz(i, 1, _pieces(3)))
	var five: Array[PreflightHazard] = []
	five.append_array(four)
	five.append(_hz(9, 1, _pieces(3)))

	assert_eq(ObstacleMath.validate_piece_counts(four, 12).size(), 0)
	var recs: Array[PreflightRecord] = ObstacleMath.validate_piece_counts(five, 12)
	assert_eq(recs.size(), 1)
	assert_eq(recs[0].count, 15)


func test_piece_count_other_segments_do_not_add_up() -> void:
	var hz: Array[PreflightHazard] = [_hz(1, 1, _pieces(12)), _hz(2, 2, _pieces(12))]

	assert_eq(ObstacleMath.validate_piece_counts(hz, 12).size(), 0)


func test_spacing_default_is_6_25() -> void:
	assert_almost_eq(ObstacleMath.min_spacing(0.25, Fixture.V_MAX), 6.25, 1e-12)


func test_spacing_exact_boundary_accepted_and_short_rejected() -> void:
	var ok: Array[PreflightHazard] = [_hz(1, 4, [0.0, 0.1, 50.0, 50.3]), _hz(2, 4, [0.0, 0.1, 56.25, 56.5])]
	var bad: Array[PreflightHazard] = [_hz(1, 4, [0.0, 0.1, 50.0, 50.3]), _hz(2, 4, [0.0, 0.1, 56.24, 56.5])]

	assert_eq(ObstacleMath.validate_spacing(ok, 6.25).size(), 0)
	var recs: Array[PreflightRecord] = ObstacleMath.validate_spacing(bad, 6.25)
	assert_eq(_codes(recs), [ObstacleMath.TOO_DENSE] as Array[StringName])
	assert_eq(recs[0].pieces, [Vector2i(1, -1), Vector2i(2, -1)] as Array[Vector2i])


func test_spacing_non_adjacent_segments_still_fire() -> void:
	var hz: Array[PreflightHazard] = [_hz(1, 4, [0.0, 0.1, 47.9, 47.95]), _hz(2, 9, [0.0, 0.1, 100.0, 100.5]), _hz(3, 4, [0.0, 0.1, 50.0, 50.3])]

	var recs: Array[PreflightRecord] = ObstacleMath.validate_spacing(hz, 6.25)

	assert_eq(recs.size(), 1)
	assert_eq(recs[0].pieces, [Vector2i(1, -1), Vector2i(3, -1)] as Array[Vector2i])


func test_spacing_spike_cluster_is_one_read_at_earliest_start() -> void:
	var cluster: PreflightHazard = PreflightHazard.new(101, 4, Fixture.worked_hazard(101).pieces)
	var other: PreflightHazard = _hz(2, 4, [0.0, 0.1, 55.0, 55.3])

	var recs: Array[PreflightRecord] = ObstacleMath.validate_spacing(_list([cluster, other]), 6.25)

	assert_eq(recs.size(), 1)
	assert_eq(recs[0].pieces, [Vector2i(101, -1), Vector2i(2, -1)] as Array[Vector2i])


func test_spacing_reports_every_offending_pair() -> void:
	var hz: Array[PreflightHazard] = [_hz(1, 0, [0.0, 0.1, 20.0, 20.5]), _hz(2, 0, [0.0, 0.1, 22.0, 22.5]), _hz(3, 0, [0.0, 0.1, 24.0, 24.5])]

	assert_eq(ObstacleMath.validate_spacing(hz, 6.25).size(), 2)
