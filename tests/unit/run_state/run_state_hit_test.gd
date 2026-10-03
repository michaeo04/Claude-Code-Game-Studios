## Story RS-005: hit acceptance, stale run_id and same-tick tie-break (GDD AC-7, AC-20).
extends GutTest

const Factory = preload("res://tests/support/run_state_factory.gd")

const S = Factory.State
const DEBUG_LEVEL: int = RunStateMath.LogLevel.DEBUG
const WARNING_LEVEL: int = RunStateMath.LogLevel.WARNING


func _count(rig: Factory, event_name: String) -> int:
	return rig.recorder.names().count(event_name)


func _first_args(rig: Factory, event_name: String) -> Array:
	for entry: Array in rig.recorder.events:
		if entry[0] == event_name:
			return entry[1] as Array
	return []


## Sends the given hazard ids with the current run_id (or `run_id_offset` away from it), ticks once, and
## returns the `hazard_id` of `run_ended`, or -99 when the run did not end.
func _winner(ids: Array[int], stale_ids: Array[int] = []) -> int:
	var rig: Factory = Factory.new()
	rig.core_in(S.RUNNING)
	for id: int in stale_ids:
		rig.core.request_hit(id, rig.core.run_id - 1)
	for id: int in ids:
		rig.core.request_hit(id, rig.core.run_id)
	rig.tick()
	var args: Array = _first_args(rig, "run_ended")
	return -99 if args.is_empty() else (args[1] as int)


func test_hit_first_hit_emits_run_ended_once_with_run_time_ms() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RUNNING) # run_time = 1/60 s
	for i: int in range(6):
		rig.tick() # 7/60 s = 116.67 ms
	rig.core.request_hit(7, rig.core.run_id)
	rig.tick()
	assert_eq(_count(rig, "run_ended"), 1)
	assert_eq(_first_args(rig, "run_ended"), [1, 7, 117])
	assert_eq(rig.core.phase, RunStateCore.Phase.HIT)
	assert_eq(rig.recorder.names(), ["run_ended", "phase_changed"] as Array[String])


func test_hit_later_hits_while_in_hit_are_ignored() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RUNNING)
	rig.send("hit")
	rig.tick()
	rig.core.request_hit(9, rig.core.run_id)
	rig.tick()
	assert_eq(_count(rig, "run_ended"), 1)


func test_hit_two_hits_in_one_tick_end_the_run_once() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RUNNING)
	rig.core.request_hit(3, rig.core.run_id)
	rig.core.request_hit(8, rig.core.run_id)
	rig.tick()
	assert_eq(_count(rig, "run_ended"), 1)
	assert_eq(_first_args(rig, "run_ended")[1], 3)


func test_hit_next_run_ends_independently_with_its_own_run_id() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.HIT_UNLOCKED)
	rig.send("restart")
	rig.tick()
	rig.tick() # settling tick
	assert_eq(rig.core.run_id, 2)
	rig.recorder.clear()
	rig.core.request_hit(5, 2)
	rig.tick()
	assert_eq(_first_args(rig, "run_ended"), [2, 5, 0])


func test_hit_stale_run_id_is_ignored_with_debug_log() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.HIT_UNLOCKED)
	rig.send("restart")
	rig.tick()
	rig.tick() # settling tick over
	rig.tick() # live tick
	rig.recorder.clear()
	rig.logs.clear()
	rig.core.request_hit(1, 1) # the previous run's id
	rig.tick()
	assert_eq(_count(rig, "run_ended"), 0)
	assert_eq(rig.core.phase, RunStateCore.Phase.RUNNING)
	assert_eq(rig.logs.count(), 1)
	assert_eq(rig.logs.level_at(0), DEBUG_LEVEL)
	assert_true(rig.logs.message_at(0).begins_with(String(RunStateMath.LOG_HIT_STALE)))


func test_hit_on_settling_tick_after_run_started_is_ignored_then_accepted_next_tick() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.MENU)
	rig.send("start")
	rig.tick() # run_started; the next tick is the settling tick
	rig.recorder.clear()
	rig.logs.clear()
	rig.core.request_hit(2, rig.core.run_id)
	rig.tick()
	assert_eq(_count(rig, "run_ended"), 0)
	assert_eq(rig.logs.count(), 1)
	assert_eq(rig.logs.level_at(0), DEBUG_LEVEL)
	assert_true(rig.logs.message_at(0).begins_with(String(RunStateMath.LOG_HIT_SETTLING)))
	rig.core.request_hit(2, rig.core.run_id) # level-triggered: the same hit is re-reported
	rig.tick()
	assert_eq(_first_args(rig, "run_ended"), [1, 2, 0])


func test_hit_on_settling_tick_after_run_resumed_is_ignored_then_accepted_next_tick() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RESUMING)
	rig.clock.advance_us(rig.config.resume_countdown_us())
	rig.tick() # run_resumed; the next tick is the settling tick
	assert_eq(rig.core.phase, RunStateCore.Phase.RUNNING)
	rig.recorder.clear()
	rig.logs.clear()
	rig.core.request_hit(6, rig.core.run_id)
	rig.tick()
	assert_eq(_count(rig, "run_ended"), 0)
	assert_eq(rig.logs.count_level(DEBUG_LEVEL), 1)
	assert_true(rig.logs.message_at(0).begins_with(String(RunStateMath.LOG_HIT_SETTLING)))
	rig.core.request_hit(6, rig.core.run_id)
	rig.tick()
	assert_eq(_count(rig, "run_ended"), 1)
	assert_eq(_first_args(rig, "run_ended")[1], 6)


func test_hit_tie_break_lowest_id_wins_for_5_2_9() -> void:
	assert_eq(_winner([5, 2, 9] as Array[int]), 2)


func test_hit_tie_break_zero_beats_three() -> void:
	assert_eq(_winner([0, 3] as Array[int]), 0)


func test_hit_tie_break_known_id_beats_unknown() -> void:
	assert_eq(_winner([-1, 4] as Array[int]), 4)


func test_hit_tie_break_duplicate_ids_give_that_id() -> void:
	assert_eq(_winner([3, 3] as Array[int]), 3)


func test_hit_tie_break_only_unknown_gives_minus_one() -> void:
	assert_eq(_winner([-1] as Array[int]), -1)


func test_hit_tie_break_stale_dropped_before_the_tie_break() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.HIT_UNLOCKED)
	rig.send("restart")
	rig.tick()
	rig.tick()
	rig.tick()
	rig.recorder.clear()
	rig.logs.clear()
	rig.core.request_hit(0, rig.core.run_id - 1) # stale, would win on id
	rig.core.request_hit(5, rig.core.run_id)
	rig.tick()
	assert_eq(_first_args(rig, "run_ended")[1], 5)
	assert_eq(rig.logs.count_level(DEBUG_LEVEL), 1)
	assert_true(rig.logs.message_at(0).begins_with(String(RunStateMath.LOG_HIT_STALE)))


func test_hit_negative_id_below_minus_one_is_treated_as_unknown_with_one_warning() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RUNNING)
	rig.core.request_hit(-5, rig.core.run_id)
	rig.tick()
	assert_eq(_first_args(rig, "run_ended")[1], -1)
	assert_eq(rig.logs.count_level(WARNING_LEVEL), 1)
	assert_true(rig.logs.message_at(0).begins_with(String(RunStateMath.LOG_HIT_BAD_ID)))
