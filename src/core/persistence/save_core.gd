## The pure core of Save & Persistence (ADR-0007): in-memory sections, boot load, `get_value`, `set_value`.
##
## Every file operation goes through the injected `SaveFs`; time comes only from the injected `clock`
## (monotonic seconds). No engine call. The core never invents a default: a getter returns the stored value
## or the caller's own default. `config` is used as given (the owner passes a `validated()` copy).
class_name SaveCore
extends RefCounted

const REAL_PATH: String = "user://save.cfg"
const TMP_PATH: String = "user://save.cfg.tmp"
const SAVE_DIR: String = "user://"
const BACKUP_PREFIX: String = "save.cfg.corrupt-"
## Upper bound on the probes for a free backup name within one clock second (a safety stop, not a tuning knob).
const BACKUP_NAME_ATTEMPTS_MAX: int = 1000
const META_SECTION: String = "_meta"
const SCHEMA_KEY: String = "schema_version"

## Log levels passed to `log_sink` (same scale as `SaveConfig.LEVEL_ERROR`).
const LEVEL_INFO: int = 1
const LEVEL_ERROR: int = 2

## Schema version this core accepts and writes. Defaults to the build's version; a test may override it.
var current_schema_version: int = SaveConfig.CURRENT_SCHEMA_VERSION

var _fs: SaveFs
var _wall_clock: Callable
var _log_sink: Callable
var _config: SaveConfig
var _limiter: RateLimitedLog
## Section name to `Dictionary` of key to value. The complete map that is written on every `set_value`.
var _sections: Dictionary = {}
## Slots (`section/key`) whose `TYPE_MISMATCH` was already logged this load.
var _mismatch_logged: Dictionary = {}


## `clock` returns monotonic seconds (float); `wall_clock` returns Unix seconds (int);
## `log_sink(level: int, code: StringName, key: String, message: String)`.
func _init(fs: SaveFs, clock: Callable, wall_clock: Callable, log_sink: Callable, config: SaveConfig) -> void:
	_fs = fs
	_wall_clock = wall_clock
	_log_sink = log_sink
	_config = config
	var clock_us: Callable = func() -> int: return roundi(float(clock.call()) * 1_000_000.0)
	var window_us: int = roundi(config.save_log_rate_limit * 1_000_000.0) if is_finite(config.save_log_rate_limit) else -1
	_limiter = RateLimitedLog.new(log_sink, clock_us, window_us)


## Loads the save file once, synchronously, at boot. A missing file gives defaults and one INFO `FILE_MISSING`.
## A file-level failure (oversized or unknown size, parse error, incompatible schema) is logged once at ERROR
## (`FILE_UNREADABLE` > `SCHEMA_INCOMPATIBLE`), the file is renamed aside, old backups are rotated, and the
## memory stays empty so every read returns the caller's default.
func boot_load() -> void:
	_sections = {}
	_mismatch_logged = {}
	if not _fs.exists(REAL_PATH):
		_log_sink.call(LEVEL_INFO, StringName(PersistMath.FILE_MISSING), "", "no save file; using defaults")
		return
	var file_size: int = _fs.size(REAL_PATH)
	if file_size < 0 or file_size > _config.save_file_size_max:
		var why: String = "size unknown" if file_size < 0 else "oversized"
		_fail_file(PersistMath.FILE_UNREADABLE, "save file unreadable (%s)" % why)
		return
	var result: Dictionary = _fs.read_config(REAL_PATH)
	var loaded: Variant = result.get("sections", {})
	var parsed_ok: bool = result.get("status", "PARSE_ERROR") == "OK" and typeof(loaded) == TYPE_DICTIONARY
	if not parsed_ok:
		_fail_file(PersistMath.FILE_UNREADABLE, "save file could not be parsed")
		return
	var sections: Dictionary = (loaded as Dictionary).duplicate(true)
	var meta: Variant = sections.get(META_SECTION, {})
	var version: Variant = (meta as Dictionary).get(SCHEMA_KEY) if typeof(meta) == TYPE_DICTIONARY else null
	var compatible: bool = PersistMath.schema_compatible(version, current_schema_version)
	var code: String = PersistMath.read_error_code(parsed_ok, compatible, false, false)
	if not code.is_empty():
		_fail_file(code, "save file schema %s is incompatible with %d" % [str(version), current_schema_version])
		return
	_sections = sections


## Returns the stored value when it exists and has the same type as `default`, else `default` unchanged.
## An absent key logs nothing; a wrong-typed key logs one `TYPE_MISMATCH` the first time it is read.
func get_value(section: String, key: String, default: Variant) -> Variant:
	var entries: Variant = _sections.get(section)
	if typeof(entries) != TYPE_DICTIONARY or not (entries as Dictionary).has(key):
		return default
	var stored: Variant = (entries as Dictionary)[key]
	if typeof(stored) != typeof(default):
		var slot: String = "%s/%s" % [section, key]
		if not _mismatch_logged.has(slot):
			_mismatch_logged[slot] = true
			_log_sink.call(
				LEVEL_ERROR, StringName(PersistMath.TYPE_MISMATCH), slot, "stored value of %s has the wrong type" % slot
			)
		return default
	return stored


## Stores `value` and writes the complete map synchronously (temp file, size check, rename). Returns false
## when the value is unserializable (nothing changes) or the write fails (memory keeps the new value).
func set_value(section: String, key: String, value: Variant) -> bool:
	var slot: String = "%s/%s" % [section, key]
	if not PersistMath.is_serializable_type(value):
		_log_sink.call(LEVEL_ERROR, StringName(PersistMath.UNSERIALIZABLE_VALUE), slot, "value for %s cannot be saved" % slot)
		return false
	if typeof(_sections.get(section)) != TYPE_DICTIONARY:
		_sections[section] = {}
	(_sections[section] as Dictionary)[key] = value
	if typeof(_sections.get(META_SECTION)) != TYPE_DICTIONARY:
		_sections[META_SECTION] = {}
	var meta: Dictionary = _sections[META_SECTION]
	if not meta.has(SCHEMA_KEY):
		meta[SCHEMA_KEY] = current_schema_version
	if _fs.exists(TMP_PATH):
		_fs.delete(TMP_PATH)
	var written: bool = _fs.write_config(TMP_PATH, _sections.duplicate(true))
	if written and _fs.size(TMP_PATH) <= 0:
		written = false
	if written:
		written = _fs.rename(TMP_PATH, REAL_PATH)
	if not written:
		_limiter.emit(LEVEL_ERROR, StringName(PersistMath.WRITE_FAILED), slot, "could not save %s" % slot)
	return written


## Flush is a no-op: every `set_value` already wrote synchronously, so nothing is ever pending (ADR-0007).
## Makes zero `SaveFs` calls; a future async write path that adds a race must fail the AC-7 test.
## Example: `core.flush()` on `app_backgrounded`.
func flush() -> void:
	pass


## Logs a file-level failure once, moves the unusable file aside and rotates old backups.
func _fail_file(code: String, message: String) -> void:
	_log_sink.call(LEVEL_ERROR, StringName(code), "", message)
	var stamp: String = "%s%d-" % [SAVE_DIR + BACKUP_PREFIX, int(_wall_clock.call())]
	var n: int = 0
	while n < BACKUP_NAME_ATTEMPTS_MAX and _fs.exists("%s%d" % [stamp, n]):
		n += 1
	if n >= BACKUP_NAME_ATTEMPTS_MAX:
		# Every probed name is taken: leave the unusable file in place rather than loop without end.
		return
	if not _fs.rename(REAL_PATH, "%s%d" % [stamp, n]):
		return
	# Name order equals age order only while the Unix timestamps have the same digit count (10 digits until 2286).
	var names: Array[String] = []
	for backup: String in _fs.list_backups(SAVE_DIR, BACKUP_PREFIX):
		names.append(backup)
	names.sort()
	var excess: int = names.size() - _config.corrupt_backup_retention
	for i: int in range(maxi(excess, 0)):
		_fs.delete(SAVE_DIR + names[i])
