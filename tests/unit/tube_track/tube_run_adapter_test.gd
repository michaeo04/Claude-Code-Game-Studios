## Stories TT-010 / CRF-002: TubeRunAdapter maps Run State events to the TubeWindow lifecycle (TR-024, ADR-0013).
extends GutTest

const LogSink = preload("res://tests/support/platform_log_sink.gd")
const P = RunStateCore.Phase
const S = TubeWindow.State

var _sink: LogSink
var _window: TubeWindow
var _frame: WorldFrame
var _adapter: TubeRunAdapter


func before_each() -> void:
	_sink = LogSink.new()
	_window = TubeWindow.new(_sink.sink, Callable())
	_window.load_map(TubeConfig.new(), 25.0, 0.8)
	_frame = WorldFrame.new(WorldFrameConfig.new(), WorldGeometry.new(3.0, 2.0, 20, 12.0, 9))
	_adapter = TubeRunAdapter.new(_window, _frame)
	_sink.clear()


func test_phase_sequence_follows_the_transition_table_without_errors() -> void:
	_adapter.on_phase_changed(P.MENU, P.BOOT)
	assert_eq(_window.get_state(), S.IDLE, "Boot to Menu skips to_idle")
	_adapter.on_run_reset(1)
	assert_eq(_window.get_state(), S.RUNNING)
	_adapter.on_run_paused(RunStateCore.PauseSource.BUTTON)
	assert_eq(_window.get_state(), S.PAUSED)
	_adapter.on_run_paused(RunStateCore.PauseSource.BUTTON)
	assert_eq(_window.get_state(), S.PAUSED, "pause when already Paused is skipped")
	_adapter.on_run_resumed(1)
	assert_eq(_window.get_state(), S.RUNNING)
	_adapter.on_run_ended(1, 4, 1000)
	assert_eq(_window.get_state(), S.ENDED)
	_adapter.on_run_reset(2)
	assert_eq(_window.get_state(), S.RUNNING, "Hit to Running (Restart) skips Idle")
	_adapter.on_run_ended(2, 4, 1000)
	_adapter.on_phase_changed(P.MENU, P.HIT)
	assert_eq(_window.get_state(), S.IDLE)
	assert_eq(_sink.count(), 0)


func test_return_to_menu_resets_the_origin_before_to_idle() -> void:
	_adapter.on_run_reset(1)
	_frame.origin_s = 1008.0
	_adapter.on_run_paused(RunStateCore.PauseSource.BUTTON)
	_adapter.on_phase_changed(P.MENU, P.PAUSED)
	assert_eq(_frame.origin_s, 0.0)
	assert_eq(_window.get_state(), S.IDLE)
	_adapter.on_run_reset(2)
	_frame.origin_s = 1008.0
	_adapter.on_run_ended(2, 1, 10)
	_adapter.on_phase_changed(P.MENU, P.HIT)
	assert_eq(_frame.origin_s, 0.0)
	assert_eq(_sink.count(), 0)
