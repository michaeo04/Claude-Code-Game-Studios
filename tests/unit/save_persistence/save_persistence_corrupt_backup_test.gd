## Story SP-007: corrupt-file backup, rotation and oversize guard (AC-15 and the oversized edge case).
extends GutTest

const FakeFs = preload("res://tests/support/fake_save_fs.gd")
const Fixture = preload("res://tests/support/save_fixture.gd")
const SinkStub = preload("res://tests/support/platform_log_sink.gd")

const STAMP: int = 1700000000
const BACKUP_0: String = "user://save.cfg.corrupt-1700000000-0"
const BACKUP_1: String = "user://save.cfg.corrupt-1700000000-1"

var _fs: FakeFs
var _sink: SinkStub


func before_each() -> void:
	_fs = FakeFs.new()
	_sink = SinkStub.new()
	_fs.returns["size"] = 120
	_fs.returns["exists"] = true
	_fs.returns["exists_by_path"] = {BACKUP_0: false}
	_fs.returns["read_config"] = {"status": "PARSE_ERROR", "sections": {}}


func _boot(config: SaveConfig = Fixture.make_save_fixture()) -> SaveCore:
	var core: SaveCore = SaveCore.new(
		_fs, func() -> float: return 0.0, func() -> int: return STAMP, _sink.sink, config
	)
	core.current_schema_version = Fixture.CURRENT_SCHEMA_VERSION_TEST
	core.boot_load()
	return core


func _calls_of(method: String) -> Array[Array]:
	var out: Array[Array] = []
	for entry: Array in _fs.calls:
		if entry[0] == method:
			out.append(entry)
	return out


func test_parse_error_renames_old_file_to_stamped_backup() -> void:
	_boot()
	var renames: Array[Array] = _calls_of("rename")
	assert_eq(renames.size(), 1)
	assert_eq(renames[0][1], ["user://save.cfg", BACKUP_0])


func test_backup_rename_happens_before_any_write() -> void:
	var core: SaveCore = _boot()
	core.set_value("scoring", "personal_best", 5)
	var names: Array[String] = _fs.call_names()
	assert_lt(names.find("rename"), names.find("write_config"))


func test_second_event_in_same_second_gets_next_counter() -> void:
	_fs.returns["exists_by_path"] = {BACKUP_0: true, BACKUP_1: false}
	_boot()
	assert_eq(_calls_of("rename")[0][1], ["user://save.cfg", BACKUP_1])


func test_retention_three_deletes_oldest_only_on_fourth_backup() -> void:
	_fs.returns["list_backups"] = PackedStringArray(["save.cfg.corrupt-1700000000-0"])
	_boot()
	_fs.returns["list_backups"] = PackedStringArray(["save.cfg.corrupt-1700000000-0", "save.cfg.corrupt-1699999999-0"])
	_boot()
	_fs.returns["list_backups"] = PackedStringArray(
		["save.cfg.corrupt-1700000000-0", "save.cfg.corrupt-1699999999-0", "save.cfg.corrupt-1699999998-0"]
	)
	_boot()
	assert_eq(_calls_of("delete").size(), 0)
	_fs.returns["list_backups"] = PackedStringArray(
		[
			"save.cfg.corrupt-1700000000-0",
			"save.cfg.corrupt-1699999998-0",
			"save.cfg.corrupt-1699999997-0",
			"save.cfg.corrupt-1699999999-0",
		]
	)
	_boot()
	var deletes: Array[Array] = _calls_of("delete")
	assert_eq(deletes.size(), 1)
	assert_eq(deletes[0][1], ["user://save.cfg.corrupt-1699999997-0"])


func test_oversized_file_is_not_parsed_and_is_backed_up() -> void:
	var config: SaveConfig = Fixture.make_save_fixture()
	_fs.returns["size"] = config.save_file_size_max + 1
	var core: SaveCore = _boot(config)
	assert_false("read_config" in _fs.call_names())
	assert_eq(_calls_of("rename").size(), 1)
	assert_eq(_sink.count(), 1)
	assert_eq(_sink.entries[0][1], &"FILE_UNREADABLE")
	assert_true((_sink.entries[0][3] as String).contains("oversized"))
	assert_eq(core.get_value("scoring", "personal_best", 77), 77)


func test_file_exactly_at_size_limit_is_read_normally() -> void:
	var config: SaveConfig = Fixture.make_save_fixture()
	_fs.returns["size"] = config.save_file_size_max
	_fs.returns["read_config"] = {"status": "OK", "sections": Fixture.make_loaded_sections()}
	var core: SaveCore = _boot(config)
	assert_true("read_config" in _fs.call_names())
	assert_eq(_calls_of("rename").size(), 0)
	assert_eq(core.get_value("scoring", "personal_best", 0), 500)


func test_unknown_size_on_existing_file_is_unreadable() -> void:
	_fs.returns["size"] = -1
	_boot()
	assert_false("read_config" in _fs.call_names())
	assert_eq(_sink.entries[0][1], &"FILE_UNREADABLE")
	assert_eq(_calls_of("rename").size(), 1)


func test_incompatible_schema_is_also_backed_up() -> void:
	var sections: Dictionary = Fixture.make_loaded_sections()
	(sections["_meta"] as Dictionary)["schema_version"] = 4
	_fs.returns["read_config"] = {"status": "OK", "sections": sections}
	_boot()
	assert_eq(_calls_of("rename").size(), 1)
