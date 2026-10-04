## Story SP-003: SaveCore boot load, get_value and first launch (AC-4, AC-5, AC-12).
extends GutTest

const FakeFs = preload("res://tests/support/fake_save_fs.gd")
const Fixture = preload("res://tests/support/save_fixture.gd")
const SinkStub = preload("res://tests/support/platform_log_sink.gd")

var _fs: FakeFs
var _sink: SinkStub


func before_each() -> void:
	_fs = FakeFs.new()
	_sink = SinkStub.new()
	_fs.returns["size"] = 120


func _make_core() -> SaveCore:
	var core: SaveCore = SaveCore.new(
		_fs, func() -> float: return 0.0, func() -> int: return 0, _sink.sink, Fixture.make_save_fixture()
	)
	core.current_schema_version = Fixture.CURRENT_SCHEMA_VERSION_TEST
	return core


func _script_loaded(sections: Dictionary) -> void:
	_fs.returns["exists"] = true
	_fs.returns["read_config"] = {"status": "OK", "sections": sections}


func test_get_value_returns_stored_values_after_boot_load() -> void:
	var sections: Dictionary = Fixture.make_loaded_sections()
	(sections["settings"] as Dictionary)["tilt_sensitivity"] = 1.5
	_script_loaded(sections)
	var core: SaveCore = _make_core()
	core.boot_load()
	assert_eq(core.get_value("scoring", "personal_best", 77), 500)
	assert_eq(core.get_value("settings", "tilt_sensitivity", 9.5), 1.5)


func test_get_value_returns_caller_default_on_parse_error() -> void:
	_fs.returns["exists"] = true
	_fs.returns["read_config"] = {"status": "PARSE_ERROR", "sections": {}}
	var core: SaveCore = _make_core()
	core.boot_load()
	assert_eq(core.get_value("scoring", "personal_best", 77), 77)
	assert_eq(core.get_value("settings", "tilt_sensitivity", 9.5), 9.5)


func test_get_value_with_default_of_other_type_returns_default_unchanged() -> void:
	_script_loaded(Fixture.make_loaded_sections())
	var core: SaveCore = _make_core()
	core.boot_load()
	assert_eq(core.get_value("scoring", "personal_best", "none"), "none")
	assert_eq(core.get_value("settings", "tilt_sensitivity", 1), 1)


func test_get_value_of_absent_key_returns_default() -> void:
	_script_loaded(Fixture.make_loaded_sections())
	var core: SaveCore = _make_core()
	core.boot_load()
	assert_eq(core.get_value("settings", "reduced_motion_enabled", false), false)
	assert_eq(core.get_value("cosmetics", "skin", 4), 4)


func test_boot_load_is_synchronous_and_every_fixture_key_is_readable() -> void:
	_script_loaded(Fixture.make_loaded_sections())
	var core: SaveCore = _make_core()
	core.boot_load()
	assert_eq(core.get_value("scoring", "personal_best", -1), 500)
	assert_eq(core.get_value("settings", "haptics_enabled", false), true)
	assert_eq(core.get_value("settings", "tilt_sensitivity", 0.0), 1.0)
	assert_eq(_sink.count(), 0)
	assert_eq(_fs.call_names(), ["exists", "size", "read_config"] as Array[String])


func test_missing_file_gives_defaults_and_one_info_file_missing() -> void:
	_fs.returns["exists"] = false
	var core: SaveCore = _make_core()
	core.boot_load()
	assert_eq(core.get_value("scoring", "personal_best", 0), 0)
	assert_eq(core.get_value("settings", "haptics_enabled", true), true)
	assert_eq(core.get_value("settings", "tilt_sensitivity", 1.0), 1.0)
	assert_eq(_sink.count(), 1)
	assert_eq(_sink.entries[0][0], SaveCore.LEVEL_INFO)
	assert_eq(_sink.entries[0][1], &"FILE_MISSING")
	assert_false("read_config" in _fs.call_names())


func test_missing_file_first_set_value_checks_tmp_then_writes() -> void:
	_fs.returns["exists"] = false
	var core: SaveCore = _make_core()
	core.boot_load()
	_fs.calls.clear()
	assert_true(core.set_value("scoring", "personal_best", 10))
	assert_eq(_fs.call_names(), ["exists", "write_config", "size", "rename"] as Array[String])
