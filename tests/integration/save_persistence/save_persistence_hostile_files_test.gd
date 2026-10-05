## Story SP-011: SP-2 desktop sweep. Hostile save files go through the real SaveService boot-load path
## (RealSaveFs, real ConfigFile) in a per-test directory under user://. Every case must load cleanly or be
## rejected with the right Rule 7 code, in bounded time, and no oversized file may reach `read_config`.
extends GutTest

const Fixture = preload("res://tests/support/save_fixture.gd")
const SinkStub = preload("res://tests/support/platform_log_sink.gd")
const Probe = preload("res://tests/support/hostile_saves/sp2_side_effect_probe.gd")
const HOSTILE_DIR: String = "res://tests/support/hostile_saves/"
const WALL_TIME_BOUND_MS: int = 2000


## Wraps the real file system and counts `read_config` calls (the "oversized never reaches the parser" proof).
class SpyFs:
	extends SaveFs

	var real: SaveService.RealSaveFs
	var read_calls: int = 0

	func _init(real_fs: SaveService.RealSaveFs) -> void:
		real = real_fs

	func read_config(path: String) -> Dictionary:
		read_calls += 1
		return real.read_config(path)

	func write_config(path: String, sections: Dictionary) -> bool:
		return real.write_config(path, sections)

	func exists(path: String) -> bool:
		return real.exists(path)

	func size(path: String) -> int:
		return real.size(path)

	func rename(from: String, to: String) -> bool:
		return real.rename(from, to)

	func delete(path: String) -> bool:
		return real.delete(path)

	func list_backups(dir: String, prefix: String) -> PackedStringArray:
		return real.list_backups(dir, prefix)


var _dir: String = ""
var _spy: SpyFs
var _sink: SinkStub
var _core: SaveCore
var _elapsed_ms: int = 0


func before_each() -> void:
	_dir = "user://sp011_test_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_dir)
	_spy = SpyFs.new(SaveService.RealSaveFs.new(_dir))
	_sink = SinkStub.new()
	Probe.fired = false


func after_each() -> void:
	var access: DirAccess = DirAccess.open(_dir)
	if access != null:
		for file_name: String in access.get_files():
			DirAccess.remove_absolute(_dir + "/" + file_name)
	DirAccess.remove_absolute(_dir)


func _write_bytes(bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(_dir + "/save.cfg", FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _boot_fixture(file_name: String) -> void:
	_boot_bytes(FileAccess.get_file_as_bytes(HOSTILE_DIR + file_name))


func _boot_bytes(bytes: PackedByteArray) -> void:
	_write_bytes(bytes)
	_core = SaveCore.new(_spy, func() -> float: return 0.0, func() -> int: return 1000, _sink.sink, Fixture.make_save_fixture())
	_core.current_schema_version = 1
	var started: int = Time.get_ticks_msec()
	SaveService.new(_core, null)
	_elapsed_ms = Time.get_ticks_msec() - started


func _backups() -> int:
	return _spy.list_backups("user://", "save.cfg.corrupt-").size()


func _assert_rejected(code: String) -> void:
	assert_eq(_sink.count(), 1, "exactly one log line")
	assert_eq(_sink.code_at(0), StringName(code))
	assert_eq(_sink.level_at(0), LogLevel.ERROR)
	assert_eq(_backups(), 1, "unusable file moved aside")
	assert_false(_spy.exists("user://save.cfg"))
	assert_eq(_core.get_value("settings", "x", 42), 42, "defaults returned")
	assert_lt(_elapsed_ms, WALL_TIME_BOUND_MS)


func _padded(limit_bytes: int) -> PackedByteArray:
	var head: PackedByteArray = "[_meta]\nschema_version=1\n".to_utf8_buffer()
	var out: PackedByteArray = head.duplicate()
	var filler: PackedByteArray = ";pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp\n".to_utf8_buffer()
	while out.size() + filler.size() <= limit_bytes:
		out.append_array(filler)
	while out.size() < limit_bytes:
		out.append(0x0A)
	return out


func test_schema_version_string_is_rejected_schema_incompatible() -> void:
	_boot_fixture("schema_string.cfg")
	_assert_rejected(PersistMath.SCHEMA_INCOMPATIBLE)


func test_schema_version_array_is_rejected_schema_incompatible() -> void:
	_boot_fixture("schema_array.cfg")
	_assert_rejected(PersistMath.SCHEMA_INCOMPATIBLE)


func test_schema_version_bool_is_rejected_schema_incompatible() -> void:
	_boot_fixture("schema_bool.cfg")
	_assert_rejected(PersistMath.SCHEMA_INCOMPATIBLE)


func test_empty_file_is_rejected_schema_incompatible_and_backed_up() -> void:
	_boot_fixture("empty.cfg")
	_assert_rejected(PersistMath.SCHEMA_INCOMPATIBLE)


func test_typed_constructor_values_load_cleanly_as_plain_values() -> void:
	_boot_fixture("typed_constructors_value.cfg")
	assert_eq(_sink.count(), 0)
	assert_eq(_backups(), 0)
	assert_eq(_core.get_value("settings", "v", Vector2.ZERO), Vector2(1, 2))
	assert_lt(_elapsed_ms, WALL_TIME_BOUND_MS)


func test_object_payload_is_rejected_by_the_sniff_without_creating_an_object() -> void:
	var before: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	_boot_fixture("object_payload.cfg")
	_assert_rejected(PersistMath.FILE_UNREADABLE)
	assert_false(_core.get_value("settings", "x", 42) is Object)
	assert_lt(Performance.get_monitor(Performance.OBJECT_COUNT) - before, 50.0)


func test_script_object_payload_is_rejected_and_the_script_never_runs() -> void:
	_boot_fixture("object_script_payload.cfg")
	assert_false(Probe.fired, "parsing must not instantiate a script (GDD Open Question 1, confirmed without the sniff)")
	_assert_rejected(PersistMath.FILE_UNREADABLE)


func test_truncated_file_is_rejected_file_unreadable() -> void:
	_boot_fixture("truncated.cfg")
	assert_engine_error_count(1)
	_assert_rejected(PersistMath.FILE_UNREADABLE)


func test_binary_garbage_file_is_rejected_with_a_rule_7_code() -> void:
	var bytes: PackedByteArray = PackedByteArray()
	for i: int in range(4096):
		bytes.append((i * 37 + 11) % 256)
	_boot_bytes(bytes)
	# The real parser reads this payload as an empty config (no engine error), so Rule 7 rejects it as an
	# incompatible schema; a parse error (FILE_UNREADABLE) would be equally valid.
	assert_eq(_sink.count(), 1)
	assert_true(_sink.code_at(0) in [StringName(PersistMath.FILE_UNREADABLE), StringName(PersistMath.SCHEMA_INCOMPATIBLE)])
	assert_eq(_backups(), 1)
	assert_false(_spy.exists("user://save.cfg"))
	assert_lt(_elapsed_ms, WALL_TIME_BOUND_MS)


func test_file_exactly_at_size_max_is_parsed_and_loads_cleanly() -> void:
	var limit: int = Fixture.make_save_fixture().save_file_size_max
	_boot_bytes(_padded(limit))
	assert_eq(_spy.size("user://save.cfg"), limit)
	assert_eq(_spy.read_calls, 1)
	assert_eq(_sink.count(), 0)
	assert_eq(_backups(), 0)
	assert_lt(_elapsed_ms, WALL_TIME_BOUND_MS)


func test_file_one_byte_over_size_max_never_reaches_read_config() -> void:
	var limit: int = Fixture.make_save_fixture().save_file_size_max
	_boot_bytes(_padded(limit + 1))
	assert_eq(_spy.read_calls, 0, "oversized file must not reach the parser")
	_assert_rejected(PersistMath.FILE_UNREADABLE)


func test_far_oversized_file_never_reaches_read_config() -> void:
	_boot_bytes(_padded(4 * 1048576))
	assert_eq(_spy.read_calls, 0)
	_assert_rejected(PersistMath.FILE_UNREADABLE)
