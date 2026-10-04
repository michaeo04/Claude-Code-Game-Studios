## Story CRF-013 (milestone M1): a scripted run through the REAL cores driven by `GameRoot._tick()` and wired by
## `GameRoot._wire()`: dodge, near miss, hit, final score, personal best, restart, determinism.
##
## Real: Run State, Tilt Input (+ adapter), Ball, Tube Window (+ adapter), WorldFrame, Obstacle, Near-Miss, Scoring.
## Fakes: the hazard content provider (a table keyed by segment; the Pattern provider does not exist yet, so the
## chunk library of `tests/support/data/obstacle_library_fixture.tres` is not compiled here), the Save seam
## (a dictionary) and the gravity sample source (`TiltFixture.set_pose`). Strict spies: views, Camera, Juice, HUD, Menus.
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
## Run-local tick of the first tilt, the return to neutral, and the tick after which the script waits for the hit.
const TILT_ON_TICK: int = 60
const TILT_OFF_TICK: int = 125
const TILT_POSE_DEG: float = 12.5
const START_TICK: int = 10
const MAX_RUN_TICKS: int = 400
const RESTART_WAIT_TICKS: int = 20
## Hazards by segment index (local segment 0, so footprint s = chunk-local s + index * L).
const SEG_DODGE: int = 6
const SEG_NEAR: int = 9
const SEG_HIT: int = 14
const SAVE_SECTION: String = "scoring"
const SAVE_KEY: String = "personal_best"


## One rig: every real core, wired by the real `GameRoot._wire()`.
class Rig:
	extends RefCounted
	var fixture: Fixture
	var sink: LogSink = LogSink.new()
	var run_state: RunStateCore
	var ball: BallCore
	var window: TubeWindow
	var frame: WorldFrame
	var obstacle: ObstacleCore
	var near_miss: NearMissCore
	var scoring: ScoreCore
	var root: GameRoot
	var provider: ObstacleFixture.FakeProvider
	var spies: Dictionary = {}
	var log_lines: Array[String] = []
	var store: Dictionary = {}
	var writes: Array = []
	var near_misses: Array[Array] = []
	var hits: Array[Array] = []
	var ended: Array[Array] = []
	var pb_updates: Array[int] = []
	var hazard_s_start: Dictionary = {}
	var trace: Array = []

	func get_value(section: String, key: String, default: Variant) -> Variant:
		return store.get(section + "/" + key, default)

	func set_value(section: String, key: String, value: Variant) -> bool:
		store[section + "/" + key] = value
		writes.append([section, key, value])
		return true

	func read_s() -> float:
		return ball.s

	func _on_near_miss(hazard_id: int, run_id: int) -> void:
		near_misses.append([hazard_id, run_id])

	func _on_hit(hazard_id: int, run_id: int) -> void:
		hits.append([hazard_id, run_id])

	func _on_ended(run_id: int, hazard_id: int, run_time_ms: int) -> void:
		ended.append([run_id, hazard_id, run_time_ms])

	func _on_bound(hazard_id: int, footprint: PackedFloat64Array) -> void:
		hazard_s_start[hazard_id] = footprint[2]

	func _on_pb(final_score: int) -> void:
		pb_updates.append(final_score)


var _rig: Rig


func _spike(theta_min: float, theta_max: float, s_start: float, s_end: float) -> HazardSpec:
	return HazardSpec.new(HazardPlacement.HazardType.SPIKE, 0,
			PackedFloat64Array([theta_min, theta_max, s_start, s_end]), PackedFloat64Array())


func _make_rig(stored_best: int = 0) -> Rig:
	var rig: Rig = Rig.new()
	rig.fixture = Fixture.new()
	if stored_best > 0:
		rig.store[SAVE_SECTION + "/" + SAVE_KEY] = stored_best
	var clock: Callable = rig.fixture.clock.as_callable()
	rig.run_state = RunStateCore.new(RunConfig.new(), clock, rig.sink.sink)
	var ball_cfg: BallConfig = BallFixtures.make_ball_fixture()
	rig.ball = BallFixtures.make_core(ball_cfg)
	rig.window = TubeWindow.new(rig.sink.sink, Callable())
	var tube_cfg: TubeConfig = TubeConfig.new()
	tube_cfg.segment_length = SEGMENT_L
	tube_cfg.segments_ahead = 11
	var failures: Array[Dictionary] = rig.window.load_map(tube_cfg, 25.0, D)
	assert_eq(failures.size(), 0, "tube config must validate: %s" % [failures])
	var wf_cfg: WorldFrameConfig = WorldFrameConfig.new()
	wf_cfg.rebase_segments = 24
	rig.frame = WorldFrame.new(wf_cfg, WorldGeometry.new(R, 2.0, 20, SEGMENT_L, 11))
	var run_state: RunStateCore = rig.run_state
	var phase_source: Callable = func() -> int:
		return run_state.phase as int
	var tilt_adapter: TiltRunAdapter = TiltRunAdapter.new(rig.fixture.core, rig.run_state.request_pause,
			phase_source, rig.sink.sink)
	var tube_adapter: TubeRunAdapter = TubeRunAdapter.new(rig.window, rig.frame)
	rig.provider = ObstacleFixture.make_content_provider({
		SEG_DODGE: [_spike(-0.05, 0.05, 0.0, 0.3)] as Array[HazardSpec],
		SEG_NEAR: [_spike(0.18, 0.28, 0.0, 0.3)] as Array[HazardSpec],
		SEG_HIT: [_spike(-0.05, 0.05, 0.0, 0.3)] as Array[HazardSpec],
	})
	var half: float = ObstacleMath.ball_half_angle(R, D)
	rig.obstacle = ObstacleCore.new(ObstacleFixture.make_config(), rig.provider, SEGMENT_L, half, D, rig.sink.sink)
	rig.near_miss = NearMissCore.new(NearMissConfig.new(), half, D, rig.sink.sink)
	rig.scoring = ScoreCore.new(rig.read_s, rig.get_value, rig.set_value, [] as Array[int])
	var systems: Dictionary = {
		&"tilt_input": rig.fixture.core, &"tilt_adapter": tilt_adapter, &"run_state": rig.run_state,
		&"ball": rig.ball, &"tube_track": rig.window, &"world_frame": rig.frame, &"tube_adapter": tube_adapter,
		&"obstacle": rig.obstacle, &"near_miss": rig.near_miss, &"scoring": rig.scoring,
	}
	for key: StringName in [&"tube_view", &"hazard_view", &"camera", &"ball_view", &"environment", &"juice", &"hud",
			&"menus"]:
		var spy: Object = Spy.new(String(key), rig.log_lines)
		systems[key] = spy
		rig.spies[key] = spy
	rig.root = GameRoot.new()
	autofree(rig.root)
	assert_true(rig.root.inject_systems(systems))
	rig.near_miss.near_miss_detected.connect(rig._on_near_miss)
	rig.obstacle.hit_reported.connect(rig._on_hit)
	rig.obstacle.hazard_bound.connect(rig._on_bound)
	rig.run_state.run_ended.connect(rig._on_ended)
	rig.scoring.personal_best_updated.connect(rig._on_pb)
	assert_eq(rig.root._wire(), OK)
	return rig


func _pose_for(local_tick: int) -> float:
	if local_tick >= TILT_ON_TICK and local_tick < TILT_OFF_TICK:
		return TILT_POSE_DEG
	return 0.0


## One frame: advance the clock, set the scripted gravity sample, tick the real root, record the trace row.
func _frame_tick(rig: Rig, local_tick: int) -> void:
	rig.fixture.clock.advance_us(STEP_US)
	rig.fixture.set_pose(_pose_for(local_tick))
	rig.root._tick(STEP_S, STEP_S)
	rig.trace.append([rig.run_state.phase as int, rig.ball.s, rig.ball.theta, rig.scoring.current_score,
			rig.frame.origin_s, rig.window.get_first_index(), rig.obstacle.bound_count()])


## Menu warm-up, start, then ticks until the phase is Hit (bounded). Returns the local tick of the first Hit.
func _play_until_hit(rig: Rig, tick_cap: int = MAX_RUN_TICKS) -> int:
	rig.run_state.request_map_ready()
	for t: int in START_TICK:
		_frame_tick(rig, 0)
	rig.run_state.request_start()
	for local_tick: int in tick_cap:
		_frame_tick(rig, local_tick)
		if rig.run_state.phase == P.HIT:
			return local_tick
	return -1


func _restart(rig: Rig) -> void:
	for t: int in RESTART_WAIT_TICKS:
		_frame_tick(rig, 0)
	rig.run_state.request_restart(rig.fixture.clock.get_now_us())
	_frame_tick(rig, 0)


func _snapshot(rig: Rig) -> Array:
	return [rig.trace.duplicate(true), rig.near_misses.duplicate(true), rig.hits.size(), rig.ended.duplicate(true),
			rig.writes.duplicate(true), rig.scoring.final_score, rig.ball.s, rig.ball.theta]


func _hazard_with_s(rig: Rig, segment: int) -> int:
	for id: Variant in rig.hazard_s_start:
		if is_equal_approx(rig.hazard_s_start[id] as float, float(segment) * SEGMENT_L):
			return id as int
	return -1


func test_m1_wire_connects_real_rows_without_errors() -> void:
	var rig: Rig = _make_rig()
	assert_eq(GameRoot.validate_rows(rig.root._build_rows()).size(), 0, "every real row valid and typed")
	assert_gt(rig.root._build_rows().size(), 20, "tube, tilt, ball, obstacle, near-miss and scoring rows exist")


func test_m1_dodge_then_near_miss_then_hit_with_final_score_and_best() -> void:
	var rig: Rig = _make_rig()
	var hit_tick: int = _play_until_hit(rig)
	assert_gt(hit_tick, 0, "the run reached Hit")
	assert_eq(rig.run_state.phase, P.HIT)
	# Dodge: the first hazard never reported a hit; exactly one hit ever reached Run State (the third hazard).
	var dodge_id: int = _hazard_with_s(rig, SEG_DODGE)
	var near_id: int = _hazard_with_s(rig, SEG_NEAR)
	var hit_id: int = _hazard_with_s(rig, SEG_HIT)
	assert_true(dodge_id >= 0 and near_id >= 0 and hit_id >= 0, "all three hazards were bound")
	for hit: Array in rig.hits:
		assert_eq(hit[0], hit_id, "only the third hazard is ever hit")
	assert_gt(rig.hits.size(), 0)
	assert_eq(rig.ended.size(), 1)
	assert_eq(rig.ended[0][1], hit_id, "run_ended carries the hit hazard")
	# Near miss: exactly one emission, for the near hazard, carrying the run id.
	assert_eq(rig.near_misses.size(), 1, "exactly one near_miss_detected: %s" % [rig.near_misses])
	assert_eq(rig.near_misses[0][0], near_id)
	assert_eq(rig.near_misses[0][1], rig.run_state.run_id)
	# Scoring: final score is floor(s) at the hit, and the best was written through the Save seam.
	var s_at_hit: float = rig.ball.s
	assert_eq(rig.scoring.final_score, floori(s_at_hit))
	assert_eq(rig.scoring.current_score, floori(s_at_hit))
	assert_true(rig.scoring.is_new_best)
	assert_eq(rig.writes, [[SAVE_SECTION, SAVE_KEY, floori(s_at_hit)]] as Array)
	assert_eq(rig.pb_updates, [floori(s_at_hit)] as Array[int])
	assert_eq(rig.scoring.get_personal_best(), floori(s_at_hit))
	for entry: Array in rig.sink.entries:
		assert_lt(entry[0] as int, LogLevel.WARNING, "no warning or error line: %s" % [entry])
	for key: StringName in rig.spies:
		assert_eq((rig.spies[key] as Object).get(&"errors"), [] as Array[String])


func test_m1_restart_starts_from_a_clean_state() -> void:
	var rig: Rig = _make_rig()
	assert_gt(_play_until_hit(rig), 0)
	var first_run_best: int = rig.scoring.get_personal_best()
	var first_run_id: int = rig.run_state.run_id
	_restart(rig)
	assert_eq(rig.run_state.phase, P.RUNNING)
	assert_eq(rig.run_state.run_id, first_run_id + 1)
	assert_eq(rig.scoring.current_score, 0, "score reset")
	assert_eq(rig.scoring.get_personal_best(), first_run_best, "personal best survives the restart")
	assert_false(rig.scoring.has_passed_this_run)
	assert_eq(rig.frame.origin_s, 0.0, "WorldFrame origin reset")
	assert_eq(rig.ball.s, 0.0)
	assert_eq(rig.ball.theta, 0.0)
	assert_eq(rig.obstacle.get_run_id(), rig.run_state.run_id)
	assert_eq(rig.near_miss.get_run_id(), rig.run_state.run_id)
	# Window re-primed: same first index and the same hazards bound as at the start of the first run.
	var first_run_row: Array = rig.trace[START_TICK + 1]
	assert_eq(rig.window.get_first_index(), first_run_row[5], "window first index re-primed")
	assert_eq(rig.obstacle.bound_count(), first_run_row[6], "hazards re-bound after the reset")
	assert_eq(rig.obstacle.get_run_id(), rig.near_miss.get_run_id())


func test_m1_second_run_repeats_the_first_and_does_not_rewrite_an_equal_best() -> void:
	var rig: Rig = _make_rig()
	assert_gt(_play_until_hit(rig), 0)
	var first_hit_s: float = rig.ball.s
	var first_ended: int = rig.ended.size()
	_restart(rig)
	var second_hit_tick: int = -1
	for local_tick: int in MAX_RUN_TICKS:
		_frame_tick(rig, local_tick + 1)
		if rig.run_state.phase == P.HIT:
			second_hit_tick = local_tick
			break
	assert_gt(second_hit_tick, 0, "second run also ends in a hit")
	assert_eq(rig.ended.size(), first_ended + 1)
	assert_eq(rig.near_misses.size(), 2, "one near miss per run, none carried over")
	assert_eq(rig.near_misses[1][1], rig.run_state.run_id)
	assert_almost_eq(rig.ball.s, first_hit_s, 1.0, "same script, same place (one tick of script offset)")
	assert_lte(rig.writes.size(), 2, "at most one write per strictly higher best")
	assert_eq(rig.scoring.get_personal_best(), maxi(rig.scoring.final_score, floori(first_hit_s)))


func test_m1_stored_best_above_the_run_is_not_overwritten() -> void:
	var rig: Rig = _make_rig(100000)
	assert_gt(_play_until_hit(rig), 0)
	assert_false(rig.scoring.is_new_best)
	assert_eq(rig.writes.size(), 0)
	assert_eq(rig.scoring.get_personal_best(), 100000)


func test_m1_two_identical_scripted_runs_are_bit_identical() -> void:
	var rig_a: Rig = _make_rig()
	assert_gt(_play_until_hit(rig_a), 0)
	_restart(rig_a)
	_play_after_restart(rig_a)
	var rig_b: Rig = _make_rig()
	assert_gt(_play_until_hit(rig_b), 0)
	_restart(rig_b)
	_play_after_restart(rig_b)
	var a: Array = _snapshot(rig_a)
	var b: Array = _snapshot(rig_b)
	assert_eq(a.size(), b.size())
	for i: int in a.size():
		assert_eq(a[i], b[i], "snapshot field %d identical" % i)
	assert_gt((a[0] as Array).size(), 100, "the trace is not trivially empty")


func _play_after_restart(rig: Rig) -> void:
	for local_tick: int in MAX_RUN_TICKS:
		_frame_tick(rig, local_tick + 1)
		if rig.run_state.phase == P.HIT:
			return
