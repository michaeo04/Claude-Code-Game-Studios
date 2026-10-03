## Story RS-007: pause, resume countdown, Paused guard and abandon (GDD AC-15, AC-22, AC-23, AC-28, AC-29).
extends GutTest

const Factory = preload("res://tests/support/run_state_factory.gd")

const S = Factory.State
const P = RunStateCore.Phase
const Src = RunStateCore.PauseSource
const GUARD_US: int = 300_000
const DEBUG_LEVEL: int = RunStateMath.LogLevel.DEBUG
const ERROR_LEVEL: int = RunStateMath.LogLevel.ERROR
const PAUSED_EVENTS: Array[String] = ["run_paused", "phase_changed"]


func _rig(state: Factory.State) -> Factory:
	var rig: Factory = Factory.new()
	rig.core_in(state)
	return rig


# --- AC-15: countdown ---------------------------------------------------------------------------------------

func test_countdown_rows_at_0_and_0_7_seconds() -> void:
	var rig: Factory = _rig(S.RESUMING)
	assert_almost_eq(rig.core.resume_remaining(), 2.0, 1e-6)
	assert_eq(ceili(rig.core.resume_remaining()), 2)
	assert_almost_eq(rig.core.resume_progress(), 0.0, 1e-6)
	rig.clock.advance_us(700_000)
	assert_almost_eq(rig.core.resume_remaining(), 1.3, 1e-6)
	assert_eq(ceili(rig.core.resume_remaining()), 2)
	assert_almost_eq(rig.core.resume_progress(), 0.35, 1e-6)


func test_countdown_ends_at_2_seconds_with_remaining_0() -> void:
	var rig: Factory = _rig(S.RESUMING)
	rig.clock.advance_us(2_000_000)
	assert_almost_eq(rig.core.resume_remaining(), 0.0, 1e-6)
	rig.tick()
	assert_eq(rig.core.phase, P.RUNNING)
	assert_eq(rig.recorder.names(), ["run_resumed", "phase_changed"] as Array[String])


func test_countdown_static_helper_rows() -> void:
	assert_almost_eq(RunStateCore.progress_for(2.0, 0.0), 0.0, 1e-6)
	assert_almost_eq(RunStateCore.progress_for(2.0, 0.7), 0.35, 1e-6)
	assert_almost_eq(RunStateCore.progress_for(2.0, 2.0), 1.0, 1e-6)
	assert_almost_eq(RunStateCore.progress_for(2.0, 5.0), 1.0, 1e-6, "remaining clamped to 0")


func test_countdown_static_helper_duration_zero_or_less_gives_progress_1() -> void:
	assert_eq(RunStateCore.progress_for(0.0, 1.0), 1.0)
	assert_eq(RunStateCore.progress_for(-1.0, 0.0), 1.0)
	assert_true(is_finite(RunStateCore.progress_for(0.0, 0.0)))


func test_countdown_static_helper_negative_elapsed_stays_finite_and_in_range() -> void:
	var value: float = RunStateCore.progress_for(2.0, -1.0)
	assert_true(is_finite(value))
	assert_true(value >= 0.0 and value <= 1.0)


func test_countdown_interruption_at_1_5_s_then_resume_counts_full_2_seconds() -> void:
	var rig: Factory = _rig(S.RESUMING)
	rig.clock.advance_us(1_500_000)
	rig.tick()
	assert_eq(rig.core.phase, P.RESUMING)
	rig.send("pause_app")
	assert_eq(rig.core.phase, P.PAUSED)
	rig.recorder.clear()
	rig.send("resume")
	rig.tick()
	assert_eq(rig.core.phase, P.RESUMING)
	assert_eq(rig.recorder.names(), ["run_resuming", "phase_changed"] as Array[String])
	assert_eq(rig.recorder.events[0][1], [2000] as Array)
	assert_almost_eq(rig.core.resume_remaining(), 2.0, 1e-6)
	rig.clock.advance_us(1_999_999)
	rig.tick()
	assert_eq(rig.core.phase, P.RESUMING, "1.999999 s is not enough")
	rig.clock.advance_us(1)
	rig.tick()
	assert_eq(rig.core.phase, P.RUNNING)


func test_countdown_run_resuming_is_emitted_once_per_entry() -> void:
	var rig: Factory = _rig(S.PAUSED_INSIDE)
	rig.send("resume")
	rig.tick()
	rig.clock.advance_us(100_000)
	rig.tick()
	rig.tick()
	var count: int = 0
	for event_name: String in rig.recorder.names():
		if event_name == "run_resuming":
			count += 1
	assert_eq(count, 1)


# --- AC-22: run / pause / resume / abandon ------------------------------------------------------------------

func test_pause_resume_run_time_counts_only_running_time() -> void:
	var rig: Factory = _rig(S.RUNNING)
	var start_time: float = rig.core.run_time
	for i: int in range(10):
		rig.core.tick(0.1, Factory.DT)
	assert_almost_eq(rig.core.run_time, start_time + 1.0, 1e-6)
	rig.send("pause")
	rig.tick()
	rig.send("resume")
	rig.tick()
	rig.clock.advance_us(2_000_000)
	rig.tick() # countdown ends
	rig.tick() # settling tick
	for i: int in range(5):
		rig.core.tick(0.1, Factory.DT)
	assert_almost_eq(rig.core.run_time, start_time + 1.5, 1e-6)


func test_pause_second_resume_in_resuming_is_rejected() -> void:
	var rig: Factory = _rig(S.RESUMING)
	rig.send("resume")
	rig.tick()
	assert_eq(rig.core.phase, P.RESUMING)
	assert_eq(rig.recorder.events.size(), 0)
	assert_eq(rig.logs.count_level(DEBUG_LEVEL), 1)


func test_pause_on_the_settling_tick_is_accepted_with_run_time_0() -> void:
	var rig: Factory = _rig(S.MENU)
	rig.send("start")
	rig.tick()
	rig.recorder.clear()
	rig.send("pause")
	rig.tick() # the settling tick
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(rig.core.run_time_ms(), 0)
	assert_eq(rig.recorder.names(), PAUSED_EVENTS)


func test_pause_abandon_from_paused_menu_emits_run_abandoned_first_with_0_ms() -> void:
	var rig: Factory = _rig(S.MENU)
	rig.send("start")
	rig.tick()
	rig.send("pause")
	rig.tick()
	rig.recorder.clear()
	rig.clock.advance_us(GUARD_US)
	rig.send("menu")
	rig.tick()
	assert_eq(rig.recorder.events[0][0], "run_abandoned")
	assert_eq(rig.recorder.events[0][1], [1, 0] as Array)
	assert_eq(rig.core.phase, P.MENU)


func test_pause_abandon_from_paused_restart_emits_run_abandoned_before_run_reset() -> void:
	var rig: Factory = _rig(S.PAUSED_AFTER)
	rig.send("restart")
	rig.tick()
	var names: Array[String] = rig.recorder.names()
	assert_eq(names[0], "run_abandoned")
	assert_eq(names[1], "run_reset")
	assert_eq(rig.recorder.events[0][1][0], 1)


func test_pause_in_hit_or_menu_is_rejected() -> void:
	for state: Factory.State in [S.HIT_LOCKED, S.HIT_UNLOCKED, S.MENU]:
		var rig: Factory = _rig(state)
		var phase_before: RunStateCore.Phase = rig.core.phase
		rig.send("pause")
		rig.tick()
		assert_eq(rig.core.phase, phase_before)
		assert_false(rig.recorder.names().has("run_paused"))


func test_boot_without_map_ready_stays_boot_and_rejects_start() -> void:
	var rig: Factory = _rig(S.BOOT)
	rig.tick()
	assert_eq(rig.core.phase, P.BOOT)
	assert_eq(rig.recorder.events.size(), 0)
	rig.send("start")
	rig.tick()
	assert_eq(rig.core.phase, P.BOOT)
	assert_eq(rig.recorder.events.size(), 0)
	assert_eq(rig.logs.count(), 1, "one rejection line")


# --- AC-23: Back --------------------------------------------------------------------------------------------

func test_back_in_running_gives_run_paused_back() -> void:
	var rig: Factory = _rig(S.RUNNING)
	rig.send("pause_back")
	rig.tick()
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(rig.recorder.events[0], ["run_paused", [Src.BACK]] as Array)


func test_back_in_resuming_gives_paused() -> void:
	var rig: Factory = _rig(S.RESUMING)
	rig.send("pause_back")
	rig.tick()
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(rig.recorder.events[0], ["run_paused", [Src.BACK]] as Array)


func test_back_in_other_phases_is_a_silent_no_op() -> void:
	for state: Factory.State in [S.BOOT, S.MENU, S.PAUSED_INSIDE, S.PAUSED_AFTER, S.HIT_LOCKED, S.HIT_UNLOCKED]:
		var rig: Factory = _rig(state)
		var phase_before: RunStateCore.Phase = rig.core.phase
		rig.send("pause_back")
		rig.tick()
		assert_eq(rig.core.phase, phase_before)
		assert_eq(rig.recorder.events.size(), 0, "state %d" % state)
		assert_eq(rig.logs.count(), 0, "state %d" % state)


# --- AC-28: Paused guard -----------------------------------------------------------------------------------

func _leave_accepted(kind: String, press_offset_us: int) -> bool:
	var rig: Factory = _rig(S.PAUSED_INSIDE)
	rig.clock.now_us = rig.anchor_us + press_offset_us
	rig.send(kind)
	rig.tick()
	return rig.core.phase != P.PAUSED


func test_guard_boundary_299999_rejected_300000_accepted() -> void:
	for kind: String in ["restart", "menu"]:
		assert_false(_leave_accepted(kind, GUARD_US - 1), kind)
		assert_true(_leave_accepted(kind, GUARD_US), kind)


func test_guard_rejection_is_debug_logged_without_event() -> void:
	var rig: Factory = _rig(S.PAUSED_INSIDE)
	rig.clock.now_us = rig.anchor_us + GUARD_US - 1
	rig.send("restart")
	rig.tick()
	assert_eq(rig.recorder.events.size(), 0)
	assert_eq(rig.logs.count_level(DEBUG_LEVEL), 1)
	assert_true(rig.logs.message_at(0).begins_with(String(RunStateMath.LOG_REQUEST_LOCKED)))


func test_guard_accepted_restart_emits_run_abandoned_first() -> void:
	var rig: Factory = _rig(S.PAUSED_INSIDE)
	rig.clock.now_us = rig.anchor_us + GUARD_US
	rig.send("restart")
	rig.tick()
	assert_eq(rig.recorder.names()[0], "run_abandoned")


func test_guard_resume_is_accepted_at_any_time() -> void:
	var rig: Factory = _rig(S.PAUSED_INSIDE)
	rig.send("resume")
	rig.tick()
	assert_eq(rig.core.phase, P.RESUMING)


func test_guard_resume_wins_a_same_tick_tie_against_restart_and_menu() -> void:
	for kind: String in ["restart", "menu"]:
		var rig: Factory = _rig(S.PAUSED_INSIDE)
		rig.clock.now_us = rig.anchor_us + GUARD_US
		rig.send(kind)
		rig.send("resume")
		rig.tick()
		assert_eq(rig.core.phase, P.RESUMING, kind)
		assert_false(rig.recorder.names().has("run_abandoned"), kind)


func test_guard_app_interrupted_anchors_at_the_send_not_the_tick() -> void:
	var rig: Factory = _rig(S.RUNNING)
	var sent_us: int = rig.clock.now_us
	rig.send("pause_app")
	rig.clock.advance_us(200_000)
	rig.tick()
	rig.clock.now_us = sent_us + GUARD_US - 1
	rig.send("restart")
	rig.tick()
	assert_eq(rig.core.phase, P.PAUSED, "299,999 us after the send")
	rig.clock.now_us = sent_us + GUARD_US
	rig.send("restart")
	rig.tick()
	assert_ne(rig.core.phase, P.PAUSED, "300,000 us after the send")


func test_guard_restarts_when_resuming_goes_back_to_paused() -> void:
	var rig: Factory = _rig(S.RESUMING)
	rig.clock.advance_us(1_000_000)
	var interrupted_us: int = rig.clock.now_us
	rig.send("pause_app")
	rig.clock.now_us = interrupted_us + GUARD_US - 1
	rig.send("restart")
	rig.tick()
	assert_eq(rig.core.phase, P.PAUSED)
	rig.clock.now_us = interrupted_us + GUARD_US
	rig.send("restart")
	rig.tick()
	assert_ne(rig.core.phase, P.PAUSED)


func test_guard_press_us_0_is_replaced_by_now_with_one_error() -> void:
	var rig: Factory = _rig(S.PAUSED_INSIDE)
	rig.clock.now_us = rig.anchor_us + GUARD_US
	rig.core.request_restart(0)
	rig.tick()
	assert_ne(rig.core.phase, P.PAUSED)
	assert_eq(rig.logs.count_level(ERROR_LEVEL), 1)


func test_guard_future_press_us_is_clamped_to_now_with_one_error() -> void:
	var rig: Factory = _rig(S.PAUSED_INSIDE)
	rig.clock.now_us = rig.anchor_us + 10_000
	rig.core.request_menu(rig.clock.now_us + 5_000_000)
	rig.tick()
	assert_eq(rig.core.phase, P.PAUSED, "a future stamp cannot bypass the guard")
	assert_eq(rig.logs.count_level(ERROR_LEVEL), 1)


# --- AC-29: sensor_lost -------------------------------------------------------------------------------------

func test_sensor_lost_in_running_gives_run_paused_sensor_lost() -> void:
	var rig: Factory = _rig(S.RUNNING)
	rig.send("pause_sensor")
	rig.tick()
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(rig.recorder.events[0], ["run_paused", [Src.SENSOR_LOST]] as Array)


func test_sensor_lost_in_resuming_gives_paused() -> void:
	var rig: Factory = _rig(S.RESUMING)
	rig.send("pause_sensor")
	rig.tick()
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(rig.recorder.events[0], ["run_paused", [Src.SENSOR_LOST]] as Array)


func test_sensor_lost_elsewhere_is_silent_without_log() -> void:
	for state: Factory.State in [S.BOOT, S.MENU, S.PAUSED_INSIDE, S.HIT_LOCKED, S.HIT_UNLOCKED]:
		var rig: Factory = _rig(state)
		var phase_before: RunStateCore.Phase = rig.core.phase
		rig.send("pause_sensor")
		rig.tick()
		assert_eq(rig.core.phase, phase_before)
		assert_eq(rig.recorder.events.size(), 0, "state %d" % state)
		assert_eq(rig.logs.count(), 0, "state %d" % state)


func test_sensor_lost_on_the_same_tick_as_a_hit_loses_to_the_hit() -> void:
	var rig: Factory = _rig(S.RUNNING)
	rig.send("pause_sensor")
	rig.send("hit")
	rig.tick()
	assert_eq(rig.core.phase, P.HIT)
	assert_eq(rig.recorder.names(), ["run_ended", "phase_changed"] as Array[String])


func test_sensor_lost_with_app_interrupted_on_one_frame_gives_one_pause() -> void:
	var rig: Factory = _rig(S.RUNNING)
	rig.send("pause_app")
	rig.send("pause_sensor")
	rig.tick()
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(rig.recorder.names(), PAUSED_EVENTS)
	assert_eq(rig.recorder.events[0][1], [Src.APP_INTERRUPTED] as Array)
	assert_eq(rig.logs.count(), 0)
