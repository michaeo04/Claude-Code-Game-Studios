extends GutTest

const Fixture = preload("res://tests/support/near_miss_fixture.gd")

const W: float = 0.2358


func _eff(raw: PackedFloat64Array) -> PackedFloat64Array:
	return ObstacleMath.effective_footprint_array(raw, ObstacleMath.ball_half_angle(3.0, 0.8), 0.8)


func _near(raw: PackedFloat64Array, ac: float, sc: float) -> PackedFloat64Array:
	var half: float = ObstacleMath.ball_half_angle(3.0, 0.8)
	return NearMissMath.near_footprint(raw, half, 0.8, ac * half, sc * 0.4)


func test_graze_near_bounds_and_widths() -> void:
	var raw: PackedFloat64Array = Fixture.worked_raw(701)
	var near: PackedFloat64Array = _near(raw, 1.0, 1.0)
	var eff: PackedFloat64Array = _eff(raw)
	assert_almost_eq(near[0], -0.5358, 1e-4)
	assert_almost_eq(near[1], 0.5358, 1e-4)
	assert_almost_eq(near[2], 99.2, 1e-4)
	assert_almost_eq(near[3], 102.3, 1e-4)
	assert_almost_eq((near[1] - near[0]) - (eff[1] - eff[0]), W, 1e-4)
	assert_almost_eq((near[3] - near[2]) - (eff[3] - eff[2]), 0.8, 1e-6)


func _assert_strict(id: int, ac: float, sc: float) -> void:
	var raw: PackedFloat64Array = Fixture.worked_raw(id)
	var eff: PackedFloat64Array = _eff(raw)
	var near: PackedFloat64Array = _near(raw, ac, sc)
	assert_eq(near.size(), raw.size())
	for p: int in range(raw.size() / 4):
		var i: int = p * 4
		assert_lt(near[i], eff[i])
		assert_gt(near[i + 1], eff[i + 1])
		assert_lt(near[i + 2], eff[i + 2])
		assert_gt(near[i + 3], eff[i + 3])


func test_strict_containment_defaults() -> void:
	for id: int in [701, 101, 202]:
		_assert_strict(id, 1.0, 1.0)


func test_strict_containment_at_floor() -> void:
	for id: int in [701, 101, 202]:
		_assert_strict(id, 0.5, 0.5)
