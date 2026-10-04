extends GutTest

const Fixture = preload("res://tests/support/near_miss_fixture.gd")

var _core: NearMissCore
var _events: Array = []


func before_each() -> void:
	_core = Fixture.make_core(NearMissConfig.new())
	_core.on_run_reset(3)
	_events = []
	_core.near_miss_detected.connect(func(hazard_id: int, run_id: int) -> void: _events.append([hazard_id, run_id]))


func _tick(theta: float, s: float = 100.5) -> void:
	_core.step(Fixture.make_ball_state_stub(theta, theta, s, s))


func test_hit_after_near_zone_suppresses_exit_emit() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	_tick(-0.5)
	_core.on_hit_reported(701, 3)
	_tick(0.0)
	_tick(2.5)
	assert_eq(_events.size(), 0)
	assert_true(_core.hit_ever_true(701))


func test_hit_after_near_zone_suppresses_release_emit() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	_tick(-0.5)
	_core.on_hit_reported(701, 3)
	_tick(0.0)
	_core.on_hazard_released(701, false)
	_tick(2.5)
	assert_eq(_events.size(), 0)


func test_cluster_hit_from_another_piece_overrides_the_hazard() -> void:
	Fixture.make_hazard_bound_stub(_core, 101)
	_tick(-0.25, 50.5)
	assert_true(_core.was_in_near_zone(101))
	_core.on_hit_reported(101, 3)
	_tick(0.7, 50.5)
	_tick(2.5, 50.5)
	assert_eq(_events.size(), 0)


func test_hit_and_exit_on_the_same_tick_hit_delivered_first() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	_tick(-0.5)
	_core.on_hit_reported(701, 3)
	_tick(2.5)
	assert_eq(_events.size(), 0)


func test_hit_and_release_on_the_same_tick_in_both_delivery_orders() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	_core.on_hazard_bound(702, Fixture.worked_raw(701))
	_tick(-0.5)
	_core.on_hit_reported(701, 3)
	_core.on_hazard_released(701, false)
	_core.on_hazard_released(702, false)
	_core.on_hit_reported(702, 3)
	_tick(-0.5)
	assert_eq(_events.size(), 0)


func test_hit_for_unknown_id_is_ignored() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	_core.on_hit_reported(999, 3)
	_tick(-0.5)
	_tick(2.5)
	assert_false(_core.is_bound(999))
	assert_eq(_events.size(), 1)


func test_hit_never_leaks_to_other_hazards() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	_core.on_hazard_bound(5, Fixture.worked_raw(701))
	_tick(-0.5)
	_core.on_hit_reported(5, 3)
	_tick(2.5)
	assert_eq(_events, [[701, 3]])
