## In-memory `SaveFs` that really keeps files, so a second `SaveCore` can cold-boot from what the first wrote.
## Framework-free (ADR-0009): no GUT call. `fail_writes` makes every `write_config` fail.
extends SaveFs

## Path to the section map stored there.
var files: Dictionary = {}
## When true, `write_config` returns false and stores nothing.
var fail_writes: bool = false
## Number of `write_config` calls (successful or not).
var write_calls: int = 0


func read_config(path: String) -> Dictionary:
	if not files.has(path):
		return {"status": "MISSING", "sections": {}}
	return {"status": "OK", "sections": (files[path] as Dictionary).duplicate(true)}


func write_config(path: String, sections: Dictionary) -> bool:
	write_calls += 1
	if fail_writes:
		return false
	files[path] = sections.duplicate(true)
	return true


func exists(path: String) -> bool:
	return files.has(path)


func size(path: String) -> int:
	return 100 if files.has(path) else -1


func rename(from: String, to: String) -> bool:
	if not files.has(from):
		return false
	files[to] = files[from]
	files.erase(from)
	return true


func delete(path: String) -> bool:
	files.erase(path)
	return true


func list_backups(_dir: String, _prefix: String) -> PackedStringArray:
	return PackedStringArray()
