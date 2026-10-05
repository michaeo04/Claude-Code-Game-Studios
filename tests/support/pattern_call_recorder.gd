## Recording double for the read-only accessors Pattern & Difficulty may use (Run State `run_time`, Tube Track `L`).
## `run_time()` is handed to the core as its run-time `Callable`; every call is logged by name. Framework-free.
extends RefCounted

## Run time answered to every call.
var value: float = 0.0
## Names of every accessor called, in order.
var calls: Array[StringName] = []


func run_time() -> float:
	calls.append(&"run_time")
	return value


## True when every recorded call is one of the read-only accessors in `allowed`.
func only_called(allowed: Array[StringName]) -> bool:
	for call_name: StringName in calls:
		if not allowed.has(call_name):
			return false
	return true
