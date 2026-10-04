## Stories TI-012 / CRF-002: TiltRunAdapter and the level-triggered sensor-lost pause (AC-43, AC-43b).
extends GutTest

const Fixture = preload("res://tests/support/tilt_fixture.gd")
const Factory = preload("res://tests/support/run_state_factory.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")
const P = RunStateCore.Phase


func test_sensor_lost_table_is_true_only_for_running_and_resuming_with_invalid() -> void:
	for phase: int in [P.BOOT, P.MENU, P.RUNNING, P.PAUSED, P.RESUMING, P.HIT]:
		var live: bool = phase == P.RUNNING or phase == P.RESUMING
		assert_eq(TiltMath.sensor_lost_pause_needed(phase, false), live, "invalid, phase %d" % phase)
		assert_false(TiltMath.sensor_lost_pause_needed(phase, true), "valid, phase %d" % phase)


func _adapter(rig: Factory, fixture: Fixture, requests: Array[int]) -> TiltRunAdapter:
	var request: Callable = func(source: int) -> void:
		requests.append(source)
		rig.core.request_pause(source as RunStateCore.PauseSource)
	var phase: Callable = func() -> int:
		return rig.core.phase as int
	return TiltRunAdapter.new(fixture.core, request, phase)


func test_flush_requests_one_sensor_lost_pause_when_invalid_in_running() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(Factory.State.RUNNING)
	var fixture: Fixture = Fixture.new()
	var requests: Array[int] = []
	var adapter: TiltRunAdapter = _adapter(rig, fixture, requests)
	var sources: Array[int] = []
	rig.core.run_paused.connect(func(source: int) -> void: sources.append(source))
	var run_id: int = rig.core.run_id
	adapter.flush()
	rig.tick()
	adapter.flush()
	rig.tick()
	assert_eq(requests, [RunStateCore.PauseSource.SENSOR_LOST] as Array[int])
	assert_eq(sources, [RunStateCore.PauseSource.SENSOR_LOST] as Array[int])
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(rig.core.run_id, run_id)
	assert_eq(rig.logs.count(), 0)


func test_flush_does_nothing_when_valid_or_in_menu() -> void:
	var fixture: Fixture = Fixture.new()
	fixture.tick(0.0, 60)
	fixture.core.on_run_reset(TiltCore.PreviousPhase.MENU)
	fixture.tick(0.0, 20)
	assert_true(fixture.core.get_valid(), "fixture precondition")
	var rig: Factory = Factory.new()
	rig.core_in(Factory.State.RUNNING)
	var requests: Array[int] = []
	_adapter(rig, fixture, requests).flush()
	var menu_rig: Factory = Factory.new()
	menu_rig.core_in(Factory.State.MENU)
	_adapter(menu_rig, Fixture.new(), requests).flush()
	assert_eq(requests.size(), 0)


func test_invalid_callable_logs_one_error_each_and_flush_is_inert() -> void:
	var sink: LogSink = LogSink.new()
	var adapter: TiltRunAdapter = TiltRunAdapter.new(Fixture.new().core, Callable(), Callable(), sink.sink)
	adapter.flush()
	assert_eq(sink.count(), 2)
	assert_eq(sink.code_at(0), TiltRunAdapter.LOG_SEAM_INVALID)
