## Story SP-009: the real SaveFs against the real file system, in a per-test directory under user:// (ADR-0007, ADR-0009).
extends GutTest

const Fixture = preload("res://tests/support/save_fixture.gd")
const SinkStub = preload("res://tests/support/platform_log_sink.gd")

var _dir: String = ""
var _fs: SaveService.RealSaveFs
var _sink: SinkStub


func before_each() -> void:
	_dir = "user://sp009_test_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_dir)
	_fs = SaveService.RealSaveFs.new(_dir)
	_sink = SinkStub.new()


func after_each() -> void:
	var access: DirAccess = DirAccess.open(_dir)
	if access != null:
		for file_name: String in access.get_files():
			DirAccess.remove_absolute(_dir + "/" + file_name)
	DirAccess.remove_absolute(_dir)


func _write_raw(name: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(_dir + "/" + name, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _core() -> SaveCore:
	return SaveCore.new(_fs, func() -> float: return 0.0, func() -> int: return 100, _sink.sink, Fixture.make_save_fixture())


func test_round_trip_mixed_types_keeps_value_and_typeof() -> void:
	var sections: Dictionary = {"a": {"i": 1, "f": 1.0, "b": true, "s": "hi", "v": Vector2(1.5, -2.0)}}
	assert_true(_fs.write_config("user://rt.cfg", sections))
	var result: Dictionary = _fs.read_config("user://rt.cfg")
	assert_eq(result["status"], "OK")
	var back: Dictionary = (result["sections"] as Dictionary)["a"]
	assert_eq(back["i"], 1)
	assert_eq(typeof(back["i"]), TYPE_INT)
	assert_almost_eq(back["f"] as float, 1.0, 1e-6)
	assert_eq(typeof(back["f"]), TYPE_FLOAT)
	assert_eq(back["b"], true)
	assert_eq(back["s"], "hi")
	assert_eq(back["v"], Vector2(1.5, -2.0))


func test_empty_file_reads_ok_with_no_sections() -> void:
	_write_raw("empty.cfg", "")
	var result: Dictionary = _fs.read_config("user://empty.cfg")
	assert_eq(result["status"], "OK")
	assert_eq((result["sections"] as Dictionary).size(), 0)


func test_missing_path_reads_missing() -> void:
	assert_eq(_fs.read_config("user://nope.cfg")["status"], "MISSING")


func test_garbage_file_reads_parse_error_and_does_not_leak_into_next_read() -> void:
	_fs.write_config("user://good.cfg", {"s": {"k": 1}})
	_write_raw("bad.cfg", "[sec\nthis is not a config line\n")
	assert_eq(_fs.read_config("user://good.cfg")["status"], "OK")
	var bad: Dictionary = _fs.read_config("user://bad.cfg")
	assert_eq(bad["status"], "PARSE_ERROR")
	assert_engine_error("ConfigFile parse error")
	assert_eq((bad["sections"] as Dictionary).size(), 0)
	var empty_after: Dictionary = _fs.read_config("user://nope.cfg")
	assert_eq((empty_after["sections"] as Dictionary).size(), 0)


func test_size_is_minus_one_when_absent_and_byte_length_otherwise() -> void:
	assert_eq(_fs.size("user://nope.cfg"), -1)
	_write_raw("five.cfg", "12345")
	assert_eq(_fs.size("user://five.cfg"), 5)
	assert_true(_fs.exists("user://five.cfg"))
	assert_false(_fs.exists("user://nope.cfg"))


func test_rename_over_existing_destination_replaces_content_and_removes_source() -> void:
	_write_raw("src.cfg", "new")
	_write_raw("dst.cfg", "old content")
	assert_true(_fs.rename("user://src.cfg", "user://dst.cfg"))
	assert_false(_fs.exists("user://src.cfg"))
	assert_eq(_fs.size("user://dst.cfg"), 3)


func test_delete_removes_file() -> void:
	_write_raw("x.cfg", "x")
	assert_true(_fs.delete("user://x.cfg"))
	assert_false(_fs.exists("user://x.cfg"))
	assert_false(_fs.delete("user://x.cfg"))


func test_list_backups_returns_exactly_the_prefixed_names() -> void:
	_write_raw("save.cfg.corrupt-1-0", "a")
	_write_raw("save.cfg.corrupt-2-1", "b")
	_write_raw("save.cfg", "c")
	_write_raw("other.txt", "d")
	var names: Array = Array(_fs.list_backups("user://", "save.cfg.corrupt-"))
	names.sort()
	assert_eq(names, ["save.cfg.corrupt-1-0", "save.cfg.corrupt-2-1"])


func test_core_set_value_then_new_core_boot_load_returns_value() -> void:
	var first: SaveCore = _core()
	first.boot_load()
	assert_true(first.set_value("settings", "tilt_sensitivity", 1.5))
	assert_true(first.set_value("settings", "count", 3))
	var second: SaveCore = _core()
	second.boot_load()
	assert_almost_eq(second.get_value("settings", "tilt_sensitivity", 1.0) as float, 1.5, 1e-6)
	assert_eq(second.get_value("settings", "count", 0), 3)
	assert_false(_fs.exists("user://save.cfg.tmp"))
