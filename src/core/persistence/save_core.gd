## The pure core of Save & Persistence (ADR-0007): in-memory sections, boot load, `get_value`, `set_value`.
##
## Every file operation goes through the injected `SaveFs`; time comes only from the injected `clock`
## (monotonic seconds). No engine call. The core never invents a default: a getter returns the stored value
## or the caller's own default. `config` is used as given (the owner passes a `validated()` copy).
class_name SaveCore
extends RefCounted

const REAL_PATH: String = "user://save.cfg"
const TMP_PATH: String = "user://save.cfg.tmp"
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
## Unusable files (parse error, incompatible schema) leave the memory empty; their logging and backup
## belong to stories 006 and 007.
func boot_load() -> void:
	_sections = {}
	if not _fs.exists(REAL_PATH):
		_log_sink.call(LEVEL_INFO, StringName(PersistMath.FILE_MISSING), "", "no save file; using defaults")
		return
	var result: Dictionary = _fs.read_config(REAL_PATH)
	if result.get("status", "PARSE_ERROR") != "OK":
		return
	var loaded: Variant = result.get("sections", {})
	if typeof(loaded) != TYPE_DICTIONARY:
		return
	var sections: Dictionary = (loaded as Dictionary).duplicate(true)
	var meta: Variant = sections.get(META_SECTION, {})
	var version: Variant = (meta as Dictionary).get(SCHEMA_KEY) if typeof(meta) == TYPE_DICTIONARY else null
	if not PersistMath.schema_compatible(version, current_schema_version):
		return
	_sections = sections


## Returns the stored value when it exists and has the same type as `default`, else `default` unchanged.
func get_value(section: String, key: String, default: Variant) -> Variant:
	var entries: Variant = _sections.get(section)
	if typeof(entries) != TYPE_DICTIONARY or not (entries as Dictionary).has(key):
		return default
	var stored: Variant = (entries as Dictionary)[key]
	if typeof(stored) != typeof(default):
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
