## Story CRF-007: the `_wire()` row table, its sort and the pinned subscriber order (ADR-0002 Decision 7).
extends GutTest

const Fakes = preload("res://tests/support/rebase_fakes.gd")
const WireSpy = preload("res://tests/support/wire_spy.gd")

const EXPECTED: Array[String] = [
	"pattern.run_reset", "obstacle.run_reset", "ball.run_reset", "camera.run_reset", "other.run_reset",
	"juice.run_ended", "scoring.run_ended", "hud.run_ended", "other.run_ended",
	"juice.run_abandoned", "scoring.run_abandoned", "other.run_abandoned",
]

var _log: Array[String] = []
var _rs: RunStateCore
var _root: GameRoot
var _spies: Dictionary = {}
var _frame: WorldFrame


func before_each() -> void:
	_log.clear()
	_rs = RunStateCore.new(RunConfig.new(), func() -> int: return 0, Callable())
	_frame = WorldFrame.new(WorldFrameConfig.new(), WorldGeometry.new())
	for n: String in ["pattern", "obstacle", "ball", "camera", "other", "juice", "scoring", "hud"]:
		_spies[n] = WireSpy.new(n, _log)
	var view: Fakes.View = Fakes.View.new(_frame, "v", _log)
	_root = GameRoot.new(Callable())
	var overrides: Dictionary = {&"juice": _spies["juice"], &"scoring": _spies["scoring"]}
	assert_true(_root.inject_systems(Fakes.systems(_rs, Fakes.Stub.new(), _frame, view, view, overrides)))


func after_each() -> void:
	_root.free()


func _spy(spy_name: String) -> WireSpy:
	return _spies[spy_name] as WireSpy


func _add_all_rows(reversed: bool) -> void:
	var rows: Array = [
		[_rs.run_reset, _spy("camera").on_run_reset, GameRoot.RANK_CAMERA],
		[_rs.run_reset, _spy("other").on_run_reset, GameRoot.RANK_REST],
		[_rs.run_reset, _spy("ball").on_run_reset, GameRoot.RANK_BALL],
		[_rs.run_reset, _spy("obstacle").on_run_reset, GameRoot.RANK_TUBE_OBSTACLE],
		[_rs.run_reset, _spy("pattern").on_run_reset, GameRoot.RANK_PATTERN_FRAME],
		[_rs.run_ended, _spy("other").on_run_ended, GameRoot.RANK_ENDED_REST],
		[_rs.run_ended, _spy("hud").on_run_ended, GameRoot.RANK_HUD],
		[_rs.run_ended, _spy("scoring").on_run_ended, GameRoot.RANK_SCORING],
		[_rs.run_ended, _spy("juice").on_run_ended, GameRoot.RANK_JUICE],
		[_rs.run_abandoned, _spy("other").on_run_abandoned, GameRoot.RANK_REST],
		[_rs.run_abandoned, _spy("scoring").on_run_abandoned, GameRoot.RANK_SCORING],
		[_rs.run_abandoned, _spy("juice").on_run_abandoned, GameRoot.RANK_JUICE],
	]
	if reversed:
		rows.reverse()
	for row: Array in rows:
		_root.add_wire_row(row[0] as Signal, row[1] as Callable, row[2] as int)


func _emit_all() -> void:
	_log.clear()
	_rs.run_reset.emit(1)
	_rs.run_ended.emit(1, 2, 3)
	_rs.run_abandoned.emit(1, 3)


func test_wire_pinned_order_per_signal_and_after_disconnect_reconnect() -> void:
	_add_all_rows(false)
	assert_eq(_root._wire(), OK)
	_emit_all()
	assert_eq(_log, EXPECTED, "run_reset / run_ended / run_abandoned order")
	_root.unwire()
	_emit_all()
	assert_eq(_log.size(), 0, "unwire removed every row")
	assert_eq(_root._wire(), OK)
	_emit_all()
	assert_eq(_log, EXPECTED, "same order after disconnect and reconnect")


func test_wire_world_frame_row_is_rank_one_and_resets_origin() -> void:
	_frame.origin_s = 1008.0
	assert_eq(_root._wire(), OK)
	_rs.run_reset.emit(1)
	assert_eq(_frame.origin_s, 0.0)


func test_wire_input_order_does_not_change_the_connect_order() -> void:
	_add_all_rows(true)
	assert_eq(_root._wire(), OK)
	_emit_all()
	assert_eq(_log, EXPECTED, "ranks are unique per signal here, so input order does not matter")


func test_wire_ties_follow_row_index() -> void:
	var a: Array = [_rs.run_reset, _spy("pattern").on_run_reset, 1]
	var b: Array = [_rs.run_reset, _spy("obstacle").on_run_reset, 1]
	var c: Array = [_rs.run_reset, _spy("ball").on_run_reset, 0]
	assert_eq(GameRoot.order_rows([a, b, c]), [c, a, b])
	assert_eq(GameRoot.order_rows([b, a, c]), [c, b, a])
	var many: Array = []
	for i: int in 40:
		many.append([_rs.run_reset, a[1], i % 3, i])
	var ordered: Array = GameRoot.order_rows(many)
	for i: int in range(1, ordered.size()):
		var prev: Array = ordered[i - 1] as Array
		var cur: Array = ordered[i] as Array
		var in_order: bool = (prev[2] as int) < (cur[2] as int) or ((prev[2] as int) == (cur[2] as int) and (prev[3] as int) < (cur[3] as int))
		assert_true(in_order, "row %d follows (rank, index)" % i)


func test_wire_untyped_handler_is_rejected_with_a_code() -> void:
	var rows: Array = [[_rs.run_reset, _spy("ball").on_untyped_reset, 1]]
	assert_eq(GameRoot.validate_rows(rows), [GameRoot.CODE_HANDLER_UNTYPED] as Array[String])
	_root.add_wire_row(_rs.run_reset, _spy("ball").on_untyped_reset, 1)
	assert_eq(_root._wire(), ERR_INVALID_DATA)
	assert_push_error("WIRE_HANDLER_UNTYPED")
	_rs.run_reset.emit(1)
	assert_eq(_log.size(), 0, "a failed validation connects nothing")


func test_wire_every_row_is_valid_and_typed() -> void:
	_add_all_rows(false)
	assert_eq(GameRoot.validate_rows(_root._build_rows()).size(), 0)
	var bad: Array = [[_rs.run_reset, Callable(), 1]]
	assert_eq(GameRoot.validate_rows(bad), [GameRoot.CODE_ROW_INVALID] as Array[String])


func test_wire_scoring_before_juice_fails_loudly() -> void:
	_root.add_wire_row(_rs.run_ended, _spy("scoring").on_run_ended, GameRoot.RANK_JUICE)
	_root.add_wire_row(_rs.run_ended, _spy("juice").on_run_ended, GameRoot.RANK_SCORING)
	assert_eq(_root._wire(), ERR_INVALID_DATA)
	assert_push_error("WIRE_JUICE_AFTER_SCORING")
	_rs.run_ended.emit(1, 2, 3)
	assert_eq(_log.size(), 0)


func test_wire_emit_before_connect_is_lost() -> void:
	_root.add_wire_row(_rs.run_reset, _spy("pattern").on_run_reset, GameRoot.RANK_PATTERN_FRAME)
	_rs.run_reset.emit(1)
	assert_eq(_log.size(), 0, "negative control: nothing connected yet, the emit is lost")
	assert_eq(_root._wire(), OK)
	_rs.run_reset.emit(1)
	assert_eq(_log, ["pattern.run_reset"] as Array[String])
