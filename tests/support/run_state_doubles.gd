## Contract double of a Run State subscriber (Ball Movement, Obstacle System, Juice or Scoring), story RS-011.
##
## Connects to `run_reset`, `run_started` and `run_ended` of a `RunStateCore` and counts what it receives.
## `sequence_ok` stays true while every `run_reset` carries the previous id plus one. With
## `hit_on_started` set it sends a forbidden `request_hit` from inside its `run_started` handler.
## Framework-free (ADR-0009 Decision 1): no GUT call. Holds the core through a WeakRef (no reference cycle).
extends RefCounted

## Which system this double stands for (diagnostics only).
var kind: String
## Number of `run_reset` signals received.
var resets: int = 0
## Number of `run_started` signals received.
var starts: int = 0
## Number of `run_ended` signals received.
var ends: int = 0
## True while every reset id was the previous one plus one (the first must be 1).
var sequence_ok: bool = true
## When true, the double sends `request_hit` from its `run_started` handler.
var hit_on_started: bool = false

var _core_ref: WeakRef
var _last_id: int = 0


func _init(core: RunStateCore, system_kind: String) -> void:
	kind = system_kind
	_core_ref = weakref(core)
	core.run_reset.connect(_on_run_reset)
	core.run_started.connect(_on_run_started)
	core.run_ended.connect(_on_run_ended)


func _on_run_reset(run_id: int) -> void:
	resets += 1
	if run_id != _last_id + 1:
		sequence_ok = false
	_last_id = run_id


func _on_run_started(run_id: int) -> void:
	starts += 1
	if hit_on_started:
		var core: RunStateCore = _core_ref.get_ref() as RunStateCore
		if core != null:
			core.request_hit(0, run_id)


func _on_run_ended(_run_id: int, _hazard_id: int, _run_time_ms: int) -> void:
	ends += 1
