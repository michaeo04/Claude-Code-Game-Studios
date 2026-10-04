## Test-only driver (Ball Movement story 010): the real per-frame order of ADR-0002 with real `TiltCore`,
## `TiltRunAdapter`, `RunStateCore` and `BallCore`. Stepped manually by the test; no `_process`.
## Framework-free: no GUT call. Not the production `GameRoot` (its order is proven by the composition-root tests).
extends RefCounted

const TiltFixture = preload("res://tests/support/tilt_fixture.gd")
const BallFixtures = preload("res://tests/support/ball_fixtures.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")

const STEP_S: float = 0.05
const STEP_US: int = 50000

var fixture: TiltFixture = TiltFixture.new()
var sink: LogSink = LogSink.new()
var run_state: RunStateCore
var ball: BallCore
var adapter: TiltRunAdapter
## Mutation switch: when true the tilt poll runs AFTER the ball step (violates ADR-0002).
var poll_after_step: bool = false
## One row per frame: [dt_eff, theta, s, t_run, run_time, steer, resets_seen, starts_seen, resumes_seen, phase].
var trace: Array[Array] = []
var resets: int = 0
var starts: int = 0
var resumes: int = 0


func _init() -> void:
	run_state = RunStateCore.new(RunConfig.new(), fixture.clock.as_callable(), sink.sink)
	ball = BallFixtures.make_core(BallFixtures.make_ball_fixture())
	var rs: RunStateCore = run_state
	var phase_source: Callable = func() -> int:
		return rs.phase as int
	adapter = TiltRunAdapter.new(fixture.core, run_state.request_pause, phase_source, sink.sink)
	run_state.run_reset.connect(adapter.on_run_reset)
	run_state.run_reset.connect(ball.on_run_reset)
	run_state.run_reset.connect(_on_reset)
	run_state.run_started.connect(adapter.on_run_started)
	run_state.run_started.connect(_on_started)
	run_state.run_resumed.connect(adapter.on_run_resumed)
	run_state.run_resumed.connect(ball.on_run_resumed)
	run_state.run_resumed.connect(_on_resumed)
	run_state.run_paused.connect(adapter.on_run_paused)
	run_state.run_ended.connect(adapter.on_run_ended)
	run_state.phase_changed.connect(adapter.on_phase_changed)


func _on_reset(_run_id: int) -> void:
	resets += 1


func _on_started(_run_id: int) -> void:
	starts += 1


func _on_resumed(_run_id: int) -> void:
	resumes += 1


## One frame at `pose_deg` roll: clock, poll, flush, `RunState.tick`, `Ball.step`. Returns the Run State `dt_eff`.
func frame(pose_deg: float) -> float:
	fixture.clock.advance_us(STEP_US)
	fixture.set_pose(pose_deg)
	if not poll_after_step:
		fixture.core.poll()
	adapter.flush()
	var dt_eff: float = run_state.tick(STEP_S, STEP_S)
	ball.step(dt_eff, fixture.core.get_steer(), fixture.core.get_valid(), fixture.core.get_input_source())
	if poll_after_step:
		fixture.core.poll()
	trace.append([dt_eff, ball.theta, ball.s, ball.t_run, run_state.run_time, fixture.core.get_steer(), resets, starts,
			resumes, run_state.phase as int])
	return dt_eff


## `count` frames at `pose_deg`.
func frames(pose_deg: float, count: int) -> void:
	for i: int in count:
		frame(pose_deg)


## Menu warm-up at neutral (capture), then `request_map_ready` and `request_start`; leaves the driver in Running.
func start_run() -> void:
	run_state.request_map_ready()
	frames(0.0, 70)
	run_state.request_start()
	frames(0.0, 2)
