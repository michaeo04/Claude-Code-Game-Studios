## Recording, STRICT stand-in for any system `GameRoot._tick()` calls (CR-002, CRF-002).
##
## Framework-free: no GUT call. Every call appends `"<name>.<method>"` to the shared log and stores its
## arguments in `last_args`. Every method is variadic and checks the argument count and types against its
## signature (`set_signature`); a wrong call appends a line to `errors` instead of failing silently, so a test
## asserts `errors.is_empty()`.
extends RefCounted

## Phase reported to `_tick()` (an int of `RunStateCore.Phase`); only the run-state spy uses it.
var phase: int = 0
## Distance reported by the ball spy.
var s: float = 0.0
## Value returned by `maybe_rebase`.
var rebase_result: bool = false
## Value returned by `tick` (the `dt_eff` of the run-state spy).
var dt_eff_result: float = 0.0
## Tilt outputs published by the tilt-input spy.
var steer_result: float = 0.0
var valid_result: bool = true
var input_source_result: int = 0
## Wrong calls recorded as text (empty when every call matched its signature).
var errors: Array[String] = []
## Arguments of the last call per method name.
var last_args: Dictionary = {}

var _name: String
var _log: Array[String]
var _signatures: Dictionary = {
	"poll": [], "flush": [], "tick": [], "step": [], "advance": [TYPE_FLOAT], "test": [],
	"idle_step": [TYPE_FLOAT], "rebase": [], "maybe_rebase": [TYPE_FLOAT],
	"get_steer": [], "get_valid": [], "get_input_source": [],
}


func _init(system_name: String, shared_log: Array[String]) -> void:
	_name = system_name
	_log = shared_log


## Replaces the expected argument types (`TYPE_*`) of `method_name`; the count is the array size.
func set_signature(method_name: String, types: Array[int]) -> void:
	_signatures[method_name] = types


func poll(...args: Array) -> void:
	_record("poll", args, true)


func flush(...args: Array) -> void:
	_record("flush", args, true)


func tick(...args: Array) -> float:
	_record("tick", args, true)
	return dt_eff_result


func step(...args: Array) -> void:
	_record("step", args, true)


func advance(...args: Array) -> void:
	_record("advance", args, true)


func test(...args: Array) -> void:
	_record("test", args, true)


func idle_step(...args: Array) -> void:
	_record("idle_step", args, true)


func rebase(...args: Array) -> void:
	_record("rebase", args, true)


func maybe_rebase(...args: Array) -> bool:
	_record("maybe_rebase", args, true)
	return rebase_result


func get_steer(...args: Array) -> float:
	_record("get_steer", args, false)
	return steer_result


func get_valid(...args: Array) -> bool:
	_record("get_valid", args, false)
	return valid_result


func get_input_source(...args: Array) -> int:
	_record("get_input_source", args, false)
	return input_source_result


func _record(method_name: String, args: Array, logged: bool) -> void:
	if logged:
		_log.append(_name + "." + method_name)
	last_args[method_name] = args
	var expected: Array = _signatures[method_name]
	if args.size() != expected.size():
		errors.append("%s.%s: expected %d arguments, got %d" % [_name, method_name, expected.size(), args.size()])
		return
	for i: int in expected.size():
		if typeof(args[i]) != (expected[i] as int):
			errors.append("%s.%s: argument %d has type %d, expected %d" % [
				_name, method_name, i, typeof(args[i]), expected[i] as int])
