## Story CRF-007: an app interrupt sent while the core is busy is rejected visibly, never silently lost
## (GDD Core Rule 3 / AC-5: a request sent from inside a handler is rejected with one error-level log line).
extends GutTest

const Factory = preload("res://tests/support/run_state_factory.gd")

const S = Factory.State
const P = RunStateCore.Phase


func test_interrupt_from_run_started_handler_is_rejected_with_error_and_counter() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.MENU)
	rig.send("start")
	var rig_ref: Factory = rig
	rig.recorder.hook = func(name: String) -> void:
		if name == "run_started":
			rig_ref.core.request_pause(RunStateCore.PauseSource.APP_INTERRUPTED)
	var errors_before: int = rig.logs.count_level(LogLevel.ERROR)
	rig.tick()
	assert_eq(rig.core.phase, P.RUNNING, "rejected, not applied mid-emission")
	assert_eq(rig.logs.count_level(LogLevel.ERROR) - errors_before, 1, "one error line")
	assert_eq(rig.core.nested_request_rejections, 1, "the rejection is counted")


func test_interrupt_after_the_handler_returns_pauses() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.MENU)
	rig.send("start")
	rig.tick()
	rig.core.request_pause(RunStateCore.PauseSource.APP_INTERRUPTED)
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(rig.core.nested_request_rejections, 0)


func test_every_nested_request_kind_is_counted() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RUNNING)
	rig.send("pause")
	var rig_ref: Factory = rig
	rig.recorder.hook = func(name: String) -> void:
		if name == "run_paused":
			rig_ref.send("resume")
			rig_ref.send("pause_app")
	rig.tick()
	assert_eq(rig.core.nested_request_rejections, 2)
