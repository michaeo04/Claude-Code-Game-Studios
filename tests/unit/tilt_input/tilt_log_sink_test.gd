## Story TI-013: AC-42, the production log sink (RateLimitedLog on the injected clock) as Tilt Input uses it.
extends GutTest

const ClockStub = preload("res://tests/support/clock_stub.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")


func _limited(clock: ClockStub, sink: LogSink) -> RateLimitedLog:
	return RateLimitedLog.new(sink.sink, clock.as_callable())


func test_one_message_per_code_per_second_ac42() -> void:
	var clock: ClockStub = ClockStub.new(0)
	var sink: LogSink = LogSink.new()
	var limited: RateLimitedLog = _limited(clock, sink)
	assert_true(limited.emit(LogLevel.ERROR, TiltCore.LOG_SENSOR_TIMEOUT, "", "a"))
	clock.now_us = 999999
	assert_false(limited.emit(LogLevel.ERROR, TiltCore.LOG_SENSOR_TIMEOUT, "", "b"))
	clock.now_us = 1000000
	assert_true(limited.emit(LogLevel.ERROR, TiltCore.LOG_SENSOR_TIMEOUT, "", "c"))
	assert_eq(sink.count(), 2)


func test_two_codes_at_the_same_stamp_both_pass_ac42() -> void:
	var clock: ClockStub = ClockStub.new(5)
	var sink: LogSink = LogSink.new()
	var limited: RateLimitedLog = _limited(clock, sink)
	assert_true(limited.emit(LogLevel.ERROR, TiltCore.LOG_SENSOR_TIMEOUT, "", "a"))
	assert_true(limited.emit(LogLevel.ERROR, TiltCore.LOG_SENSORS_DISABLED, "", "b"))
	assert_eq(sink.count(), 2)


func test_level_is_preserved_ac42() -> void:
	var clock: ClockStub = ClockStub.new(0)
	var sink: LogSink = LogSink.new()
	var limited: RateLimitedLog = _limited(clock, sink)
	limited.emit(LogLevel.WARNING, TiltCore.LOG_SETTING_CLAMPED, "tilt_sensitivity", "w")
	limited.emit(LogLevel.ERROR, TiltCore.LOG_BAD_OUTPUT, "", "e")
	assert_eq(sink.level_at(0), LogLevel.WARNING)
	assert_eq(sink.level_at(1), LogLevel.ERROR)
	assert_eq(sink.code_at(0), TiltCore.LOG_SETTING_CLAMPED)
