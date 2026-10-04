## The thin node driver of Save & Persistence (ADR-0007). It owns no rules: it runs the core's boot load once at
## construction (before the node can be observed in a scene tree) and calls `flush()` once per `app_backgrounded`.
##
## `GameRoot` builds it second, right after Platform Services. It is never an autoload and has no interface to
## Run State. `app_foregrounded`, `app_interrupted` and `app_returned` are deliberately not connected.
class_name SaveService
extends Node

var _core: SaveCore


## The real file-system implementation of `SaveFs` (ADR-0007): the only place in `src/` that calls
## `ConfigFile`, `FileAccess` or `DirAccess`. `redirect_dir` is empty in production; tests pass a per-test
## directory and every `user://` path is remapped under it.
class RealSaveFs:
	extends SaveFs

	const USER_PREFIX: String = "user://"

	var _redirect_dir: String

	## Example: `SaveService.RealSaveFs.new()` in production, `.new("user://test_1")` in an integration test.
	func _init(redirect_dir: String = "") -> void:
		_redirect_dir = redirect_dir.trim_suffix("/")

	## Reads a config into `{"status", "sections"}`; a fresh `ConfigFile` per read.
	func read_config(path: String) -> Dictionary:
		var cfg: ConfigFile = ConfigFile.new()
		var err: Error = cfg.load(_map(path))
		if err == ERR_FILE_NOT_FOUND:
			return {"status": "MISSING", "sections": {}}
		if err != OK:
			return {"status": "PARSE_ERROR", "sections": {}}
		var sections: Dictionary = {}
		for section: String in cfg.get_sections():
			var entries: Dictionary = {}
			for key: String in cfg.get_section_keys(section):
				entries[key] = cfg.get_value(section, key)
			sections[section] = entries
		return {"status": "OK", "sections": sections}

	## Writes the complete section map; true only when `ConfigFile.save` returns `OK`.
	func write_config(path: String, sections: Dictionary) -> bool:
		var cfg: ConfigFile = ConfigFile.new()
		for section: Variant in sections:
			var entries: Variant = sections[section]
			if typeof(entries) != TYPE_DICTIONARY:
				continue
			for key: Variant in (entries as Dictionary):
				cfg.set_value(str(section), str(key), (entries as Dictionary)[key])
		return cfg.save(_map(path)) == OK

	## True when the file exists.
	func exists(path: String) -> bool:
		return FileAccess.file_exists(_map(path))

	## Byte length, or -1 when the file cannot be opened.
	func size(path: String) -> int:
		var file: FileAccess = FileAccess.open(_map(path), FileAccess.READ)
		if file == null:
			return -1
		var length: int = file.get_length()
		file.close()
		return length

	## Renames, replacing an existing target.
	func rename(from: String, to: String) -> bool:
		return DirAccess.rename_absolute(_map(from), _map(to)) == OK

	## Deletes a file.
	func delete(path: String) -> bool:
		return DirAccess.remove_absolute(_map(path)) == OK

	## Lists the file names in `dir` that start with `prefix`.
	func list_backups(dir: String, prefix: String) -> PackedStringArray:
		var found: PackedStringArray = PackedStringArray()
		var access: DirAccess = DirAccess.open(_map(dir))
		if access == null:
			return found
		for file_name: String in access.get_files():
			if file_name.begins_with(prefix):
				found.append(file_name)
		return found

	func _map(path: String) -> String:
		if _redirect_dir.is_empty() or not path.begins_with(USER_PREFIX):
			return path
		return _redirect_dir + "/" + path.substr(USER_PREFIX.length())


## `source` is the Platform-Services-shaped signal source (anything with an `app_backgrounded` signal).
## Runs `core.boot_load()` synchronously, exactly once, then connects `app_backgrounded`.
## Example: `SaveService.new(core, platform_services)`.
func _init(core: SaveCore, source: Object) -> void:
	_core = core
	_core.boot_load()
	if source != null and source.has_signal(&"app_backgrounded"):
		source.connect(&"app_backgrounded", _on_app_backgrounded)


## The core this node drives (read-only for dependents).
func get_core() -> SaveCore:
	return _core


## Converts the platform's `clock_us` (integer microseconds) to the float seconds the core's clock uses.
## Example: `SaveService.us_to_seconds(1_500_000)` is `1.5`.
static func us_to_seconds(clock_us: int) -> float:
	return float(clock_us) / 1_000_000.0


func _on_app_backgrounded() -> void:
	_core.flush()
