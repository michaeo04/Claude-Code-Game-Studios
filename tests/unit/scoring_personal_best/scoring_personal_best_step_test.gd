extends GutTest

const Fx = preload("res://tests/support/scoring_fixtures.gd")


func test_step_publishes_floor_each_tick() -> void:
	var core: ScoreCore = Fx.make_core(Fx.make_s_stub([0.4, 9.999, 10.5, 1574.991, 1575.008]), Fx.make_save_stub(500))
	var expected: Array[int] = [0, 9, 10, 1574, 1575]
	for e: int in expected:
		core.step()
		assert_eq(core.get_current_score(), e)


func test_step_frozen_s_holds_score() -> void:
	var core: ScoreCore = Fx.make_core(Fx.make_s_stub([42.7, 42.7, 42.7, 42.7]), Fx.make_save_stub(500))
	for i: int in 6:
		core.step()
		assert_eq(core.get_current_score(), 42)


func test_reset_zeroes_score_without_step_or_seam_read() -> void:
	var s: Fx.SStub = Fx.make_s_stub([1575.0])
	var core: ScoreCore = Fx.make_core(s, Fx.make_save_stub(500))
	core.step()
	assert_eq(core.get_current_score(), 1575)
	var calls: int = s.calls
	core.on_run_reset()
	core.on_run_reset()
	assert_eq(core.get_current_score(), 0)
	assert_eq(s.calls, calls)
	assert_false(core.has_passed_this_run)
	assert_eq(core.next_milestone_index, 0)


func test_reset_clears_memory_for_next_run() -> void:
	var s: Fx.SStub = Fx.make_s_stub([1575.0])
	var core: ScoreCore = Fx.make_core(s, Fx.make_save_stub(500))
	core.step()
	core.on_run_reset()
	s.sequence = [0.0, 0.5, 3.0, 12.0]
	s.index = 0
	var expected: Array[int] = [0, 0, 3, 12]
	for e: int in expected:
		core.step()
		assert_eq(core.get_current_score(), e)


func test_nan_first_step_after_reset_holds_zero() -> void:
	var s: Fx.SStub = Fx.make_s_stub([1575.0])
	var core: ScoreCore = Fx.make_core(s, Fx.make_save_stub(500))
	core.step()
	core.on_run_reset()
	s.sequence = [NAN]
	s.index = 0
	core.step()
	assert_eq(core.get_current_score(), 0)
