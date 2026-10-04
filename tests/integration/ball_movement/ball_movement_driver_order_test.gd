## Ball Movement story 010 (AC-29, AC-31): sign and driver order with real Tilt, Run State and Ball cores.
## Proves neither the production driver's order nor the phone's physical sign (Tilt V-1).
extends GutTest

const Driver = preload("res://tests/support/ball_test_driver.gd")
const P = RunStateCore.Phase
const POSE_DEG: float = 20.0
const R: float = 3.0
const H: float = 0.4
const TILT_TICKS: int = 60


func _x_of(theta: float) -> float:
	return TubeMath.local_point(theta, H, R).x


func _run_tilted(pose: float, poll_after: bool = false) -> Driver:
	var d: Driver = Driver.new()
	d.poll_after_step = poll_after
	d.start_run()
	assert_eq(d.run_state.phase, P.RUNNING)
	d.frames(pose, TILT_TICKS)
	return d


func test_ac29_right_edge_lowered_steers_positive_and_theta_x_increase() -> void:
	var d: Driver = _run_tilted(POSE_DEG)
	var rows: Array = d.trace.slice(d.trace.size() - TILT_TICKS)
	assert_gt(rows[TILT_TICKS - 1][5] as float, 0.0, "steer > 0")
	var increases: int = 0
	var prev_theta: float = d.trace[d.trace.size() - TILT_TICKS - 1][1] as float
	for row: Array in rows:
		assert_gte(row[1] as float, prev_theta, "theta never decreases")
		if (row[1] as float) > prev_theta:
			increases += 1
		prev_theta = row[1] as float
	assert_gt(increases, 5, "theta strictly increases while it travels to the target")
	assert_gt(_x_of(d.ball.theta), _x_of(0.0), "P.x increases")
	assert_gt(d.ball.theta, 0.0)


func test_ac29_left_edge_mirrors_the_right_edge() -> void:
	var right: Driver = _run_tilted(POSE_DEG)
	var left: Driver = _run_tilted(-POSE_DEG)
	assert_lt(left.trace[left.trace.size() - 1][5] as float, 0.0, "steer < 0")
	assert_lt(left.ball.theta, 0.0)
	assert_lt(_x_of(left.ball.theta), _x_of(0.0), "P.x decreases")
	assert_almost_eq(left.ball.theta, -right.ball.theta, 1e-6)


func test_ac29_poll_after_step_mutation_changes_the_timing() -> void:
	var good: Driver = _run_tilted(POSE_DEG)
	var bad: Driver = _run_tilted(POSE_DEG, true)
	var i: int = good.trace.size() - TILT_TICKS
	var differs: bool = false
	for k: int in 6:
		if not is_equal_approx(good.trace[i + k][1] as float, bad.trace[i + k][1] as float):
			differs = true
	assert_true(differs, "a late poll delays theta by a tick, so the order is observable")
	assert_lt(bad.trace[i][1] as float, good.trace[i][1] as float + 1e-12)


func test_ac31_zero_dt_ticks_are_bit_identical_and_t_run_follows_run_time() -> void:
	var d: Driver = Driver.new()
	d.start_run()
	d.frames(10.0, 20)
	d.run_state.request_pause(RunStateCore.PauseSource.BUTTON)
	d.frames(10.0, 5)
	d.run_state.request_resume()
	d.frames(10.0, 60)
	d.run_state.request_hit(1, d.run_state.run_id)
	d.frames(10.0, 5)
	d.run_state.request_restart(d.fixture.clock.get_now_us())
	d.frames(0.0, 3)
	var zero_ticks: int = 0
	for i: int in range(1, d.trace.size()):
		var cur: Array = d.trace[i]
		var prev: Array = d.trace[i - 1]
		if (cur[0] as float) == 0.0 and cur[6] == prev[6]:
			zero_ticks += 1
			assert_eq(cur[1], prev[1], "theta bit-identical on tick %d" % i)
			assert_eq(cur[2], prev[2], "s bit-identical on tick %d" % i)
			assert_eq(cur[3], prev[3], "t_run bit-identical on tick %d" % i)
	assert_gt(zero_ticks, 8, "pause, resuming settle and hit ticks were exercised")
	for row: Array in d.trace:
		if (row[9] as int) == P.RUNNING or (row[9] as int) == P.PAUSED or (row[9] as int) == P.HIT:
			assert_almost_eq(row[3] as float, row[4] as float, 1e-9, "t_run == run_time")


func test_ac31_nothing_moves_on_the_first_tick_after_run_started_and_run_resumed() -> void:
	var d: Driver = Driver.new()
	d.run_state.request_map_ready()
	d.frames(0.0, 70)
	d.run_state.request_start()
	var start_row: Array = []
	for i: int in 3:
		d.frame(0.0)
		if start_row.is_empty() and d.starts == 1:
			start_row = d.trace[d.trace.size() - 1]
	assert_false(start_row.is_empty(), "run_started fired")
	assert_eq(start_row[0], 0.0, "dt_eff 0 on the run_started tick")
	assert_eq(start_row[2], 0.0)
	assert_eq(start_row[1], 0.0)
	assert_eq(start_row[3], 0.0)
	d.frames(10.0, 20)
	d.run_state.request_pause(RunStateCore.PauseSource.BUTTON)
	d.frames(10.0, 2)
	d.run_state.request_resume()
	var before: Array = d.trace[d.trace.size() - 1]
	var resumed_row: Array = []
	for i: int in 80:
		d.frame(10.0)
		if d.resumes == 1:
			resumed_row = d.trace[d.trace.size() - 1]
			break
	assert_false(resumed_row.is_empty(), "run_resumed fired")
	assert_eq(resumed_row[0], 0.0, "dt_eff 0 on the run_resumed tick")
	assert_eq(resumed_row[1], before[1])
	assert_eq(resumed_row[2], before[2])
	assert_eq(resumed_row[3], before[3])
