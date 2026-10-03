## Story PS-002: RateLimitedLog (AC-6) and the Platform Services log codes.
extends GutTest

const ClockStub = preload("res://tests/support/clock_stub.gd")
const SinkStub = preload("res://tests/support/platform_log_sink.gd")

var _clock: ClockStub
var _sink: SinkStub
var _limiter: RateLimitedLog


func before_each() -> void:
	_clock = ClockStub.new(0)
	_sink = SinkStub.new()
	_limiter = RateLimitedLog.new(_sink.sink, _clock.as_callable())


func _send(code: StringName, key: String, at_us: int, level: int = RateLimitedLog.Level.ERROR) -> bool:
	_clock.now_us = at_us
	return _limiter.emit(level, code, key, "msg")


func test_codes_are_exact() -> void:
	assert_eq(RateLimitedLog.UNKNOWN_HAPTIC_KIND, &"UNKNOWN_HAPTIC_KIND")
	assert_eq(RateLimitedLog.KNOB_CLAMPED, &"KNOB_CLAMPED")
	assert_eq(RateLimitedLog.SETTINGS_MISMATCH, &"SETTINGS_MISMATCH")
	assert_eq(RateLimitedLog.LIFECYCLE_NOOP, &"LIFECYCLE_NOOP")
	assert_eq(RateLimitedLog.RATE_LIMIT_US, 1_000_000)


func test_first_message_passes_at_zero() -> void:
	assert_true(_send(RateLimitedLog.UNKNOWN_HAPTIC_KIND, "99", 0))
	assert_eq(_sink.count(), 1)


func test_same_key_just_inside_window_dropped() -> void:
	_send(RateLimitedLog.UNKNOWN_HAPTIC_KIND, "99", 0)
	assert_false(_send(RateLimitedLog.UNKNOWN_HAPTIC_KIND, "99", 999_999))
	assert_eq(_sink.count(), 1)


func test_same_key_at_window_edge_passes() -> void:
	_send(RateLimitedLog.UNKNOWN_HAPTIC_KIND, "99", 0)
	assert_true(_send(RateLimitedLog.UNKNOWN_HAPTIC_KIND, "99", 1_000_000))
	assert_eq(_sink.count(), 2)


func test_different_keys_at_one_stamp_both_pass() -> void:
	assert_true(_send(RateLimitedLog.UNKNOWN_HAPTIC_KIND, "99", 500))
	assert_true(_send(RateLimitedLog.UNKNOWN_HAPTIC_KIND, "98", 500))
	assert_eq(_sink.count(), 2)


func test_same_key_different_code_passes() -> void:
	assert_true(_send(RateLimitedLog.KNOB_CLAMPED, "x", 500))
	assert_true(_send(RateLimitedLog.SETTINGS_MISMATCH, "x", 500))
	assert_eq(_sink.count(), 2)


func test_window_runs_from_last_passed_not_first() -> void:
	_send(RateLimitedLog.LIFECYCLE_NOOP, "FO", 0)
	_send(RateLimitedLog.LIFECYCLE_NOOP, "FO", 1_000_000)
	assert_false(_send(RateLimitedLog.LIFECYCLE_NOOP, "FO", 1_999_999), "measured from 1_000_000")
	assert_true(_send(RateLimitedLog.LIFECYCLE_NOOP, "FO", 2_000_000))
	assert_eq(_sink.count(), 3)


func test_dropped_message_does_not_move_window() -> void:
	_send(RateLimitedLog.LIFECYCLE_NOOP, "FO", 0)
	_send(RateLimitedLog.LIFECYCLE_NOOP, "FO", 900_000)
	assert_true(_send(RateLimitedLog.LIFECYCLE_NOOP, "FO", 1_000_000))


func test_clock_backwards_passes_and_rebases() -> void:
	_send(RateLimitedLog.KNOB_CLAMPED, "a.b", 5_000_000)
	assert_true(_send(RateLimitedLog.KNOB_CLAMPED, "a.b", 4_000_000), "backwards passes")
	assert_false(_send(RateLimitedLog.KNOB_CLAMPED, "a.b", 4_500_000), "window re-based on 4_000_000")
	assert_true(_send(RateLimitedLog.KNOB_CLAMPED, "a.b", 5_000_000))
	assert_eq(_sink.count(), 3)


func test_sink_receives_level_code_key_and_message() -> void:
	_clock.now_us = 10
	_limiter.emit(RateLimitedLog.Level.DEBUG, RateLimitedLog.LIFECYCLE_NOOP, "FI", "noop")
	_limiter.emit(RateLimitedLog.Level.ERROR, RateLimitedLog.SETTINGS_MISMATCH, "orientation", "bad")
	assert_eq(_sink.entries[0], [RateLimitedLog.Level.DEBUG, &"LIFECYCLE_NOOP", "FI", "noop"])
	assert_eq(_sink.entries[1], [RateLimitedLog.Level.ERROR, &"SETTINGS_MISMATCH", "orientation", "bad"])
