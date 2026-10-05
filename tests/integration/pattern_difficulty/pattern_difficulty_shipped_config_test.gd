## Story 009: the shipped `assets/data/pattern_config.tres` equals the Tuning Knobs table (GDD AC-22).
extends GutTest

const Sink = preload("res://tests/support/platform_log_sink.gd")
const Defaults = preload("res://tests/support/data/pattern_shipped_defaults.gd")
const PATH: String = "res://assets/data/pattern_config.tres"


func test_shipped_config_loads_as_pattern_config() -> void:
	var cfg: Resource = load(PATH)
	assert_true(cfg is PatternConfig)


func test_shipped_knobs_equal_tuning_table() -> void:
	var cfg: PatternConfig = load(PATH) as PatternConfig
	assert_almost_eq(cfg.tier_intro_duration, Defaults.TIER_INTRO_DURATION, 1e-9)
	assert_almost_eq(cfg.tier_ramp_duration, Defaults.TIER_RAMP_DURATION, 1e-9)
	assert_almost_eq(cfg.angular_reversal_threshold, Defaults.ANGULAR_REVERSAL_THRESHOLD, 1e-9)
	assert_almost_eq(cfg.max_opposing_fraction, Defaults.MAX_OPPOSING_FRACTION, 1e-9)


func test_shipped_config_validates_without_any_log_line() -> void:
	var sink: Sink = Sink.new()
	var cfg: PatternConfig = (load(PATH) as PatternConfig).validated(Callable(sink, "sink"))
	assert_eq(sink.count(), 0)
	assert_almost_eq(cfg.angular_reversal_threshold, Defaults.ANGULAR_REVERSAL_THRESHOLD, 1e-9)
