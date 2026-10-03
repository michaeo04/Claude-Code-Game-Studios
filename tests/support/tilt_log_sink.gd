## Recording sink for `log_sink(level, code, detail)` seams of Tilt Input.
##
## Framework-free: no GUT call.
extends RefCounted

## One entry per call: `[level, code, detail]`.
var entries: Array[Array] = []


## The injected `log_sink` callable target.
func sink(level: int, code: StringName, detail: String) -> void:
	entries.append([level, code, detail])


## Number of lines recorded.
func count() -> int:
	return entries.size()


## Code of line `i`.
func code_at(i: int) -> StringName:
	return entries[i][1] as StringName
