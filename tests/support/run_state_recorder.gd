## Ordered signal recorder for Run State tests (test plan section 3).
##
## Connects one typed handler to each of the 9 signals of a `RunStateCore` and appends
## `[name: String, args: Array]` to an ordered Array that several recorders may share, so cross-signal
## order is preserved. It also notes the core phase seen inside each handler and calls an optional `hook`
## (`hook.call(event_name)`) at the end of every handler, which lets a test act from inside a handler.
## Framework-free (ADR-0009 Decision 1): no GUT call. Holds the core only through a WeakRef, so the
## connection creates no reference cycle.
extends RefCounted

## Ordered events: `[name, args]`. Pass the same Array to several recorders to interleave them.
var events: Array[Array]
## `core.phase` read inside each handler, parallel to `events` of this recorder only.
var phases_seen: Array[int] = []
## Optional `func(event_name: String) -> void`, called at the end of every handler.
var hook: Callable

var _core_ref: WeakRef


func _init(core: RunStateCore, shared_events: Array[Array] = []) -> void:
	events = shared_events
	_core_ref = weakref(core)
	core.run_reset.connect(_on_run_reset)
	core.run_started.connect(_on_run_started)
	core.run_paused.connect(_on_run_paused)
	core.run_resuming.connect(_on_run_resuming)
	core.run_resumed.connect(_on_run_resumed)
	core.run_ended.connect(_on_run_ended)
	core.run_abandoned.connect(_on_run_abandoned)
	core.restart_unlocked.connect(_on_restart_unlocked)
	core.phase_changed.connect(_on_phase_changed)


## Forgets every recorded event (also clears a shared Array).
func clear() -> void:
	events.clear()
	phases_seen.clear()


## Event names in order.
func names() -> Array[String]:
	var out: Array[String] = []
	for entry: Array in events:
		out.append(entry[0] as String)
	return out


func _record(event_name: String, args: Array) -> void:
	events.append([event_name, args])
	var core: RunStateCore = _core_ref.get_ref() as RunStateCore
	phases_seen.append(core.phase if core != null else -1)
	if hook.is_valid():
		hook.call(event_name)


func _on_run_reset(run_id: int) -> void:
	_record("run_reset", [run_id])


func _on_run_started(run_id: int) -> void:
	_record("run_started", [run_id])


func _on_run_paused(source: int) -> void:
	_record("run_paused", [source])


func _on_run_resuming(duration_ms: int) -> void:
	_record("run_resuming", [duration_ms])


func _on_run_resumed(run_id: int) -> void:
	_record("run_resumed", [run_id])


func _on_run_ended(run_id: int, hazard_id: int, run_time_ms: int) -> void:
	_record("run_ended", [run_id, hazard_id, run_time_ms])


func _on_run_abandoned(run_id: int, run_time_ms: int) -> void:
	_record("run_abandoned", [run_id, run_time_ms])


func _on_restart_unlocked(run_id: int) -> void:
	_record("restart_unlocked", [run_id])


func _on_phase_changed(new_phase: int, old_phase: int) -> void:
	_record("phase_changed", [new_phase, old_phase])
