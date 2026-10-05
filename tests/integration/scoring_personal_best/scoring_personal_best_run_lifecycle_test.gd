## Story SPB-013 (AC-22, AC-26): real Run State, Ball Movement and Scoring driven by `GameRoot._tick()` and wired by
## `GameRoot._wire()`; Juice and HUD are order spies registered through the rank table. Hits come from the real Obstacle
## and Tube Window (same scripted track as the M1 headless run test).
extends GutTest

const Spy = preload("res://tests/support/system_spy.gd")
const Fixture = preload("res://tests/support/tilt_fixture.gd")
const BallFixtures = preload("res://tests/support/ball_fixtures.gd")
const ObstacleFixture = preload("res://tests/support/obstacle_fixture.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")
const P = RunStateCore.Phase

const STEP_US: int = 50000
const STEP_S: float = 0.05
const SEGMENT_L: float = 9.0
const R: float = 3.0
const D: float = 0.8
const START_TICK: int = 10
const MAX_RUN_TICKS: int = 400
const WAIT_TICKS: int = 20
const RUN_TICKS_BEFORE_PAUSE: int = 15
const SEG_HIT: int = 6


## Order spy for the Juice and HUD ranks: records `<name>.<signal>` and the Scoring state it can see at that moment.
class OrderSpy:
	extends "res://tests/support/system_spy.gd"
	var order_log: Array[String]
	var order_name: String
	var score: ScoreCore
	## `final_score` as read inside each `run_ended` / `run_abandoned` handler.
	var seen_final: Array[int] = []

	func _init(spy_name: String, tick_log: Array[String], order: Array[String], core: ScoreCore) -> void:
		super(spy_name, tick_log)
		order_log = order
		order_name = spy_name
		score = core

	func on_run_ended(_run_id: int, _hazard_id: int, _run_time_ms: int) -> void:
		order_log.append(order_name + ".run_ended")
		seen_final.append(score.final_score)

	func on_run_abandoned(_run_id: int, _run_time_ms: int) -> void:
		order_log.append(order_name + ".run_abandoned")
		seen_final.append(score.final_score)


class Rig:
	extends RefCounted
	var fixture: Fixture
	var sink: LogSink = LogSink.new()
	var run_state: RunStateCore
	var ball: BallCore
	var scoring: ScoreCore
	var root: GameRoot
	var juice: OrderSpy
	var hud: OrderSpy
	var log_lines: Array[String] = []
	var order: Array[String] = []
	var store: Dictionary = {}
	var ended_scores: Array[int] = []
	var ended_s: Array[float] = []

	func get_value(section: String, key: String, default: Variant) -> Variant:
		return store.get(section + "/" + key, default)

	func set_value(section: String, key: String, value: Variant) -> bool:
		store[section + "/" + key] = value
		return true

	func read_s() -> float:
		return ball.s

	func on_pb(_final_score: int) -> void:
		order.append("scoring.personal_best_updated")

	## Probe connected after the composition root: runs after every `run_ended` row, so it only samples the end state.
	func on_ended_probe(_run_id: int, _hazard_id: int, _run_time_ms: int) -> void:
		ended_scores.append(scoring.final_score)
		ended_s.append(ball.s)


func _spike() -> HazardSpec:
	return HazardSpec.new(HazardPlacement.HazardType.SPIKE, 0,
			PackedFloat64Array([-0.05, 0.05, 0.0, 0.3]), PackedFloat64Array())


func _make_rig(mis_rank_juice: bool = false) -> Rig:
	var rig: Rig = Rig.new()
	rig.fixture = Fixture.new()
	var clock: Callable = rig.fixture.clock.as_callable()
	rig.run_state = RunStateCore.new(RunConfig.new(), clock, rig.sink.sink)
	rig.ball = BallFixtures.make_core(BallFixtures.make_ball_fixture())
	var window: TubeWindow = TubeWindow.new(rig.sink.sink, Callable())
	var tube_cfg: TubeConfig = TubeConfig.new()
	tube_cfg.segment_length = SEGMENT_L
	tube_cfg.segments_ahead = 11
	assert_eq(window.load_map(tube_cfg, 25.0, D).size(), 0)
	var wf_cfg: WorldFrameConfig = WorldFrameConfig.new()
	wf_cfg.rebase_segments = 24
	var frame: WorldFrame = WorldFrame.new(wf_cfg, WorldGeometry.new(R, 2.0, 20, SEGMENT_L, 11))
	var run_state: RunStateCore = rig.run_state
	var phase_source: Callable = func() -> int:
		return run_state.phase as int
	var tilt_adapter: TiltRunAdapter = TiltRunAdapter.new(rig.fixture.core, rig.run_state.request_pause,
			phase_source, rig.sink.sink)
	var tube_adapter: TubeRunAdapter = TubeRunAdapter.new(window, frame)
	var provider: ObstacleFixture.FakeProvider = ObstacleFixture.make_content_provider({
		SEG_HIT: [_spike()] as Array[HazardSpec],
	})
	var half: float = ObstacleMath.ball_half_angle(R, D)
	var obstacle: ObstacleCore = ObstacleCore.new(ObstacleFixture.make_config(), provider, SEGMENT_L, half, D,
			rig.sink.sink)
	var near_miss: NearMissCore = NearMissCore.new(NearMissConfig.new(), half, D, rig.sink.sink)
	rig.scoring = ScoreCore.new(rig.read_s, rig.get_value, rig.set_value, [] as Array[int])
	rig.juice = OrderSpy.new("juice", rig.log_lines, rig.order, rig.scoring)
	rig.hud = OrderSpy.new("hud", rig.log_lines, rig.order, rig.scoring)
	var systems: Dictionary = {
		&"tilt_input": rig.fixture.core, &"tilt_adapter": tilt_adapter, &"run_state": rig.run_state,
		&"ball": rig.ball, &"tube_track": window, &"world_frame": frame, &"tube_adapter": tube_adapter,
		&"obstacle": obstacle, &"near_miss": near_miss, &"scoring": rig.scoring,
		&"juice": rig.juice, &"hud": rig.hud,
	}
	for key: StringName in [&"tube_view", &"hazard_view", &"camera", &"ball_view", &"environment", &"menus"]:
		systems[key] = Spy.new(String(key), rig.log_lines)
	rig.root = GameRoot.new()
	autofree(rig.root)
	assert_true(rig.root.inject_systems(systems))
	var juice_rank: int = GameRoot.RANK_HUD if mis_rank_juice else GameRoot.RANK_JUICE
	rig.root.add_wire_row(rig.run_state.run_ended, rig.juice.on_run_ended, juice_rank)
	rig.root.add_wire_row(rig.run_state.run_abandoned, rig.juice.on_run_abandoned, juice_rank)
	rig.root.add_wire_row(rig.run_state.run_ended, rig.hud.on_run_ended, GameRoot.RANK_HUD)
	rig.scoring.personal_best_updated.connect(rig.on_pb)
	return rig


func _wire(rig: Rig) -> void:
	assert_eq(rig.root._wire(), OK)
	rig.run_state.run_ended.connect(rig.on_ended_probe)


func _frame(rig: Rig) -> void:
	rig.fixture.clock.advance_us(STEP_US)
	rig.fixture.set_pose(0.0)
	rig.root._tick(STEP_S, STEP_S)


func _start_run(rig: Rig) -> void:
	rig.run_state.request_map_ready()
	for t: int in START_TICK:
		_frame(rig)
	rig.run_state.request_start()


func _play_until_hit(rig: Rig) -> bool:
	_start_run(rig)
	for t: int in MAX_RUN_TICKS:
		_frame(rig)
		assert_eq(rig.scoring.current_score, floori(rig.ball.s), "score tracks the real s every frame")
		if rig.run_state.phase == P.HIT:
			return true
	return false


## Runs a few ticks, pauses, waits out the guard and restarts: Run State emits `run_abandoned` then `run_reset`.
## Returns `ball.s` at the moment of the abandon.
func _abandon_by_restart(rig: Rig) -> float:
	_start_run(rig)
	for t: int in RUN_TICKS_BEFORE_PAUSE:
		_frame(rig)
	assert_eq(rig.run_state.phase, P.RUNNING)
	rig.run_state.request_pause(RunStateCore.PauseSource.BUTTON)
	_frame(rig)
	assert_eq(rig.run_state.phase, P.PAUSED)
	for t: int in WAIT_TICKS:
		_frame(rig)
	var s_at_abandon: float = rig.ball.s
	rig.order.clear()
	rig.run_state.request_restart(rig.fixture.clock.get_now_us())
	_frame(rig)
	return s_at_abandon


func test_lifecycle_hit_final_score_equals_floor_of_ball_s_and_restart_reads_zero() -> void:
	var rig: Rig = _make_rig()
	_wire(rig)
	assert_true(_play_until_hit(rig), "the run reached Hit")
	assert_eq(rig.ended_scores.size(), 1, "the first emission after construction was not dropped")
	assert_eq(rig.ended_scores[0], floori(rig.ended_s[0]), "final_score == floori(ball.s) at ending time")
	assert_eq(rig.scoring.final_score, floori(rig.ball.s))
	assert_gt(rig.scoring.final_score, 0)
	for t: int in WAIT_TICKS:
		_frame(rig)
	rig.run_state.request_restart(rig.fixture.clock.get_now_us())
	_frame(rig)
	assert_eq(rig.run_state.phase, P.RUNNING)
	assert_eq(rig.scoring.current_score, 0, "first frame of the new run reads 0")
	assert_eq(rig.ball.s, 0.0)


func test_lifecycle_abandon_final_score_equals_floor_of_ball_s() -> void:
	var rig: Rig = _make_rig()
	_wire(rig)
	var s_at_abandon: float = _abandon_by_restart(rig)
	assert_gt(s_at_abandon, 0.0)
	assert_eq(rig.scoring.final_score, floori(s_at_abandon), "abandoned run: final_score == floori(ball.s)")
	assert_eq(rig.scoring.current_score, 0, "first frame of the new run reads 0")
	assert_eq(rig.run_state.phase, P.RUNNING)


func test_run_ended_order_is_juice_scoring_personal_best_updated_hud() -> void:
	var rig: Rig = _make_rig()
	_wire(rig)
	assert_true(_play_until_hit(rig))
	assert_eq(rig.order, ["juice.run_ended", "scoring.personal_best_updated", "hud.run_ended"] as Array[String])
	assert_eq(rig.juice.seen_final, [0] as Array[int], "Juice ran before Scoring finalized")
	assert_eq(rig.hud.seen_final, [rig.scoring.final_score] as Array[int], "HUD ran after Scoring finalized")
	assert_true(rig.scoring.is_new_best)


func test_run_abandoned_order_is_juice_then_scoring() -> void:
	var rig: Rig = _make_rig()
	_wire(rig)
	_abandon_by_restart(rig)
	assert_eq(rig.order, ["juice.run_abandoned", "scoring.personal_best_updated"] as Array[String])
	assert_eq(rig.juice.seen_final, [0] as Array[int], "Juice saw the state before Scoring finalized")
	assert_gt(rig.scoring.final_score, 0)


func test_mis_ranked_juice_is_a_composition_root_failure() -> void:
	var rig: Rig = _make_rig(true)
	assert_eq(rig.root._wire(), ERR_INVALID_DATA)
	assert_push_error(GameRoot.CODE_JUICE_AFTER_SCORING)
