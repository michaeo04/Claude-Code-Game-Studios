## Story TI-012: TiltRunAdapter wired to a real RunStateCore and a real TiltCore (AC-39a-e, g, h; AC-43b).
##
## Each frame is `tilt.poll()`, `adapter.flush()`, `run_state.tick()` (ADR-0002 Decision 6).
extends GutTest

const Fixture = preload("res://tests/support/tilt_fixture.gd")
const Factory = preload("res://tests/support/run_state_factory.gd")

const P = RunStateCore.Phase
const FRAME_US: int = 16667

var _rig: Factory
var _fx: Fixture
var _adapter: TiltRunAdapter
var _requests: Array[int] = []
var _events: Array[String] = []
var _pose: float = 10.0
var _valid_poll: bool = true
## Per-event snapshot `[name, phi0, neutral_pending, stop_us]` taken after the adapter handled the event.
var _snaps: Array[Array] = []


func before_each() -> void:
	_requests = []
	_events = []
	_snaps = []
	_pose = 10.0
	_valid_poll = true
	_rig = Factory.new()
	_fx = Fixture.new()


func _build(state: Factory.State) -> void:
	_rig.core_in(state)
	var request: Callable = func(source: int) -> void:
		_requests.append(source)
		_rig.core.request_pause(source as RunStateCore.PauseSource)
	var phase: Callable = func() -> int:
		return _rig.core.phase as int
	_adapter = TiltRunAdapter.new(_fx.core, request, phase)
	var core: RunStateCore = _rig.core
	# Adapter handlers first (connection order), then the observers.
	core.run_reset.connect(_adapter.on_run_reset)
	core.run_started.connect(_adapter.on_run_started)
	core.run_resumed.connect(_adapter.on_run_resumed)
	core.run_ended.connect(_adapter.on_run_ended)
	core.run_paused.connect(_adapter.on_run_paused)
	core.phase_changed.connect(_adapter.on_phase_changed)
	core.run_reset.connect(_on_reset_seen)
	core.run_started.connect(_on_started_seen)
	core.run_resumed.connect(_on_resumed_seen)
	core.run_ended.connect(_on_ended_seen)
	core.run_paused.connect(_on_paused_seen)


func _snap(event_name: String) -> void:
	_events.append(event_name)
	_snaps.append([event_name, _fx.core.get_phi0(), _fx.core.get_neutral_pending(), _fx.core.get_stop_us()])


func _on_reset_seen(_id: int) -> void:
	_snap("reset")


func _on_started_seen(_id: int) -> void:
	_snap("started")


func _on_resumed_seen(_id: int) -> void:
	_snap("resumed")


func _on_ended_seen(_id: int, _hazard: int, _ms: int) -> void:
	_snap("ended")


func _on_paused_seen(source: int) -> void:
	_snap("paused:%d" % source)


func _snap_of(event_name: String) -> Array:
	for s: Array in _snaps:
		if s[0] == event_name:
			return s
	return []


## One frame: poll (valid at `_pose` or invalid), flush, tick; advances the Run State clock by one frame.
func _frame() -> void:
	_rig.clock.advance_us(FRAME_US)
	if _valid_poll:
		_fx.tick(_pose)
	else:
		_fx.tick_invalid()
	_adapter.flush()
	_rig.tick()


func _frames(count: int) -> void:
	for i: int in count:
		_frame()


func _sensor_lost_pauses() -> int:
	return _events.count("paused:%d" % RunStateCore.PauseSource.SENSOR_LOST)


func _start_running() -> void:
	_fx.tick(10.0, 60)
	_build(Factory.State.MENU)
	_rig.core.request_start()
	_frames(80)
	assert_eq(_rig.core.phase, P.RUNNING)


func _pause_and_start_countdown() -> void:
	_rig.core.request_pause(RunStateCore.PauseSource.BUTTON)
	_frames(1)
	_rig.clock.advance_us(_rig.config.pause_input_guard_us())
	_rig.core.request_resume()
	_frames(1)
	assert_eq(_rig.core.phase, P.RESUMING)


func test_menu_reset_captures_before_run_started_ac39a() -> void:
	_fx.tick(10.0, 60)
	_build(Factory.State.MENU)
	_rig.core.request_start()
	_frame()
	assert_eq(_events.slice(0, 2), ["reset", "started"] as Array[String])
	var at_reset: Array = _snap_of("reset")
	assert_false(at_reset[2], "capture finished inside the run_reset handler chain")
	assert_almost_eq(at_reset[1] as float, 10.0, 1e-6)
	assert_eq(_requests.size(), 0)


func test_first_reset_has_previous_phase_menu_ac39g() -> void:
	_fx.tick(10.0, 60)
	_fx.core.on_run_reset(TiltCore.PreviousPhase.MENU)
	assert_almost_eq(_fx.core.get_phi0(), 10.0, 1e-6)
	_build(Factory.State.MENU)
	_pose = 11.0
	_fx.tick(11.0, 60)
	_rig.core.request_start()
	_frame()
	# A Menu reset always captures (a Hit or Paused reset would inherit 10 for this 1 degree change).
	assert_almost_eq(_snap_of("reset")[1] as float, 11.0, 1e-6)


func test_hit_restart_inherits_a_steady_pose_ac39a() -> void:
	_start_running()
	_rig.core.request_hit(Factory.HAZARD_ID, _rig.core.run_id)
	_frames(1)
	assert_eq(_rig.core.phase, P.HIT)
	_frames(60)
	_snaps.clear()
	_events.clear()
	_rig.core.request_restart(_rig.clock.now_us)
	_frame()
	assert_eq(_events.slice(0, 2), ["reset", "started"] as Array[String])
	assert_almost_eq(_snap_of("reset")[1] as float, 10.0, 1e-6)
	assert_false(_snap_of("reset")[2])


func test_resume_end_captures_ac39b() -> void:
	_start_running()
	_rig.core.request_pause(RunStateCore.PauseSource.BUTTON)
	_frames(1)
	_pose = 20.0
	_frames(40)
	_rig.clock.advance_us(_rig.config.pause_input_guard_us())
	_rig.core.request_resume()
	_frames(1)
	assert_eq(_rig.core.phase, P.RESUMING)
	_rig.clock.advance_us(_rig.config.resume_countdown_us())
	_frame()
	assert_eq(_rig.core.phase, P.RUNNING)
	assert_eq(_events.count("resumed"), 1)
	assert_almost_eq(_snap_of("resumed")[1] as float, 20.0, 1e-6)


func test_pause_during_countdown_emits_no_resumed_ac39c() -> void:
	_start_running()
	_pause_and_start_countdown()
	_rig.core.request_pause(RunStateCore.PauseSource.BUTTON)
	_frames(1)
	assert_eq(_rig.core.phase, P.PAUSED)
	_rig.clock.advance_us(_rig.config.resume_countdown_us())
	_frames(2)
	assert_eq(_events.count("resumed"), 0)


func test_flush_requests_pause_only_in_running_or_resuming_ac39d() -> void:
	_valid_poll = false
	_build(Factory.State.MENU)
	_frames(3)
	assert_eq(_requests.size(), 0, "Menu with an invalid sensor requests nothing")
	_valid_poll = true
	_fx.tick(10.0, 60)
	_rig.core.request_start()
	_frames(5)
	assert_eq(_requests.size(), 0, "a valid sensor requests nothing")
	_valid_poll = false
	_fx.tick_invalid(10)
	_frame()
	assert_eq(_requests.size(), 1, "one request in the frame")
	assert_eq(_rig.core.phase, P.PAUSED)
	assert_eq(_sensor_lost_pauses(), 1)
	_frames(5)
	assert_eq(_requests.size(), 1, "Paused requests nothing more")


func test_invalid_sensor_in_resuming_requests_a_pause_ac39d() -> void:
	_start_running()
	_pause_and_start_countdown()
	_valid_poll = false
	_fx.tick_invalid(10)
	_frame()
	assert_eq(_requests.size(), 1)
	assert_eq(_rig.core.phase, P.PAUSED)


func test_run_started_with_invalid_sensor_pauses_on_settling_tick_ac39e() -> void:
	_valid_poll = false
	_build(Factory.State.MENU)
	_rig.core.request_start()
	_frame()  # accepts the start
	assert_eq(_rig.core.phase, P.RUNNING)
	_frame()  # settling tick: flush() queued the pause request and it is applied
	assert_eq(_rig.core.phase, P.PAUSED)
	assert_eq(_sensor_lost_pauses(), 1)
	assert_eq(_events.count("started"), 1)
	assert_eq(_rig.logs.count(), 0, "no Run State Error")
	_frames(3)
	assert_eq(_requests.size(), 1)


func test_run_ended_and_run_paused_reach_on_run_stopped_ac39h() -> void:
	_start_running()
	assert_eq(_fx.core.get_stop_us(), 0)
	_rig.core.request_pause(RunStateCore.PauseSource.BUTTON)
	_frame()
	var after_pause: int = _snap_of("paused:%d" % RunStateCore.PauseSource.BUTTON)[3] as int
	assert_eq(after_pause, _fx.clock.now_us)
	assert_gt(after_pause, 0)
	_rig.clock.advance_us(_rig.config.pause_input_guard_us())
	_rig.core.request_resume()
	_frames(1)
	_rig.clock.advance_us(_rig.config.resume_countdown_us())
	_frames(5)
	assert_eq(_rig.core.phase, P.RUNNING)
	_rig.core.request_hit(Factory.HAZARD_ID, _rig.core.run_id)
	_frame()
	assert_eq(_rig.core.phase, P.HIT)
	assert_eq(_snap_of("ended")[3] as int, _fx.clock.now_us)
	assert_gt(_fx.core.get_stop_us(), after_pause)


func _hit_then_sensor(valid_at_restart: bool) -> void:
	_start_running()
	_rig.core.request_hit(Factory.HAZARD_ID, _rig.core.run_id)
	_frames(1)
	assert_eq(_rig.core.phase, P.HIT)
	_frames(60)
	if not valid_at_restart:
		_valid_poll = false
		_fx.tick_invalid(10)
		assert_false(_fx.core.get_valid())


func test_restart_with_invalid_sensor_pauses_next_tick_once_ac43b() -> void:
	_hit_then_sensor(false)
	var run_id: int = _rig.core.run_id
	_events.clear()
	_requests.clear()
	_rig.logs.clear()
	_rig.core.request_restart(_rig.clock.now_us)
	_frame()  # accepts the restart
	assert_eq(_rig.core.run_id, run_id + 1)
	_frame()  # the next tick pauses
	assert_eq(_rig.core.phase, P.PAUSED)
	_frames(5)
	assert_eq(_sensor_lost_pauses(), 1)
	assert_eq(_requests.size(), 1)
	assert_eq(_rig.core.run_id, run_id + 1)
	assert_eq(_rig.logs.count(), 0, "no Run State Error")


func test_restart_with_valid_sensor_requests_nothing_ac43b() -> void:
	_hit_then_sensor(true)
	_requests.clear()
	_rig.logs.clear()
	_rig.core.request_restart(_rig.clock.now_us)
	_frames(6)
	assert_eq(_rig.core.phase, P.RUNNING)
	assert_eq(_requests.size(), 0)
	assert_eq(_rig.logs.count(), 0)


func test_paused_restart_reanchors_after_a_large_steady_move_ac39a() -> void:
	_start_running()
	_rig.core.request_pause(RunStateCore.PauseSource.BUTTON)
	_frames(1)
	_pose = 30.0
	_frames(80)
	_rig.clock.advance_us(_rig.config.pause_input_guard_us())
	_events.clear()
	_snaps.clear()
	_rig.core.request_restart(_rig.clock.now_us)
	_frame()
	assert_eq(_events.slice(0, 2), ["reset", "started"] as Array[String])
	assert_almost_eq(_snap_of("reset")[1] as float, 30.0, 1e-6)
