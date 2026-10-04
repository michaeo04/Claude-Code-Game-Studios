extends GutTest

const Fx = preload("res://tests/support/scoring_fixtures.gd")
const SCRIPT_PATH: String = "res://src/core/scoring_personal_best/score_core.gd"

# Mechanism (verified on 4.7.2, story 008): Script.get_script_method_list() returns only script-defined members
# (no inherited RefCounted/Object ones), including static and underscore-prefixed ones; the underscore ones are filtered here.


func _public_methods() -> Array[String]:
	var names: Array[String] = []
	for m: Dictionary in (load(SCRIPT_PATH) as Script).get_script_method_list():
		var n: String = str(m["name"])
		if not n.begins_with("_"):
			names.append(n)
	names.sort()
	return names


func test_ac11b_public_methods_are_exactly_the_closed_set() -> void:
	var expected: Array[String] = [
		"get_current_score", "get_personal_best", "on_run_abandoned", "on_run_ended", "on_run_reset", "step",
		"validate_seams",
	]
	expected.sort()
	assert_eq(_public_methods(), expected)


func test_ac11b_no_near_miss_shaped_method_exists() -> void:
	for n: String in _public_methods():
		assert_false(n.contains("near_miss"), "near-miss method present: " + n)


func test_ac11b_signals_are_exactly_the_three_with_typed_params() -> void:
	var found: Dictionary = {}
	for sg: Dictionary in (load(SCRIPT_PATH) as Script).get_script_signal_list():
		var args: Array = sg["args"]
		var arg_names: Array[String] = []
		for a: Dictionary in args:
			arg_names.append(str(a["name"]) + ":" + str(a["type"]))
		found[str(sg["name"])] = arg_names
	assert_eq(found.size(), 3)
	assert_eq(found.get("personal_best_updated"), ["final_score:%d" % TYPE_INT] as Array[String])
	assert_eq(found.get("personal_best_passed"), ["personal_best:%d" % TYPE_INT] as Array[String])
	assert_eq(found.get("milestone_crossed"), ["threshold:%d" % TYPE_INT] as Array[String])


# Session: boot, run 1 (best 500 beaten at 600), reset, run 2 (not a best), abandon, reset, run 3 (new best 900).
func _run_session(s_stub: Fx.SStub, save: Fx.SaveStub, core: ScoreCore, scores: Array) -> void:
	for step_s: float in [100.0, 600.0]:
		s_stub.sequence = [step_s]
		s_stub.index = 0
		core.step()
	scores.append(core.get_current_score())
	core.on_run_ended(1, 1, 1000)
	core.on_run_reset()
	for step_s: float in [10.0, 20.0, 30.0]:
		s_stub.sequence = [step_s]
		s_stub.index = 0
		core.step()
		scores.append(core.get_current_score())
	core.on_run_abandoned(2, 500)
	scores.append(core.is_new_best)
	core.on_run_reset()
	s_stub.sequence = [900.5]
	s_stub.index = 0
	core.step()
	scores.append(core.get_current_score())
	core.on_run_ended(3, 1, 800)
	scores.append(core.is_new_best)


func test_ac12_seam_budget_over_mixed_session() -> void:
	var s_stub: Fx.SStub = Fx.make_s_stub([])
	var save: Fx.SaveStub = Fx.make_save_stub(500)
	var core: ScoreCore = Fx.make_core(s_stub, save, [100, 250] as Array[int])
	assert_eq(save.get_calls, 1)
	assert_eq(save.set_calls, 0)
	var scores: Array = []
	_run_session(s_stub, save, core, scores)
	# 2 + 3 + 1 steps, resets and endings never read s.
	assert_eq(s_stub.calls, 6)
	assert_eq(save.get_calls, 1)
	assert_eq(save.set_calls, 2)


func test_ac12_reset_and_endings_do_not_read_s() -> void:
	var s_stub: Fx.SStub = Fx.make_s_stub([5.0])
	var save: Fx.SaveStub = Fx.make_save_stub(0)
	var core: ScoreCore = Fx.make_core(s_stub, save)
	core.step()
	core.on_run_ended(1, 1, 1)
	core.on_run_reset()
	core.on_run_abandoned(1, 1)
	assert_eq(s_stub.calls, 1)
	assert_eq(save.set_calls, 1)


func test_ac13_two_cores_are_bit_identical() -> void:
	var results: Array = []
	for i: int in 2:
		var s_stub: Fx.SStub = Fx.make_s_stub([])
		var save: Fx.SaveStub = Fx.make_save_stub(500)
		var core: ScoreCore = Fx.make_core(s_stub, save, [100, 250] as Array[int])
		var scores: Array = []
		_run_session(s_stub, save, core, scores)
		results.append(scores)
	assert_eq(results[0], results[1])
	assert_eq(results[0], [600, 10, 20, 30, false, 900, true])
