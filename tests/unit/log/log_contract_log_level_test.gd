## The one log-level scale and sink contract (code review finding 1, story CRF-001).
extends GutTest

const Recorder = preload("res://tests/support/platform_log_sink.gd")


func test_levels_are_ordered_debug_info_warning_error() -> void:
	assert_eq(LogLevel.DEBUG, 0)
	assert_eq(LogLevel.INFO, 1)
	assert_eq(LogLevel.WARNING, 2)
	assert_eq(LogLevel.ERROR, 3)


func test_name_of_maps_each_level_and_unknown() -> void:
	assert_eq(LogLevel.name_of(LogLevel.DEBUG), "DEBUG")
	assert_eq(LogLevel.name_of(LogLevel.INFO), "INFO")
	assert_eq(LogLevel.name_of(LogLevel.WARNING), "WARNING")
	assert_eq(LogLevel.name_of(LogLevel.ERROR), "ERROR")
	assert_eq(LogLevel.name_of(99), "UNKNOWN")


func test_run_config_logs_through_the_four_argument_sink_at_error_level() -> void:
	var rec: Recorder = Recorder.new()
	var cfg: RunConfig = RunConfig.new()
	cfg.dt_max = 99.0
	cfg.validated(rec.sink)
	assert_eq(rec.count(), 1)
	assert_eq(rec.level_at(0), LogLevel.ERROR)
	assert_eq(rec.code_at(0), RunStateMath.LOG_CONFIG_CLAMPED)


func test_world_frame_config_logs_through_the_four_argument_sink_at_warning_level() -> void:
	var rec: Recorder = Recorder.new()
	var cfg: WorldFrameConfig = WorldFrameConfig.new()
	cfg.rebase_segments = 1
	cfg.validated(rec.sink)
	assert_eq(rec.level_at(0), LogLevel.WARNING)
	assert_eq(rec.key_at(0), "rebase_segments")


func test_rate_limited_log_passes_shared_levels_through_unchanged() -> void:
	var rec: Recorder = Recorder.new()
	var limiter: RateLimitedLog = RateLimitedLog.new(rec.sink, func() -> int: return 0)
	limiter.emit(LogLevel.WARNING, &"X", "k", "m")
	assert_eq(rec.level_at(0), LogLevel.WARNING)
