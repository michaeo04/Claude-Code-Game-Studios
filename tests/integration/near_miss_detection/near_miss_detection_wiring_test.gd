## Story 011: real BallCore, ObstacleCore, RunStateCore and NearMissCore wired as `GameRoot._real_core_rows` does
## (same signal-to-handler pairs, same per-tick order Obstacle.step then NearMiss.step). The full GameRoot run is
## already proven by composition_root_m1_headless_run_test.gd; this file isolates the Near-Miss wiring.
## AC-26 (Juice consumption contract) is DEFERRED: no Juice core exists yet; it is owned by the juice epic.
extends GutTest

const Fixture = preload("res://tests/support/near_miss_fixture.gd")
const ObstacleFixture = preload("res://tests/support/obstacle_fixture.gd")
const BallFixtures = preload("res://tests/support/ball_fixtures.gd")
const ClockStub = preload("res://tests/support/clock_stub.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")

const SEG_L: float = 9.0
const DT: float = 0.05
const STEER: float = 0.5
const SETTLE_TICKS: int = 40
const NEAR_SEG: int = 6
const HIT_SEG: int = 8

var _sink: LogSink
var _obstacle: ObstacleCore
var _near: NearMissCore
var _ball: BallCore
var _emits: Array[Array] = []
var _bound_s: Dictionary = {}


func _spike(theta_min: float, theta_max: float) -> HazardSpec:
	return HazardSpec.new(HazardPlacement.HazardType.SPIKE, 0,
			PackedFloat64Array([theta_min, theta_max, 0.0, 0.3]), PackedFloat64Array())


func _on_emit(hazard_id: int, run_id: int) -> void:
	_emits.append([hazard_id, run_id])


func _on_bound(hazard_id: int, footprint: PackedFloat64Array) -> void:
	_bound_s[hazard_id] = footprint[2]


## Obstacle and Near-Miss cores wired with the GameRoot row pairs.
func _build(table: Dictionary) -> void:
	_sink = LogSink.new()
	_emits = []
	_bound_s = {}
	var half: float = ObstacleMath.ball_half_angle(Fixture.R, Fixture.D)
	_obstacle = ObstacleCore.new(ObstacleFixture.make_config(), ObstacleFixture.make_content_provider(table), SEG_L,
			half, Fixture.D, _sink.sink)
	_near = NearMissCore.new(NearMissConfig.new(), half, Fixture.D, _sink.sink)
	_obstacle.hazard_bound.connect(_near.on_hazard_bound)
	_obstacle.hazard_released.connect(_near.on_hazard_released)
	_obstacle.hit_reported.connect(_near.on_hit_reported)
	_obstacle.hazard_bound.connect(_on_bound)
	_near.near_miss_detected.connect(_on_emit)


func _new_ball() -> BallCore:
	return BallFixtures.make_core(BallFixtures.make_ball_fixture())


func _tick(ball: BallCore) -> void:
	ball.step(DT, STEER, true, 0)
	_obstacle.step(ball)
	_near.step(ball)


## Steady-state theta of the ball held at STEER (hazards are placed relative to it).
func _measure_theta_ss() -> float:
	var ball: BallCore = _new_ball()
	for i: int in SETTLE_TICKS:
		ball.step(DT, STEER, true, 0)
	return ball.theta


func test_ac23_near_miss_reads_the_four_values_the_ball_published_that_tick() -> void:
	_build({})
	var twin: NearMissCore = NearMissCore.new(NearMissConfig.new(), ObstacleMath.ball_half_angle(Fixture.R, Fixture.D),
			Fixture.D)
	var ball: BallCore = _new_ball()
	var prev_theta: float = ball.theta
	var prev_s: float = ball.s
	for i: int in 60:
		ball.step(DT, STEER, true, 0)
		assert_eq(ball.theta_prev, prev_theta, "theta_prev is last tick's theta (not stale)")
		assert_eq(ball.s_prev, prev_s, "s_prev is last tick's s")
		prev_theta = ball.theta
		prev_s = ball.s
	assert_gt(ball.s, ball.s_prev)
	# The real ball and a stub holding the same four values drive two cores to the same decisions.
	var theta_ss: float = ball.theta
	var raw: PackedFloat64Array = PackedFloat64Array([theta_ss + 0.2, theta_ss + 0.3, 100.0, 100.3])
	_near.on_hazard_bound(1, raw)
	twin.on_hazard_bound(1, raw)
	var twin_emits: Array = []
	twin.near_miss_detected.connect(func(hazard_id: int, _run_id: int) -> void: twin_emits.append(hazard_id))
	for i: int in 400:
		ball.step(DT, STEER, true, 0)
		var stub: RefCounted = Fixture.make_ball_state_stub(ball.theta_prev, ball.theta, ball.s_prev, ball.s)
		_near.step(ball)
		twin.step(stub)
		assert_eq(_near.was_in_near_zone(1), twin.was_in_near_zone(1), "same decision at tick %d" % i)
	assert_eq(_emits.size(), twin_emits.size())
	assert_eq(_emits.size(), 1, "the ball swept through the near zone of the hazard and left it once")


func test_ac24_real_graze_emits_once_and_real_hit_emits_none() -> void:
	var theta_ss: float = _measure_theta_ss()
	var half: float = ObstacleMath.ball_half_angle(Fixture.R, Fixture.D)
	var margin: float = NearMissConfig.new().angle_margin(half)
	var graze_min: float = theta_ss + half + margin * 0.5
	var table: Dictionary = {
		NEAR_SEG: [_spike(graze_min, graze_min + 0.1)] as Array[HazardSpec],
		HIT_SEG: [_spike(theta_ss - 0.05, theta_ss + 0.05)] as Array[HazardSpec],
	}
	_build(table)
	var hits: Array = []
	_obstacle.hit_reported.connect(func(hazard_id: int, _run_id: int) -> void: hits.append(hazard_id))
	_obstacle.on_window_primed(0, 10)
	var ball: BallCore = _new_ball()
	for i: int in 300:
		_tick(ball)
		if ball.s > float(HIT_SEG) * SEG_L + 10.0:
			break
	assert_gt(ball.s, float(HIT_SEG) * SEG_L, "the ball passed both hazards")
	var near_id: int = -1
	var hit_id: int = -1
	for id: Variant in _bound_s:
		if is_equal_approx(_bound_s[id] as float, float(NEAR_SEG) * SEG_L):
			near_id = id as int
		if is_equal_approx(_bound_s[id] as float, float(HIT_SEG) * SEG_L):
			hit_id = id as int
	assert_true(near_id >= 0 and hit_id >= 0)
	assert_eq(hits.has(near_id), false, "the graze is not a hit")
	assert_eq(hits.has(hit_id), true, "the gate is a hit")
	assert_eq(_emits.size(), 1, "one emission in total: %s" % [_emits])
	assert_eq(_emits[0][0], near_id)
	assert_false(_emits.any(func(e: Array) -> bool: return e[0] == hit_id), "no emission for the hit hazard")


func test_ac25_window_reprime_with_a_hazard_in_its_near_zone_emits_nothing() -> void:
	var clock: ClockStub = ClockStub.new()
	var rs: RunStateCore = RunStateCore.new(RunConfig.new(), clock.as_callable(), Callable())
	var table: Dictionary = {1: [_spike(0.18, 0.28)] as Array[HazardSpec]}
	_build(table)
	rs.run_reset.connect(_obstacle.on_run_reset)
	rs.run_reset.connect(_near.on_run_reset)
	rs.request_map_ready()
	rs.tick(DT, DT)
	rs.request_start()
	rs.tick(DT, DT)
	assert_gt(rs.run_id, 0)
	assert_eq(_near.get_run_id(), rs.run_id, "run_reset reached Near-Miss")
	assert_eq(_obstacle.get_run_id(), rs.run_id)
	_obstacle.on_window_primed(0, 3)
	assert_eq(_near.bound_count(), 1)
	# Ball inside the near zone (hazard theta 0.18..0.28, s SEG_L + 0.0..0.3), outside the hit zone.
	var half: float = ObstacleMath.ball_half_angle(Fixture.R, Fixture.D)
	var near_theta: float = 0.28 + half + 0.05
	var s: float = SEG_L + 0.15
	var pose: RefCounted = Fixture.make_ball_state_stub(near_theta, near_theta, s, s)
	_obstacle.step(pose)
	_near.step(pose)
	var id: int = 0
	assert_true(_near.was_in_near_zone(id), "the hazard is in the near zone before the re-prime")
	_obstacle.on_window_primed(0, 3)
	assert_eq(_near.bound_count(), 1, "state rebuilt for the re-bound hazard")
	assert_false(_near.was_in_near_zone(0), "state cleared by the re-prime")
	var far: RefCounted = Fixture.make_ball_state_stub(2.5, 2.5, s, s)
	_obstacle.step(far)
	_near.step(far)
	assert_eq(_emits.size(), 0, "a reset release never emits")
	# The next run starts clean: a new run_reset only changes the carried id.
	clock.advance_us(2_000_000)
	rs.request_restart(clock.get_now_us())
	rs.tick(DT, DT)
	_near.step(far)
	assert_eq(_emits.size(), 0)
	assert_eq(_near.get_run_id(), rs.run_id)
	for entry: Array in _sink.entries:
		assert_lt(entry[0] as int, LogLevel.WARNING, "no warning or error line: %s" % [entry])

