## Story TT-010: TubeRunAdapter against a real RunStateCore, a real TubeWindow and a real WorldFrame
## (TR-024, ADR-0013 Decision 3, ADR-0004 B5).
extends GutTest

const Factory = preload("res://tests/support/run_state_factory.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")
const WindowSpy = preload("res://tests/support/tube_window_spy.gd")
const S = TubeWindow.State

var _rig: Factory
var _sink: LogSink
var _spy: WindowSpy
var _window: TubeWindow
var _frame: WorldFrame
var _adapter: TubeRunAdapter
var _map_ready_count: Array[int] = [0]


func before_each() -> void:
	_rig = Factory.new()
	_sink = LogSink.new()
	_spy = WindowSpy.new()
	_window = TubeWindow.new(_sink.sink, _spy.binder)
	_window.load_map(TubeConfig.new(), 25.0, 0.8)
	_frame = WorldFrame.new(WorldFrameConfig.new(), WorldGeometry.new(3.0, 2.0, 20, 12.0, 9))
	_adapter = TubeRunAdapter.new(_window, _frame)
	# Rank 1 (world frame) before rank 2 (adapter) for run_reset, as the composition root wires it.
	_rig.core.run_reset.connect(_frame.on_run_reset)
	_rig.core.run_reset.connect(_adapter.on_run_reset)
	_rig.core.run_paused.connect(_adapter.on_run_paused)
	_rig.core.run_resumed.connect(_adapter.on_run_resumed)
	_rig.core.run_ended.connect(_adapter.on_run_ended)
	_rig.core.phase_changed.connect(_adapter.on_phase_changed)
	_spy.clear()
	_sink.clear()


func test_phase_sequence_follows_the_table_with_a_real_core() -> void:
	_rig.send("map_ready")
	_rig.tick()
	assert_eq(_window.get_state(), S.IDLE, "Boot to Menu skips to_idle")
	_rig.send("start")
	_rig.tick()
	assert_eq(_window.get_state(), S.RUNNING, "run_reset begins the run")
	_rig.tick()
	_rig.tick()
	_rig.send("pause")
	_rig.tick()
	assert_eq(_window.get_state(), S.PAUSED)
	_rig.clock.advance_us(_rig.config.pause_input_guard_us())
	_rig.tick()
	_rig.send("resume")
	_rig.tick()
	for i: int in range(400):
		if _rig.core.phase == RunStateCore.Phase.RUNNING:
			break
		_rig.clock.advance_us(16_667)
		_rig.tick()
	assert_eq(_rig.core.phase, RunStateCore.Phase.RUNNING)
	assert_eq(_window.get_state(), S.RUNNING, "run_resumed resumes")
	_rig.tick()
	_rig.tick()
	_rig.send("hit")
	_rig.tick()
	assert_eq(_window.get_state(), S.ENDED)
	_rig.clock.advance_us(_rig.config.restart_lock_us())
	_rig.tick()
	_rig.send("restart")
	_rig.tick()
	assert_eq(_window.get_state(), S.RUNNING, "Hit to Running (Restart) skips Idle")
	assert_eq(_sink.count(), 0, "no rejected-event errors")


func test_return_to_menu_after_a_rebase_reprimes_like_a_fresh_placement() -> void:
	var fresh_spy: WindowSpy = WindowSpy.new()
	var fresh: TubeWindow = TubeWindow.new(_sink.sink, fresh_spy.binder)
	fresh.load_map(TubeConfig.new(), 25.0, 0.8)
	var fresh_binds: Array[Array] = fresh_spy.binds.duplicate()
	_rig.core_in(Factory.State.MENU)
	_rig.send("start")
	_rig.tick()
	_rig.tick()
	_frame.origin_s = 1008.0
	_rig.send("pause")
	_rig.tick()
	_rig.clock.advance_us(_rig.config.pause_input_guard_us())
	_rig.tick()
	_spy.clear()
	_rig.send("menu")
	_rig.tick()
	assert_eq(_frame.origin_s, 0.0, "Paused to Menu resets the origin")
	assert_eq(_window.get_state(), S.IDLE)
	assert_eq(_spy.binds, fresh_binds, "idle slots equal a fresh placement")
	# Hit to Menu
	_rig.send("start")
	_rig.tick()
	_rig.tick()
	_rig.tick()
	_frame.origin_s = 1008.0
	_rig.send("hit")
	_rig.tick()
	_rig.clock.advance_us(_rig.config.restart_lock_us())
	_rig.tick()
	_spy.clear()
	_rig.send("menu")
	_rig.tick()
	assert_eq(_frame.origin_s, 0.0, "Hit to Menu resets the origin")
	assert_eq(_spy.binds, fresh_binds)


func test_restart_reprimes_at_origin_zero_through_run_reset() -> void:
	_rig.core_in(Factory.State.HIT_UNLOCKED)
	_frame.origin_s = 1008.0
	_spy.clear()
	_rig.send("restart")
	_rig.tick()
	assert_eq(_frame.origin_s, 0.0, "rank 1 reset the origin")
	assert_eq(_window.get_state(), S.RUNNING)
	assert_eq(_window.get_s(), 0.0)
	assert_eq(_window.get_first_index(), -2)


func test_loader_double_owns_load_map_and_retry_does_not_recreate_slots() -> void:
	var unloaded: TubeWindow = TubeWindow.new(_sink.sink, _spy.binder)
	var bad: TubeConfig = TubeConfig.new()
	bad.segment_length = -1.0
	_spy.clear()
	assert_false(_load_b5(unloaded, bad), "B5 returns false on a validation failure")
	assert_eq(unloaded.get_state(), S.UNINITIALIZED)
	assert_eq(_map_ready_count[0], 0, "no map_ready after a failed B5")
	assert_eq(_spy.binds.size(), 0, "no slot bound")
	assert_true(_load_b5(unloaded, TubeConfig.new()), "Retry succeeds")
	assert_eq(unloaded.get_state(), S.IDLE)
	assert_eq(_map_ready_count[0], 1, "one map_ready after the successful B5")
	assert_eq(_spy.binds.size(), 12, "slots created once (2 behind + 9 ahead + 1)")


## Loader double: B5 is the last step and map_ready follows only a successful return.
func _load_b5(window: TubeWindow, cfg: TubeConfig) -> bool:
	var ok: bool = window.load_map(cfg, 25.0, 0.8).is_empty()
	if ok:
		_map_ready_count[0] += 1
	return ok
