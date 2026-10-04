## The one log-severity scale and the one log-sink contract shared by every core and config.
##
## Sink contract (every `log_sink` Callable in `src/core/`):
## `log_sink.call(level: int, code: StringName, key: String, message: String)`
## - `level`: a member of this class (`LogLevel.DEBUG` .. `LogLevel.ERROR`);
## - `code`: the machine-checked log code (a `StringName` constant of the emitting module);
## - `key`: what the line is about (field, slot, event name), or "" when the code says it all;
## - `message`: the human-readable detail.
## No module defines its own level numbers (lint rule `forbidden:private_log_level_constants`).
class_name LogLevel
extends RefCounted

## Severity scale, lowest first. Usage: `LogLevel.WARNING`.
enum { DEBUG, INFO, WARNING, ERROR }


## Upper-case name of `level` ("DEBUG", "INFO", "WARNING", "ERROR"), or "UNKNOWN".
static func name_of(level: int) -> String:
	match level:
		DEBUG:
			return "DEBUG"
		INFO:
			return "INFO"
		WARNING:
			return "WARNING"
		ERROR:
			return "ERROR"
	return "UNKNOWN"
