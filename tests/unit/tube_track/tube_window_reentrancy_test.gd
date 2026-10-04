## Story TT-007: re-entrancy guard, binder contract and idempotent begin_run (AC-20).
extends GutTest

const Spy = preload("res://tests/support/tube_window_spy.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")

const SIGNALS: Array[String] = ["primed", "state", "entered", "left"]
const ACTIONS: Array[String] = ["advance", "begin_run", "pause"]


func _make(spy: RefCounted, sink: RefCounted) -> TubeWindow:
	var w: TubeWindow = TubeWindow.new(sink.sink, spy.binder)
	spy.attach(w)
	w.load_map(TubeConfig.new(), 25.0, 0.8)
	return w


## Runs the triggering operation of `signal_name`: begin_run for primed/state, advance(12.0) in Running otherwise.
func _trigger(w: TubeWindow, spy: RefCounted, signal_name: String, action: String) -> void:
	if signal_name == "primed" or signal_name == "state":
		if action != "":
			spy.probe[signal_name] = action
		w.begin_run()
	else:
		w.begin_run()
		if action != "":
			spy.probe[signal_name] = action
		w.advance(12.0)


func test_handler_calls_are_rejected_with_one_error_and_no_state_change() -> void:
	for signal_name: String in SIGNALS:
		for action: String in ACTIONS:
			var ref_spy: RefCounted = Spy.new()
			var ref: TubeWindow = _make(ref_spy, LogSink.new())
			_trigger(ref, ref_spy, signal_name, "")
			var spy: RefCounted = Spy.new()
			var sink: RefCounted = LogSink.new()
			var w: TubeWindow = _make(spy, sink)
			_trigger(w, spy, signal_name, action)
			var label: String = "%s/%s" % [signal_name, action]
			assert_eq(sink.count(), 1, "one error " + label)
			assert_eq(sink.entries[0][1], TubeWindow.LOG_EVENT_REJECTED, label)
			assert_eq(w.get_state(), ref.get_state(), "state " + label)
			assert_eq(w.get_s(), ref.get_s(), "s " + label)
			assert_eq(w.get_first_index(), ref.get_first_index(), "first " + label)
			assert_eq(w.get_last_index(), ref.get_last_index(), "last " + label)
			assert_eq(spy.events.size(), ref_spy.events.size(), "events " + label)
			assert_eq(spy.segs, ref_spy.segs, "segs " + label)


func test_handler_sees_consistent_window() -> void:
	var spy: RefCounted = Spy.new()
	var w: TubeWindow = _make(spy, LogSink.new())
	spy.clear()
	w.begin_run()
	for e: Array in spy.events:
		assert_eq(e[4], -2)
		assert_eq(e[5], 9)


func test_begin_run_twice_emits_two_primes_and_twelve_unique_slots() -> void:
	var spy: RefCounted = Spy.new()
	var w: TubeWindow = _make(spy, LogSink.new())
	spy.clear()
	w.begin_run()
	w.begin_run()
	var primes: int = 0
	for e: Array in spy.events:
		if e[0] == "primed":
			assert_eq(e[1], -2)
			assert_eq(e[2], 9)
			primes += 1
	assert_eq(primes, 2)
	assert_eq(w.get_s(), 0.0)
	var slots: Dictionary = {}
	for b: Array in spy.binds:
		slots[b[0]] = b[1]
	assert_eq(slots.size(), 12)


func test_binder_called_once_per_slot_with_posmod_segment() -> void:
	var spy: RefCounted = Spy.new()
	var w: TubeWindow = TubeWindow.new(LogSink.new().sink, spy.binder)
	w.load_map(TubeConfig.new(), 25.0, 0.8)
	spy.clear()
	w.begin_run()
	assert_eq(spy.binds.size(), 12)
	var seen: Dictionary = {}
	for i: int in range(12):
		var b: Array = spy.binds[i]
		assert_eq(b[1], -2 + i)
		assert_eq(b[0], posmod(b[1], 12))
		seen[b[0]] = true
	assert_eq(seen.size(), 12)
