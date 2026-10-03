## Story SP-002 AC-23: the shipped SaveConfig resource matches the GDD Tuning Knobs (ADVISORY).
extends GutTest


func test_shipped_save_config_matches_the_tuning_knob_table() -> void:
	var config: SaveConfig = load("res://assets/data/save_config.tres") as SaveConfig
	assert_not_null(config)
	assert_almost_eq(config.save_log_rate_limit, 1.0, 1e-6)
	assert_eq(config.corrupt_backup_retention, 5)
	assert_eq(config.save_file_size_max, 65536)
	assert_eq(SaveConfig.CURRENT_SCHEMA_VERSION, 1)
