## Story TI-004: TiltCore poll, clock stamps and ring buffer (AC-3 [C], AC-47c [C]).
extends GutTest

const TiltSink = preload("res://tests/support/platform_log_sink.gd")
const ClockStub = preload("res://tests/support/clock_stub.gd")
const TiltCoreClass = preload("res://src/core/tilt_input/tilt_core.gd")

var _g: Vector3 = Vector3(0, -9.8, 0)
var _clock: ClockStub
var _sink: TiltSink
var _fallback_value: int = 0


func before_each() -> void:
	_g = Vector3(0, -9.8, 0)
	_clock = ClockStub.new(0)
	_sink = TiltSink.new()


func _source() -> Vector3:
	return _g


func _fallback() -> int:
	return _fallback_value


func _core() -> TiltCore:
	return TiltCoreClass.new(TiltConfig.new(), _source, _clock.as_callable(), _sink.sink, _fallback)


func test_rejected_vectors_keep_acquiring_and_no_sample() -> void:
	var rows: Array[Vector3] = [
		Vector3.ZERO, Vector3(NAN, 0, 0), Vector3(INF, 0, 0), Vector3(0, -2.99, 0), Vector3(0, -1, 0),
		Vector3(0, NAN, 0), Vector3(1e200, 0, 0),
	]
	for row: Vector3 in rows:
		var core: TiltCore = _core()
		_g = row
		core.poll()
		assert_eq(core.get_sample_count(), 0, "count for %s" % row)
		assert_eq(core.get_state(), TiltCore.State.ACQUIRING, "state for %s" % row)


func test_vector_at_g_min_is_accepted_and_goes_live() -> void:
	var core: TiltCore = _core()
	_g = Vector3(0, -3, 0)
	core.poll()
	assert_eq(core.get_sample_count(), 1)
	assert_eq(core.get_state(), TiltCore.State.LIVE)
	assert_true(core.get_sensor_ever_live())


func test_each_invalid_seam_logs_one_error_and_core_is_unavailable() -> void:
	var good_clock: Callable = _clock.as_callable()
	var rows: Array[Array] = [
		[Callable(), good_clock, _sink.sink, _fallback],
		[_source, Callable(), _sink.sink, _fallback],
		[_source, good_clock, _sink.sink, Callable()],
	]
	for row: Array in rows:
		_sink = TiltSink.new()
		var args: Array = row.duplicate()
		args[2] = _sink.sink
		var core: TiltCore = TiltCoreClass.new(TiltConfig.new(), args[0], args[1], args[2], args[3])
		assert_eq(_sink.count(), 1, "one error")
		assert_eq(_sink.code_at(0), TiltCore.LOG_SEAM_INVALID)
		assert_eq(core.get_state(), TiltCore.State.UNAVAILABLE)
		core.poll()
		assert_eq(core.get_sample_count(), 0, "poll is a no-op")


func test_invalid_log_sink_leaves_core_unavailable_without_crash() -> void:
	var core: TiltCore = TiltCoreClass.new(TiltConfig.new(), _source, _clock.as_callable(), Callable(), _fallback)
	assert_eq(core.get_state(), TiltCore.State.UNAVAILABLE)
	core.poll()
	assert_eq(core.get_sample_count(), 0)


func test_first_poll_at_stamp_zero_is_accepted_with_dt_zero() -> void:
	var core: TiltCore = _core()
	core.poll()
	assert_eq(core.get_sample_count(), 1)
	assert_eq(core.get_last_dt(), 0.0)


func test_dt_is_stamp_difference_and_clamped_to_dt_max() -> void:
	var core: TiltCore = _core()
	core.poll()
	_clock.advance_us(16667)
	core.poll()
	assert_almost_eq(core.get_last_dt(), 0.016667, 1e-6)
	_clock.advance_us(500000)
	core.poll()
	assert_eq(core.get_last_dt(), 0.1)


func test_equal_or_backwards_stamp_appends_nothing_and_keeps_previous() -> void:
	var core: TiltCore = _core()
	_clock.now_us = 1000
	core.poll()
	core.poll()
	assert_eq(core.get_sample_count(), 1)
	assert_eq(core.get_last_dt(), 0.0)
	_clock.now_us = 500
	core.poll()
	assert_eq(core.get_sample_count(), 1)
	_clock.now_us = 21000
	core.poll()
	assert_almost_eq(core.get_last_dt(), 0.02, 1e-9)
	assert_eq(core.get_sample_count(), 2)


func test_invalid_poll_is_accepted_for_stamp_but_appends_no_sample() -> void:
	var core: TiltCore = _core()
	core.poll()
	_g = Vector3.ZERO
	_clock.advance_us(20000)
	core.poll()
	assert_eq(core.get_sample_count(), 1)
	assert_almost_eq(core.get_last_dt(), 0.02, 1e-9)
	_g = Vector3(0, -9.8, 0)
	_clock.advance_us(20000)
	core.poll()
	assert_almost_eq(core.get_last_dt(), 0.02, 1e-9)


func test_samples_older_than_buffer_age_are_dropped_at_append() -> void:
	var core: TiltCore = _core()
	core.poll()
	_clock.now_us = 1000000
	core.poll()
	assert_eq(core.get_sample_count(), 2, "exactly BUFFER_AGE old is kept")
	_clock.now_us = 1000001
	core.poll()
	assert_eq(core.get_sample_count(), 2, "the stamp-0 sample is dropped")
	_clock.now_us = 5000000
	core.poll()
	assert_eq(core.get_sample_count(), 1, "a long hitch drops all old samples by true time")


func test_ring_buffer_capacity_is_256() -> void:
	var core: TiltCore = _core()
	for i: int in 600:
		_clock.now_us = i + 1
		core.poll()
	assert_eq(core.get_sample_count(), 256)
