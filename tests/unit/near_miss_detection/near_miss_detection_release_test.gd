extends GutTest

const Fixture = preload("res://tests/support/near_miss_fixture.gd")

# Graze 701 and cluster 101 poses (stationary).
const NEAR_THETA: float = -0.5
const OUT_THETA: float = 2.5
const GRAZE_S: float = 100.5

var _core: NearMissCore
var _events: Array = []


func before_each() -> void:
	_core = Fixture.make_core(NearMissConfig.new())
	_core.on_run_reset(7)
	_events = []
	_core.near_miss_detected.connect(func(hazard_id: int, run_id: int) -> void: _events.append([hazard_id, run_id]))


func _tick(theta: float, s: float = GRAZE_S) -> void:
	_core.step(Fixture.make_ball_state_stub(theta, theta, s, s))


func test_ac28_reset_release_emits_nothing_and_discards() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	_tick(NEAR_THETA)
	assert_true(_core.was_in_near_zone(701))
	_core.on_hazard_released(701, true)
	_tick(NEAR_THETA)
	assert_eq(_events.size(), 0)
	assert_false(_core.is_bound(701))


func test_ac28_ordinary_release_emits_exactly_one() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	_tick(NEAR_THETA)
	_core.on_hazard_released(701, false)
	_tick(NEAR_THETA)
	_tick(OUT_THETA)
	assert_eq(_events, [[701, 7]])


func test_ac28_reset_then_ordinary_release_of_rebound_hazard() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	_tick(NEAR_THETA)
	_core.on_hazard_released(701, true)
	_tick(NEAR_THETA)
	assert_eq(_events.size(), 0)
	Fixture.make_hazard_bound_stub(_core, 701)
	_tick(NEAR_THETA)
	_core.on_hazard_released(701, false)
	_tick(NEAR_THETA)
	assert_eq(_events, [[701, 7]])


func test_ac28_hit_on_a_then_prime_release_of_b_by_reset_fires_nothing() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	Fixture.make_hazard_bound_stub(_core, 101)
	_core.step(Fixture.make_ball_state_stub(-0.25, -0.25, 50.5, 50.5))
	assert_true(_core.was_in_near_zone(101))
	_core.on_hit_reported(701, 7)
	_core.on_hazard_released(101, true)
	_core.on_hazard_released(701, true)
	_tick(OUT_THETA, 200.0)
	assert_eq(_events.size(), 0)
	assert_eq(_core.bound_count(), 0)


func test_ac18_bind_and_release_same_tick_emit_nothing() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	_core.on_hazard_released(701, false)
	_tick(NEAR_THETA)
	assert_eq(_events.size(), 0)
	assert_false(_core.is_bound(701))


func test_ac18_natural_exit_and_release_same_tick_emit_exactly_once() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	_tick(NEAR_THETA)
	_core.on_hazard_released(701, false)
	_tick(OUT_THETA)
	assert_eq(_events, [[701, 7]])
	_tick(OUT_THETA)
	assert_eq(_events.size(), 1)
	assert_false(_core.is_bound(701))
