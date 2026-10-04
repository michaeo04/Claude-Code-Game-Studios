## Glue between Run State events and `TiltCore` (Tilt Input story 012, ADR-0002 Decision 6).
##
## Pure and engine-free. The composition root connects Run State signals to the `on_*` handlers (immediate
## connections, from one `_wire()` table) and calls `flush()` once per frame after `TiltCore.poll()` and before
## `RunStateCore.tick()`. Handlers only forward; the sensor-lost pause is requested from `flush()`, never from a
## Run State handler (Run State rejects requests sent from inside its handlers).
class_name TiltRunAdapter
extends RefCounted

## Logged once per invalid seam Callable at construction.
const LOG_SEAM_INVALID: StringName = &"TILT_ADAPTER_SEAM_INVALID"

var _tilt: TiltCore
var _request_pause: Callable
var _phase_source: Callable
var _previous_phase: TiltCore.PreviousPhase = TiltCore.PreviousPhase.UNKNOWN


## `request_pause(source: int)` forwards to `RunStateCore.request_pause`; `phase_source() -> int` returns the
## current `RunStateCore.Phase`. An invalid Callable logs one error through `log_sink` and disables `flush()`.
func _init(tilt: TiltCore, request_pause: Callable, phase_source: Callable, log_sink: Callable = Callable()) -> void:
	_tilt = tilt
	_request_pause = request_pause
	_phase_source = phase_source
	if not request_pause.is_valid():
		_log(log_sink, "request_pause is not a valid Callable")
	if not phase_source.is_valid():
		_log(log_sink, "phase_source is not a valid Callable")
	else:
		_previous_phase = _map_phase(phase_source.call() as int)


## Once per frame: while the phase is Running or Resuming and the tilt output is invalid, requests a pause with
## `PauseSource.SENSOR_LOST` (at most one request per call).
func flush() -> void:
	if not _request_pause.is_valid() or not _phase_source.is_valid():
		return
	if TiltMath.sensor_lost_pause_needed(_phase_source.call() as int, _tilt.get_valid()):
		_request_pause.call(RunStateCore.PauseSource.SENSOR_LOST)


## `run_reset`: forwards the phase that was current before the reset (cached from `phase_changed`).
func on_run_reset(_run_id: int) -> void:
	_tilt.on_run_reset(_previous_phase)


## `run_started`.
func on_run_started(_run_id: int) -> void:
	_tilt.on_run_started()


## `run_resumed`.
func on_run_resumed(_run_id: int) -> void:
	_tilt.on_run_resumed()


## `run_ended`.
func on_run_ended(_run_id: int, _hazard_id: int, _run_time_ms: int) -> void:
	_tilt.on_run_stopped()


## `run_paused`.
func on_run_paused(_source: int) -> void:
	_tilt.on_run_stopped()


## `phase_changed` (emitted after `run_reset`): refreshes the previous-phase cache.
func on_phase_changed(new_phase: int, _old_phase: int) -> void:
	_previous_phase = _map_phase(new_phase)


func _map_phase(phase: int) -> TiltCore.PreviousPhase:
	match phase:
		RunStateCore.Phase.BOOT:
			return TiltCore.PreviousPhase.BOOT
		RunStateCore.Phase.MENU:
			return TiltCore.PreviousPhase.MENU
		RunStateCore.Phase.HIT:
			return TiltCore.PreviousPhase.HIT
		RunStateCore.Phase.PAUSED:
			return TiltCore.PreviousPhase.PAUSED
		_:
			return TiltCore.PreviousPhase.UNKNOWN


func _log(log_sink: Callable, message: String) -> void:
	if log_sink.is_valid():
		log_sink.call(LogLevel.ERROR, LOG_SEAM_INVALID, "tilt_run_adapter", message)
