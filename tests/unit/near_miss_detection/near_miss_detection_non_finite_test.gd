extends GutTest

const Fixture = preload("res://tests/support/near_miss_fixture.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")

const NEAR_THETA: float = -0.5
const OUT_THETA: float = 2.5
const GRAZE_S: float = 100.5

var _core: NearMissCore
var _sink: RefCounted
var _events: Array = []


func before_each() -> void:
	_sink = LogSink.new()
	_core = Fixture.make_core(NearMissConfig.new(), _sink.sink)
	_core.on_run_reset(7)
	_events = []
	_core.near_miss_detected.connect(func(hazard_id: int, run_id: int) -> void: _events.append([hazard_id, run_id]))
	Fixture.make_hazard_bound_stub(_core, 701)


func _tick(theta: float, s: float = GRAZE_S) -> void:
	_core.step(Fixture.make_ball_state_stub(theta, theta, s, s))


func test_ac17_nan_theta_is_noop_logs_once_and_resumes() -> void:
	_tick(NEAR_THETA)
	assert_true(_core.was_in_near_zone(701))
	_tick(NAN)
	assert_eq(_events.size(), 0)
	assert_true(_core.was_in_near_zone(701))
	assert_eq(_sink.count(), 1)
	assert_eq(_sink.level_at(0), LogLevel.ERROR)
	assert_eq(_sink.code_at(0), NearMissCore.LOG_NON_FINITE_BALL)
	_tick(OUT_THETA)
	assert_eq(_events, [[701, 7]])
	assert_eq(_sink.count(), 1)


func test_ac17_inf_s_is_noop_logs_once_and_resumes() -> void:
	_tick(NEAR_THETA)
	_tick(NEAR_THETA, INF)
	assert_eq(_events.size(), 0)
	assert_true(_core.was_in_near_zone(701))
	assert_eq(_sink.count(), 1)
	_tick(NEAR_THETA)
	assert_true(_core.was_in_near_zone(701))
	_tick(OUT_THETA)
	assert_eq(_events, [[701, 7]])
	assert_eq(_sink.count(), 1)


func test_ac17_non_finite_previous_pose_is_also_a_noop() -> void:
	_tick(NEAR_THETA)
	_core.step(Fixture.make_ball_state_stub(NAN, NEAR_THETA, GRAZE_S, GRAZE_S))
	_core.step(Fixture.make_ball_state_stub(NEAR_THETA, NEAR_THETA, -INF, GRAZE_S))
	assert_eq(_events.size(), 0)
	assert_eq(_sink.count(), 2)
