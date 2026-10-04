## Maps Run State events to `TubeWindow` lifecycle calls (Tube Track story 010, ADR-0013 Decision 3).
##
## Pure and engine-free. The composition root connects the Run State signals to these handlers, after
## `WorldFrame.on_run_reset` (rank 1) for `run_reset`. A pause when Tube Track is already Paused, and the
## Boot to Menu `to_idle`, are skipped without an error.
class_name TubeRunAdapter
extends RefCounted

var _window: TubeWindow
var _world_frame: WorldFrame


func _init(window: TubeWindow, world_frame: WorldFrame) -> void:
	_window = window
	_world_frame = world_frame


## `run_reset`: primes the window at `s = 0` (`begin_run`).
func on_run_reset(_run_id: int) -> void:
	_window.begin_run()


## `run_paused`: Running to Paused; skipped when the window is not Running (for example already Paused).
func on_run_paused(_source: int) -> void:
	if _window.get_state() == TubeWindow.State.RUNNING:
		_window.pause()


## `run_resumed`: Paused to Running.
func on_run_resumed(_run_id: int) -> void:
	if _window.get_state() == TubeWindow.State.PAUSED:
		_window.resume()


## `run_ended`: Running to Ended.
func on_run_ended(_run_id: int, _hazard_id: int, _run_time_ms: int) -> void:
	if _window.get_state() == TubeWindow.State.RUNNING:
		_window.end_run()


## `phase_changed`: a return to Menu (not from Boot) resets the render origin, then re-primes the idle slots.
func on_phase_changed(new_phase: int, old_phase: int) -> void:
	if new_phase != RunStateCore.Phase.MENU or old_phase == RunStateCore.Phase.BOOT:
		return
	_world_frame.reset()
	_window.to_idle()
