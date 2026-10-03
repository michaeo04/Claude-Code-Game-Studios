## Story RS-008: timers, stall guard and clock robustness (GDD AC-2, AC-13, AC-16, AC-21).
extends GutTest

const Factory = preload("res://tests/support/run_state_factory.gd")

const S = Factory.State
const P = RunStateCore.Phase
const Src = RunStateCore.PauseSource
const TICK_US: int = 16_667
const WARNING_LEVEL: int = RunStateMath.LogLevel.WARNING
const DEBUG_LEVEL: int = RunStateMath.LogLevel.DEBUG


func _rig(state: Factory.State) -> Factory:
	var rig: Factory = Factory.new()
	rig.core_in(state)
	return rig


# --- AC-2: 2 timers x 6 phases ------------------------------------------------------------------------------

func test_timer_matrix_countdown_expiry_acts_only_in_resuming() -> void:
	# Hit is entered already unlocked so that only the countdown timer is under test.
	var cases: Array[Factory.State] = [S.BOOT, S.MENU, S.RUNNING, S.PAUSED_AFTER, S.RESUMING, S.HIT_UNLOCKED]
	for state: Factory.State in cases:
		var rig: Factory = _rig(state)
		rig.clock.advance_us(rig.config.resume_countdown_us())
		rig.tick()
		if state == S.RESUMING:
			assert_eq(rig.recorder.names(), ["run_resumed", "phase_changed"] as Array[String])
			assert_eq(rig.core.phase, P.RUNNING)
		else:
			assert_eq(rig.recorder.events.size(), 0, "state %d" % state)
			assert_eq(rig.logs.count(), 0, "state %d" % state)


func test_timer_matrix_lock_expiry_acts_only_in_hit() -> void:
	var cases: Array[Factory.State] = [S.BOOT, S.MENU, S.RUNNING, S.PAUSED_INSIDE, S.RESUMING, S.HIT_LOCKED]
	for state: Factory.State in cases:
		var rig: Factory = _rig(state)
		var phase_before: RunStateCore.Phase = rig.core.phase
		rig.clock.advance_us(rig.config.restart_lock_us())
		rig.tick()
		assert_eq(rig.core.phase, phase_before, "no phase change, state %d" % state)
		if state == S.HIT_LOCKED:
			assert_eq(rig.recorder.names(), ["restart_unlocked"] as Array[String])
		else:
			assert_eq(rig.recorder.events.size(), 0, "state %d" % state)
			assert_eq(rig.logs.count(), 0, "state %d" % state)


func test_timer_lock_expiry_is_emitted_once_per_hit() -> void:
	var rig: Factory = _rig(S.HIT_LOCKED)
	rig.clock.advance_us(rig.config.restart_lock_us())
	rig.tick()
	rig.clock.advance_us(1_000_000)
	rig.tick()
	assert_eq(rig.recorder.names(), ["restart_unlocked"] as Array[String])


# --- AC-13: tick arithmetic ---------------------------------------------------------------------------------

func _ticks_until_event(rig: Factory, event_name: String, limit: int) -> int:
	for i: int in range(1, limit + 1):
		rig.clock.advance_us(TICK_US)
		rig.core.tick(0.0, Factory.DT)
		if rig.recorder.names().has(event_name):
			return i
	return -1


func test_timer_lock_unlocks_at_tick_30_exactly() -> void:
	var rig: Factory = _rig(S.HIT_LOCKED)
	assert_eq(_ticks_until_event(rig, "restart_unlocked", 60), 30)


func test_timer_countdown_resumes_at_tick_120_exactly() -> void:
	var rig: Factory = _rig(S.RESUMING)
	assert_eq(_ticks_until_event(rig, "run_resumed", 200), 120)


func test_timer_huge_world_dt_with_small_clock_step_expires_neither_timer() -> void:
	var hit: Factory = _rig(S.HIT_LOCKED)
	hit.clock.advance_us(100_000)
	hit.core.tick(100.0, Factory.DT)
	assert_eq(hit.recorder.events.size(), 0)
	var resuming: Factory = _rig(S.RESUMING)
	resuming.clock.advance_us(100_000)
	resuming.core.tick(100.0, Factory.DT)
	assert_eq(resuming.core.phase, P.RESUMING)
	assert_eq(resuming.recorder.events.size(), 0)


func test_timer_stall_on_the_countdown_expiry_tick_pauses_instead() -> void:
	var rig: Factory = _rig(S.RESUMING)
	rig.clock.advance_us(2_500_000)
	rig.core.tick(Factory.DT, 0.6)
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(rig.recorder.names(), ["run_paused", "phase_changed"] as Array[String])
	assert_false(rig.recorder.names().has("run_resumed"))


# --- AC-16: stall guard -------------------------------------------------------------------------------------

func test_stall_just_below_threshold_does_not_pause() -> void:
	var rig: Factory = _rig(S.RUNNING)
	var dt_eff: float = rig.core.tick(Factory.DT, 0.499)
	assert_eq(rig.core.phase, P.RUNNING)
	assert_almost_eq(dt_eff, Factory.DT, 1e-6)
	assert_eq(rig.recorder.events.size(), 0)


func test_stall_at_threshold_pauses_once_with_dt_eff_0_and_run_time_unchanged() -> void:
	var rig: Factory = _rig(S.RUNNING)
	var run_time_before: float = rig.core.run_time
	var dt_eff: float = rig.core.tick(Factory.DT, 0.5)
	assert_eq(dt_eff, 0.0)
	assert_eq(rig.core.run_time, run_time_before)
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(rig.recorder.names(), ["run_paused", "phase_changed"] as Array[String])
	assert_eq(rig.recorder.events[0][1], [Src.APP_INTERRUPTED] as Array)


func test_stall_in_resuming_returns_to_paused() -> void:
	var rig: Factory = _rig(S.RESUMING)
	var dt_eff: float = rig.core.tick(Factory.DT, 0.5)
	assert_eq(dt_eff, 0.0)
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(rig.recorder.events[0][1], [Src.APP_INTERRUPTED] as Array)


func test_stall_discards_the_hit_of_the_stalled_tick() -> void:
	var rig: Factory = _rig(S.RUNNING)
	rig.send("hit")
	rig.core.tick(Factory.DT, 0.5)
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(rig.recorder.names(), ["run_paused", "phase_changed"] as Array[String])
	assert_eq(rig.logs.count_level(DEBUG_LEVEL), 1)


func test_stall_does_not_pause_in_hit_paused_menu_or_boot() -> void:
	for state: Factory.State in [S.HIT_LOCKED, S.PAUSED_INSIDE, S.MENU, S.BOOT]:
		var rig: Factory = _rig(state)
		var phase_before: RunStateCore.Phase = rig.core.phase
		var dt_eff: float = rig.core.tick(Factory.DT, 5.0)
		assert_eq(dt_eff, 0.0)
		assert_eq(rig.core.phase, phase_before, "state %d" % state)
		assert_eq(rig.recorder.events.size(), 0, "state %d" % state)
		assert_eq(rig.logs.count(), 0, "state %d" % state)


func test_stall_on_a_settling_tick_gives_no_pause_dt_eff_0_and_ignored_hit() -> void:
	var rig: Factory = _rig(S.MENU)
	rig.send("start")
	rig.tick()
	rig.recorder.clear()
	rig.logs.clear()
	rig.send("hit")
	var dt_eff: float = rig.core.tick(Factory.DT, 5.0)
	assert_eq(dt_eff, 0.0)
	assert_eq(rig.core.phase, P.RUNNING)
	assert_eq(rig.recorder.events.size(), 0)
	assert_eq(rig.logs.count_level(DEBUG_LEVEL), 1)


func test_stall_non_finite_or_negative_real_dt_does_not_pause_and_warns_once_per_second() -> void:
	for bad: float in [NAN, INF, -0.1]:
		var rig: Factory = _rig(S.RUNNING)
		for i: int in range(3):
			var dt_eff: float = rig.core.tick(Factory.DT, bad)
			assert_almost_eq(dt_eff, Factory.DT, 1e-6)
		assert_eq(rig.core.phase, P.RUNNING)
		assert_eq(rig.recorder.events.size(), 0)
		assert_eq(rig.logs.count_level(WARNING_LEVEL), 1, "one warning for %s" % bad)
		assert_true(rig.logs.message_at(0).begins_with(String(RunStateMath.LOG_DT_INVALID)))
		rig.clock.advance_us(1_000_000)
		rig.core.tick(Factory.DT, bad)
		assert_eq(rig.logs.count_level(WARNING_LEVEL), 2, "a second warning after one second")


# --- AC-21: clock robustness --------------------------------------------------------------------------------

func test_clock_backwards_or_repeated_never_unlocks_early() -> void:
	var rig: Factory = _rig(S.HIT_LOCKED)
	rig.clock.now_us = rig.anchor_us - 1_000_000
	rig.tick()
	rig.tick()
	rig.clock.now_us = rig.anchor_us
	rig.tick()
	rig.clock.now_us = rig.anchor_us + rig.config.restart_lock_us() - 1
	rig.tick()
	assert_eq(rig.recorder.events.size(), 0)
	rig.clock.now_us = rig.anchor_us + rig.config.restart_lock_us()
	rig.tick()
	assert_eq(rig.recorder.names(), ["restart_unlocked"] as Array[String])


func test_clock_backwards_or_repeated_never_expires_the_countdown_early() -> void:
	var rig: Factory = _rig(S.RESUMING)
	rig.clock.now_us = rig.anchor_us - 5_000_000
	rig.tick()
	rig.clock.now_us = rig.anchor_us
	rig.tick()
	rig.tick()
	rig.clock.now_us = rig.anchor_us + rig.config.resume_countdown_us() - 1
	rig.tick()
	assert_eq(rig.core.phase, P.RESUMING)
	assert_eq(rig.recorder.events.size(), 0)
	assert_eq(rig.core.resume_remaining() > 0.0, true)


func test_clock_thirty_second_background_in_hit_unlocks_on_the_first_tick() -> void:
	var rig: Factory = _rig(S.HIT_LOCKED)
	rig.clock.advance_us(30_000_000)
	rig.core.tick(Factory.DT, 30.0)
	assert_eq(rig.core.phase, P.HIT)
	assert_eq(rig.recorder.names(), ["restart_unlocked"] as Array[String])


func test_clock_interruption_in_resuming_then_resume_takes_the_full_countdown() -> void:
	var rig: Factory = _rig(S.RESUMING)
	rig.clock.advance_us(1_900_000)
	rig.send("pause_app")
	assert_eq(rig.core.phase, P.PAUSED)
	rig.clock.advance_us(10_000_000)
	rig.send("resume")
	rig.tick()
	assert_eq(rig.core.phase, P.RESUMING)
	rig.clock.advance_us(rig.config.resume_countdown_us() - 1)
	rig.tick()
	assert_eq(rig.core.phase, P.RESUMING)
	rig.clock.advance_us(1)
	rig.tick()
	assert_eq(rig.core.phase, P.RUNNING)


func test_clock_app_interrupted_and_back_change_nothing_in_menu_paused_boot_hit() -> void:
	for state: Factory.State in [S.MENU, S.PAUSED_INSIDE, S.BOOT, S.HIT_LOCKED]:
		for request: String in ["pause_app", "pause_back"]:
			var rig: Factory = _rig(state)
			var phase_before: RunStateCore.Phase = rig.core.phase
			rig.send(request)
			rig.tick()
			assert_eq(rig.core.phase, phase_before, "%s state %d" % [request, state])
			assert_eq(rig.recorder.events.size(), 0)
			assert_eq(rig.logs.count(), 0)
