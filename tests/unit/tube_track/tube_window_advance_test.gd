## Story TT-006: TubeWindow.advance and synchronous recycling (AC-8, AC-9, AC-10).
extends GutTest

const Spy = preload("res://tests/support/tube_window_spy.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")

var _spy: RefCounted
var _sink: RefCounted
var _window: TubeWindow


func before_each() -> void:
	_spy = Spy.new()
	_sink = LogSink.new()
	_window = TubeWindow.new(_sink.sink, _spy.binder)
	_spy.attach(_window)
	_window.load_map(TubeConfig.new(), 25.0, 0.8)


func _run() -> void:
	_window.begin_run()
	_spy.clear()
	_sink.entries.clear()



func test_begin_run_signals_in_order_and_window() -> void:
	_spy.clear()
	_window.begin_run()
	assert_eq(_spy.events.size(), 2)
	assert_eq(_spy.events[0].slice(0, 3), ["primed", -2, 9])
	assert_eq(_spy.events[1].slice(0, 3), ["state", TubeWindow.State.RUNNING, TubeWindow.State.IDLE])
	assert_eq(_spy.segs.size(), 0)


func test_advance_boundary_recycles_exactly_once() -> void:
	_run()
	_window.advance(11.999)
	assert_eq(_spy.segs.size(), 0)
	_window.advance(12.0)
	assert_eq(_spy.segs, [["left", -2], ["entered", 10]] as Array[Array])
	_window.advance(12.0)
	assert_eq(_spy.segs.size(), 2)
	assert_eq(_window.get_first_index(), -1)
	assert_eq(_window.get_last_index(), 10)


func test_advance_just_below_boundary_literal_does_not_recycle() -> void:
	_run()
	_window.advance(11.999999999999998)
	assert_eq(_spy.segs.size(), 0)


func test_advance_eleven_segments_emits_ordered_pairs() -> void:
	_run()
	_window.advance(132.0)
	var expected: Array[Array] = []
	for k: int in range(11):
		expected.append(["left", -2 + k])
		expected.append(["entered", 10 + k])
	assert_eq(_spy.segs, expected)
	assert_eq(_window.get_first_index(), 9)
	assert_eq(_window.get_last_index(), 20)
	assert_eq(_spy.binds.size(), 11)


func test_advance_n_segments_reprimes_without_segment_signals() -> void:
	_run()
	_window.advance(144.0)
	assert_eq(_spy.segs.size(), 0)
	assert_eq(_spy.events.size(), 1)
	assert_eq(_spy.events[0].slice(0, 3), ["primed", 10, 21])
	assert_eq(_spy.binds.size(), 12)


func test_advance_decrease_keeps_s_with_one_warning() -> void:
	_run()
	_window.advance(50.0)
	_sink.entries.clear()
	_window.advance(49.0)
	assert_eq(_window.get_s(), 50.0)
	assert_eq(_sink.count(), 1)
	assert_eq(_sink.entries[0][1], TubeWindow.LOG_S_DECREASED)


func test_advance_equal_is_silent_noop() -> void:
	_run()
	_window.advance(50.0)
	_spy.clear()
	_sink.entries.clear()
	_window.advance(50.0)
	assert_eq(_sink.count(), 0)
	assert_eq(_spy.segs.size(), 0)
	assert_eq(_spy.events.size(), 0)


func test_advance_non_finite_ignored_with_one_error_each() -> void:
	_run()
	_window.advance(50.0)
	_sink.entries.clear()
	_window.advance(NAN)
	assert_eq(_sink.count(), 1)
	_window.advance(INF)
	assert_eq(_sink.count(), 2)
	assert_eq(_window.get_s(), 50.0)
	assert_eq(_sink.entries[0][1], TubeWindow.LOG_NON_FINITE)


func test_begin_run_resets_s() -> void:
	_run()
	_window.advance(50.0)
	_window.begin_run()
	assert_eq(_window.get_s(), 0.0)
