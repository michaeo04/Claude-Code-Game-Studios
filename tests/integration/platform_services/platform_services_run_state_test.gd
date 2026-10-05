## Platform Services story 012: real PlatformCore + real RunStateCore + test-only adapter (AC-14, AC-15).
## Run State queues every pause source except `app_interrupted` until the next tick (its GDD Core Rule 3), so BACK
## is observed after one tick; INT is applied before the `on_*` call returns.
extends GutTest

const ClockStub = preload("res://tests/support/clock_stub.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")
const Rig = preload("res://tests/support/platform_rig.gd")
const Adapter = preload("res://tests/support/platform_run_adapter.gd")

const DT: float = 0.016
const EVENTS: Array[String] = ["FO", "FI", "P", "R"]

var _clock: ClockStub
var _rs: RunStateCore
var _rs_sink: LogSink
var _rig: Rig
var _adapter: Adapter
var _pauses: Array[int] = []
var _ended: Array[int] = []


func _build(fis: bool) -> void:
	_rs_sink = LogSink.new()
	_pauses = []
	_ended = []
	_clock = ClockStub.new(0)
	_rs = RunStateCore.new(RunConfig.new(), _clock.as_callable(), _rs_sink.sink)
	_rs.run_paused.connect(_on_paused)
	_rs.run_ended.connect(_on_ended)
	_rig = Rig.new(fis)
	_adapter = Adapter.new(_rig.core, _rs)


func _on_paused(source: RunStateCore.PauseSource) -> void:
	_pauses.append(source as int)


func _on_ended(_run_id: int, _hazard_id: int, _run_time_ms: int) -> void:
	_ended.append(1)


## Drives the core to `target` phase.
func _go(target: RunStateCore.Phase) -> void:
	if target == RunStateCore.Phase.BOOT:
		return
	_rs.request_map_ready()
	_rs.tick(DT, DT)
	if target == RunStateCore.Phase.MENU:
		return
	_rs.request_start()
	_rs.tick(DT, DT)
	if target == RunStateCore.Phase.RUNNING:
		return
	if target == RunStateCore.Phase.HIT:
		_rs.tick(DT, DT) # past the settling tick
		assert_eq(_rs.phase, RunStateCore.Phase.RUNNING, "setup: running before the hit")
		_rs.request_hit(0, _rs.run_id)
		_rs.tick(DT, DT)
		assert_eq(_rs.phase, RunStateCore.Phase.HIT, "setup: hit")
		return
	_rs.request_pause(RunStateCore.PauseSource.BUTTON)
	_rs.tick(DT, DT)
	if target == RunStateCore.Phase.RESUMING:
		_rs.request_resume()
		_rs.tick(DT, DT)
	_pauses.clear()
	_rs_sink.clear()


func _deliver(event: String) -> void:
	match event:
		"FO":
			_rig.core.on_focus_out()
		"FI":
			_rig.core.on_focus_in()
		"P":
			_rig.core.on_paused()
		"R":
			_rig.core.on_resumed()


func test_ac14_int_in_running_and_resuming_pauses_once_before_the_call_returns() -> void:
	for phase: RunStateCore.Phase in [RunStateCore.Phase.RUNNING, RunStateCore.Phase.RESUMING]:
		_build(true)
		_go(phase)
		_rs_sink.clear()
		_pauses.clear()
		_rig.core.on_focus_out()
		assert_eq(_rs.phase, RunStateCore.Phase.PAUSED, "phase %s" % phase)
		assert_eq(_pauses, [RunStateCore.PauseSource.APP_INTERRUPTED as int], "one run_paused, source app_interrupted")
		assert_eq(_rs_sink.count(), 0)


func test_ac14_back_in_running_and_resuming_pauses_once_with_source_back() -> void:
	for phase: RunStateCore.Phase in [RunStateCore.Phase.RUNNING, RunStateCore.Phase.RESUMING]:
		_build(true)
		_go(phase)
		_rs_sink.clear()
		_pauses.clear()
		_rig.core.on_back_requested()
		_rs.tick(DT, DT)
		assert_eq(_rs.phase, RunStateCore.Phase.PAUSED, "phase %s" % phase)
		assert_eq(_pauses, [RunStateCore.PauseSource.BACK as int], "one run_paused, source back")
		assert_eq(_rs_sink.count(), 0)


func test_ac14_int_and_back_in_menu_boot_hit_and_paused_change_nothing_and_log_nothing() -> void:
	for phase: RunStateCore.Phase in [
		RunStateCore.Phase.MENU, RunStateCore.Phase.BOOT, RunStateCore.Phase.HIT, RunStateCore.Phase.PAUSED
	]:
		_build(true)
		_go(phase)
		_rs_sink.clear()
		_pauses.clear()
		_ended.clear()
		_rig.core.on_focus_out()
		_rig.core.on_back_requested()
		_rs.tick(DT, DT)
		assert_eq(_rs.phase, phase, "no phase change in %s" % phase)
		assert_eq(_pauses.size(), 0, "no run_paused in %s" % phase)
		assert_eq(_ended.size(), 0)
		assert_eq(_rs_sink.count(), 0, "zero log lines in %s" % phase)


func test_ac14_two_back_in_running_give_one_pause_and_a_second_back_in_paused_is_silent() -> void:
	_build(true)
	_go(RunStateCore.Phase.RUNNING)
	_rs_sink.clear()
	_rig.core.on_back_requested()
	_rig.core.on_back_requested()
	_rs.tick(DT, DT)
	assert_eq(_rs.phase, RunStateCore.Phase.PAUSED)
	assert_eq(_pauses.size(), 1, "two BACK give one pause")
	_rig.core.on_back_requested()
	_rs.tick(DT, DT)
	assert_eq(_rs.phase, RunStateCore.Phase.PAUSED)
	assert_eq(_pauses.size(), 1, "a second BACK in Paused is a no-op")
	assert_eq(_rs_sink.count(), 0, "silent")


func test_ac14_android_home_sequence_a1_pauses_with_run_id_unchanged_and_no_run_ended() -> void:
	_build(true)
	_go(RunStateCore.Phase.RUNNING)
	var run_id: int = _rs.run_id
	_rs_sink.clear()
	_rig.core.on_focus_out()
	_rig.core.on_focus_in()
	_rs.tick(DT, DT)
	assert_eq(_rs.phase, RunStateCore.Phase.PAUSED)
	assert_eq(_rs.run_id, run_id, "run_id unchanged")
	assert_eq(_ended.size(), 0, "no run_ended")
	assert_eq(_pauses.size(), 1)
	assert_eq(_rs_sink.count(), 0)


func test_ac15_all_340_sequences_give_no_run_state_errors_and_pause_iff_fo_or_p_on_desktop() -> void:
	var total: int = 0
	for fis: bool in [false, true]:
		for length: int in range(1, 5):
			var count: int = int(pow(4.0, float(length)))
			for code: int in count:
				var seq: Array[String] = []
				var rest: int = code
				for i: int in length:
					seq.append(EVENTS[rest % 4])
					rest /= 4
				_build(fis)
				_go(RunStateCore.Phase.RUNNING)
				_rs_sink.clear()
				for event: String in seq:
					_deliver(event)
				_rs.tick(DT, DT)
				var expect_paused: bool = seq.has("FO") or (not fis and seq.has("P"))
				var label: String = "fis=%s seq=%s" % [fis, seq]
				assert_eq(_rs.phase == RunStateCore.Phase.PAUSED, expect_paused, label)
				var errors: int = 0
				for i: int in _rs_sink.count():
					if _rs_sink.level_at(i) == LogLevel.ERROR:
						errors += 1
				assert_eq(errors, 0, label)
				total += 1
	assert_eq(total, 680, "340 sequences x 2 fis values")
