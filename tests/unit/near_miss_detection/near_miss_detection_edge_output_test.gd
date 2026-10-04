extends GutTest

const Fixture = preload("res://tests/support/near_miss_fixture.gd")

# Graze 701 poses (stationary: theta_prev == theta, s_prev == s).
const NEAR_THETA: float = -0.5
const HIT_THETA: float = 0.0
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


func test_stationary_near_zone_emits_only_on_exit_tick() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	for i: int in range(5):
		_tick(NEAR_THETA)
		assert_eq(_events.size(), 0)
	assert_true(_core.was_in_near_zone(701))
	_tick(OUT_THETA)
	assert_eq(_events, [[701, 7]])
	assert_false(_core.was_in_near_zone(701))


func test_no_second_emit_after_exit() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	_tick(NEAR_THETA)
	_tick(OUT_THETA)
	_tick(OUT_THETA)
	assert_eq(_events.size(), 1)


func test_release_in_near_zone_emits_once_at_release() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	_tick(NEAR_THETA)
	_core.on_hazard_released(701, false)
	_tick(NEAR_THETA)
	assert_eq(_events, [[701, 7]])
	assert_false(_core.is_bound(701))
	_tick(OUT_THETA)
	assert_eq(_events.size(), 1)


func test_release_outside_near_zone_does_not_emit() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	_tick(OUT_THETA)
	_core.on_hazard_released(701, false)
	_tick(OUT_THETA)
	assert_eq(_events.size(), 0)


func test_cluster_pieces_on_different_ticks_give_one_transition_and_one_emit() -> void:
	Fixture.make_hazard_bound_stub(_core, 101)
	_tick(OUT_THETA, 50.5)
	assert_false(_core.was_in_near_zone(101))
	_tick(-0.25, 50.5)
	assert_true(_core.was_in_near_zone(101))
	_tick(0.175, 50.5)
	_tick(0.95, 50.5)
	assert_true(_core.was_in_near_zone(101))
	assert_eq(_events.size(), 0)
	_tick(OUT_THETA, 50.5)
	assert_eq(_events, [[101, 7]])


func test_payload_is_exactly_hazard_id_and_run_id() -> void:
	var args: Array = []
	for sig: Dictionary in NearMissCore.new(NearMissConfig.new(), 0.1, 0.8).get_signal_list():
		if (sig["name"] as String) == "near_miss_detected":
			args = sig["args"] as Array
	assert_eq(args.size(), 2)
	assert_eq((args[0] as Dictionary)["name"], "hazard_id")
	assert_eq((args[1] as Dictionary)["name"], "run_id")
	Fixture.make_hazard_bound_stub(_core, 701)
	_tick(NEAR_THETA)
	_tick(OUT_THETA)
	assert_eq((_events[0] as Array).size(), 2)
	assert_eq((_events[0] as Array)[0], 701)
	assert_eq((_events[0] as Array)[1], 7)


func test_run_id_follows_last_run_reset() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	_tick(NEAR_THETA)
	_core.on_run_reset(8)
	_tick(OUT_THETA)
	assert_eq(_events, [[701, 8]])
	assert_eq(_core.get_run_id(), 8)


func test_two_hazards_emit_in_ascending_id_order() -> void:
	Fixture.make_hazard_bound_stub(_core, 701)
	Fixture.make_hazard_bound_stub(_core, 101)
	_core.on_hazard_bound(5, PackedFloat64Array([-0.3, 0.3, 100.0, 101.5]))
	_tick(NEAR_THETA, 100.5)
	_tick(OUT_THETA, 100.5)
	assert_eq(_events, [[5, 7], [701, 7]])
