## Story SP-005: write failure handling and rate-limited logging (AC-8, AC-14).
extends GutTest

const FakeFs = preload("res://tests/support/fake_save_fs.gd")
const Fixture = preload("res://tests/support/save_fixture.gd")
const SinkStub = preload("res://tests/support/platform_log_sink.gd")

var _fs: FakeFs
var _sink: SinkStub
var _core: SaveCore
## Injected clock in seconds; advances `_step` after every read.
var _now: Array[float] = [0.0]
var _step: Array[float] = [0.0]


func before_each() -> void:
	_now[0] = 0.0
	_step[0] = 0.0
	_fs = FakeFs.new()
	_sink = SinkStub.new()
	_fs.returns["size"] = 120
	var now: Array[float] = _now
	var step: Array[float] = _step
	var clock: Callable = func() -> float:
		var t: float = now[0]
		now[0] += step[0]
		return t
	_core = SaveCore.new(_fs, clock, func() -> int: return 0, _sink.sink, Fixture.make_save_fixture())
	_core.boot_load()
	_fs.calls.clear()
	_sink.entries.clear()


func test_failed_write_config_stops_before_rename_and_keeps_memory() -> void:
	_fs.returns["write_config"] = false
	assert_false(_core.set_value("scoring", "personal_best", 700))
	assert_false("rename" in _fs.call_names())
	assert_eq(_sink.count(), 1)
	assert_eq(_sink.entries[0][1], &"WRITE_FAILED")
	assert_eq(_sink.entries[0][2], "scoring/personal_best")
	assert_eq(_core.get_value("scoring", "personal_best", -1), 700)


func test_failed_rename_reports_write_failed_and_keeps_memory() -> void:
	_fs.returns["rename"] = false
	assert_false(_core.set_value("scoring", "personal_best", 700))
	assert_eq(_sink.count(), 1)
	assert_eq(_sink.entries[0][1], &"WRITE_FAILED")
	assert_eq(_core.get_value("scoring", "personal_best", -1), 700)


func test_zero_size_temp_file_is_a_write_failure() -> void:
	_fs.returns["size"] = 0
	assert_false(_core.set_value("scoring", "personal_best", 700))
	assert_false("rename" in _fs.call_names())
	assert_eq(_sink.count(), 1)
	assert_eq(_sink.entries[0][1], &"WRITE_FAILED")


func test_successful_write_logs_nothing_and_returns_true() -> void:
	assert_true(_core.set_value("scoring", "personal_best", 700))
	assert_eq(_sink.count(), 0)


func test_ten_failures_on_one_key_log_once_and_all_update_memory() -> void:
	_fs.returns["write_config"] = false
	_step[0] = 0.001
	for i: int in range(10):
		assert_false(_core.set_value("scoring", "personal_best", 100 + i))
	assert_eq(_sink.count(), 1)
	assert_eq(_core.get_value("scoring", "personal_best", -1), 109)
	assert_false(_core.set_value("settings", "tilt_sensitivity", 2.0))
	assert_eq(_sink.count(), 2)
	assert_eq(_sink.entries[1][2], "settings/tilt_sensitivity")


func test_failure_logs_again_after_the_rate_limit_window() -> void:
	_fs.returns["write_config"] = false
	_core.set_value("scoring", "personal_best", 1)
	_now[0] = 0.04
	_core.set_value("scoring", "personal_best", 2)
	assert_eq(_sink.count(), 1)
	_now[0] = 0.06
	_core.set_value("scoring", "personal_best", 3)
	assert_eq(_sink.count(), 2)
