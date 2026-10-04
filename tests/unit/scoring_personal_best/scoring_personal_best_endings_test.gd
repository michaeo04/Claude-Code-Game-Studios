extends GutTest

const Fx = preload("res://tests/support/scoring_fixtures.gd")


func _make(seq: Array[float], best: Variant = 500, ok: bool = true) -> Dictionary:
	var s: Fx.SStub = Fx.make_s_stub(seq)
	var save: Fx.SaveStub = Fx.make_save_stub(best, ok)
	var core: ScoreCore = Fx.make_core(s, save)
	for i: int in seq.size():
		core.step()
	return {"core": core, "save": save, "log": Fx.make_signal_log(core), "s": s}


func _snapshot(d: Dictionary) -> Array:
	var core: ScoreCore = d["core"]
	var save: Fx.SaveStub = d["save"]
	var log: Fx.SignalLog = d["log"]
	return [core.final_score, core.is_new_best, save.set_calls, save.last_set_args, log.count("personal_best_updated")]


func test_both_endings_identical_for_new_best_and_not() -> void:
	var seqs: Array = [[650.5], [300.0]]
	for raw: Array in seqs:
		var seq: Array[float] = []
		seq.assign(raw)
		var a: Dictionary = _make(seq)
		var b: Dictionary = _make(seq)
		(a["core"] as ScoreCore).on_run_ended(1, 7, 1000)
		(b["core"] as ScoreCore).on_run_abandoned(1, 1000)
		assert_eq(_snapshot(a), _snapshot(b))


func test_abandon_only_produces_score() -> void:
	var d: Dictionary = _make([650.0])
	(d["core"] as ScoreCore).on_run_abandoned(1, 5)
	assert_eq((d["core"] as ScoreCore).final_score, 650)
	assert_true((d["core"] as ScoreCore).is_new_best)


func test_hazard_id_and_run_time_do_not_change_outcome() -> void:
	var a: Dictionary = _make([650.0])
	var b: Dictionary = _make([650.0])
	(a["core"] as ScoreCore).on_run_ended(1, 1, 10)
	(b["core"] as ScoreCore).on_run_ended(99, 42, 999999)
	assert_eq(_snapshot(a), _snapshot(b))


func test_non_new_best_has_zero_writes_and_events_for_both_endings() -> void:
	var a: Dictionary = _make([400.0])
	var b: Dictionary = _make([400.0])
	(a["core"] as ScoreCore).on_run_ended(1, 1, 1)
	(b["core"] as ScoreCore).on_run_abandoned(1, 1)
	for d: Dictionary in [a, b]:
		assert_eq((d["save"] as Fx.SaveStub).set_calls, 0)
		assert_eq((d["log"] as Fx.SignalLog).entries.size(), 0)


func test_strict_new_best_writes_once_and_best_readable_in_event() -> void:
	var s: Fx.SStub = Fx.make_s_stub([600.0])
	var save: Fx.SaveStub = Fx.make_save_stub(500)
	var core: ScoreCore = Fx.make_core(s, save)
	var seen: Array[int] = []
	core.personal_best_updated.connect(func(v: int) -> void: seen.append(core.get_personal_best() * 1000 + v))
	core.step()
	core.on_run_ended(1, 1, 1)
	assert_eq(save.set_calls, 1)
	assert_eq(save.last_set_args, ["scoring", "personal_best", 600])
	assert_eq(seen, [600600] as Array[int])
	assert_eq(core.get_personal_best(), 600)


func test_tie_and_lower_do_not_write() -> void:
	for v: float in [500.0, 400.0]:
		var d: Dictionary = _make([v])
		(d["core"] as ScoreCore).on_run_ended(1, 1, 1)
		assert_eq((d["save"] as Fx.SaveStub).set_calls, 0)
		assert_eq((d["log"] as Fx.SignalLog).entries.size(), 0)
		assert_eq((d["core"] as ScoreCore).get_personal_best(), 500)


func test_failed_write_keeps_in_memory_best_and_fires_event() -> void:
	var d: Dictionary = _make([600.0], 500, false)
	var core: ScoreCore = d["core"]
	core.on_run_ended(1, 1, 1)
	assert_eq(core.get_personal_best(), 600)
	assert_eq((d["log"] as Fx.SignalLog).count("personal_best_updated"), 1)
	assert_eq((d["save"] as Fx.SaveStub).set_calls, 1)
	core.on_run_reset()
	var s: Fx.SStub = d["s"]
	s.sequence = [550.0]
	s.index = 0
	core.step()
	core.on_run_ended(2, 1, 1)
	assert_false(core.is_new_best)
	assert_eq((d["save"] as Fx.SaveStub).set_calls, 1)


func test_zero_distance_ending_never_new_best() -> void:
	for stored: int in [0, 500, -5]:
		for abandon: bool in [false, true]:
			var s: Fx.SStub = Fx.make_s_stub([])
			var save: Fx.SaveStub = Fx.make_save_stub(stored)
			var core: ScoreCore = Fx.make_core(s, save)
			core.on_run_reset()
			if abandon:
				core.on_run_abandoned(1, 0)
			else:
				core.on_run_ended(1, 1, 0)
			assert_eq(core.final_score, 0)
			assert_false(core.is_new_best)
			assert_eq(save.set_calls, 0)


func test_double_ending_writes_and_fires_once() -> void:
	var d: Dictionary = _make([600.0])
	var core: ScoreCore = d["core"]
	core.on_run_ended(1, 1, 1)
	core.on_run_abandoned(1, 1)
	assert_eq((d["save"] as Fx.SaveStub).set_calls, 1)
	assert_eq((d["log"] as Fx.SignalLog).count("personal_best_updated"), 1)
