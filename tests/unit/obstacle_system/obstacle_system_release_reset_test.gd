## Story OBS-008: release flag (AC-40), run_reset handler (AC-41) and read accessors.
extends GutTest

const Fixture = preload("res://tests/support/obstacle_fixture.gd")
const Recorder = preload("res://tests/support/obstacle_recorder.gd")

var _provider: Fixture.FakeProvider
var _core: ObstacleCore
var _rec: RefCounted


func before_each() -> void:
	_provider = Fixture.make_content_provider({})
	_core = Fixture.make_core(Fixture.make_config(), _provider)
	_rec = Recorder.new()
	_rec.call("attach", _core)


func _spike(local_seg: int = 0) -> HazardSpec:
	return HazardSpec.new(
		HazardPlacement.HazardType.SPIKE, local_seg, PackedFloat64Array([-0.05, 0.05, 5.0, 5.3]), PackedFloat64Array()
	)


## Window 10..18 with hazards 0 and 1 on segment 10 and hazard 2 on segment 12.
func _bind_window() -> void:
	_provider.table[10] = [_spike(), _spike()]
	_provider.table[12] = [_spike()]
	_provider.table[-2] = [_spike()]
	for i: int in range(10, 19):
		_core.on_segment_entered_window(i)
	_rec.call("clear")


func _released() -> Array:
	return _rec.get("released") as Array


func test_primed_releases_each_hazard_once_with_true() -> void:
	_bind_window()
	_core.on_window_primed(-2, 6)
	assert_eq(_released(), [[0, true], [1, true], [2, true]])


func test_left_window_releases_only_that_segment_with_false() -> void:
	_bind_window()
	_core.on_segment_left_window(10)
	assert_eq(_released(), [[0, false], [1, false]])
	assert_true(_core.is_bound(2))


func test_overlapping_reprime_and_to_idle_prime_both_true() -> void:
	_bind_window()
	_core.on_window_primed(12, 14)
	for r: Array in _released():
		assert_true(r[1] as bool)
	assert_eq(_released().size(), 3)
	_rec.call("clear")
	_core.on_window_primed(-2, -1) # to-idle style prime of a small range
	assert_eq(_released().size(), 1)
	assert_true((_released()[0] as Array)[1] as bool)


func _ball_at(s_prev: float, s: float) -> RefCounted:
	return Fixture.make_ball_state_stub(0.0, 0.0, s_prev, s)


func _end_state() -> Array:
	_core.step(_ball_at(-18.1, -17.9)) # hazard at segment -2: s = 5 - 24 = -19 .. -18.7
	return [_core.bound_count(), _provider.queried.duplicate(), _rec.get("hits")]


func test_run_reset_and_primed_in_both_orders_give_same_state() -> void:
	_provider.table[-2] = [_spike()]
	_core.on_run_reset(2)
	_core.on_window_primed(-2, 6)
	_core.step(_ball_at(-19.1, -18.9))
	var a_hits: Array = (_rec.get("hits") as Array).duplicate()
	var a_count: int = _core.bound_count()
	var a_queried: Array[int] = _provider.queried.duplicate()

	var provider_b: Fixture.FakeProvider = Fixture.make_content_provider({-2: [_spike()]})
	var core_b: ObstacleCore = Fixture.make_core(Fixture.make_config(), provider_b)
	var rec_b: RefCounted = Recorder.new()
	rec_b.call("attach", core_b)
	core_b.on_window_primed(-2, 6)
	core_b.on_run_reset(2)
	core_b.step(_ball_at(-19.1, -18.9))

	assert_eq(a_hits, [[0, 2]])
	assert_eq(rec_b.get("hits"), a_hits)
	assert_eq(core_b.bound_count(), a_count)
	assert_eq(provider_b.queried, a_queried)
	assert_eq(a_queried, [-2, -1, 0, 1, 2, 3, 4, 5, 6] as Array[int])


func test_run_reset_alone_changes_nothing() -> void:
	_bind_window()
	_core.on_run_reset(2)
	assert_eq(_core.bound_count(), 3)
	assert_eq(_released().size(), 0)
	assert_eq(_core.get_run_id(), 2)
	_provider.table[20] = [_spike()]
	_core.on_segment_entered_window(20)
	assert_true(_core.is_bound(3), "the id counter was not touched")
	_core.on_run_reset(5)
	assert_eq(_core.get_run_id(), 5, "the latest run id is the one captured")


func test_accessors_inside_hazard_bound_handler_match_the_record() -> void:
	var spec: HazardSpec = _spike(1)
	_provider.table[4] = [spec]
	_core.on_segment_entered_window(4)
	var probe: Array = (_rec.get("probe_log") as Array)[0] as Array
	assert_eq(probe[0], PackedFloat64Array([-0.05, 0.05, 41.0, 41.3]))
	assert_eq(probe[1], HazardPlacement.HazardType.SPIKE)
	assert_same(probe[2], spec)
	assert_almost_eq(probe[3] as float, 36.0, 1e-9)
	assert_eq(((_rec.get("bound") as Array)[0] as Array)[1], probe[0])


func test_accessors_report_unbound_defaults_after_release() -> void:
	_provider.table[4] = [_spike()]
	_core.on_segment_entered_window(4)
	_core.on_segment_left_window(4)
	assert_eq(_core.footprint_of(0).size(), 0)
	assert_eq(_core.hazard_type_of(0), -1)
	assert_null(_core.spec_of(0))
