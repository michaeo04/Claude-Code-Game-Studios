## Story RS-012: subscriber order through the real `GameRoot._wire()` (AC-30) and the tick driver contract
## (D4 / TR-024, TR-012): `real_dt` from the injected clock, Ball stepped by `dt_eff`, Tube Track `advance` only in Running.
extends GutTest

const Fakes = preload("res://tests/support/rebase_fakes.gd")
const WireSpy = preload("res://tests/support/wire_spy.gd")
const Factory = preload("res://tests/support/run_state_factory.gd")

const RESET_ORDER: Array[String] = [
	"pattern.run_reset", "adapter.run_reset", "adapter.window_primed", "obstacle.run_reset", "ball.run_reset",
	"camera.run_reset", "other.run_reset", "run_started",
]
const ENDED_ORDER: Array[String] = [
	"juice.run_ended", "scoring.run_ended", "juice.pb_latched", "hud.run_ended", "other.run_ended",
]
const ABANDONED_ORDER: Array[String] = [
	"juice.run_abandoned", "scoring.run_abandoned", "other.run_abandoned",
]


## Tube Track adapter spy: its run_reset handler appends the `window_primed` emission.
class AdapterSpy extends RefCounted:
	var log: Array[String]

	func _init(shared_log: Array[String]) -> void:
		log = shared_log

	func on_run_reset(_run_id: int) -> void:
		log.append("adapter.run_reset")
		log.append("adapter.window_primed")


## Juice spy: latches `personal_best_updated` (the listener side of Scoring's emission).
class JuiceSpy extends WireSpy:
	func _init(shared_log: Array[String]) -> void:
		super("juice", shared_log)

	func on_pb(_distance: float) -> void:
		_log.append("juice.pb_latched")

	func tick() -> void:
		pass


## Scoring spy: emits `personal_best_updated` inside its run_ended handler.
class ScoringSpy extends WireSpy:
	signal personal_best_updated(distance: float)

	func _init(shared_log: Array[String]) -> void:
		super("scoring", shared_log)

	func on_run_ended(run_id: int, hazard_id: int, run_time_ms: int) -> void:
		super(run_id, hazard_id, run_time_ms)
		personal_best_updated.emit(1.0)

	func step() -> void:
		pass


## Tube Track spy for the driver: records the phase read at every `advance` call.
class TrackSpy extends RefCounted:
	var run_state: RunStateCore
	var calls: int = 0
	var rejected: int = 0

	func advance(_ball_s: float) -> void:
		calls += 1
		if run_state.phase != RunStateCore.Phase.RUNNING:
			rejected += 1


## Ball spy for the driver: records every `dt_eff` it is stepped with.
class BallSpy extends RefCounted:
	var s: float = 0.0
	var dts: Array[float] = []

	func step(dt_eff: float, _steer: float, _valid: bool, _source: int) -> void:
		dts.append(dt_eff)
		s += 25.0 * dt_eff


var _log: Array[String] = []
var _rig: Factory
var _rs: RunStateCore
var _root: GameRoot
var _frame: WorldFrame
var _juice: JuiceSpy
var _scoring: ScoringSpy
var _saved_time_scale: float = 1.0
var _keep: Array[RefCounted] = []


func before_each() -> void:
	_log.clear()
	_keep.clear()
	_saved_time_scale = Engine.time_scale
	_rig = Factory.new()
	_rs = _rig.core
	_frame = WorldFrame.new(WorldFrameConfig.new(), WorldGeometry.new())
	_juice = JuiceSpy.new(_log)
	_scoring = ScoringSpy.new(_log)
	_scoring.personal_best_updated.connect(_juice.on_pb)


func after_each() -> void:
	Engine.time_scale = _saved_time_scale
	if _root != null:
		_root.free()
		_root = null


func _make_root(overrides: Dictionary = {}) -> void:
	var view: Fakes.View = Fakes.View.new(_frame, "v", _log)
	var merged: Dictionary = {&"juice": _juice, &"scoring": _scoring}
	merged.merge(overrides, true)
	_root = GameRoot.new(_rig.clock.as_callable())
	assert_true(_root.inject_systems(Fakes.systems(_rs, Fakes.Stub.new(), _frame, view, view, merged)))


## Registers the pinned subscribers; `swap_ranks` mutates ranks (adapter ahead of Pattern, Camera ahead of Ball).
func _add_rows(swap_ranks: bool = false) -> void:
	var adapter: AdapterSpy = AdapterSpy.new(_log)
	_keep.append(adapter)
	var spies: Dictionary = {}
	for n: String in ["pattern", "obstacle", "ball", "camera", "other", "hud"]:
		spies[n] = WireSpy.new(n, _log)
		_keep.append(spies[n] as RefCounted)
	var pattern_rank: int = GameRoot.RANK_TUBE_OBSTACLE if swap_ranks else GameRoot.RANK_PATTERN_FRAME
	var adapter_rank: int = GameRoot.RANK_PATTERN_FRAME if swap_ranks else GameRoot.RANK_TUBE_OBSTACLE
	var camera_rank: int = GameRoot.RANK_BALL if swap_ranks else GameRoot.RANK_CAMERA
	var ball_rank: int = GameRoot.RANK_CAMERA if swap_ranks else GameRoot.RANK_BALL
	# Registered in a deliberately scrambled order: the ranks, not the registration order, decide.
	_root.add_wire_row(_rs.run_reset, (spies["other"] as WireSpy).on_run_reset, GameRoot.RANK_REST)
	_root.add_wire_row(_rs.run_reset, (spies["camera"] as WireSpy).on_run_reset, camera_rank)
	_root.add_wire_row(_rs.run_reset, (spies["ball"] as WireSpy).on_run_reset, ball_rank)
	_root.add_wire_row(_rs.run_reset, adapter.on_run_reset, adapter_rank)
	_root.add_wire_row(_rs.run_reset, (spies["obstacle"] as WireSpy).on_run_reset, GameRoot.RANK_TUBE_OBSTACLE)
	_root.add_wire_row(_rs.run_reset, (spies["pattern"] as WireSpy).on_run_reset, pattern_rank)
	_root.add_wire_row(_rs.run_ended, (spies["other"] as WireSpy).on_run_ended, GameRoot.RANK_ENDED_REST)
	_root.add_wire_row(_rs.run_ended, (spies["hud"] as WireSpy).on_run_ended, GameRoot.RANK_HUD)
	_root.add_wire_row(_rs.run_ended, _scoring.on_run_ended, GameRoot.RANK_SCORING)
	_root.add_wire_row(_rs.run_ended, _juice.on_run_ended, GameRoot.RANK_JUICE)
	_root.add_wire_row(_rs.run_abandoned, (spies["other"] as WireSpy).on_run_abandoned, GameRoot.RANK_REST)
	_root.add_wire_row(_rs.run_abandoned, _scoring.on_run_abandoned, GameRoot.RANK_SCORING)
	_root.add_wire_row(_rs.run_abandoned, _juice.on_run_abandoned, GameRoot.RANK_JUICE)


func _wire_rows(swap_ranks: bool = false) -> void:
	_make_root()
	_add_rows(swap_ranks)
	assert_eq(_root._wire(), OK)
	_rs.run_started.connect(func(_id: int) -> void: _log.append("run_started"))


## Hit then accepted restart; returns the logs of the two steps.
func _drive_hit_and_restart() -> Array:
	_rig.core_in(Factory.State.RUNNING)
	_log.clear()
	_rig.send("hit")
	_rig.tick()
	var ended: Array[String] = _log.duplicate()
	_log.clear()
	_rig.clock.advance_us(_rig.config.restart_lock_us())
	_rig.tick()
	_rig.send("restart")
	_rig.tick()
	return [ended, _log.duplicate()]


func _drive_abandon_from_paused() -> Array[String]:
	_rig.core_in(Factory.State.PAUSED_AFTER)
	_log.clear()
	_rig.send("menu")
	_rig.tick()
	return _log.duplicate()


func test_ac30_restart_run_reset_order_before_run_started() -> void:
	_rig = Factory.new()
	_rs = _rig.core
	_wire_rows()
	var logs: Array = _drive_hit_and_restart()
	assert_eq(logs[1], RESET_ORDER, "Pattern, adapter(+window_primed), Obstacle, Ball, Camera, rank 5, run_started")


func test_ac30_hit_run_ended_order_juice_before_personal_best() -> void:
	_wire_rows()
	var logs: Array = _drive_hit_and_restart()
	assert_eq(logs[0], ENDED_ORDER, "Juice, then Scoring (pb emitted inside), HUD, other")
	assert_lt((logs[0] as Array).find("juice.run_ended"), (logs[0] as Array).find("juice.pb_latched"))


func test_ac30_abandon_from_paused_order() -> void:
	_wire_rows()
	assert_eq(_drive_abandon_from_paused(), ABANDONED_ORDER)


func test_ac30_order_survives_disconnect_and_reconnect() -> void:
	_wire_rows()
	_root.unwire()
	var rows_before: int = _root._rows.size()
	assert_eq(_root._wire(), OK)
	assert_eq(_root._rows.size(), rows_before)
	for row: Array in _root._connected:
		assert_true((row[1] as Callable).is_valid(), "no invalid row Callable after _wire()")
		assert_true((row[0] as Signal).is_connected(row[1] as Callable))
	var logs: Array = _drive_hit_and_restart()
	assert_eq(logs[0], ENDED_ORDER)
	assert_eq(logs[1], RESET_ORDER)


func test_ac30_mutated_rank_order_is_caught() -> void:
	_wire_rows(true)
	var logs: Array = _drive_hit_and_restart()
	assert_ne(logs[1], RESET_ORDER, "adapter ahead of Pattern and Camera ahead of Ball must not match the pin")
	var reset: Array = logs[1]
	assert_lt(reset.find("adapter.run_reset"), reset.find("pattern.run_reset"))
	assert_lt(reset.find("camera.run_reset"), reset.find("ball.run_reset"))


func test_ac30_scoring_before_juice_root_fails() -> void:
	_make_root()
	_root.add_wire_row(_rs.run_ended, _scoring.on_run_ended, GameRoot.RANK_JUICE)
	_root.add_wire_row(_rs.run_ended, _juice.on_run_ended, GameRoot.RANK_SCORING)
	assert_eq(_root._wire(), ERR_INVALID_DATA)
	assert_push_error("WIRE_JUICE_AFTER_SCORING")
	assert_eq(_root._connected.size(), 0, "a failed table connects nothing")


func _make_driver_root(track: TrackSpy, ball: BallSpy) -> void:
	track.run_state = _rs
	_make_root({&"tube_track": track, &"ball": ball})
	assert_eq(_root._wire(), OK)


func test_driver_time_scale_does_not_affect_real_dt_and_advance_only_in_running() -> void:
	_rig.core_in(Factory.State.RUNNING)
	var track: TrackSpy = TrackSpy.new()
	var ball: BallSpy = BallSpy.new()
	_make_driver_root(track, ball)
	Engine.time_scale = 0.1
	_root._process(0.001) # first tick: real_dt 0, engine delta ignored
	for i: int in 3:
		_rig.clock.advance_s(1.0 / 60.0)
		_root._process(1.0 / 600.0) # the engine delta under time_scale 0.1 is not used
	assert_eq(_rs.phase, RunStateCore.Phase.RUNNING)
	assert_eq(ball.dts.size(), 4)
	for i: int in range(1, 4):
		assert_almost_eq(ball.dts[i], 1.0 / 60.0, 1e-6, "Ball stepped by dt_eff from the clock")
	assert_eq(track.calls, 4)
	# 0.6 s clock jump in Running: the stall guard fires from the clock
	_rig.clock.advance_s(0.6)
	_root._process(1.0 / 600.0)
	assert_eq(_rs.phase, RunStateCore.Phase.PAUSED, "stall pause from the clock jump")
	assert_eq(ball.dts[4], 0.0, "no world step on the stall tick")
	assert_eq(track.calls, 4, "advance not called once the phase reads Paused")
	for i: int in 3:
		_rig.clock.advance_s(1.0 / 60.0)
		_root._process(1.0 / 600.0)
	assert_eq(track.calls, 4)
	assert_eq(track.rejected, 0, "zero rejected advance() calls")


func test_driver_advance_never_called_outside_running_over_lifecycle() -> void:
	_rig.core_in(Factory.State.MENU)
	var track: TrackSpy = TrackSpy.new()
	var ball: BallSpy = BallSpy.new()
	_make_driver_root(track, ball)
	Engine.time_scale = 0.1
	_root._process(0.0)
	for i: int in 2:
		_rig.clock.advance_s(1.0 / 60.0)
		_root._process(0.0)
	assert_eq(track.calls, 0, "Menu: no advance")
	_rs.request_start()
	for i: int in 6:
		_rig.clock.advance_s(1.0 / 60.0)
		_root._process(0.0)
	assert_gt(track.calls, 0, "Running reached")
	_rs.request_hit(1, _rs.run_id)
	for i: int in 4:
		_rig.clock.advance_s(1.0 / 60.0)
		_root._process(0.0)
	assert_eq(_rs.phase, RunStateCore.Phase.HIT)
	var calls_at_hit: int = track.calls
	_rig.clock.advance_s(1.0 / 60.0)
	_root._process(0.0)
	assert_eq(track.calls, calls_at_hit, "Hit: no advance")
	assert_eq(track.rejected, 0)
