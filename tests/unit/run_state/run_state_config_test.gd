## Story RS-010: RunConfig validation and lock bounds (GDD AC-14, F4).
##
## Decision recorded for the open point of test-plan section 6: the hitstop term of LOCK_MIN is the
## constant `hitstop_max` (F4: 0.20 + 0.25 = 0.45); the injected `hitstop_actual` only drives the
## read-time raise (`RESTART_LOCK - hitstop_actual >= T_READ`).
extends GutTest

const LogSink = preload("res://tests/support/platform_log_sink.gd")

const TOL: float = 1e-6


## Validates a config with one field set; returns [validated config, log sink].
func _validate(field: String, value: float) -> Array:
	var cfg: RunConfig = RunConfig.new()
	cfg.set(field, value)
	var logs: LogSink = LogSink.new()
	var out: RunConfig = cfg.validated(logs.sink)
	return [out, logs]


func _assert_field(field: String, input: float, expected: float) -> void:
	var result: Array = _validate(field, input)
	var out: RunConfig = result[0] as RunConfig
	var logs: LogSink = result[1] as LogSink
	assert_almost_eq(out.get(field) as float, expected, TOL, "%s=%s" % [field, input])
	assert_eq(logs.count(), 1, "%s=%s logs one error" % [field, input])
	assert_eq(logs.level_at(0), LogLevel.ERROR)
	assert_eq(logs.code_at(0), RunStateMath.LOG_CONFIG_CLAMPED)


func test_config_defaults_pass_with_zero_errors() -> void:
	var logs: LogSink = LogSink.new()
	var out: RunConfig = RunConfig.new().validated(logs.sink)
	assert_eq(logs.count(), 0)
	assert_almost_eq(out.restart_lock, 0.5, TOL)
	assert_almost_eq(out.lock_min(), 0.45, TOL)
	assert_almost_eq(out.lock_max(), 0.6, TOL)


func test_config_lock_min_and_max_have_the_default_inside() -> void:
	var cfg: RunConfig = RunConfig.new()
	assert_true(cfg.lock_min() <= cfg.restart_lock and cfg.restart_lock <= cfg.lock_max())


func test_config_lock_below_min_is_clamped_to_045() -> void:
	_assert_field("restart_lock", 0.3, 0.45)


func test_config_lock_above_max_is_clamped_to_060() -> void:
	_assert_field("restart_lock", 0.9, 0.6)


func test_config_countdown_below_range_is_clamped() -> void:
	_assert_field("resume_countdown", 0.5, 1.0)


func test_config_countdown_above_range_is_clamped() -> void:
	_assert_field("resume_countdown", 5.0, 3.0)


func test_config_stall_threshold_below_range_is_clamped() -> void:
	_assert_field("stall_pause_threshold", 0.2, 0.5)


func test_config_stall_threshold_above_range_is_clamped() -> void:
	_assert_field("stall_pause_threshold", 9.0, 3.0)


func test_config_dt_max_below_range_is_clamped() -> void:
	_assert_field("dt_max", 0.02, 0.05)


func test_config_dt_max_above_range_is_clamped() -> void:
	_assert_field("dt_max", 0.4, 0.25)


func test_config_pause_guard_below_range_is_clamped() -> void:
	_assert_field("pause_input_guard", 0.05, 0.2)


func test_config_pause_guard_above_range_is_clamped() -> void:
	_assert_field("pause_input_guard", 2.0, 0.5)


func test_config_non_finite_values_are_replaced_by_the_default() -> void:
	var defaults: RunConfig = RunConfig.new()
	for field: String in ["restart_lock", "pause_input_guard", "resume_countdown", "dt_max", "stall_pause_threshold"]:
		for bad: float in [NAN, INF, -INF]:
			_assert_field(field, bad, defaults.get(field) as float)


func test_config_stall_threshold_stays_at_least_twice_dt_max() -> void:
	var cfg: RunConfig = RunConfig.new()
	cfg.dt_max = 9.0
	cfg.stall_pause_threshold = 0.01
	var out: RunConfig = cfg.validated(LogSink.new().sink)
	assert_true(out.stall_pause_threshold >= 2.0 * out.dt_max - TOL)


func test_config_lock_min_above_lock_max_uses_lock_min() -> void:
	var cfg: RunConfig = RunConfig.new()
	cfg.t_restart_30fps = 0.7 # LOCK_MAX = min(0.6, 0.3) = 0.3 < LOCK_MIN 0.45
	var logs: LogSink = LogSink.new()
	var out: RunConfig = cfg.validated(logs.sink)
	assert_almost_eq(out.restart_lock, 0.45, TOL)
	assert_eq(logs.count_code(RunStateMath.LOG_CONFIG_LOCK_BOUNDS), 1)
	assert_eq(logs.count_level(LogLevel.ERROR), logs.count(), "every line is an error")


func test_config_lock_is_raised_to_hitstop_plus_read_time() -> void:
	var cfg: RunConfig = RunConfig.new()
	cfg.hitstop_actual = 0.3 # 0.5 - 0.3 = 0.2 < T_READ 0.25
	var logs: LogSink = LogSink.new()
	var out: RunConfig = cfg.validated(logs.sink)
	assert_almost_eq(out.restart_lock, 0.55, TOL)
	assert_eq(logs.count(), 1)
	assert_eq(logs.code_at(0), RunStateMath.LOG_CONFIG_LOCK_READ)
	assert_eq(logs.level_at(0), LogLevel.ERROR)


func test_config_lock_raise_is_capped_at_lock_max_for_hitstop_half_second() -> void:
	var cfg: RunConfig = RunConfig.new()
	cfg.hitstop_actual = 0.5 # 0.5 + 0.25 = 0.75 > LOCK_MAX
	var logs: LogSink = LogSink.new()
	var out: RunConfig = cfg.validated(logs.sink)
	assert_almost_eq(out.restart_lock, 0.6, TOL)
	assert_eq(logs.count_code(RunStateMath.LOG_CONFIG_LOCK_READ), 1)


func test_config_lock_at_exact_read_margin_is_not_raised() -> void:
	var cfg: RunConfig = RunConfig.new()
	cfg.restart_lock = 0.45 # 0.45 - 0.2 = T_READ within float noise
	var logs: LogSink = LogSink.new()
	var out: RunConfig = cfg.validated(logs.sink)
	assert_almost_eq(out.restart_lock, 0.45, TOL)
	assert_eq(logs.count(), 0)


func test_config_validated_never_mutates_the_source() -> void:
	var cfg: RunConfig = RunConfig.new()
	cfg.restart_lock = 0.9
	cfg.dt_max = NAN
	var out: RunConfig = cfg.validated(LogSink.new().sink)
	assert_ne(out, cfg)
	assert_almost_eq(cfg.restart_lock, 0.9, TOL)
	assert_true(is_nan(cfg.dt_max))


func test_config_shipped_tres_passes_with_zero_errors() -> void:
	var cfg: RunConfig = load("res://assets/data/run_config.tres") as RunConfig
	assert_not_null(cfg)
	var logs: LogSink = LogSink.new()
	var out: RunConfig = cfg.validated(logs.sink)
	assert_eq(logs.count(), 0)
	var defaults: RunConfig = RunConfig.new()
	assert_almost_eq(out.restart_lock, defaults.restart_lock, TOL)
	assert_almost_eq(out.dt_max, defaults.dt_max, TOL)
	assert_almost_eq(out.t_restart_30fps, defaults.t_restart_30fps, TOL)
