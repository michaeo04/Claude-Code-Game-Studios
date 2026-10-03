## Wraps a log sink with a rate limit of one message per (code, key) per 1.0 s of an injected clock.
##
## Generic: Platform Services and Save & Persistence both use it. The window runs from the last message that
## passed for that (code, key). A message passes when none passed before, when the clock went backwards
## (the window is re-based on the new stamp), or when at least `RATE_LIMIT_US` elapsed. Different keys, and
## the same key under different codes, are limited independently. Dropped messages are not counted or queued.
##
## The sink is called as `log_sink(level: int, code: StringName, key: String, message: String)`; the level
## is passed through unchanged. Use method Callables, not lambdas capturing `self` (reference cycle).
class_name RateLimitedLog
extends RefCounted

## Log levels of Platform Services' codes.
enum Level { DEBUG, ERROR }

## The rate-limit window in microseconds. A fixed constant, not a tuning knob.
const RATE_LIMIT_US: int = 1_000_000

## Platform Services log codes (error level except `LIFECYCLE_NOOP`).
## Key per code: kind id, `<kind>.<field>`, setting key, event name respectively.
const UNKNOWN_HAPTIC_KIND: StringName = &"UNKNOWN_HAPTIC_KIND"
const KNOB_CLAMPED: StringName = &"KNOB_CLAMPED"
const SETTINGS_MISMATCH: StringName = &"SETTINGS_MISMATCH"
const LIFECYCLE_NOOP: StringName = &"LIFECYCLE_NOOP"

var _sink: Callable
var _clock_us: Callable
## `"<code>|<key>"` to the stamp (us) of the last message that passed.
var _last_passed_us: Dictionary = {}


## `log_sink` receives passed messages; `clock_us` returns the current time as integer microseconds.
func _init(log_sink: Callable, clock_us: Callable) -> void:
	_sink = log_sink
	_clock_us = clock_us


## Sends the message to the sink if its (code, key) is not rate limited. Returns true when it passed.
func emit(level: int, code: StringName, key: String, message: String) -> bool:
	var now: int = _clock_us.call()
	var slot: String = "%s|%s" % [code, key]
	if _last_passed_us.has(slot):
		var last: int = _last_passed_us[slot]
		if now >= last and now - last < RATE_LIMIT_US:
			return false
	_last_passed_us[slot] = now
	_sink.call(level, code, key, message)
	return true
