## Story OBS-009: level-triggered swept hit test with broad phase (AC-16, AC-17, AC-18, AC-22).
extends GutTest

const Fixture = preload("res://tests/support/obstacle_fixture.gd")
const Recorder = preload("res://tests/support/obstacle_recorder.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")

var _provider: Fixture.FakeProvider
var _core: ObstacleCore
var _rec: RefCounted
var _log: RefCounted


func before_each() -> void:
	_provider = Fixture.make_content_provider({})
	_log = LogSink.new()
	_core = Fixture.make_core(Fixture.make_config(), _provider, Callable(_log, "sink"))
	_rec = Recorder.new()
	_rec.call("attach", _core)
	_core.on_run_reset(7)


func _bind(index: int, specs: Array[HazardSpec]) -> void:
	_provider.table[index] = specs
	_core.on_segment_entered_window(index)


func test_ac16_stationary_ball_inside_wall_reports_every_tick_then_stops() -> void:
	_bind(0, [Fixture.worked_hazard(301)] as Array[HazardSpec])
	var inside: RefCounted = Fixture.make_ball_state_stub(3.0, 3.0, 200.5, 200.5)
	for i: int in 5:
		_core.step(inside)
	assert_eq((_rec.get("hits") as Array).size(), 5)
	assert_eq((_rec.get("hits") as Array)[0], [0, 7])
	_core.step(Fixture.make_ball_state_stub(3.0, 3.0, 210.0, 210.0))
	assert_eq((_rec.get("hits") as Array).size(), 5, "no report and no clear event outside")


func test_ac17_double_gate_straddling_step_sends_one_report() -> void:
	_bind(0, [Fixture.worked_hazard(202)] as Array[HazardSpec])
	_core.step(Fixture.make_ball_state_stub(-0.35, 0.35, 100.5, 100.6))
	assert_eq((_rec.get("hits") as Array).size(), 1)
	assert_eq((_rec.get("hits") as Array)[0], [0, 7])


func test_ac18_colocated_hazards_both_report() -> void:
	var a: HazardSpec = Fixture.worked_hazard(501)
	var b: HazardSpec = Fixture.worked_hazard(501)
	_bind(0, [a, b] as Array[HazardSpec])
	_core.step(Fixture.make_ball_state_stub(0.0, 0.0, 400.2, 400.3))
	assert_eq(_rec.call("hit_ids"), [0, 1] as Array[int])


func test_ac22_non_finite_state_is_a_no_op_with_one_error_and_next_tick_resumes() -> void:
	_bind(0, [Fixture.worked_hazard(501)] as Array[HazardSpec])
	var bad_states: Array[RefCounted] = [
		Fixture.make_ball_state_stub(0.0, NAN, 400.2, 400.3),
		Fixture.make_ball_state_stub(0.0, 0.0, 400.2, INF),
		Fixture.make_ball_state_stub(0.0, 0.0, -INF, 400.3),
	]
	var expected_logs: int = 0
	for bad: RefCounted in bad_states:
		_core.step(bad)
		expected_logs += 1
		assert_eq(_log.call("count"), expected_logs, "one error per bad tick")
		assert_eq(_log.call("code_at", expected_logs - 1), ObstacleCore.BALL_STATE_NOT_FINITE)
		assert_eq(_log.call("level_at", expected_logs - 1), LogLevel.ERROR)
		assert_eq((_rec.get("hits") as Array).size(), 0, "no hit from a NaN comparison")
	_core.step(Fixture.make_ball_state_stub(0.0, 0.0, 400.2, 400.3))
	assert_eq((_rec.get("hits") as Array).size(), 1, "next valid tick tests normally")
	assert_eq(_log.call("count"), expected_logs)
