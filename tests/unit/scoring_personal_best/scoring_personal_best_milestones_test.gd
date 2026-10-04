extends GutTest

const Fx = preload("res://tests/support/scoring_fixtures.gd")


class MilestoneLog:
	extends RefCounted
	var thresholds: Array[int] = []

	func on_crossed(threshold: int) -> void:
		thresholds.append(threshold)


func _make(seq: Array[float], milestones: Array[int]) -> Dictionary:
	var s: Fx.SStub = Fx.make_s_stub(seq)
	var core: ScoreCore = Fx.make_core(s, Fx.make_save_stub(0), milestones)
	var log: MilestoneLog = MilestoneLog.new()
	core.milestone_crossed.connect(log.on_crossed)
	return {"s": s, "core": core, "log": log}


func _step(d: Dictionary, n: int) -> void:
	for i: int in n:
		(d["core"] as ScoreCore).step()


func _rewind(d: Dictionary, seq: Array[float]) -> void:
	var s: Fx.SStub = d["s"]
	s.sequence = seq
	s.index = 0


func test_ac23_fires_each_once_in_order_and_rearms_after_reset() -> void:
	var seq: Array[float] = [99.0, 101.0, 249.0, 251.0, 300.0]
	var d: Dictionary = _make(seq, [100, 250])
	var log: MilestoneLog = d["log"]
	_step(d, 1)
	assert_eq(log.thresholds, [] as Array[int])
	_step(d, 1)
	assert_eq(log.thresholds, [100] as Array[int])
	_step(d, 2)
	assert_eq(log.thresholds, [100, 250] as Array[int])
	_step(d, 1)
	assert_eq(log.thresholds, [100, 250] as Array[int])
	(d["core"] as ScoreCore).on_run_reset()
	_rewind(d, seq)
	_step(d, 5)
	assert_eq(log.thresholds, [100, 250, 100, 250] as Array[int])


func test_ac23_boundary_exact_100_fires_and_99_999_does_not() -> void:
	var d: Dictionary = _make([99.999, 100.0], [100])
	var log: MilestoneLog = d["log"]
	_step(d, 1)
	assert_eq(log.thresholds.size(), 0)
	_step(d, 1)
	assert_eq(log.thresholds, [100] as Array[int])


func test_ac23_first_step_100_after_reset_fires() -> void:
	var d: Dictionary = _make([50.0, 100.0], [100])
	var log: MilestoneLog = d["log"]
	_step(d, 1)
	(d["core"] as ScoreCore).on_run_reset()
	_step(d, 1)
	assert_eq(log.thresholds, [100] as Array[int])


func test_ac23_empty_thresholds_fire_nothing_over_long_run() -> void:
	var seq: Array[float] = []
	for i: int in 200:
		seq.append(float(i * 50))
	var d: Dictionary = _make(seq, [])
	_step(d, 200)
	assert_eq((d["log"] as MilestoneLog).thresholds.size(), 0)


func test_ac24_jump_fires_all_three_in_order_in_one_step() -> void:
	var d: Dictionary = _make([90.0, 600.0], [100, 250, 500])
	var log: MilestoneLog = d["log"]
	_step(d, 1)
	assert_eq(log.thresholds.size(), 0)
	_step(d, 1)
	assert_eq(log.thresholds, [100, 250, 500] as Array[int])


func test_ac25_validator_flags_descending_and_duplicate() -> void:
	assert_eq(ScoringConfig.validate_milestones([250, 100]).size(), 1)
	assert_eq(ScoringConfig.validate_milestones([100, 100]).size(), 1)


func test_ac25_validator_flags_non_positive_and_non_integer() -> void:
	assert_eq(ScoringConfig.validate_milestones([0]).size(), 1)
	assert_eq(ScoringConfig.validate_milestones([-5]).size(), 1)
	assert_eq(ScoringConfig.validate_milestones([100.5]).size(), 1)


func test_ac25_validator_accepts_valid_and_empty() -> void:
	assert_eq(ScoringConfig.validate_milestones([100, 250]), [] as Array[String])
	assert_eq(ScoringConfig.validate_milestones([]), [] as Array[String])


func test_ac25_validator_mixed_violations_one_message_each() -> void:
	assert_eq(ScoringConfig.validate_milestones([100, 50, 0, 100.5, 300]).size(), 3)


func test_ac25_default_config_is_valid() -> void:
	assert_eq(ScoringConfig.validate_milestones(ScoringConfig.new().milestone_distances), [] as Array[String])
