## Story TT-005: TubeWindow state machine, priming and load_map (AC-19, AC-20a, AC-20b).
extends GutTest

const Spy = preload("res://tests/support/tube_window_spy.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")
const WindowClass = preload("res://src/core/tube_track/tube_window.gd")

const V_MAX: float = 25.0
const BALL_D: float = 0.8
const S = TubeWindow.State
const EVENTS: Array[String] = ["load_map", "unload_map", "begin_run", "advance", "pause", "resume", "end_run", "to_idle"]

## Accepted pairs: [state, event] -> next state (the 16 pairs of the GDD table).
const ACCEPTED: Array[Array] = [
	[S.UNINITIALIZED, "load_map", S.IDLE],
	[S.IDLE, "begin_run", S.RUNNING], [S.IDLE, "unload_map", S.UNINITIALIZED],
	[S.RUNNING, "advance", S.RUNNING], [S.RUNNING, "pause", S.PAUSED], [S.RUNNING, "end_run", S.ENDED],
	[S.RUNNING, "begin_run", S.RUNNING], [S.RUNNING, "to_idle", S.IDLE], [S.RUNNING, "unload_map", S.UNINITIALIZED],
	[S.PAUSED, "resume", S.RUNNING], [S.PAUSED, "begin_run", S.RUNNING], [S.PAUSED, "to_idle", S.IDLE],
	[S.PAUSED, "unload_map", S.UNINITIALIZED],
	[S.ENDED, "begin_run", S.RUNNING], [S.ENDED, "to_idle", S.IDLE], [S.ENDED, "unload_map", S.UNINITIALIZED],
]

var _spy: RefCounted
var _sink: RefCounted
var _window: TubeWindow


func before_each() -> void:
	_spy = Spy.new()
	_sink = LogSink.new()
	_window = WindowClass.new(_sink.sink, _spy.binder)
	_spy.attach(_window)


func _load() -> void:
	_window.load_map(TubeConfig.new(), V_MAX, BALL_D)


## Drives a fresh window to `state` (running `advance` to s = 1234.5 first when asked) and clears the spy.
func _in_state(state: int, advance_to: float = 0.0) -> void:
	if state != S.UNINITIALIZED:
		_load()
	if state == S.RUNNING or state == S.PAUSED or state == S.ENDED:
		_window.begin_run()
		if advance_to > 0.0:
			_window.advance(advance_to)
	if state == S.PAUSED:
		_window.pause()
	elif state == S.ENDED:
		_window.end_run()
	_spy.clear()
	_sink.entries.clear()


func _fire(event: String) -> void:
	match event:
		"load_map": _load()
		"unload_map": _window.unload_map()
		"begin_run": _window.begin_run()
		"advance": _window.advance(5.0)
		"pause": _window.pause()
		"resume": _window.resume()
		"end_run": _window.end_run()
		"to_idle": _window.to_idle()


func _expected_next(state: int, event: String) -> int:
	for row: Array in ACCEPTED:
		if row[0] == state and row[1] == event:
			return row[2] as int
	return -1


func test_all_40_pairs_follow_the_table() -> void:
	var accepted_seen: int = 0
	for state: int in [S.UNINITIALIZED, S.IDLE, S.RUNNING, S.PAUSED, S.ENDED]:
		for event: String in EVENTS:
			_spy = Spy.new()
			_sink = LogSink.new()
			_window = WindowClass.new(_sink.sink, _spy.binder)
			_spy.attach(_window)
			_in_state(state)
			var first: int = _window.get_first_index()
			var last: int = _window.get_last_index()
			var expected: int = _expected_next(state, event)
			_fire(event)
			var label: String = "%s + %s" % [S.keys()[state], event]
			if expected == -1:
				assert_eq(_window.get_state(), state, "%s: state unchanged" % label)
				assert_eq(_spy.events.size(), 0, "%s: no signal" % label)
				assert_eq(_spy.binds.size(), 0, "%s: no binder call" % label)
				assert_eq(_sink.count(), 1, "%s: one error" % label)
				assert_eq(_window.get_first_index(), first, "%s: window unchanged" % label)
				assert_eq(_window.get_last_index(), last, "%s: window unchanged" % label)
			else:
				accepted_seen += 1
				assert_eq(_window.get_state(), expected, "%s: next state" % label)
				assert_eq(_sink.count(), 0, "%s: no error" % label)
				var state_events: int = 0
				for e: Array in _spy.events:
					if e[0] == "state":
						state_events += 1
				assert_eq(state_events, 0 if expected == state else 1, "%s: state_changed count" % label)
	assert_eq(accepted_seen, 16)


func test_state_changed_handler_sees_new_state_and_final_window() -> void:
	_in_state(S.RUNNING)
	_window.to_idle()
	var state_event: Array = _spy.events[1]
	assert_eq(state_event[0], "state")
	assert_eq(state_event[1], S.IDLE)
	assert_eq(state_event[2], S.RUNNING)
	assert_eq(state_event[3], S.IDLE, "handler sees the new state")
	assert_eq([state_event[4], state_event[5]], [-2, 9], "handler sees the final window")


func test_begin_run_from_running_emits_window_primed_only_with_old_state_seen() -> void:
	_in_state(S.RUNNING, 50.0)
	_window.begin_run()
	assert_eq(_spy.events.size(), 1)
	assert_eq(_spy.events[0][0], "primed")
	assert_eq(_window.get_s(), 0.0)


func test_window_primed_from_begin_run_sees_final_window_and_old_state() -> void:
	_in_state(S.IDLE)
	_window.begin_run()
	var primed: Array = _spy.events[0]
	assert_eq(primed[0], "primed")
	assert_eq(primed[3], S.IDLE, "old state")
	assert_eq([primed[4], primed[5]], [-2, 9], "final window")
	assert_eq(_spy.events[1][0], "state")


func test_load_map_valid_binds_12_slots_and_emits_primed_then_state() -> void:
	_load()
	assert_eq(_spy.binds.size(), 12)
	for k: int in 12:
		assert_eq(_spy.binds[k], [posmod(k - 2, 12), k - 2])
	assert_eq(_spy.events.size(), 2)
	assert_eq(_spy.events[0].slice(0, 3), ["primed", -2, 9])
	assert_eq(_spy.events[1].slice(0, 3), ["state", S.IDLE, S.UNINITIALIZED])
	assert_eq(_window.get_s_idle(), 0.0)


func test_load_map_with_nan_fog_binds_nothing_and_stays_uninitialized() -> void:
	var cfg: TubeConfig = TubeConfig.new()
	cfg.fog_end_distance = NAN
	var failures: Array[Dictionary] = _window.load_map(cfg, V_MAX, BALL_D)
	assert_eq(_spy.binds.size(), 0)
	assert_eq(_spy.events.size(), 0)
	assert_eq(_window.get_state(), S.UNINITIALIZED)
	assert_eq(failures.size(), 1)
	assert_eq(failures[0]["code"], TubeConfig.NOT_FINITE)


func test_to_idle_from_run_states_reprimes_at_zero() -> void:
	for state: int in [S.RUNNING, S.PAUSED, S.ENDED]:
		_spy = Spy.new()
		_sink = LogSink.new()
		_window = WindowClass.new(_sink.sink, _spy.binder)
		_spy.attach(_window)
		_in_state(state, 1234.5)
		assert_eq(_window.get_s(), 1234.5)
		_window.to_idle()
		assert_eq(_spy.binds.size(), 12, "binder calls from %s" % S.keys()[state])
		assert_eq(_spy.events[0].slice(0, 3), ["primed", -2, 9])
		assert_eq(_spy.events[1].slice(0, 3), ["state", S.IDLE, state])
		assert_eq(_window.get_s_idle(), 0.0)
		assert_eq(_window.get_s(), 0.0)
		assert_eq([_window.get_first_index(), _window.get_last_index()], [-2, 9])


func test_idle_scroll_for_60_seconds_emits_nothing_and_keeps_window() -> void:
	_in_state(S.IDLE)
	for i: int in 3840:
		_window.tick_idle(1.0 / 64.0)
	assert_eq(_spy.events.size(), 0)
	assert_eq(_spy.binds.size(), 0)
	assert_eq([_window.get_first_index(), _window.get_last_index()], [-2, 9])


func test_retry_after_invalid_config_is_accepted() -> void:
	var bad: TubeConfig = TubeConfig.new()
	bad.fog_end_distance = NAN
	_window.load_map(bad, V_MAX, BALL_D)
	_sink.entries.clear()
	_window.begin_run()
	assert_eq(_sink.count(), 1, "begin_run rejected with one error")
	assert_eq(_window.get_state(), S.UNINITIALIZED)
	_load()
	assert_eq(_spy.binds.size(), 12)
	assert_eq(_spy.events[0].slice(0, 3), ["primed", -2, 9])
	assert_eq(_spy.events[1].slice(0, 3), ["state", S.IDLE, S.UNINITIALIZED])


func test_load_map_from_every_non_uninitialized_state_is_rejected() -> void:
	for state: int in [S.IDLE, S.RUNNING, S.PAUSED, S.ENDED]:
		_spy = Spy.new()
		_sink = LogSink.new()
		_window = WindowClass.new(_sink.sink, _spy.binder)
		_spy.attach(_window)
		_in_state(state, 77.0)
		var s_before: float = _window.get_s()
		var window_before: Array[int] = [_window.get_first_index(), _window.get_last_index()]
		_load()
		assert_eq(_sink.count(), 1, "one error in %s" % S.keys()[state])
		assert_eq(_spy.events.size(), 0)
		assert_eq(_spy.binds.size(), 0)
		assert_eq(_window.get_state(), state)
		assert_eq(_window.get_s(), s_before)
		assert_eq([_window.get_first_index(), _window.get_last_index()], window_before)
