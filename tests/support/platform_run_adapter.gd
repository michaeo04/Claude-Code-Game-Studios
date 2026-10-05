## Test-only adapter between PlatformCore signals and Run State requests (Platform Services GDD, integration harness).
##
## INT becomes `pause_requested(app_interrupted)`, BACK becomes `pause_requested(back)`. The production adapter
## belongs to the composition-root epic. Framework-free: no GUT call.
extends RefCounted

var _run_state: RunStateCore


func _init(platform: PlatformCore, run_state: RunStateCore) -> void:
	_run_state = run_state
	platform.app_interrupted.connect(_on_interrupted)
	platform.back_pressed.connect(_on_back)


func _on_interrupted() -> void:
	_run_state.request_pause(RunStateCore.PauseSource.APP_INTERRUPTED)


func _on_back() -> void:
	_run_state.request_pause(RunStateCore.PauseSource.BACK)
