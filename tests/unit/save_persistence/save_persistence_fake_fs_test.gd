## Story SP-002: SaveFs failure defaults, the recording fake, SaveConfig validation and the fixture.
extends GutTest

const FakeFs = preload("res://tests/support/fake_save_fs.gd")
const Fixture = preload("res://tests/support/save_fixture.gd")


func test_save_fs_base_returns_failure_values() -> void:
	var fs: SaveFs = SaveFs.new()
	assert_eq(fs.read_config("p")["status"], "PARSE_ERROR")
	assert_eq((fs.read_config("p")["sections"] as Dictionary).size(), 0)
	assert_false(fs.write_config("p", {}))
	assert_false(fs.exists("p"))
	assert_eq(fs.size("p"), -1)
	assert_false(fs.rename("a", "b"))
	assert_false(fs.delete("p"))
	assert_eq(fs.list_backups("d", "x").size(), 0)


func test_fake_records_call_order_and_honours_scripted_returns() -> void:
	var fake: FakeFs = FakeFs.new()
	fake.returns["exists"] = true
	fake.returns["rename"] = false
	assert_true(fake.exists(Fixture.TMP_PATH))
	assert_true(fake.write_config(Fixture.TMP_PATH, {}))
	assert_false(fake.rename(Fixture.TMP_PATH, Fixture.REAL_PATH))
	assert_eq(fake.call_names(), ["exists", "write_config", "rename"] as Array[String])
	assert_eq(fake.calls[2][1], [Fixture.TMP_PATH, Fixture.REAL_PATH] as Array)


func test_fixture_uses_values_distinct_from_the_shipped_defaults() -> void:
	var config: SaveConfig = Fixture.make_save_fixture()
	assert_almost_eq(config.save_log_rate_limit, 0.05, 1e-6)
	assert_eq(config.corrupt_backup_retention, 3)
	assert_eq(Fixture.CURRENT_SCHEMA_VERSION_TEST, 3)
	assert_ne(Fixture.CURRENT_SCHEMA_VERSION_TEST, SaveConfig.CURRENT_SCHEMA_VERSION)


func test_validated_clamps_out_of_range_knobs_and_leaves_source_unchanged() -> void:
	var source: SaveConfig = SaveConfig.new()
	source.save_log_rate_limit = 0.1
	source.corrupt_backup_retention = 0
	source.save_file_size_max = 5_000_000
	var logs: Array[Array] = []
	var sink: Callable = func(level: int, code: String, key: String, message: String) -> void:
		logs.append([level, code, key, message])
	var out: SaveConfig = source.validated(sink)
	assert_almost_eq(out.save_log_rate_limit, 0.5, 1e-6)
	assert_eq(out.corrupt_backup_retention, 1)
	assert_eq(out.save_file_size_max, 1_048_576)
	assert_almost_eq(source.save_log_rate_limit, 0.1, 1e-6)
	assert_eq(source.corrupt_backup_retention, 0)
	assert_eq(source.save_file_size_max, 5_000_000)
	assert_eq(logs.size(), 3)
	assert_eq(logs[0][1], "KNOB_CLAMPED")


func test_validated_in_range_knobs_log_nothing() -> void:
	var logs: Array[Array] = []
	var sink: Callable = func(level: int, code: String, key: String, message: String) -> void:
		logs.append([level, code, key, message])
	SaveConfig.new().validated(sink)
	assert_eq(logs.size(), 0)


func test_validated_non_finite_rate_limit_takes_the_default() -> void:
	var source: SaveConfig = SaveConfig.new()
	source.save_log_rate_limit = NAN
	var out: SaveConfig = source.validated(Callable())
	assert_almost_eq(out.save_log_rate_limit, 1.0, 1e-6)
