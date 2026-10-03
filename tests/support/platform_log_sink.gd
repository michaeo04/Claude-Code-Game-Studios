## Recording sink for `log_sink(level, code, key, message)` seams (Platform Services, Save & Persistence).
##
## Framework-free: no GUT call.
extends RefCounted

## One entry per call: `[level, code, key, message]`.
var entries: Array[Array] = []


## The injected `log_sink` callable target.
func sink(level: int, code: StringName, key: String, message: String) -> void:
	entries.append([level, code, key, message])


## Number of lines recorded.
func count() -> int:
	return entries.size()
