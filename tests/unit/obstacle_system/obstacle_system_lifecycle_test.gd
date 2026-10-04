## Story OBS-007: ObstacleCore hazard bind and window lifecycle (AC-14, AC-19, AC-20, AC-21).
extends GutTest

const Fixture = preload("res://tests/support/obstacle_fixture.gd")
const Recorder = preload("res://tests/support/obstacle_recorder.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")

var _provider: Fixture.FakeProvider
var _core: ObstacleCore
var _rec: RefCounted
var _log: RefCounted


func before_each() -> void:
	_provider = Fixture.make_content_provider({})
	_log = LogSink.new()
	_core = Fixture.make_core(Fixture.make_config(), _provider, Callable(_log, "sink"))
	_rec = Recorder.new()
	_rec.call("attach", _core)


func _spike() -> HazardSpec:
	return HazardSpec.new(HazardPlacement.HazardType.SPIKE, 0, PackedFloat64Array([-0.05, 0.05, 5.0, 5.3]), PackedFloat64Array())


func _ball(s_prev: float, s: float) -> RefCounted:
	return Fixture.make_ball_state_stub(0.0, 0.0, s_prev, s)


func _hit_ids() -> Array[int]:
	return _rec.call("hit_ids") as Array[int]


func test_duplicate_query_rejected_once_and_first_binding_untouched() -> void:
	_provider.table[7] = [_spike()]
	_core.on_segment_entered_window(7)
	_core.on_segment_entered_window(7)
	assert_eq(_provider.calls, 1)
	assert_eq(_log.call("count"), 1)
	assert_eq(_log.call("code_at", 0), ObstacleCore.DUPLICATE_SEGMENT_QUERY)
	assert_eq(_log.call("level_at", 0), LogLevel.ERROR)
	assert_eq(_core.bound_count(), 1)
	assert_true(_core.is_bound(0))
	_provider.table[8] = [_spike()]
	_core.on_segment_entered_window(8)
	assert_eq(_core.bound_count(), 2)
	assert_eq(_log.call("count"), 1)


func test_enter_queries_once_and_assigns_sequential_ids() -> void:
	_provider.table[4] = [_spike(), _spike()]
	_core.on_segment_entered_window(4)
	assert_eq(_provider.queried, [4] as Array[int])
	assert_eq((_rec.get("bound") as Array).size(), 2)
	assert_eq(((_rec.get("bound") as Array)[0] as Array)[0], 0)
	assert_eq(((_rec.get("bound") as Array)[1] as Array)[0], 1)


func test_footprint_is_translated_by_segment_offset() -> void:
	_provider.table[4] = [_spike()]
	_core.on_segment_entered_window(4)
	var fp: PackedFloat64Array = _core.footprint_of(0)
	assert_eq(fp, PackedFloat64Array([-0.05, 0.05, 53.0, 53.3]))
	assert_almost_eq(_core.s_offset_of(0), 48.0, 1e-9)
	var spec: HazardSpec = _spike()
	assert_eq(spec.pieces, PackedFloat64Array([-0.05, 0.05, 5.0, 5.3]), "the shared spec is untouched")


func test_nonzero_local_segment_index_offsets_relative_to_home() -> void:
	var spec: HazardSpec = HazardSpec.new(
		HazardPlacement.HazardType.SPIKE, 2, PackedFloat64Array([-0.05, 0.05, 25.0, 25.3]), PackedFloat64Array()
	)
	_provider.table[5] = [spec]
	_core.on_segment_entered_window(5)
	assert_almost_eq(_core.s_offset_of(0), 36.0, 1e-9)
	assert_almost_eq(_core.footprint_of(0)[2], 61.0, 1e-9)


func test_zero_hazards_for_a_segment_is_valid() -> void:
	_core.on_segment_entered_window(3)
	assert_eq(_core.bound_count(), 0)
	assert_eq(_log.call("count"), 0)


func test_left_window_releases_and_stops_hits_at_same_coordinates() -> void:
	_provider.table[4] = [_spike()]
	_core.on_segment_entered_window(4)
	_core.step(_ball(52.9, 53.1))
	assert_eq(_hit_ids(), [0] as Array[int])
	_core.on_segment_left_window(4)
	_rec.call("clear")
	_core.step(_ball(52.9, 53.1))
	assert_eq(_hit_ids().size(), 0)
	assert_eq(_provider.calls, 1)


func test_primed_releases_everything_first_then_populates_in_increasing_order() -> void:
	for i: int in range(10, 19):
		_provider.table[i] = [_spike()]
	for i: int in range(-2, 7):
		_provider.table[i] = [_spike()]
	for i: int in range(10, 19):
		_core.on_segment_entered_window(i)
	_provider.queried.clear()
	_rec.call("clear")
	_core.on_window_primed(-2, 6)
	assert_eq(_provider.queried, [-2, -1, 0, 1, 2, 3, 4, 5, 6] as Array[int])
	var order: Array = _rec.get("order") as Array
	assert_eq(order.size(), 18)
	for n: int in range(9):
		assert_eq((order[n] as Array)[0], "released")
	for n: int in range(9, 18):
		assert_eq((order[n] as Array)[0], "bound")
	assert_eq(_core.bound_count(), 9)


func test_primed_overlapping_range_still_releases_and_requeries() -> void:
	for i: int in range(10, 13):
		_provider.table[i] = [_spike()]
	for i: int in range(10, 13):
		_core.on_segment_entered_window(i)
	_provider.queried.clear()
	_core.on_window_primed(11, 13)
	assert_eq(_provider.queried, [11, 12, 13] as Array[int])
	assert_eq((_rec.get("released") as Array).size(), 3)
	_core.on_segment_entered_window(11) # priming reset the query record only for the primed range
	assert_eq(_log.call("count"), 1)


func test_primed_old_positions_no_longer_hit() -> void:
	_provider.table[4] = [_spike()]
	_core.on_segment_entered_window(4)
	_core.on_window_primed(0, 2)
	_core.step(_ball(52.9, 53.1))
	assert_eq(_hit_ids().size(), 0)


func test_two_begin_runs_query_same_order_and_ids_restart() -> void:
	for i: int in range(-2, 7):
		_provider.table[i] = [_spike()]
	_core.on_window_primed(-2, 6)
	var first: Array[int] = _provider.queried.duplicate()
	var last_id_first: int = (((_rec.get("bound") as Array).back()) as Array)[0] as int
	_provider.queried.clear()
	_rec.call("clear")
	_core.on_window_primed(-2, 6)
	assert_eq(_provider.queried, first)
	assert_eq(last_id_first, 8)
	assert_eq(((_rec.get("bound") as Array)[0] as Array)[0], 0)
	assert_eq((((_rec.get("bound") as Array).back()) as Array)[0], 8)
