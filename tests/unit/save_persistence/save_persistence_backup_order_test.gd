## Story CRF-005: backup rotation orders by the numeric (sequence, timestamp) pair, survives a wall clock of 0 or one
## that goes backwards, and the bounded name probe stops when every name is taken.
extends GutTest

const FakeFs = preload("res://tests/support/fake_save_fs.gd")
const Fixture = preload("res://tests/support/save_fixture.gd")
const SinkStub = preload("res://tests/support/platform_log_sink.gd")

const PREFIX: String = "save.cfg.corrupt-"
const STAMP: int = 1700000000

var _fs: FakeFs
var _sink: SinkStub


func before_each() -> void:
	_fs = FakeFs.new()
	_sink = SinkStub.new()
	_fs.returns["size"] = 120
	_fs.returns["exists"] = true
	_fs.returns["read_config"] = {"status": "PARSE_ERROR", "sections": {}}


func _boot(wall: int, config: SaveConfig = Fixture.make_save_fixture()) -> void:
	var core: SaveCore = SaveCore.new(_fs, func() -> float: return 0.0, func() -> int: return wall, _sink.sink, config)
	core.current_schema_version = Fixture.CURRENT_SCHEMA_VERSION_TEST
	core.boot_load()


func _calls_of(method: String) -> Array[Array]:
	var out: Array[Array] = []
	for entry: Array in _fs.calls:
		if entry[0] == method:
			out.append(entry)
	return out


func _deleted() -> Array:
	var out: Array = []
	for entry: Array in _calls_of("delete"):
		out.append((entry[1] as Array)[0])
	return out


## Free names are only the ones the test marks existing: everything else "does not exist".
func _only_existing(names: PackedStringArray) -> void:
	var per_path: Dictionary = {}
	for n: String in names:
		per_path["user://" + n] = true
	per_path["user://save.cfg"] = true
	_fs.returns["exists"] = false
	_fs.returns["exists_by_path"] = per_path


func test_eleven_backups_in_one_second_rotate_oldest_first() -> void:
	var names: PackedStringArray = PackedStringArray()
	for i: int in 12:
		names.append("%s%d-%d" % [PREFIX, STAMP, i])
	_only_existing(names.slice(0, 11))
	_fs.returns["list_backups"] = names
	_boot(STAMP)
	assert_eq(_calls_of("rename")[0][1], ["user://save.cfg", "user://%s%d-12" % [PREFIX, STAMP]])
	var expected: Array = []
	for i: int in 9:
		expected.append("user://%s%d-%d" % [PREFIX, STAMP, i])
	assert_eq(_deleted(), expected)


func test_wall_clock_zero_does_not_make_newest_backup_oldest() -> void:
	var old: PackedStringArray = PackedStringArray([
		"%s%d-0" % [PREFIX, STAMP], "%s%d-1" % [PREFIX, STAMP], "%s%d-2" % [PREFIX, STAMP]
	])
	_only_existing(old)
	var after: PackedStringArray = old.duplicate()
	after.append(PREFIX + "0-3")
	_fs.returns["list_backups"] = after
	_boot(0)
	assert_eq(_calls_of("rename")[0][1], ["user://save.cfg", "user://" + PREFIX + "0-4"])
	assert_eq(_deleted(), ["user://%s%d-0" % [PREFIX, STAMP]])


func test_wall_clock_going_backwards_keeps_newest_backup() -> void:
	var old: PackedStringArray = PackedStringArray([PREFIX + "1700000100-0", PREFIX + "1700000100-1", PREFIX + "1700000100-2"])
	_only_existing(old)
	var after: PackedStringArray = old.duplicate()
	after.append(PREFIX + "1600000000-3")
	_fs.returns["list_backups"] = after
	_boot(1600000000)
	assert_eq(_deleted(), ["user://" + PREFIX + "1700000100-0"])


func test_exhausted_names_leave_file_in_place_and_stop() -> void:
	_fs.returns["exists"] = true
	_boot(STAMP)
	assert_eq(_calls_of("rename").size(), 0)
	assert_eq(_calls_of("delete").size(), 0)
	assert_eq(_calls_of("exists").size() - 1 <= SaveCore.BACKUP_NAME_ATTEMPTS_MAX, true)
