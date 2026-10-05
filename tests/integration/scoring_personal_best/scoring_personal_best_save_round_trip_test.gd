## Story SPB-012 (AC-21): a real `SaveCore` over an in-memory `SaveFs`, bound to `ScoreCore` through the real seam
## (`get_value` / `set_value`): a new best survives a cold boot, and a failed write reverts on cold boot.
extends GutTest

const MemFs = preload("res://tests/support/memory_save_fs.gd")
const Fixtures = preload("res://tests/support/scoring_fixtures.gd")
const SaveFixture = preload("res://tests/support/save_fixture.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")

const START_BEST: int = 500
const NEW_BEST: int = 600


## One boot: a `SaveCore` over `fs` (cold `boot_load()`), and a `ScoreCore` reading `s_value` through the real seam.
class Pair:
	extends RefCounted
	var save: SaveCore
	var score: ScoreCore
	var s_stub: Fixtures.SStub


var _fs: MemFs
var _sink: LogSink


func before_each() -> void:
	_fs = MemFs.new()
	_sink = LogSink.new()


func _boot(s_value: float = 0.0) -> Pair:
	var pair: Pair = Pair.new()
	pair.save = SaveCore.new(_fs, func() -> float: return 0.0, func() -> int: return 0, _sink.sink,
			SaveFixture.make_save_fixture())
	pair.save.boot_load()
	var seq: Array[float] = [s_value]
	pair.s_stub = Fixtures.make_s_stub(seq)
	pair.score = ScoreCore.new(pair.s_stub.read, pair.save.get_value, pair.save.set_value, [] as Array[int])
	return pair


func _end_run_at(pair: Pair, score_value: int) -> void:
	pair.s_stub.sequence = [float(score_value) + 0.5] as Array[float]
	pair.s_stub.index = 0
	pair.score.on_run_reset(1)
	pair.score.step()
	pair.score.on_run_ended(1, 7, 1000)


func _seed_best() -> void:
	var seed_pair: Pair = _boot()
	assert_true(seed_pair.save.set_value("scoring", "personal_best", START_BEST))


func test_new_best_round_trips_a_cold_boot() -> void:
	_seed_best()
	var first: Pair = _boot()
	assert_eq(first.score.get_personal_best(), START_BEST, "seeded best read at construction")
	_end_run_at(first, NEW_BEST)
	assert_true(first.score.is_new_best)
	assert_eq(first.score.get_personal_best(), NEW_BEST)
	var second: Pair = _boot()
	assert_eq(second.score.get_personal_best(), NEW_BEST, "a second SaveCore/ScoreCore pair reads the new best")
	assert_eq(second.save.get_value("scoring", "personal_best", 0), NEW_BEST)


func test_failed_write_keeps_session_best_but_cold_boot_reads_old_value() -> void:
	_seed_best()
	var first: Pair = _boot()
	_fs.fail_writes = true
	_end_run_at(first, NEW_BEST)
	assert_true(first.score.is_new_best)
	assert_eq(first.score.get_personal_best(), NEW_BEST, "in-session best is the new value")
	_fs.fail_writes = false
	var second: Pair = _boot()
	assert_eq(second.score.get_personal_best(), START_BEST, "cold boot reads the old value")


func test_tie_and_lower_endings_leave_the_stored_value_untouched() -> void:
	_seed_best()
	var first: Pair = _boot()
	var writes_before: int = _fs.write_calls
	_end_run_at(first, START_BEST)
	assert_false(first.score.is_new_best, "tie is not a new best")
	_end_run_at(first, START_BEST - 100)
	assert_false(first.score.is_new_best)
	assert_eq(_fs.write_calls, writes_before, "no write for a tie or a lower ending")
	assert_eq(_boot().score.get_personal_best(), START_BEST)


func test_first_ever_best_with_no_save_file_round_trips() -> void:
	var first: Pair = _boot()
	assert_eq(first.score.get_personal_best(), 0)
	_end_run_at(first, 42)
	assert_eq(_boot().score.get_personal_best(), 42)
