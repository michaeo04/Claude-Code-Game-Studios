## The one recording sink for the shared `log_sink(level, code, key, message)` contract (`LogLevel`).
##
## Serves every core and config test. Framework-free: no GUT call.
extends RefCounted

## One entry per call: `[level: int, code: StringName, key: String, message: String]`.
var entries: Array[Array] = []


## The injected `log_sink` callable target.
func sink(level: int, code: StringName, key: String, message: String) -> void:
	entries.append([level, code, key, message])


## Forgets everything recorded so far.
func clear() -> void:
	entries.clear()


## Number of lines recorded.
func count() -> int:
	return entries.size()


## Level of the line at `index`.
func level_at(index: int) -> int:
	return entries[index][0] as int


## Code of the line at `index`.
func code_at(index: int) -> StringName:
	return entries[index][1] as StringName


## Key of the line at `index`.
func key_at(index: int) -> String:
	return entries[index][2] as String


## Message of the line at `index`.
func message_at(index: int) -> String:
	return entries[index][3] as String


## Number of lines whose code equals `code`.
func count_code(code: StringName) -> int:
	var total: int = 0
	for entry: Array in entries:
		if (entry[1] as StringName) == code:
			total += 1
	return total


## Number of lines whose level equals `level`.
func count_level(level: int) -> int:
	var total: int = 0
	for entry: Array in entries:
		if (entry[0] as int) == level:
			total += 1
	return total
