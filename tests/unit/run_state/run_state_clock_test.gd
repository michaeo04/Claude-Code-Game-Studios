## Story RS-004: tick(), run clock F1 and settling tick (GDD AC-10, AC-11).
extends GutTest

const Factory = preload("res://tests/support/run_state_factory.gd")

const S = Factory.State
const WARNING_LEVEL: int = LogLevel.WARNING
const EPS: float = 1e-6


## A Running core whose settling tick is over and whose `run_time` is exactly 0.
func _running_at_zero() -> Factory:
	var rig: Factory = Factory.new()
	rig.core_in(S.MENU)
	rig.send("start")
	rig.tick() # accepts the start
	rig.tick() # settling tick
	rig.recorder.clear()
	rig.logs.clear()
	return rig


func test_clock_3600_ticks_at_60fps_give_60_seconds() -> void:
	var rig: Factory = _running_at_zero()
	for i: int in range(3600):
		rig.tick()
	assert_almost_eq(rig.core.run_time, 60.0, 1e-3)


func test_clock_step_above_dt_max_is_clamped_to_one_tenth() -> void:
	var rig: Factory = _running_at_zero()
	var dt_eff: float = rig.core.tick(0.3, 0.3)
	assert_almost_eq(dt_eff, 0.1, EPS)
	assert_almost_eq(rig.core.run_time, 0.1, EPS)


func test_clock_bad_inputs_add_zero_and_return_zero() -> void:
	var rig: Factory = _running_at_zero()
	assert_eq(rig.core.tick(NAN, NAN), 0.0)
	assert_eq(rig.core.tick(INF, INF), 0.0)
	assert_eq(rig.core.tick(-1.0, -1.0), 0.0)
	assert_eq(rig.core.run_time, 0.0)


func test_clock_bad_input_warning_is_rate_limited_to_one_per_second() -> void:
	var rig: Factory = _running_at_zero()
	rig.core.tick(NAN, NAN)
	assert_eq(rig.logs.count_level(WARNING_LEVEL), 1, "first bad input warns")
	assert_true(rig.logs.code_at(0) == RunStateMath.LOG_DT_INVALID)
	rig.clock.advance_us(999_999)
	rig.core.tick(INF, INF)
	assert_eq(rig.logs.count_level(WARNING_LEVEL), 1, "no second warning within 1.0 s")
	rig.clock.advance_us(1)
	rig.core.tick(-1.0, -1.0)
	assert_eq(rig.logs.count_level(WARNING_LEVEL), 2, "one again after 1.0 s")
	assert_eq(rig.logs.count(), 2)


func test_clock_zero_dt_adds_zero_and_logs_nothing() -> void:
	var rig: Factory = _running_at_zero()
	var dt_eff: float = rig.core.tick(0.0, 0.0)
	assert_eq(dt_eff, 0.0)
	assert_eq(rig.core.run_time, 0.0)
	assert_eq(rig.logs.count(), 0)


func test_clock_run_time_ms_rounds_1_2344_down_to_1234() -> void:
	var rig: Factory = _running_at_zero()
	for i: int in range(12):
		rig.core.tick(0.1, 0.1)
	rig.core.tick(0.0344, 0.0344)
	assert_almost_eq(rig.core.run_time, 1.2344, EPS)
	assert_eq(rig.core.run_time_ms(), 1234)


func test_clock_run_time_ms_rounds_1_2346_up_to_1235() -> void:
	var rig: Factory = _running_at_zero()
	for i: int in range(12):
		rig.core.tick(0.1, 0.1)
	rig.core.tick(0.0346, 0.0346)
	assert_almost_eq(rig.core.run_time, 1.2346, EPS)
	assert_eq(rig.core.run_time_ms(), 1235)


func test_clock_run_time_never_decreases() -> void:
	var rig: Factory = _running_at_zero()
	var inputs: Array[float] = [0.016, NAN, -1.0, 0.3, 0.0, INF, 0.01, -0.5]
	var previous: float = rig.core.run_time
	for dt: float in inputs:
		rig.core.tick(dt, dt)
		assert_true(rig.core.run_time >= previous, "run_time went backwards at dt=%s" % dt)
		previous = rig.core.run_time


func test_clock_tick_returns_zero_in_every_phase_except_running() -> void:
	for state: int in [S.BOOT, S.MENU, S.PAUSED_INSIDE, S.PAUSED_AFTER, S.RESUMING, S.HIT_LOCKED, S.HIT_UNLOCKED]:
		var rig: Factory = Factory.new()
		rig.core_in(state)
		var before: float = rig.core.run_time
		assert_eq(rig.core.tick(0.016, 0.016), 0.0, "state %d" % state)
		assert_eq(rig.core.run_time, before, "state %d" % state)


func test_clock_running_tick_without_transition_returns_the_step() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RUNNING)
	assert_almost_eq(rig.tick(), Factory.DT, EPS)


func test_clock_hit_tick_returns_zero_and_event_carries_last_full_step() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RUNNING) # run_time = 1/60 s = 17 ms
	var before: float = rig.core.run_time
	rig.send("hit")
	assert_eq(rig.tick(), 0.0)
	assert_eq(rig.core.run_time, before)
	var ended: Array = rig.recorder.events[0]
	assert_eq(ended[0], "run_ended")
	assert_eq((ended[1] as Array)[2], 17)


func test_clock_button_pause_tick_returns_zero_and_keeps_run_time() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RUNNING)
	var before: float = rig.core.run_time
	rig.send("pause")
	assert_eq(rig.tick(), 0.0)
	assert_eq(rig.core.run_time, before)
	assert_eq(rig.core.phase, RunStateCore.Phase.PAUSED)


func test_clock_restart_tick_returns_zero_and_resets_run_time() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.HIT_UNLOCKED)
	rig.send("restart")
	assert_eq(rig.tick(), 0.0)
	assert_eq(rig.core.run_time, 0.0)
	assert_eq(rig.core.phase, RunStateCore.Phase.RUNNING)


func test_clock_abandon_tick_returns_zero_and_event_carries_last_step() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.PAUSED_AFTER)
	rig.send("menu")
	assert_eq(rig.tick(), 0.0)
	var abandoned: Array = rig.recorder.events[0]
	assert_eq(abandoned[0], "run_abandoned")
	assert_eq((abandoned[1] as Array)[1], 17)


func test_clock_countdown_expiry_tick_and_settling_tick_return_zero() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RESUMING)
	var before: float = rig.core.run_time
	rig.clock.advance_us(rig.config.resume_countdown_us())
	assert_eq(rig.tick(), 0.0, "expiry tick")
	assert_eq(rig.core.phase, RunStateCore.Phase.RUNNING)
	assert_eq(rig.tick(), 0.0, "settling tick after run_resumed")
	assert_eq(rig.core.run_time, before)
	assert_almost_eq(rig.tick(), Factory.DT, EPS)


func test_clock_settling_tick_after_run_started_returns_zero() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.MENU)
	rig.send("start")
	assert_eq(rig.tick(), 0.0, "start tick")
	assert_eq(rig.tick(), 0.0, "settling tick")
	assert_eq(rig.core.run_time, 0.0)
	assert_almost_eq(rig.tick(), Factory.DT, EPS)


func test_clock_pause_and_restart_on_one_tick_gives_paused_and_zero_step() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RUNNING)
	var before: float = rig.core.run_time
	rig.send("pause")
	rig.send("restart")
	assert_eq(rig.tick(), 0.0)
	assert_eq(rig.core.phase, RunStateCore.Phase.PAUSED)
	assert_eq(rig.core.run_time, before)
	assert_false(rig.recorder.names().has("run_reset"))


func test_clock_pause_and_menu_on_one_tick_gives_paused_and_zero_step() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RUNNING)
	rig.send("pause")
	rig.send("menu")
	assert_eq(rig.tick(), 0.0)
	assert_eq(rig.core.phase, RunStateCore.Phase.PAUSED)
	assert_false(rig.recorder.names().has("run_abandoned"))
