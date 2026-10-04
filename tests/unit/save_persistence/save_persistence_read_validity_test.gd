## Story SP-006: read validity, per-key fallback and error logging (AC-10, AC-11).
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
	_fs.returns["exists"] = true


func _boot() -> SaveCore:
	var core: SaveCore = SaveCore.new(
		_fs, func() -> float: return 0.0, func() -> int: return 1700000000, _sink.sink, Fixture.make_save_fixture()
	)
	core.current_schema_version = Fixture.CURRENT_SCHEMA_VERSION_TEST
	core.boot_load()
	return core


func _read_all(core: SaveCore) -> void:
	core.get_value("scoring", "personal_best", 0)
	core.get_value("settings", "haptics_enabled", true)
	core.get_value("settings", "tilt_sensitivity", 1.0)


func test_parse_error_gives_defaults_and_one_file_unreadable_error() -> void:
	_fs.returns["read_config"] = {"status": "PARSE_ERROR", "sections": {}}
	var core: SaveCore = _boot()
	_read_all(core)
	assert_eq(core.get_value("scoring", "personal_best", 77), 77)
	assert_eq(core.get_value("settings", "tilt_sensitivity", 9.5), 9.5)
	assert_eq(_sink.count(), 1)
	assert_eq(_sink.entries[0][0], SaveCore.LEVEL_ERROR)
	assert_eq(_sink.entries[0][1], &"FILE_UNREADABLE")


func test_incompatible_schema_gives_defaults_and_one_schema_incompatible() -> void:
	var sections: Dictionary = Fixture.make_loaded_sections()
	(sections["_meta"] as Dictionary)["schema_version"] = 4
	_fs.returns["read_config"] = {"status": "OK", "sections": sections}
	var core: SaveCore = _boot()
	_read_all(core)
	assert_eq(core.get_value("scoring", "personal_best", 77), 77)
	assert_eq(core.get_value("settings", "haptics_enabled", false), false)
	assert_eq(_sink.count(), 1)
	assert_eq(_sink.entries[0][0], SaveCore.LEVEL_ERROR)
	assert_eq(_sink.entries[0][1], &"SCHEMA_INCOMPATIBLE")


func test_wrong_typed_key_returns_default_with_one_type_mismatch_others_unaffected() -> void:
	var sections: Dictionary = Fixture.make_loaded_sections()
	(sections["settings"] as Dictionary)["haptics_enabled"] = "yes"
	(sections["settings"] as Dictionary)["tilt_sensitivity"] = 1.5
	_fs.returns["read_config"] = {"status": "OK", "sections": sections}
	var core: SaveCore = _boot()
	assert_eq(core.get_value("settings", "haptics_enabled", true), true)
	assert_eq(core.get_value("settings", "tilt_sensitivity", 9.5), 1.5)
	assert_eq(_sink.count(), 1)
	assert_eq(_sink.entries[0][1], &"TYPE_MISMATCH")
	assert_eq(_sink.entries[0][2], "settings/haptics_enabled")


func test_absent_key_returns_default_and_logs_nothing() -> void:
	_fs.returns["read_config"] = {"status": "OK", "sections": Fixture.make_loaded_sections()}
	var core: SaveCore = _boot()
	assert_eq(core.get_value("settings", "reduced_motion_enabled", false), false)
	assert_eq(core.get_value("settings", "reduced_motion_enabled", 0), 0)
	assert_eq(_sink.count(), 0)


func test_wrong_typed_key_read_twice_logs_once() -> void:
	var sections: Dictionary = Fixture.make_loaded_sections()
	(sections["settings"] as Dictionary)["haptics_enabled"] = "yes"
	_fs.returns["read_config"] = {"status": "OK", "sections": sections}
	var core: SaveCore = _boot()
	core.get_value("settings", "haptics_enabled", true)
	assert_eq(core.get_value("settings", "haptics_enabled", true), true)
	assert_eq(_sink.count(), 1)


func test_stored_int_where_float_default_declared_is_type_mismatch() -> void:
	var sections: Dictionary = Fixture.make_loaded_sections()
	(sections["settings"] as Dictionary)["tilt_sensitivity"] = 2
	_fs.returns["read_config"] = {"status": "OK", "sections": sections}
	var core: SaveCore = _boot()
	assert_eq(core.get_value("settings", "tilt_sensitivity", 1.0), 1.0)
	assert_eq(_sink.entries[0][1], &"TYPE_MISMATCH")
