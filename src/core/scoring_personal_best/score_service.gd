## The thin node driver of Scoring (ADR-0002 Decision 5). It owns no rules: it forwards the Run State signals to
## `ScoreCore` and the once-per-tick `step()` from `GameRoot`. Never an autoload; it declares no per-frame callback.
##
## Two ways to connect it: pass a signal `source` to `_init` (the node connects itself, non-deferred, during
## construction), or leave `source` null and let `GameRoot._wire()` connect these typed handlers from its sorted row table.
class_name ScoreService
extends Node

var _core: ScoreCore


## `source` is anything with `run_reset(run_id)`, `run_ended(run_id, hazard_id, run_time_ms)` and
## `run_abandoned(run_id, run_time_ms)` signals, or null. Signals the source lacks are skipped.
## Example: `ScoreService.new(core, run_state)`.
func _init(core: ScoreCore, source: Object = null) -> void:
	_core = core
	if source == null:
		return
	if source.has_signal(&"run_reset"):
		source.connect(&"run_reset", on_run_reset)
	if source.has_signal(&"run_ended"):
		source.connect(&"run_ended", on_run_ended)
	if source.has_signal(&"run_abandoned"):
		source.connect(&"run_abandoned", on_run_abandoned)


## The core this node drives.
func get_core() -> ScoreCore:
	return _core


## Called once per tick by `GameRoot`, after the Ball Movement step.
func step() -> void:
	_core.step()


## Forwards `run_reset(run_id)`.
func on_run_reset(run_id: int) -> void:
	_core.on_run_reset(run_id)


## Forwards `run_ended(run_id, hazard_id, run_time_ms)`.
func on_run_ended(run_id: int, hazard_id: int, run_time_ms: int) -> void:
	_core.on_run_ended(run_id, hazard_id, run_time_ms)


## Forwards `run_abandoned(run_id, run_time_ms)`.
func on_run_abandoned(run_id: int, run_time_ms: int) -> void:
	_core.on_run_abandoned(run_id, run_time_ms)
