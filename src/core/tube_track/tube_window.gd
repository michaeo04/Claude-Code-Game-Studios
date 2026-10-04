## Tube Track window state machine (design/gdd/tube-track.md, States and Transitions; ADR-0002, ADR-0003, ADR-0013).
##
## Engine-free `RefCounted`, not an autoload, no `_process`: `GameRoot` drives it. It owns the primed segment window
## `first_index .. last_index`, the run distance `s` and the idle offset `s_idle`, re-targets pool slots through the
## injected `slot_binder` and reports through signals. `advance` recycles slots synchronously; a re-entrancy guard
## rejects any mutating call made from a signal handler (immediate connections only: a deferred or awaiting handler
## runs outside the guard). A multi-recycle `advance` shows handlers an intermediate window.
##
## Binder contract: `slot_binder.call(slot_index: int, segment_index: int)` with `slot_index = posmod(segment_index, N)`.
## Log contract: `log_sink.call(level: int, code: StringName, key: String, message: String)`.
class_name TubeWindow
extends RefCounted

## Lifecycle of the window and the map (not the phase of play, which Run State owns).
enum State { UNINITIALIZED, IDLE, RUNNING, PAUSED, ENDED }

## The window was reset (load_map, to_idle, begin_run); consumers discard anything tied to the old window.
signal window_primed(first_index: int, last_index: int)
## The state changed; emitted after the effects of the transition are complete.
signal state_changed(new_state: int, old_state: int)
## A segment entered the window by a recycle (Story 006).
signal segment_entered_window(index: int)
## A segment left the window by a recycle (Story 006).
signal segment_left_window(index: int)

## Log code of an event rejected in the current state (error level).
const LOG_EVENT_REJECTED: StringName = &"TUBE_EVENT_REJECTED"
## Log code of a `load_map` that failed validation (error level, one line per failure record).
const LOG_LOAD_FAILED: StringName = &"TUBE_LOAD_FAILED"
## Log code of a non-finite `s` passed to `advance` (error level).
const LOG_NON_FINITE: StringName = &"TUBE_NON_FINITE_INPUT"
## Log code of an `advance` whose `s` is below the previous one (debug level: the log has no warning level).
const LOG_S_DECREASED: StringName = &"TUBE_S_DECREASED"

var _config: TubeConfig = null
var _log_sink: Callable
var _slot_binder: Callable
var _state: State = State.UNINITIALIZED
var _s: float = 0.0
var _s_idle: float = 0.0
var _first_index: int = 0
var _last_index: int = -1
var _n: int = 0
var _in_emission: bool = false


## `log_sink` and `slot_binder` are injected; an unset Callable is skipped (never called).
func _init(log_sink: Callable, slot_binder: Callable) -> void:
	_log_sink = log_sink
	_slot_binder = slot_binder


## Validates `cfg` for `v_max` and the ball diameter `d` (`TubeConfig.validate`), then primes `-B .. A` at
## `s_idle = 0` and enters Idle. Accepted only from Uninitialized. Returns the failure records: empty on success; on a
## validation failure nothing is bound or emitted and the state stays Uninitialized (the loader may Retry); a call from
## any other state returns one `TUBE_EVENT_REJECTED` record and logs one error.
func load_map(cfg: TubeConfig, v_max: float, d: float) -> Array[Dictionary]:
	if _in_emission or _state != State.UNINITIALIZED:
		_reject("load_map")
		return [{"code": LOG_EVENT_REJECTED}] as Array[Dictionary]
	var failures: Array[Dictionary] = cfg.validate(v_max, d)
	if not failures.is_empty():
		for record: Dictionary in failures:
			_log(LOG_LOAD_FAILED, str(record.get("field", "")), "load_map failed: %s" % [record])
		return failures
	_config = cfg.duplicate() as TubeConfig
	_n = _config.segments_ahead + _config.segments_behind + 1
	_enter_idle()
	return failures


## Idle or Running, Paused, Ended to Uninitialized: releases the window (no binder call). Rejected in Uninitialized.
func unload_map() -> void:
	if _in_emission or _state == State.UNINITIALIZED:
		_reject("unload_map")
		return
	_first_index = 0
	_last_index = -1
	_s = 0.0
	_s_idle = 0.0
	_change_state(State.UNINITIALIZED)


## Idle, Running, Paused or Ended to Running: resets `s` to 0 and primes `-B .. A`. From Running it re-primes and
## emits `window_primed` only (no `state_changed`).
func begin_run() -> void:
	if _in_emission or _state == State.UNINITIALIZED:
		_reject("begin_run")
		return
	_s = 0.0
	_prime(-_config.segments_behind, _config.segments_ahead)
	_commit_state(State.RUNNING)


## Running only (one caller, once per frame): moves the run distance to `s` and recycles synchronously. `s` never
## decreases (`max(s, prev)`, one debug-level `TUBE_S_DECREASED`); an equal `s` is a silent no-op; a non-finite `s` is
## ignored with one error. Each crossed boundary `k + 1` emits `segment_left_window(k - B)` then
## `segment_entered_window(k + 1 + A)` and re-targets the recycled slot, in increasing index order (a boundary value
## `s = i * L` counts as entered). A jump of N or more segments re-primes (`window_primed` only, no `segment_*`).
## Handlers of a multi-recycle call see the intermediate window.
func advance(s: float) -> void:
	if _in_emission or _state != State.RUNNING:
		_reject("advance")
		return
	if not is_finite(s):
		_log(LOG_NON_FINITE, "advance", "advance ignored a non-finite s")
		return
	if s < _s:
		_log_level(LogLevel.DEBUG, LOG_S_DECREASED, "advance", "advance(%s) below s %s ignored" % [s, _s])
		return
	if s == _s:
		return
	_s = s
	var target: int = TubeMath.segment_index(s, _config.segment_length)
	var current: int = _last_index - _config.segments_ahead
	if target <= current:
		return
	if target - current >= _n:
		_prime(target - _config.segments_behind, target + _config.segments_ahead)
		return
	for k: int in range(current, target):
		var leaving: int = _first_index
		var entering: int = _last_index + 1
		_first_index += 1
		_last_index = entering
		if _slot_binder.is_valid():
			_slot_binder.call(posmod(entering, _n), entering)
		_emit_left(leaving)
		_emit_entered(entering)


## Running to Paused; `s` and the window are kept.
func pause() -> void:
	if _in_emission or _state != State.RUNNING:
		_reject("pause")
		return
	_change_state(State.PAUSED)


## Paused to Running; `s` is unchanged.
func resume() -> void:
	if _in_emission or _state != State.PAUSED:
		_reject("resume")
		return
	_change_state(State.RUNNING)


## Running to Ended (a hit); `s` and the window are kept.
func end_run() -> void:
	if _in_emission or _state != State.RUNNING:
		_reject("end_run")
		return
	_change_state(State.ENDED)


## Running, Paused or Ended to Idle: `s_idle = 0`, the run's `s` is discarded and `-B .. A` is primed.
func to_idle() -> void:
	if _in_emission or (_state != State.RUNNING and _state != State.PAUSED and _state != State.ENDED):
		_reject("to_idle")
		return
	_enter_idle()


## Idle only: scrolls the idle offset by `idle_scroll_speed * min(dt, t_lat)`, wrapped into `[0, L)`.
## Emits nothing and never moves the window.
func tick_idle(dt: float) -> void:
	if _state != State.IDLE:
		return
	_s_idle = TubeMath.idle_step(_s_idle, _config.idle_scroll_speed, dt, _config.t_lat, _config.segment_length)


## Current lifecycle state.
func get_state() -> State:
	return _state


## Run distance `s` (0 outside a run).
func get_s() -> float:
	return _s


## Idle scroll offset in `[0, L)`.
func get_s_idle() -> float:
	return _s_idle


## First segment index of the window (`-B` right after a prime).
func get_first_index() -> int:
	return _first_index


## Last segment index of the window (`A` right after a prime); -1 with `first_index` 0 when no map is loaded.
func get_last_index() -> int:
	return _last_index


## Far end of the window along the track, `(last_index + 1) * L`.
func get_far_end_s() -> float:
	if _config == null:
		return 0.0
	return float(_last_index + 1) * _config.segment_length


func _enter_idle() -> void:
	_s = 0.0
	_s_idle = 0.0
	_prime(-_config.segments_behind, _config.segments_ahead)
	_commit_state(State.IDLE)


## Sets the window, re-targets every slot through the binder, then emits `window_primed` (the state is still the old one).
func _prime(first: int, last: int) -> void:
	_first_index = first
	_last_index = last
	if _slot_binder.is_valid():
		for i: int in range(first, last + 1):
			_slot_binder.call(posmod(i, _n), i)
	_in_emission = true
	window_primed.emit(first, last)
	_in_emission = false


## Changes state after a prime and emits `state_changed` only if it changed.
func _commit_state(new_state: State) -> void:
	_change_state(new_state)


func _change_state(new_state: State) -> void:
	var old_state: State = _state
	if new_state == old_state:
		return
	_state = new_state
	_in_emission = true
	state_changed.emit(new_state, old_state)
	_in_emission = false


func _emit_left(index: int) -> void:
	_in_emission = true
	segment_left_window.emit(index)
	_in_emission = false


func _emit_entered(index: int) -> void:
	_in_emission = true
	segment_entered_window.emit(index)
	_in_emission = false


func _reject(event_name: String) -> void:
	_log(LOG_EVENT_REJECTED, event_name, "%s rejected in state %s" % [event_name, State.keys()[_state]])


func _log(code: StringName, key: String, message: String) -> void:
	_log_level(LogLevel.ERROR, code, key, message)


func _log_level(level: int, code: StringName, key: String, message: String) -> void:
	if _log_sink.is_valid():
		_log_sink.call(level, code, key, message)
