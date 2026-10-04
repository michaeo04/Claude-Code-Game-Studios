extends GutTest

const Fx = preload("res://tests/support/scoring_fixtures.gd")


func _run(seq: Array[float], best: int = 500) -> Array[int]:
	var s: Fx.SStub = Fx.make_s_stub(seq)
	var core: ScoreCore = Fx.make_core(s, Fx.make_save_stub(best))
	var out: Array[int] = []
	for i: int in seq.size():
		core.step()
		out.append(core.get_current_score())
	return out


func test_nan_then_inf_hold_last_good_and_ending_writes_finite_int() -> void:
	var s: Fx.SStub = Fx.make_s_stub([700.0, NAN, INF, -INF])
	var save: Fx.SaveStub = Fx.make_save_stub(500)
	var core: ScoreCore = Fx.make_core(s, save)
	for i: int in 4:
		core.step()
		assert_eq(core.get_current_score(), 700)
	core.on_run_ended(1, 1, 1)
	assert_eq(core.final_score, 700)
	assert_eq(save.set_calls, 1)
	assert_eq(save.last_set_args, ["scoring", "personal_best", 700])
	assert_typeof(save.last_set_args[2], TYPE_INT)


func test_negative_holds() -> void:
	assert_eq(_run([10.0, -5.0]), [10, 10] as Array[int])
	assert_eq(_run([-5.0]), [0] as Array[int])


func test_decreasing_holds_at_500() -> void:
	assert_eq(_run([500.0, 490.0]), [500, 500] as Array[int])


func test_huge_finite_holds_without_garbage_int() -> void:
	assert_eq(_run([12.0, 1e19]), [12, 12] as Array[int])


func test_recovery_sequences() -> void:
	assert_eq(_run([500.0, 490.0, 495.0, 510.0]), [500, 500, 500, 510] as Array[int])
	assert_eq(_run([500.0, NAN, 510.0]), [500, 500, 510] as Array[int])


func test_upper_bound_accepted_exactly_and_held_just_above() -> void:
	assert_eq(_run([9.2e18])[0], floori(9.2e18))
	var above: float = 9.2e18 * 1.0000001
	assert_eq(_run([5.0, above]), [5, 5] as Array[int])


func test_nan_first_step_after_reset_holds_zero() -> void:
	var s: Fx.SStub = Fx.make_s_stub([300.0])
	var core: ScoreCore = Fx.make_core(s, Fx.make_save_stub(500))
	core.step()
	core.on_run_reset()
	s.sequence = [NAN]
	s.index = 0
	core.step()
	assert_eq(core.get_current_score(), 0)


func test_held_frame_fires_nothing() -> void:
	var s: Fx.SStub = Fx.make_s_stub([501.0, 400.0, NAN])
	var core: ScoreCore = Fx.make_core(s, Fx.make_save_stub(500))
	var log: Fx.SignalLog = Fx.make_signal_log(core)
	core.step()
	var n: int = log.entries.size()
	core.step()
	core.step()
	assert_eq(log.entries.size(), n)
