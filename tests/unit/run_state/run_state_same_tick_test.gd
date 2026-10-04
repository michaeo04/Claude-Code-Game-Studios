## Story RS-009: same-tick request conflicts and order independence (GDD AC-18, AC-19; test plan section 5).
## Expectations are hard-coded; permutations are generated only to feed requests in, never to compute results.
extends GutTest

const Factory = preload("res://tests/support/run_state_factory.gd")

const S = Factory.State
const P = RunStateCore.Phase
const Src = RunStateCore.PauseSource
const D: int = LogLevel.DEBUG
const W: int = LogLevel.WARNING

const ALL_FIVE: Array[String] = ["hit", "pause", "menu", "restart", "resume"]


func _rig(state: Factory.State) -> Factory:
	var rig: Factory = Factory.new()
	rig.core_in(state)
	return rig


func _levels(rig: Factory) -> Array[int]:
	var out: Array[int] = []
	for i: int in rig.logs.count():
		out.append(rig.logs.level_at(i))
	return out


func _first_pause_source(rig: Factory) -> int:
	for entry: Array in rig.recorder.events:
		if entry[0] == "run_paused":
			return (entry[1] as Array)[0] as int
	return -1


func _count_event(rig: Factory, event_name: String) -> int:
	return rig.recorder.names().count(event_name)


# --- AC-18: pair table ----------------------------------------------------------------------------------------

func test_hit_then_button_pause_gives_hit_and_one_debug_for_the_pause() -> void:
	var rig: Factory = _rig(S.RUNNING)
	rig.send("hit")
	rig.send("pause")
	rig.tick()
	assert_eq(rig.core.phase, P.HIT)
	assert_eq(rig.recorder.names(), ["run_ended", "phase_changed"] as Array[String])
	assert_eq(_levels(rig), [D] as Array[int])


func test_app_interrupted_while_a_hit_is_queued_gives_paused_and_one_debug_for_the_hit() -> void:
	var rig: Factory = _rig(S.RUNNING)
	rig.send("hit")
	rig.send("pause_app")
	assert_eq(rig.logs.count(), 0, "no log line for the interruption")
	rig.tick()
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(rig.recorder.names(), ["run_paused", "phase_changed"] as Array[String])
	assert_eq(_count_event(rig, "run_ended"), 0)
	assert_eq(_levels(rig), [D] as Array[int])


func test_stall_tick_with_a_hit_gives_paused_no_run_ended_and_one_debug() -> void:
	var rig: Factory = _rig(S.RUNNING)
	rig.send("hit")
	rig.core.tick(Factory.DT, 0.5)
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(_count_event(rig, "run_ended"), 0)
	assert_eq(rig.recorder.names(), ["run_paused", "phase_changed"] as Array[String])
	assert_eq(_levels(rig), [D] as Array[int])


func test_menu_then_restart_in_unlocked_hit_gives_menu_and_restart_rejected_debug() -> void:
	var rig: Factory = _rig(S.HIT_UNLOCKED)
	rig.send("restart")
	rig.send("menu")
	rig.tick()
	assert_eq(rig.core.phase, P.MENU)
	assert_eq(rig.recorder.names(), ["phase_changed"] as Array[String])
	assert_eq(_levels(rig), [D] as Array[int])


func test_menu_then_restart_in_paused_after_guard_gives_menu_abandon_and_restart_debug() -> void:
	var rig: Factory = _rig(S.PAUSED_AFTER)
	rig.send("menu")
	rig.send("restart")
	rig.tick()
	assert_eq(rig.core.phase, P.MENU)
	assert_eq(rig.recorder.names(), ["run_abandoned", "phase_changed"] as Array[String])
	assert_eq(_levels(rig), [D] as Array[int])


func test_resume_then_restart_in_paused_after_guard_gives_resuming_without_abandon() -> void:
	var rig: Factory = _rig(S.PAUSED_AFTER)
	rig.send("restart")
	rig.send("resume")
	rig.tick()
	assert_eq(rig.core.phase, P.RESUMING)
	assert_eq(rig.recorder.names(), ["run_resuming", "phase_changed"] as Array[String])
	assert_eq(_count_event(rig, "run_abandoned"), 0)
	assert_eq(_levels(rig), [D] as Array[int])


func test_button_pause_then_restart_from_running_gives_paused_and_restart_inside_guard_debug() -> void:
	var rig: Factory = _rig(S.RUNNING)
	rig.send("pause")
	rig.send("restart")
	rig.tick()
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(rig.recorder.names(), ["run_paused", "phase_changed"] as Array[String])
	assert_eq(_levels(rig), [D] as Array[int])


func test_button_pause_then_menu_from_running_gives_paused_and_menu_inside_guard_debug() -> void:
	var rig: Factory = _rig(S.RUNNING)
	rig.send("pause")
	rig.send("menu")
	rig.tick()
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(rig.recorder.names(), ["run_paused", "phase_changed"] as Array[String])
	assert_eq(_levels(rig), [D] as Array[int])


func test_app_interrupted_and_button_give_one_pause_with_source_app_interrupted_either_order() -> void:
	for app_first: bool in [true, false]:
		var rig: Factory = _rig(S.RUNNING)
		if app_first:
			rig.send("pause_app")
			rig.send("pause")
		else:
			rig.send("pause")
			rig.send("pause_app")
		rig.tick()
		assert_eq(rig.core.phase, P.PAUSED)
		assert_eq(_count_event(rig, "run_paused"), 1)
		assert_eq(_first_pause_source(rig), Src.APP_INTERRUPTED, "app_first=%s" % app_first)
		assert_eq(_levels(rig), [D] as Array[int], "the queued button pause is a repeated tap")


func test_button_then_back_gives_one_pause_with_the_first_source_and_no_log() -> void:
	var rig: Factory = _rig(S.RUNNING)
	rig.send("pause")
	rig.send("pause_back")
	rig.tick()
	assert_eq(_count_event(rig, "run_paused"), 1)
	assert_eq(_first_pause_source(rig), Src.BUTTON)
	assert_eq(rig.logs.count(), 0, "a non-button duplicate is silent")


func test_back_then_button_gives_one_pause_with_the_first_source_and_one_debug() -> void:
	var rig: Factory = _rig(S.RUNNING)
	rig.send("pause_back")
	rig.send("pause")
	rig.tick()
	assert_eq(_count_event(rig, "run_paused"), 1)
	assert_eq(_first_pause_source(rig), Src.BACK)
	assert_eq(_levels(rig), [D] as Array[int])


func test_app_interrupted_then_restart_in_unlocked_hit_gives_running() -> void:
	var rig: Factory = _rig(S.HIT_UNLOCKED)
	rig.send("pause_app")
	rig.send("restart")
	rig.tick()
	assert_eq(rig.core.phase, P.RUNNING)
	assert_eq(_count_event(rig, "run_paused"), 0)
	assert_eq(_count_event(rig, "run_reset"), 1)
	assert_eq(rig.logs.count(), 0)


func test_pause_on_the_countdown_expiry_tick_wins() -> void:
	var rig: Factory = _rig(S.RESUMING)
	rig.clock.advance_us(2_000_000)
	rig.send("pause")
	rig.tick()
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(rig.recorder.names(), ["run_paused", "phase_changed"] as Array[String])
	assert_eq(_count_event(rig, "run_resumed"), 0)


# --- AC-19: permutations ---------------------------------------------------------------------------------------

func _permutations(items: Array[String]) -> Array[Array]:
	if items.size() <= 1:
		return [items.duplicate()]
	var out: Array[Array] = []
	for i: int in items.size():
		var rest: Array[String] = items.duplicate()
		rest.remove_at(i)
		for tail: Array in _permutations(rest):
			var order: Array[String] = [items[i]]
			for name: String in tail:
				order.append(name)
			out.append(order)
	return out


func _run_all_orderings(state: Factory.State, final_phase: int, events: Array[String], levels: Array[int]) -> void:
	var orderings: Array[Array] = _permutations(ALL_FIVE)
	assert_eq(orderings.size(), 120)
	var mismatches: Array[String] = []
	for order: Array in orderings:
		var rig: Factory = _rig(state)
		for name: String in order:
			rig.send(name)
		rig.tick()
		if (
			rig.core.phase != final_phase
			or rig.recorder.names() != events
			or _levels(rig) != levels
		):
			mismatches.append(str(order))
	assert_eq(mismatches, [] as Array[String], "orderings that differ from the hard-coded row")


func test_all_120_orderings_from_running_give_hit_with_3_debug_and_1_warning() -> void:
	_run_all_orderings(S.RUNNING, P.HIT, ["run_ended", "phase_changed"] as Array[String], [D, W, D, D] as Array[int])


func test_all_120_orderings_from_paused_after_guard_give_resuming_with_4_debug() -> void:
	_run_all_orderings(
		S.PAUSED_AFTER, P.RESUMING, ["run_resuming", "phase_changed"] as Array[String], [D, D, D, D] as Array[int]
	)


func test_all_120_orderings_from_unlocked_hit_give_menu_with_phase_changed_only() -> void:
	_run_all_orderings(S.HIT_UNLOCKED, P.MENU, ["phase_changed"] as Array[String], [D, W, W, D] as Array[int])


func test_two_restarts_in_unlocked_hit_give_one_run_either_order() -> void:
	for early_first: bool in [true, false]:
		var rig: Factory = _rig(S.HIT_UNLOCKED)
		var early_us: int = rig.anchor_us + 1000
		if early_first:
			rig.send("restart", early_us)
			rig.send("restart")
		else:
			rig.send("restart")
			rig.send("restart", early_us)
		rig.tick()
		assert_eq(rig.core.phase, P.RUNNING, "early_first=%s" % early_first)
		assert_eq(_count_event(rig, "run_reset"), 1)
		assert_eq(rig.logs.count(), 1, "exactly one rejected restart")
		assert_eq(rig.logs.level_at(0), D)


func test_pause_and_resume_from_running_apply_in_class_order_pause_then_resume() -> void:
	# GDD Open Question 17 asks for a semantic oracle; this records the current class-priority behaviour only.
	var rig: Factory = _rig(S.RUNNING)
	rig.send("resume")
	rig.send("pause")
	rig.tick()
	assert_eq(rig.core.phase, P.RESUMING)
	assert_eq(
		rig.recorder.names(),
		["run_paused", "phase_changed", "run_resuming", "phase_changed"] as Array[String]
	)
	assert_eq(rig.logs.count(), 0)
