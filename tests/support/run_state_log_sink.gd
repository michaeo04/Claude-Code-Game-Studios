## Recording log sink for Run State tests: collects every `(level, message)` the core logs.
##
## Framework-free (ADR-0009 Decision 1): no GUT call. The core is built with `sink` as its `log_sink`.
extends RefCounted

## One entry per logged line: `[level: int, message: String]`.
var entries: Array[Array] = []


## The injected `log_sink(level, message)` callable target.
func sink(level: int, message: String) -> void:
	entries.append([level, message])


## Forgets everything logged so far.
func clear() -> void:
	entries.clear()


## Number of lines logged since the last `clear()`.
func count() -> int:
	return entries.size()


## Level of the line at `index`.
func level_at(index: int) -> int:
	return entries[index][0] as int


## Message of the line at `index`.
func message_at(index: int) -> String:
	return entries[index][1] as String


## Number of lines whose level equals `level`.
func count_level(level: int) -> int:
	var total: int = 0
	for entry: Array in entries:
		if (entry[0] as int) == level:
			total += 1
	return total
