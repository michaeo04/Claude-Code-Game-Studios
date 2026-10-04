## Recording subscriber with typed handlers for the `_wire()` order tests; one shared log across spies.
##
## Framework-free: no GUT call. `on_untyped_reset` has an untyped parameter on purpose (validation fixture).
extends RefCounted

var _name: String
var _log: Array[String]


func _init(spy_name: String, shared_log: Array[String]) -> void:
	_name = spy_name
	_log = shared_log


func on_run_reset(_run_id: int) -> void:
	_log.append(_name + ".run_reset")


func on_run_ended(_run_id: int, _hazard_id: int, _run_time_ms: int) -> void:
	_log.append(_name + ".run_ended")


func on_run_abandoned(_run_id: int, _run_time_ms: int) -> void:
	_log.append(_name + ".run_abandoned")


func on_untyped_reset(_run_id) -> void:
	_log.append(_name + ".untyped")
