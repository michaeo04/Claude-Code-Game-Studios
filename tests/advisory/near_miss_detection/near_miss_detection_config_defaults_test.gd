extends GutTest

const Sink = preload("res://tests/support/platform_log_sink.gd")


func test_shipped_config_matches_tuning_knobs_and_validates_clean() -> void:
	var cfg: NearMissConfig = load("res://assets/data/near_miss_config.tres") as NearMissConfig
	var sink: Sink = Sink.new()
	var out: NearMissConfig = cfg.validated(sink.sink)
	assert_eq(out.near_miss_angle_coeff, 1.0)
	assert_eq(out.near_miss_s_coeff, 1.0)
	assert_eq(sink.count(), 0)
