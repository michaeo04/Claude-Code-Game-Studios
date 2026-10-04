extends GutTest

const Fx = preload("res://tests/support/scoring_fixtures.gd")


func _make(seq: Array[float], best: int) -> Dictionary:
	var s: Fx.SStub = Fx.make_s_stub(seq)
	var core: ScoreCore = Fx.make_core(s, Fx.make_save_stub(best))
	return {"s": s, "core": core, "log": Fx.make_signal_log(core)}


func _step(d: Dictionary, n: int) -> void:
	for i: int in n:
		(d["core"] as ScoreCore).step()


func _rewind(d: Dictionary, seq: Array[float]) -> void:
	var s: Fx.SStub = d["s"]
	s.sequence = seq
	s.index = 0


func test_ac20a_fires_once_at_501_strict() -> void:
	var d: Dictionary = _make([499.5, 500.4, 501.2, 700.0], 500)
	var log: Fx.SignalLog = d["log"]
	_step(d, 2)
	assert_eq(log.entries.size(), 0)
	_step(d, 1)
	assert_eq(log.entries, [["personal_best_passed", 500]])
	_step(d, 1)
	assert_eq(log.entries.size(), 1)


func test_ac20b_never_reaching_best_never_fires() -> void:
	var d: Dictionary = _make([10.0, 300.0, 500.9], 500)
	_step(d, 3)
	assert_eq((d["log"] as Fx.SignalLog).entries.size(), 0)


func test_ac20c_reset_rearms_latch() -> void:
	var d: Dictionary = _make([501.0], 500)
	_step(d, 1)
	(d["core"] as ScoreCore).on_run_reset()
	_rewind(d, [501.0])
	_step(d, 1)
	assert_eq((d["log"] as Fx.SignalLog).count("personal_best_passed"), 2)


func test_ac20d_first_step_crossing_fires_once() -> void:
	var d: Dictionary = _make([501.0], 500)
	_step(d, 3)
	assert_eq((d["log"] as Fx.SignalLog).entries, [["personal_best_passed", 500]])


func test_ac20e_zero_best_suppressed_then_lifts_within_session() -> void:
	var d: Dictionary = _make([1.0], 0)
	_step(d, 1)
	assert_eq((d["log"] as Fx.SignalLog).entries.size(), 0)
	var core: ScoreCore = d["core"]
	core.on_run_reset()
	_rewind(d, [50.0])
	_step(d, 1)
	core.on_run_ended(1, 1, 1)
	assert_eq(core.get_personal_best(), 50)
	core.on_run_reset()
	_rewind(d, [49.0, 51.0])
	_step(d, 2)
	assert_eq((d["log"] as Fx.SignalLog).entries, [["personal_best_updated", 50], ["personal_best_passed", 50]])


func test_ac20f_crossing_then_ending_then_frozen_step() -> void:
	var d: Dictionary = _make([501.0, 501.0, 501.0], 500)
	var core: ScoreCore = d["core"]
	_step(d, 1)
	core.on_run_ended(1, 1, 1)
	_step(d, 2)
	assert_eq((d["log"] as Fx.SignalLog).entries, [["personal_best_passed", 500], ["personal_best_updated", 501]])
	assert_eq(core.get_current_score(), 501)
	assert_eq(core.get_personal_best(), 501)
