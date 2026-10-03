## Tilt Input core (design/gdd/tilt-input.md rules 4, 6, 8, 12): poll, clock stamps and the sample ring buffer.
##
## Engine-free `RefCounted`: no `Input`, no `Time`, no node. The gravity vector comes from the injected
## `sample_source`, time from the injected microsecond `clock`. This story covers the poll path only;
## neutral capture, the filter, availability timeouts and the fallback arrive in later stories.
class_name TiltCore
extends RefCounted

enum State { ACQUIRING, LIVE, UNAVAILABLE }

## Log code of an invalid injected Callable at construction (error level).
const LOG_SEAM_INVALID: StringName = &"SEAM_INVALID"
## Ring buffer capacity (fixed constant, GDD rule 8).
const BUFFER_CAPACITY: int = 256
## Samples older than this (microseconds) are dropped at every append (`BUFFER_AGE` 1.0 s).
const BUFFER_AGE_US: int = 1000000
## Shared clamp of `dt` in microseconds (`DT_MAX` 0.1 s, Run State registry `dt_max`).
const DT_MAX_US: int = 100000

var _config: TiltConfig
var _sample_source: Callable
var _clock: Callable
var _log_sink: Callable
var _fallback_source: Callable

var _state: State = State.ACQUIRING
var _sensor_ever_live: bool = false
var _has_previous: bool = false
var _previous_now_us: int = 0
var _last_dt: float = 0.0
var _g_min_sq: float = 0.0

# Ring buffer: roll angles (degrees) and their poll stamps (us); `_head` is the next write slot.
var _angles: PackedFloat64Array = PackedFloat64Array()
var _stamps: PackedInt64Array = PackedInt64Array()
var _head: int = 0
var _count: int = 0


## Builds a core. `config` should already be validated. An invalid Callable (unset or freed) logs one
## `SEAM_INVALID` error per seam through `log_sink` (when that one is valid) and leaves the core Unavailable
## for good; `poll()` then does nothing.
func _init(config: TiltConfig, sample_source: Callable, clock: Callable, log_sink: Callable, fallback_source: Callable) -> void:
	_config = config
	_sample_source = sample_source
	_clock = clock
	_log_sink = log_sink
	_fallback_source = fallback_source
	_g_min_sq = config.g_min * config.g_min
	_angles.resize(BUFFER_CAPACITY)
	_stamps.resize(BUFFER_CAPACITY)
	var seams: Dictionary = {
		"sample_source": sample_source, "clock": clock, "log_sink": log_sink, "fallback_source": fallback_source,
	}
	var broken: bool = false
	for seam_name: String in seams:
		var seam: Callable = seams[seam_name]
		if not seam.is_valid():
			broken = true
			_log(LOG_SEAM_INVALID, "%s is not a valid Callable" % seam_name)
	if broken:
		_state = State.UNAVAILABLE


## Reads one sample and stamps it with the injected clock (once per rendered frame, GDD rule 6).
## `dt` is the clamped stamp difference to the last accepted poll; an equal or backwards stamp appends
## nothing and gives `dt` 0. A valid sample (finite, `|g| >= g_min`) is appended to the ring buffer.
func poll() -> void:
	if _is_broken():
		return
	var now_us: int = _clock.call() as int
	if _has_previous and now_us <= _previous_now_us:
		_last_dt = 0.0
		return
	var diff_us: int = 0
	if _has_previous:
		diff_us = clampi(now_us - _previous_now_us, 0, DT_MAX_US)
	_last_dt = float(diff_us) / 1e6
	_has_previous = true
	_previous_now_us = now_us

	var g: Vector3 = _sample_source.call() as Vector3
	if not g.is_finite() or g.length_squared() < _g_min_sq:
		return
	_append(TiltMath.roll_deg(g, _config.sensor_sign), now_us)
	_sensor_ever_live = true
	if _state != State.LIVE:
		_state = State.LIVE


## Current availability state.
func get_state() -> State:
	return _state


## Number of samples currently held in the ring buffer.
func get_sample_count() -> int:
	return _count


## Clamped `dt` in seconds of the last poll (0 for the first, an equal or a backwards stamp).
func get_last_dt() -> float:
	return _last_dt


## True once a valid sample was accepted.
func get_sensor_ever_live() -> bool:
	return _sensor_ever_live


func _is_broken() -> bool:
	return not (_sample_source.is_valid() and _clock.is_valid() and _log_sink.is_valid() and _fallback_source.is_valid())


func _append(angle_deg: float, now_us: int) -> void:
	# Drop samples older than BUFFER_AGE (true time), oldest first.
	while _count > 0:
		var tail: int = posmod(_head - _count, BUFFER_CAPACITY)
		if now_us - _stamps[tail] > BUFFER_AGE_US:
			_count -= 1
		else:
			break
	_angles[_head] = angle_deg
	_stamps[_head] = now_us
	_head = (_head + 1) % BUFFER_CAPACITY
	_count = mini(_count + 1, BUFFER_CAPACITY)


func _log(code: StringName, detail: String) -> void:
	if _log_sink.is_valid():
		_log_sink.call(RateLimitedLog.Level.ERROR, code, detail)
