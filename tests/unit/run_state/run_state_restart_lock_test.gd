## Story RS-006: restart lock, press_us handling and restart_unlocked (GDD AC-12).
extends GutTest

const Factory = preload("res://tests/support/run_state_factory.gd")

const S = Factory.State
const HIT_US: int = 10_000_000
const LOCK_US: int = 500_000
const DEBUG_LEVEL: int = RunStateMath.LogLevel.DEBUG
const ERROR_LEVEL: int = RunStateMath.LogLevel.ERROR


## A core in Hit, entered at exactly `HIT_US` on the injected clock; recorder and log are clear.
func _hit_rig() -> Factory:
	var rig: Factory = Factory.new()
	rig.core_in(S.RUNNING)
	rig.clock.now_us = HIT_US
	rig.send("hit")
	rig.tick()
	rig.recorder.clear()
	rig.logs.clear()
	return rig


## Sends `kind` ("restart" or "menu") with `press_us`, processed at `processed_us`. True when it left Hit.
func _accepted(kind: String, press_us: int, processed_us: int) -> bool:
	var rig: Factory = _hit_rig()
	rig.clock.now_us = processed_us
	if kind == "restart":
		rig.core.request_restart(press_us)
	else:
		rig.core.request_menu(press_us)
	rig.tick()
	return rig.core.phase != RunStateCore.Phase.HIT


func test_restart_lock_is_500000_us_by_default() -> void:
	assert_eq(RunConfig.new().restart_lock_us(), LOCK_US)


func test_restart_lock_press_just_inside_processed_late_is_rejected() -> void:
	assert_false(_accepted("restart", 10_499_000, 10_520_000), "judged on press_us, not on processing time")


func test_restart_lock_press_one_us_inside_is_rejected() -> void:
	assert_false(_accepted("restart", 10_499_999, 10_499_999))


func test_restart_lock_press_exactly_at_the_lock_is_accepted() -> void:
	assert_true(_accepted("restart", 10_500_000, 10_500_000))


func test_restart_lock_press_one_us_after_the_lock_is_accepted() -> void:
	assert_true(_accepted("restart", 10_500_001, 10_500_001))


func test_restart_lock_press_after_lock_processed_late_is_accepted() -> void:
	assert_true(_accepted("restart", 10_517_000, 10_520_000))


func test_restart_lock_menu_follows_the_same_arithmetic() -> void:
	assert_false(_accepted("menu", 10_499_000, 10_520_000))
	assert_false(_accepted("menu", 10_499_999, 10_499_999))
	assert_true(_accepted("menu", 10_500_000, 10_500_000))
	assert_true(_accepted("menu", 10_500_001, 10_500_001))
	assert_true(_accepted("menu", 10_517_000, 10_520_000))


func test_restart_lock_rejected_press_logs_debug_and_emits_nothing() -> void:
	var rig: Factory = _hit_rig()
	rig.clock.now_us = 10_520_000
	rig.core.request_restart(10_499_000)
	rig.tick()
	assert_eq(rig.logs.count_level(DEBUG_LEVEL), 1)
	assert_true(rig.logs.message_at(0).begins_with(String(RunStateMath.LOG_REQUEST_LOCKED)))
	assert_false(rig.recorder.names().has("run_reset"))


func test_restart_lock_accepted_restart_starts_a_new_run() -> void:
	var rig: Factory = _hit_rig()
	rig.clock.now_us = 10_500_000
	rig.core.request_restart(10_500_000)
	rig.tick()
	assert_eq(rig.core.phase, RunStateCore.Phase.RUNNING)
	assert_eq(rig.core.run_id, 2)
	assert_true(rig.recorder.names().has("run_reset"))


func test_restart_lock_held_press_never_converts() -> void:
	var rig: Factory = _hit_rig()
	rig.clock.now_us = 10_600_000
	rig.core.request_restart(10_400_000) # stamped inside the lock, still held after it
	rig.tick()
	assert_eq(rig.core.phase, RunStateCore.Phase.HIT)
	rig.clock.now_us = 10_700_000
	rig.tick() # no buffering: nothing re-sends the press
	assert_eq(rig.core.phase, RunStateCore.Phase.HIT)
	assert_false(rig.recorder.names().has("run_reset"))


func test_restart_lock_unlocked_emitted_once_over_1000_ticks() -> void:
	var rig: Factory = _hit_rig()
	for i: int in range(1000):
		rig.clock.advance_us(1000)
		rig.tick()
	assert_eq(rig.recorder.names().count("restart_unlocked"), 1)
	assert_eq(rig.recorder.names().count("phase_changed"), 0)
	assert_eq(rig.core.phase, RunStateCore.Phase.HIT)


func test_restart_lock_unlocked_not_emitted_before_the_lock_ends() -> void:
	var rig: Factory = _hit_rig()
	rig.clock.now_us = 10_499_999
	rig.tick()
	assert_eq(rig.recorder.names().count("restart_unlocked"), 0)
	rig.clock.now_us = 10_500_000
	rig.tick()
	assert_eq(rig.recorder.names().count("restart_unlocked"), 1)


func test_restart_lock_unlocked_rearms_for_the_next_hit() -> void:
	var rig: Factory = _hit_rig()
	rig.clock.now_us = 10_500_000
	rig.tick()
	rig.core.request_restart(10_500_000)
	rig.tick()
	rig.tick() # settling tick
	rig.tick()
	rig.recorder.clear()
	rig.clock.now_us = 20_000_000
	rig.send("hit")
	rig.tick()
	rig.clock.now_us = 20_500_000
	rig.tick()
	rig.tick()
	assert_eq(rig.recorder.names().count("restart_unlocked"), 1)
	assert_eq(rig.core.phase, RunStateCore.Phase.HIT)


func test_restart_lock_unlocked_not_emitted_on_tick_of_accepted_restart() -> void:
	var rig: Factory = _hit_rig()
	rig.clock.now_us = 10_500_000
	rig.core.request_restart(10_500_000)
	rig.tick()
	assert_eq(rig.recorder.names().count("restart_unlocked"), 0)


func test_restart_lock_unlocked_not_emitted_on_tick_of_accepted_menu() -> void:
	var rig: Factory = _hit_rig()
	rig.clock.now_us = 10_500_000
	rig.core.request_menu(10_500_000)
	rig.tick()
	assert_eq(rig.core.phase, RunStateCore.Phase.MENU)
	assert_eq(rig.recorder.names().count("restart_unlocked"), 0)


func test_restart_lock_press_zero_is_replaced_by_now_with_one_error() -> void:
	var rig: Factory = _hit_rig()
	rig.clock.now_us = 10_600_000
	rig.core.request_restart(0)
	rig.tick()
	assert_eq(rig.logs.count_level(ERROR_LEVEL), 1)
	assert_true(rig.logs.message_at(0).begins_with(String(RunStateMath.LOG_PRESS_US_INVALID)))
	assert_eq(rig.core.phase, RunStateCore.Phase.RUNNING, "now_us is after the lock")


func test_restart_lock_press_negative_is_replaced_by_now_with_one_error() -> void:
	var rig: Factory = _hit_rig()
	rig.clock.now_us = 10_100_000
	rig.core.request_restart(-5)
	rig.tick()
	assert_eq(rig.logs.count_level(ERROR_LEVEL), 1)
	assert_eq(rig.core.phase, RunStateCore.Phase.HIT, "now_us is still inside the lock")
	assert_eq(rig.logs.count_level(DEBUG_LEVEL), 1, "the replaced stamp is rejected at debug level")


func test_restart_lock_press_in_the_future_is_clamped_with_one_error() -> void:
	var rig: Factory = _hit_rig()
	rig.clock.now_us = 10_100_000
	rig.core.request_restart(10_900_000) # would bypass the lock if trusted
	rig.tick()
	assert_eq(rig.logs.count_level(ERROR_LEVEL), 1)
	assert_eq(rig.core.phase, RunStateCore.Phase.HIT)


func test_restart_lock_menu_press_zero_and_future_each_log_one_error() -> void:
	var rig: Factory = _hit_rig()
	rig.clock.now_us = 10_100_000
	rig.core.request_menu(0)
	rig.tick()
	assert_eq(rig.logs.count_level(ERROR_LEVEL), 1)
	rig.core.request_menu(11_000_000)
	rig.tick()
	assert_eq(rig.logs.count_level(ERROR_LEVEL), 2)
	assert_eq(rig.core.phase, RunStateCore.Phase.HIT)


func test_restart_lock_hit_never_times_out() -> void:
	var rig: Factory = _hit_rig()
	for i: int in range(10):
		rig.clock.advance_us(360_000_000) # 6 minutes of idle per step
		rig.tick()
	assert_eq(rig.core.phase, RunStateCore.Phase.HIT)
	assert_eq(rig.recorder.names().count("restart_unlocked"), 1)
	assert_eq(rig.recorder.names().count("phase_changed"), 0)
