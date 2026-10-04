extends GutTest

const Fixture = preload("res://tests/support/near_miss_fixture.gd")


func _zones(tp: float, t: float, sp: float, s: float, ac: float = 1.0, sc: float = 1.0) -> int:
	var half: float = ObstacleMath.ball_half_angle(3.0, 0.8)
	var raw: PackedFloat64Array = Fixture.worked_raw(701)
	var eff: PackedFloat64Array = ObstacleMath.effective_footprint_array(raw, half, 0.8)
	var near: PackedFloat64Array = NearMissMath.near_footprint(raw, half, 0.8, ac * half, sc * 0.4)
	return NearMissMath.zones(tp, t, sp, s, eff, near, 0)


func test_angular_graze_is_candidate() -> void:
	var m: int = _zones(-0.5, -0.45, 100.5, 100.6)
	assert_eq(m & NearMissMath.HIT_BIT, 0)
	assert_ne(m & NearMissMath.NEAR_BIT, 0)
	assert_true(NearMissMath.is_candidate(m))


func test_along_track_graze_is_candidate() -> void:
	var m: int = _zones(0.0, 0.05, 99.3, 99.5)
	assert_eq(m & NearMissMath.HIT_BIT, 0)
	assert_ne(m & NearMissMath.NEAR_BIT, 0)
	assert_true(NearMissMath.is_candidate(m))


func test_single_margin_mutants_fail() -> void:
	assert_false(NearMissMath.is_candidate(_zones(-0.5, -0.45, 100.5, 100.6, 0.0, 1.0)))
	assert_false(NearMissMath.is_candidate(_zones(0.0, 0.05, 99.3, 99.5, 1.0, 0.0)))


func test_seam_wrapped_delta_graze() -> void:
	var half: float = ObstacleMath.ball_half_angle(3.0, 0.8)
	var raw: PackedFloat64Array = PackedFloat64Array([PI - 0.3, PI + 0.3, 100.0, 101.5])
	var eff: PackedFloat64Array = ObstacleMath.effective_footprint_array(raw, half, 0.8)
	var near: PackedFloat64Array = NearMissMath.near_footprint(raw, half, 0.8, half, 0.4)
	assert_true(NearMissMath.is_candidate(NearMissMath.zones(PI - 0.5, PI - 0.45, 100.5, 100.6, eff, near, 0)))
	assert_true(NearMissMath.is_candidate(NearMissMath.zones(-PI - 0.5, -PI - 0.45, 100.5, 100.6, eff, near, 0)))


func test_pose_table_containment_and_exclusion() -> void:
	var rows: Array[PackedFloat64Array] = [
		PackedFloat64Array([-0.1, 0.1, 100.4, 100.6]),
		PackedFloat64Array([-0.5, -0.45, 100.5, 100.6]),
		PackedFloat64Array([0.0, 0.05, 99.3, 99.5]),
		PackedFloat64Array([2.0, 2.1, 50.0, 50.1]),
	]
	var expect_candidate: Array[bool] = [false, true, true, false]
	for n: int in range(rows.size()):
		var r: PackedFloat64Array = rows[n]
		var m: int = _zones(r[0], r[1], r[2], r[3])
		if (m & NearMissMath.HIT_BIT) != 0:
			assert_ne(m & NearMissMath.NEAR_BIT, 0, "row %d hit implies near" % n)
			assert_false(NearMissMath.is_candidate(m))
		assert_eq(NearMissMath.is_candidate(m), expect_candidate[n], "row %d" % n)
