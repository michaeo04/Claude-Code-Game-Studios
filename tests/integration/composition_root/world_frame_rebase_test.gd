## Story CRF-005: the rebase contract for views, the reset wiring and the 3600 s soak (ADR-0013 VC-2, VC-4, VC-6).
extends GutTest

const Fakes = preload("res://tests/support/rebase_fakes.gd")

const L: float = 12.0
const STEP: float = 1.0 / 60.0

var _log: Array[String] = []
var _frame: WorldFrame
var _tube: Fakes.View
var _hazards: Fakes.View
var _effect: Fakes.Effect
var _renderer: Fakes.Renderer
var _ball: Fakes.Stub
var _run_state: Fakes.Stub
var _root: GameRoot


func before_each() -> void:
	_log.clear()
	_frame = WorldFrame.new(WorldFrameConfig.new(), WorldGeometry.new(3.0, 0.8, 20, L, 9))
	_tube = Fakes.View.new(_frame, "tube", _log)
	_hazards = Fakes.View.new(_frame, "hazard", _log)
	_effect = Fakes.Effect.new(_frame)
	_renderer = Fakes.Renderer.new(_frame)
	_renderer.views = [_tube, _hazards]
	_renderer.effects = [_effect]
	_ball = Fakes.Stub.new()
	_run_state = Fakes.Stub.new()
	_root = GameRoot.new(Callable())
	var overrides: Dictionary = {&"environment": _effect, &"menus": _renderer}
	assert_true(_root.inject_systems(Fakes.systems(_run_state, _ball, _frame, _tube, _hazards, overrides)))


func after_each() -> void:
	_root.free()


func _populate(ball_s: float) -> void:
	for k: int in 12:
		_tube.bind(ball_s - 2.0 * L + float(k) * L)
	for i: int in 17:
		_hazards.bind(ball_s + 20.0 + float(i) * 10.0)
	_hazards.bind(ball_s - 5.0) # behind the ball: positive z
	_effect.stored_s = ball_s + 3.0
	_effect.tick()


func _new_run_state() -> RunStateCore:
	return RunStateCore.new(RunConfig.new(), func() -> int: return 0, Callable())


func test_rebase_replaces_every_node_and_keeps_relative_z() -> void:
	_ball.s = 1007.9
	_populate(_ball.s)
	var before: Array[float] = _tube.node_z.duplicate()
	before.append_array(_hazards.node_z)
	_root._tick(0.05, 0.05)
	assert_eq(_frame.origin_s, 1008.0, "the rebase fired")
	assert_eq(_tube.rebase_calls, 1)
	assert_eq(_hazards.rebase_calls, 1)
	var after: Array[float] = _tube.node_z.duplicate()
	after.append_array(_hazards.node_z)
	var stored: Array[float] = _tube.node_s.duplicate()
	stored.append_array(_hazards.node_s)
	for i: int in after.size():
		assert_almost_eq(after[i], -(stored[i] - 1008.0), 1e-9, "node %d equals a fresh placement" % i)
		assert_almost_eq(after[i] - after[0], before[i] - before[0], 1e-9, "relative z unchanged")
	assert_gt(after[after.size() - 1], 0.0, "the node behind the ball has positive z")
	assert_eq(_tube.interpolation_resets, 1, "reset_physics_interpolation belt-and-braces")


func test_paused_to_menu_resets_origin_before_to_idle() -> void:
	_ball.s = 1007.9
	_populate(_ball.s)
	_root._tick(0.05, 0.05)
	var adapter: Fakes.FakeTubeAdapter = Fakes.FakeTubeAdapter.new(_frame, _tube, _log)
	var rs: RunStateCore = _new_run_state()
	rs.phase_changed.connect(adapter.on_phase_changed)
	_log.clear()
	rs.phase_changed.emit(RunStateCore.Phase.MENU, RunStateCore.Phase.PAUSED)
	assert_eq(_log, ["frame.reset", "tube.to_idle@0.0"] as Array[String], "reset strictly precedes to_idle")
	for i: int in _tube.node_s.size():
		assert_almost_eq(_tube.node_z[i], -(float(i) * L), 1e-9, "idle slot %d equals a fresh placement at origin 0" % i)


func test_hit_to_menu_resets_origin_before_to_idle() -> void:
	_frame.origin_s = 1008.0
	_populate(1010.0)
	var adapter: Fakes.FakeTubeAdapter = Fakes.FakeTubeAdapter.new(_frame, _tube, _log)
	adapter.on_phase_changed(RunStateCore.Phase.MENU, RunStateCore.Phase.HIT)
	assert_eq(_frame.origin_s, 0.0)
	assert_eq(_log.slice(-2), ["frame.reset", "tube.to_idle@0.0"] as Array[String])


func test_restart_primes_at_origin_zero_through_wired_run_reset() -> void:
	var rs: RunStateCore = _new_run_state()
	var adapter: Fakes.FakeTubeAdapter = Fakes.FakeTubeAdapter.new(_frame, _tube, _log)
	_frame.origin_s = 1008.0
	_populate(1010.0)
	var root: GameRoot = GameRoot.new(Callable())
	assert_true(root.inject_systems(Fakes.systems(rs, _ball, _frame, _tube, _hazards)))
	root.add_wire_row(rs.run_reset, adapter.on_run_reset, GameRoot.RANK_TUBE_OBSTACLE)
	assert_eq(root._wire(), OK)
	_log.clear()
	rs.run_reset.emit(2)
	assert_eq(_frame.origin_s, 0.0, "WorldFrame row (rank 1) ran first")
	assert_eq(_log, ["tube_adapter.run_reset@0.0", "tube.to_idle@0.0"] as Array[String])
	for i: int in _tube.node_s.size():
		assert_almost_eq(_tube.node_z[i], -(float(i) * L), 1e-9)
	root.free()


func test_soak_3600_seconds_at_v_max_keeps_every_z_inside_budget() -> void:
	_frame.report_violations = false
	_ball.speed = 25.0
	var max_ahead: float = 0.0
	var max_behind: float = 0.0
	for _i: int in 216000:
		_effect.stored_s = _ball.s + 3.0 # the effect follows the ball
		_root._tick(STEP, STEP)
		max_ahead = maxf(max_ahead, absf(_frame.render_z(_ball.s + 10.0 * L)))
		max_behind = maxf(max_behind, absf(_frame.render_z(_ball.s - 3.0 * L)))
	assert_gt(_ball.s, 89000.0, "3600 s at 25 u/s")
	assert_lt(max_ahead, WorldFrameConfig.Z_RENDER_MAX)
	assert_lt(max_behind, WorldFrameConfig.Z_RENDER_MAX)
	assert_eq(_frame.budget_violations, 0)


func test_rebase_runs_only_in_running_and_draw_never_sees_a_half_shifted_world() -> void:
	_ball.s = 2000.0 # far beyond the threshold, but the phase is not Running
	_populate(_ball.s)
	_run_state.phase = RunStateCore.Phase.PAUSED
	_root._tick(0.05, 0.05)
	assert_eq(_tube.rebase_calls, 0, "no rebase outside Running")
	assert_eq(_frame.origin_s, 0.0)
	_run_state.phase = RunStateCore.Phase.RUNNING
	_root._tick(0.05, 0.05)
	assert_gt(_frame.origin_s, 0.0, "rebased in Running")
	assert_eq(_renderer.draws, 2)
	assert_eq(_renderer.inconsistent_nodes, 0, "views and the stored-s effect agree with the origin at every draw")
	assert_eq(_log, ["tube.rebase", "hazard.rebase"] as Array[String], "hooks fired in the same tick")
