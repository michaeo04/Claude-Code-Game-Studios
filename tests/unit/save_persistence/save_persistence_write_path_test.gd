## Story SP-004: SaveCore.set_value write path (AC-6, AC-6b, AC-9, AC-13).
extends GutTest

const FakeFs = preload("res://tests/support/fake_save_fs.gd")
const Fixture = preload("res://tests/support/save_fixture.gd")
const SinkStub = preload("res://tests/support/platform_log_sink.gd")

var _fs: FakeFs
var _sink: SinkStub
var _core: SaveCore


func before_each() -> void:
	_fs = FakeFs.new()
	_sink = SinkStub.new()
	_fs.returns["size"] = 120
	_fs.returns["exists"] = true
	_fs.returns["read_config"] = {"status": "OK", "sections": Fixture.make_loaded_sections()}
	_core = SaveCore.new(
		_fs, func() -> float: return 0.0, func() -> int: return 0, _sink.sink, Fixture.make_save_fixture()
	)
	_core.current_schema_version = Fixture.CURRENT_SCHEMA_VERSION_TEST
	_core.boot_load()
	_fs.calls.clear()
	_fs.returns["exists"] = false


func test_set_value_calls_exists_write_size_rename_in_order() -> void:
	assert_true(_core.set_value("scoring", "personal_best", 900))
	assert_eq(_fs.call_names(), ["exists", "write_config", "size", "rename"] as Array[String])
	assert_eq(_fs.calls[0][1], [Fixture.TMP_PATH] as Array)
	assert_eq(_fs.calls[1][1][0], Fixture.TMP_PATH)
	assert_eq(_fs.calls[3][1], [Fixture.TMP_PATH, Fixture.REAL_PATH] as Array)


func test_set_value_writes_the_complete_map_not_only_the_changed_section() -> void:
	_core.set_value("scoring", "personal_best", 900)
	var written: Dictionary = _fs.calls[1][1][1]
	assert_eq(written["scoring"]["personal_best"], 900)
	assert_eq(written["settings"]["haptics_enabled"], true)
	assert_eq(written["settings"]["tilt_sensitivity"], 1.0)
	assert_eq(written["_meta"]["schema_version"], Fixture.CURRENT_SCHEMA_VERSION_TEST)
	assert_eq(written.size(), 3)


func test_set_value_on_fresh_core_writes_meta_schema_version() -> void:
	var fs: FakeFs = FakeFs.new()
	fs.returns["size"] = 5
	var core: SaveCore = SaveCore.new(
		fs, func() -> float: return 0.0, func() -> int: return 0, _sink.sink, Fixture.make_save_fixture()
	)
	core.boot_load()
	core.set_value("scoring", "personal_best", 1)
	var written: Dictionary = fs.calls[fs.calls.size() - 3][1][1]
	assert_eq(written["_meta"]["schema_version"], SaveConfig.CURRENT_SCHEMA_VERSION)
	assert_eq(written["scoring"]["personal_best"], 1)


func test_settings_write_keeps_personal_best_in_memory_and_in_the_map() -> void:
	_core.set_value("settings", "haptics_enabled", false)
	_core.set_value("settings", "haptics_enabled", false)
	assert_eq(_core.get_value("scoring", "personal_best", -1), 500)
	var second: Dictionary = _fs.calls[5][1][1]
	assert_eq(_fs.calls[5][0], "write_config")
	assert_eq(second["scoring"]["personal_best"], 500)
	assert_eq(second["settings"]["haptics_enabled"], false)


func test_wrong_typed_stored_key_is_carried_into_the_map() -> void:
	var sections: Dictionary = Fixture.make_loaded_sections()
	(sections["settings"] as Dictionary)["tilt_sensitivity"] = "high"
	_fs.returns["read_config"] = {"status": "OK", "sections": sections}
	_fs.returns["exists"] = true
	_core.boot_load()
	_fs.returns["exists"] = false
	_fs.calls.clear()
	_core.set_value("settings", "haptics_enabled", false)
	var written: Dictionary = _fs.calls[1][1][1]
	assert_eq(written["settings"]["tilt_sensitivity"], "high")


func test_existing_tmp_is_deleted_before_write_once_only() -> void:
	_fs.returns["exists"] = true
	_core.set_value("scoring", "personal_best", 1)
	assert_eq(_fs.call_names(), ["exists", "delete", "write_config", "size", "rename"] as Array[String])
	assert_eq(_fs.calls[1][1], [Fixture.TMP_PATH] as Array)
	_fs.calls.clear()
	_fs.returns["exists"] = false
	_core.set_value("scoring", "personal_best", 2)
	assert_false("delete" in _fs.call_names())


func test_unserializable_object_calls_no_seam_and_logs_once() -> void:
	var obj: Object = Object.new()
	assert_false(_core.set_value("scoring", "personal_best", obj))
	obj.free()
	assert_eq(_fs.calls.size(), 0)
	assert_eq(_core.get_value("scoring", "personal_best", -1), 500)
	assert_eq(_sink.count(), 1)
	assert_eq(_sink.entries[0][1], &"UNSERIALIZABLE_VALUE")
	assert_eq(_sink.entries[0][2], "scoring/personal_best")


func test_nan_float_is_rejected_like_an_object() -> void:
	assert_false(_core.set_value("settings", "tilt_sensitivity", NAN))
	assert_false(_core.set_value("settings", "tilt_sensitivity", INF))
	assert_eq(_fs.calls.size(), 0)
	assert_eq(_core.get_value("settings", "tilt_sensitivity", 0.0), 1.0)
	assert_eq(_sink.count(), 2)
