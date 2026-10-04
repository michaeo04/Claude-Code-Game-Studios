## Story CRF-002: GameRoot._tick over the REAL Run State, Ball, Tube Window, Tilt and WorldFrame cores.
##
## 20 Hz ticks, 600 of them: warm-up in Menu, a run that rebases once, a scripted hit, a restart, a pause and a
## resume. Only the collaborators that do not exist yet are (strict) spies.
extends GutTest

const Spy = preload("res://tests/support/system_spy.gd")
const Fixture = preload("res://tests/support/tilt_fixture.gd")
const BallFixtures = preload("res://tests/support/ball_fixtures.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")
const P = RunStateCore.Phase

const TICKS: int = 600
const STEP_US: int = 50000
const STEP_S: float = 0.05
const SEGMENT_L: float = 9.0
const REBASE_SEGMENTS: int = 24
const HIT_TICK: int = 320
const RESTART_TICK: int = 335
const PAUSE_TICK: int = 440
const RESUME_TICK: int = 450
const START_TICK: int = 10

var _fixture: Fixture
var _run_state: RunStateCore
var _ball: BallCore
var _window: TubeWindow
var _frame: WorldFrame
var _root: GameRoot
var _tube_adapter: TubeRunAdapter
var _log: Array[String] = []
var _spies: Dictionary = {}
var _sink: LogSink = LogSink.new()
var _rebases: Array[Array] = []
var _phases: Array[int] = []
var _ball_s: Array[float] = []
var _first_indices: Array[int] = []
var _resumes: Array[int] = []


func before_each() -> void:
	_fixture = Fixture.new()
	var clock: Callable = _fixture.clock.as_callable()
	_run_state = RunStateCore.new(RunConfig.new(), clock, _sink.sink)
	var ball_cfg: BallConfig = BallFixtures.make_ball_fixture()
	ball_cfg.v_start = 20.0
	_ball = BallFixtures.make_core(ball_cfg)
	_window = TubeWindow.new(_sink.sink, Callable())
	var tube_cfg: TubeConfig = TubeConfig.new()
	tube_cfg.segment_length = SEGMENT_L
	tube_cfg.segments_ahead = 11
	var failures: Array[Dictionary] = _window.load_map(tube_cfg, 25.0, 0.8)
	assert_eq(failures.size(), 0, "tube config must validate: %s" % [failures])
	var wf_cfg: WorldFrameConfig = WorldFrameConfig.new()
	wf_cfg.rebase_segments = REBASE_SEGMENTS
	_frame = WorldFrame.new(wf_cfg, WorldGeometry.new(3.0, 2.0, 20, SEGMENT_L, 11))
	var phase_source: Callable = func() -> int:
		return _run_state.phase as int
	var tilt_adapter: TiltRunAdapter = TiltRunAdapter.new(_fixture.core, _run_state.request_pause, phase_source,
			_sink.sink)
	_tube_adapter = TubeRunAdapter.new(_window, _frame)
	# The _wire() rows that matter here, in rank order (WorldFrame first on run_reset).
	_run_state.run_reset.connect(_frame.on_run_reset)
	_run_state.run_reset.connect(_tube_adapter.on_run_reset)
	_run_state.run_reset.connect(_on_reset_ball)
	_run_state.run_reset.connect(tilt_adapter.on_run_reset)
	_run_state.run_started.connect(tilt_adapter.on_run_started)
	_run_state.run_resumed.connect(tilt_adapter.on_run_resumed)
	_run_state.run_resumed.connect(_tube_adapter.on_run_resumed)
	_run_state.run_resumed.connect(_on_resumed_ball)
	_run_state.run_ended.connect(tilt_adapter.on_run_ended)
	_run_state.run_ended.connect(_tube_adapter.on_run_ended)
	_run_state.run_paused.connect(tilt_adapter.on_run_paused)
	_run_state.run_paused.connect(_tube_adapter.on_run_paused)
	_run_state.phase_changed.connect(tilt_adapter.on_phase_changed)
	_run_state.phase_changed.connect(_tube_adapter.on_phase_changed)
	var systems: Dictionary = {
		&"tilt_input": _fixture.core, &"tilt_adapter": tilt_adapter, &"run_state": _run_state, &"ball": _ball,
		&"tube_track": _window, &"world_frame": _frame,
	}
	for key: StringName in [&"tube_view", &"hazard_view", &"obstacle", &"near_miss", &"scoring", &"camera",
			&"ball_view", &"environment", &"juice", &"hud", &"menus"]:
		var spy: Object = Spy.new(String(key), _log)
		systems[key] = spy
		_spies[key] = spy
	_root = GameRoot.new()
	autofree(_root)
	assert_true(_root.inject_systems(systems))


func _on_reset_ball(_run_id: int) -> void:
	_ball.reset()


func _on_resumed_ball(_run_id: int) -> void:
	_ball.on_resumed()
	_resumes.append(_phases.size())


func _run_script() -> void:
	_run_state.request_map_ready()
	for tick: int in TICKS:
		_fixture.clock.advance_us(STEP_US)
		_fixture.set_pose(5.0 if tick % 40 < 20 else -5.0)
		var now_us: int = _fixture.clock.get_now_us()
		if tick == START_TICK:
			_run_state.request_start()
		elif tick == HIT_TICK:
			_run_state.request_hit(3, _run_state.run_id)
		elif tick == RESTART_TICK:
			_run_state.request_restart(now_us)
		elif tick == PAUSE_TICK:
			_run_state.request_pause(RunStateCore.PauseSource.BUTTON)
		elif tick == RESUME_TICK:
			_run_state.request_resume()
		var origin_before: float = _frame.origin_s
		var s_before: float = _ball.s
		_root._tick(STEP_S, STEP_S)
		_phases.append(_run_state.phase as int)
		_ball_s.append(_ball.s)
		if _frame.origin_s != origin_before:
			_rebases.append([tick, _ball.s, _frame.origin_s, s_before])
		_first_indices.append(_window.get_first_index())


func test_600_ticks_hit_restart_pause_resume_with_real_cores() -> void:
	_run_script()
	assert_eq(_phases.size(), TICKS)
	for phase: int in [P.MENU, P.RUNNING, P.HIT, P.PAUSED, P.RESUMING]:
		assert_true(_phases.has(phase), "phase %d reached" % phase)
	# Ball s never moves while the phase stays Menu, Hit, Paused or Resuming.
	for i: int in range(1, TICKS):
		if _phases[i] in [P.MENU, P.HIT, P.PAUSED, P.RESUMING] and _phases[i - 1] == _phases[i]:
			assert_eq(_ball_s[i], _ball_s[i - 1], "ball s frozen at tick %d (phase %d)" % [i, _phases[i]])
	assert_eq(_ball_s[HIT_TICK], _ball_s[HIT_TICK - 1], "no step on the hit tick")
	assert_eq(_ball_s[RESTART_TICK], 0.0, "restart resets s")
	assert_gt(_ball_s[TICKS - 1], 0.0)
	# The window index follows s (first index = floor(s / L) - B) while running.
	for i: int in range(TICKS):
		if _phases[i] == P.RUNNING and _ball_s[i] > 0.0:
			assert_eq(_first_indices[i], int(floor(_ball_s[i] / SEGMENT_L)) - 2, "window at tick %d" % i)
	# Rebase: exactly one in the first run, at the first tick whose s reaches REBASE_SEGMENTS * L.
	var first_run: Array[Array] = []
	for record: Array in _rebases:
		if (record[0] as int) < HIT_TICK:
			first_run.append(record)
	assert_eq(first_run.size(), 1)
	var threshold: float = float(REBASE_SEGMENTS) * SEGMENT_L
	assert_gte(first_run[0][1] as float, threshold)
	assert_lt(first_run[0][3] as float, threshold, "s one tick earlier was below the threshold")
	assert_eq(first_run[0][2] as float, threshold)
	assert_eq(_sink.count(), 0, "no log lines: %s" % [_sink.entries])
	assert_eq(_resumes.size(), 1)
	for key: StringName in _spies:
		assert_eq((_spies[key] as Object).get(&"errors"), [] as Array[String])


func test_ball_time_only_advances_on_running_ticks_that_take_a_step() -> void:
	_run_script()
	var running_after_restart: int = 0
	for i: int in range(RESTART_TICK + 1, TICKS):
		if _phases[i] == P.RUNNING:
			running_after_restart += 1
	assert_gt(_ball.t_run, 0.0)
	# The settling tick after the restart and the one after the resume take no step.
	assert_lt(_ball.t_run, float(running_after_restart) * STEP_S - 1e-6)
