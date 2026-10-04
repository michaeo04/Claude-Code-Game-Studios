## Story TT-009: 300 s deterministic window simulation (AC-21, AC-22, AC-23).
extends GutTest

const Spy = preload("res://tests/support/tube_window_spy.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")

const L: float = 12.0
const A: int = 9
const REAR_EXTENT: float = 6.0
const MIN_FAR: float = 86.5
const FRAMES: int = 19200
const STEP: float = 25.0 / 64.0

var _min_far: float = INF
var _bad_pairing: int = 0
var _max_recycled_edge_excess: float = -INF
var _lefts: int = 0
var _enters: int = 0
var _bad_slots: int = 0
var _bad_posmod: int = 0
var _final_s: float = 0.0
var _spy: RefCounted
var _w: TubeWindow


func before_all() -> void:
	_spy = Spy.new()
	_w = TubeWindow.new(LogSink.new().sink, _spy.binder)
	_spy.attach(_w)
	_w.load_map(TubeConfig.new(), 25.0, 0.8)
	_w.begin_run()
	_spy.clear()
	var s: float = 0.0
	for f: int in range(FRAMES):
		s += STEP
		var before: int = _spy.segs.size()
		_w.advance(s)
		var added: int = _spy.segs.size() - before
		if added != 0 and added != 2:
			_bad_pairing += 1
		if added == 2:
			var left_idx: int = _spy.segs[before][1]
			var recycled_far: float = float(left_idx + 1) * L
			_max_recycled_edge_excess = maxf(_max_recycled_edge_excess, recycled_far - (s - REAR_EXTENT))
		_min_far = minf(_min_far, _w.get_far_end_s() - s)
	_final_s = s
	for e: Array in _spy.segs:
		if e[0] == "left":
			_lefts += 1
		else:
			_enters += 1
	for b: Array in _spy.binds:
		if b[0] < 0 or b[0] > 11:
			_bad_slots += 1
		if b[0] != posmod(b[1], 12):
			_bad_posmod += 1


func test_far_edge_bounds_hold_every_frame() -> void:
	assert_gte(_min_far, MIN_FAR)
	assert_gte(_min_far, float(A) * L)


func test_t_lat_step_keeps_bounds() -> void:
	var w: TubeWindow = TubeWindow.new(LogSink.new().sink, Spy.new().binder)
	w.load_map(TubeConfig.new(), 25.0, 0.8)
	w.begin_run()
	var s: float = 0.0
	for i: int in range(300):
		s += 2.5
		w.advance(s)
		var far: float = w.get_far_end_s() - s
		assert_gte(far, MIN_FAR)
		assert_gte(far, float(A) * L)


func test_each_crossing_emits_one_pair_in_same_call() -> void:
	assert_eq(_bad_pairing, 0)
	assert_eq(_final_s, 7500.0)
	assert_eq(_lefts, 625)
	assert_eq(_enters, 625)


func test_recycled_slot_is_out_of_view() -> void:
	assert_lte(_max_recycled_edge_excess, 0.0)


func test_binder_slot_indices_in_range_and_posmod() -> void:
	assert_eq(_bad_slots, 0)
	assert_eq(_bad_posmod, 0)
	assert_eq(_spy.binds.size(), 625)
