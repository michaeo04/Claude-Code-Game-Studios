## The file-system facade of Save & Persistence (ADR-0007 Key Interfaces).
##
## A plain base class, not `@abstract`: every method returns a failure value, so a core built on the bare
## base degrades safely. It holds no engine call; the real implementation (story 009) extends it, and test
## fakes extend it to record calls and script returns.
class_name SaveFs
extends RefCounted


## Reads a config file. Returns `{"status": "OK"|"MISSING"|"PARSE_ERROR", "sections": Dictionary}`.
func read_config(_path: String) -> Dictionary:
	return {"status": "PARSE_ERROR", "sections": {}}


## Writes the complete section map to `_path`. Returns false on failure.
func write_config(_path: String, _sections: Dictionary) -> bool:
	return false


## True when the file exists.
func exists(_path: String) -> bool:
	return false


## File size in bytes, or -1 when unknown.
func size(_path: String) -> int:
	return -1


## Renames `_from` to `_to`, replacing an existing target. Returns false on failure.
func rename(_from: String, _to: String) -> bool:
	return false


## Deletes a file. Returns false on failure.
func delete(_path: String) -> bool:
	return false


## Lists the corrupt-backup files in `_dir` whose names start with `_prefix`.
func list_backups(_dir: String, _prefix: String) -> PackedStringArray:
	return PackedStringArray()
