## Recording stand-in for any system `GameRoot._tick()` calls (CR-002).
##
## Framework-free: no GUT call. Every call appends `"<name>.<method>"` to the shared log.
extends RefCounted

## Phase reported to `_tick()` (an int of `RunStateCore.Phase`); only the run-state spy uses it.
var phase: int = 0
## Distance reported by the ball spy.
var s: float = 0.0
## Value returned by `maybe_rebase`.
var rebase_result: bool = false

var _name: String
var _log: Array[String]


func _init(system_name: String, shared_log: Array[String]) -> void:
	_name = system_name
	_log = shared_log


func poll() -> void:
	_log.append(_name + ".poll")


func flush() -> void:
	_log.append(_name + ".flush")


func tick(_a: float = 0.0, _b: float = 0.0) -> void:
	_log.append(_name + ".tick")


func step(_a: float = 0.0) -> void:
	_log.append(_name + ".step")


func advance(_a: float = 0.0) -> void:
	_log.append(_name + ".advance")


func test() -> void:
	_log.append(_name + ".test")


func idle_step(_real_dt: float) -> void:
	_log.append(_name + ".idle_step")


func rebase() -> void:
	_log.append(_name + ".rebase")


func maybe_rebase(_s: float) -> bool:
	_log.append(_name + ".maybe_rebase")
	return rebase_result
