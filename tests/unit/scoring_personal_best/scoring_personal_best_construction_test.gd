extends GutTest

const Fx = preload("res://tests/unit/scoring_personal_best/scoring_personal_best_fixtures.gd")


func _noop_f() -> float:
	return 0.0


func _noop_g(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> Variant:
	return 0


func test_construction_reads_save_exactly_once_across_cycles() -> void:
	var s: Fx.SStub = Fx.make_s_stub([1.0, 2.0, 3.0])
	var save: Fx.SaveStub = Fx.make_save_stub(500)
	var core: ScoreCore = Fx.make_core(s, save)
	assert_eq(save.get_calls, 1, "count after construction")
	assert_eq(save.last_get_args, ["scoring", "personal_best", 0])
	for i: int in 3:
		core.on_run_reset()
		core.step()
		core.step()
	assert_eq(save.get_calls, 1)
	assert_eq(core.get_personal_best(), 500)


func test_consecutive_resets_without_step_keep_count_and_score() -> void:
	var save: Fx.SaveStub = Fx.make_save_stub(500)
	var core: ScoreCore = Fx.make_core(Fx.make_s_stub([5.0]), save)
	core.on_run_reset()
	core.on_run_reset()
	assert_eq(save.get_calls, 1)
	assert_eq(core.get_current_score(), 0)


func test_init_has_exactly_four_non_near_miss_parameters() -> void:
	var core: ScoreCore = Fx.make_core(Fx.make_s_stub([]), Fx.make_save_stub(0))
	var found: bool = false
	for m: Dictionary in core.get_script().get_script_method_list():
		if m["name"] == "_init":
			found = true
			var names: Array = []
			for a: Dictionary in m["args"]:
				names.append(a["name"])
			assert_eq(names, ["s_seam", "get_value_seam", "set_value_seam", "milestone_distances"])
			for n: String in names:
				assert_false(n.contains("near") or n.contains("miss"), n)
	assert_true(found)


func test_validate_seams_rejects_each_unset_slot() -> void:
	var s: Callable = Callable(self, "_noop_f")
	var g: Callable = Callable(self, "_noop_g")
	assert_true(ScoreCore.validate_seams(s, g, g))
	assert_false(ScoreCore.validate_seams(Callable(), g, g))
	assert_false(ScoreCore.validate_seams(s, Callable(), g))
	assert_false(ScoreCore.validate_seams(s, g, Callable()))


func test_no_save_file_default_zero_compares_against_zero() -> void:
	var core: ScoreCore = Fx.make_core(Fx.make_s_stub([]), Fx.make_save_stub(0))
	assert_eq(core.get_current_score(), 0)
	assert_eq(core.get_personal_best(), 0)
	assert_true(ScoreMath.is_new_best(1, core.get_personal_best()))
	assert_false(ScoreMath.is_new_best(0, core.get_personal_best()))


func test_negative_best_clamps_to_zero() -> void:
	var core: ScoreCore = Fx.make_core(Fx.make_s_stub([]), Fx.make_save_stub(-5))
	assert_eq(core.get_personal_best(), 0)
	assert_false(ScoreMath.is_new_best(0, core.get_personal_best()))


func test_minus_one_best_then_ending_one_is_new_best() -> void:
	var core: ScoreCore = Fx.make_core(Fx.make_s_stub([]), Fx.make_save_stub(-1))
	assert_eq(core.get_personal_best(), 0)
	assert_true(ScoreMath.is_new_best(1, core.get_personal_best()))


func test_oversized_best_is_not_clamped() -> void:
	var core: ScoreCore = Fx.make_core(Fx.make_s_stub([]), Fx.make_save_stub(9223372036854775806))
	assert_eq(core.get_personal_best(), 9223372036854775806)
	assert_false(ScoreMath.is_new_best(5000, core.get_personal_best()))


func test_float_best_truncates_to_int() -> void:
	var core: ScoreCore = Fx.make_core(Fx.make_s_stub([]), Fx.make_save_stub(500.7))
	assert_eq(core.get_personal_best(), 500)
	assert_eq(typeof(core.get_personal_best()), TYPE_INT)
