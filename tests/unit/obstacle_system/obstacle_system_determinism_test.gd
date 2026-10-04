## Story OBS-010: determinism and no side effects (AC-23, AC-39). The AC-24 lint is in tools/ci.
extends GutTest

const Fixture = preload("res://tests/support/obstacle_fixture.gd")
const Doubles = preload("res://tests/support/obstacle_call_doubles.gd")

const TICKS: int = 500


func _make_provider() -> Fixture.FakeProvider:
	return Fixture.make_content_provider({
		0: [Fixture.worked_hazard(501)] as Array[HazardSpec],
		1: [Fixture.worked_hazard(301), Fixture.worked_hazard(101)] as Array[HazardSpec],
		2: [Fixture.worked_hazard(202)] as Array[HazardSpec],
	})


class Run:
	extends RefCounted
	var core: ObstacleCore
	var stream: Array = []
	var tick: int = 0

	func _on_hit(hazard_id: int, run_id: int) -> void:
		stream.append([tick, hazard_id, run_id])


func _make_run() -> Run:
	var run: Run = Run.new()
	run.core = Fixture.make_core(Fixture.make_config(), _make_provider())
	run.core.hit_reported.connect(run._on_hit)
	return run


## Scripted tick `i`: window signals, resets and a ball pair, all closed-form (no randomness).
func _apply(run: Run, i: int, ball: RefCounted) -> void:
	run.tick = i
	if i == 0:
		run.core.on_window_primed(0, 2)
	if i % 97 == 0:
		run.core.on_run_reset(i / 97 + 1)
	if i == 150:
		run.core.on_segment_left_window(0)
	if i == 300:
		run.core.on_segment_entered_window(0)
	if i == 400:
		run.core.on_window_primed(1, 2)
	var s_now: float = float(i) * 0.9
	var noop: bool = i % 11 == 5
	var s_prev: float = s_now if noop else s_now - 0.9
	var theta: float = sin(float(i) * 0.37) * 3.0
	var theta_prev: float = theta if noop else sin(float(i - 1) * 0.37) * 3.0
	ball.set(&"theta_prev", theta_prev)
	ball.set(&"theta", theta)
	ball.set(&"s_prev", s_prev)
	ball.set(&"s", s_now)
	run.core.step(ball)


func test_ac23_identical_scripts_give_identical_streams_and_a_third_does_not_interfere() -> void:
	var a: Run = _make_run()
	var b: Run = _make_run()
	var c: Run = _make_run()
	var ball_a: RefCounted = Fixture.make_ball_state_stub(0.0, 0.0, 0.0, 0.0)
	var ball_b: RefCounted = Fixture.make_ball_state_stub(0.0, 0.0, 0.0, 0.0)
	var ball_c: RefCounted = Fixture.make_ball_state_stub(0.0, 0.0, 0.0, 0.0)
	for i: int in TICKS:
		_apply(a, i, ball_a)
		_apply(c, i, ball_c)
		_apply(b, i, ball_b)
	var solo: Run = _make_run()
	var ball_s: RefCounted = Fixture.make_ball_state_stub(0.0, 0.0, 0.0, 0.0)
	for i: int in TICKS:
		_apply(solo, i, ball_s)
	assert_gt(a.stream.size(), 3, "the script produces hits")
	assert_eq(a.stream.size(), b.stream.size())
	for k: int in a.stream.size():
		assert_eq(a.stream[k], b.stream[k], "hit %d identical" % k)
	assert_eq(a.stream, solo.stream, "interleaving a third instance changes nothing")
	assert_eq(c.stream, a.stream)


func test_ac39_core_reads_only_the_named_accessors() -> void:
	var ball: Doubles.RecordingBall = Doubles.RecordingBall.new()
	var core: ObstacleCore = Fixture.make_core(Fixture.make_config(), _make_provider())
	core.on_window_primed(0, 2)
	core.on_run_reset(1)
	for i: int in 200:
		ball.values[&"s"] = float(i) * 2.0
		ball.values[&"s_prev"] = float(i) * 2.0 - 2.0
		ball.values[&"theta"] = sin(float(i))
		ball.values[&"theta_prev"] = sin(float(i - 1))
		core.step(ball)
	assert_gt(ball.reads.size(), 0)
	var allowed: Array[StringName] = [&"theta", &"theta_prev", &"s", &"s_prev"]
	for name: StringName in ball.reads:
		assert_true(allowed.has(name), "only read-only accessors: %s" % name)
