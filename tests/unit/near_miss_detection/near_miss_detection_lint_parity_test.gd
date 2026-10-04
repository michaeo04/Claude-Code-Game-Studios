extends GutTest

const Fixture = preload("res://tests/support/near_miss_fixture.gd")
const PoseTable = preload("res://tests/support/near_miss_pose_table.gd")


func test_ac22_hit_zone_parity_with_obstacle_math_on_every_pose() -> void:
	var half: float = ObstacleMath.ball_half_angle(Fixture.R, Fixture.D)
	var raw: PackedFloat64Array = Fixture.worked_raw(701)
	var eff: PackedFloat64Array = ObstacleMath.effective_footprint_array(raw, half, Fixture.D)
	var near: PackedFloat64Array = NearMissMath.near_footprint(raw, half, Fixture.D, half, 0.4)
	var rows: Array[PackedFloat64Array] = PoseTable.rows()
	var hits: int = 0
	for n: int in range(rows.size()):
		var r: PackedFloat64Array = rows[n]
		var expected: bool = ObstacleMath.swept_hit(r[0], r[1], r[2], r[3], eff, 0)
		var mask: int = NearMissMath.zones(r[0], r[1], r[2], r[3], eff, near, 0)
		assert_eq((mask & NearMissMath.HIT_BIT) != 0, expected, "row %d hit parity" % n)
		hits += 1 if expected else 0
	assert_gt(hits, 0, "the table contains hits")
	assert_lt(hits, rows.size(), "the table contains non-hits")


func test_ac22_core_never_emits_for_a_pose_obstacle_math_calls_a_hit() -> void:
	var half: float = ObstacleMath.ball_half_angle(Fixture.R, Fixture.D)
	var eff: PackedFloat64Array = ObstacleMath.effective_footprint_array(Fixture.worked_raw(701), half, Fixture.D)
	var rows: Array[PackedFloat64Array] = PoseTable.rows()
	for n: int in range(rows.size()):
		var r: PackedFloat64Array = rows[n]
		if not ObstacleMath.swept_hit(r[0], r[1], r[2], r[3], eff, 0):
			continue
		var core: NearMissCore = Fixture.make_core(NearMissConfig.new())
		var emitted: Array = []
		core.near_miss_detected.connect(func(hazard_id: int, _run_id: int) -> void: emitted.append(hazard_id))
		Fixture.make_hazard_bound_stub(core, 701)
		core.step(Fixture.make_ball_state_stub(r[0], r[1], r[2], r[3]))
		core.step(Fixture.make_ball_state_stub(2.5, 2.5, 50.0, 50.0))
		assert_eq(emitted.size(), 0, "row %d is a hit pose: no near miss" % n)
