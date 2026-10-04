## Story OBS-002: AC-30 (ADVISORY) the shipped ObstacleConfig.tres equals the Tuning Knobs table.
extends GutTest

const Sink = preload("res://tests/support/platform_log_sink.gd")


func test_shipped_obstacle_config_equals_tuning_knobs_and_validates_clean() -> void:
	var cfg: ObstacleConfig = load("res://assets/data/obstacle_config.tres") as ObstacleConfig
	var sink: RefCounted = Sink.new()

	var out: ObstacleConfig = cfg.validated(Callable(sink, "sink"), 3.0, 0.1)

	assert_eq(out.gap_margin, 2.5)
	assert_eq(out.t_reveal_min, 1.5)
	assert_eq(out.hidden_span_min_time, 1.44)
	assert_eq(out.max_pieces_per_segment, 12)
	assert_eq(sink.call("count") as int, 0)
