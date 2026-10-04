## State factory for Run State tests (test plan section 2): `core_in(state)` reaches every phase through
## the public API of a fresh `RunStateCore`, with an injected clock starting at 1,000,000 us. After the
## factory returns, the recorder and the log are cleared, so a test asserts only on what it sends.
##
## Framework-free (ADR-0009 Decision 1): no GUT call. Usage:
##   var rig := Factory.new()
##   rig.core_in(Factory.State.HIT_LOCKED)
##   rig.send("restart", rig.anchor_us + rig.config.restart_lock_us())
##   rig.tick()
extends RefCounted

const ClockStub = preload("res://tests/support/clock_stub.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")
const Recorder = preload("res://tests/support/run_state_recorder.gd")

## The 8 factory states of the test plan (Paused and Hit each in the locked and the unlocked form).
enum State { BOOT, MENU, RUNNING, PAUSED_INSIDE, PAUSED_AFTER, RESUMING, HIT_LOCKED, HIT_UNLOCKED }

## Clock value at construction (a `press_us` of 0 means "missing", so the clock never starts at 0).
const START_US: int = 1_000_000
## One 60 fps frame.
const DT: float = 1.0 / 60.0
## Hazard id used by `send("hit")`.
const HAZARD_ID: int = 4

var core: RunStateCore
var clock: ClockStub = ClockStub.new(START_US)
var logs: LogSink = LogSink.new()
var recorder: Recorder
var config: RunConfig = RunConfig.new()
## Clock value at the tick that entered Paused, Resuming or Hit (0 in other states).
var anchor_us: int = 0


## A fresh Boot core; the recorder is connected from the start.
func _init() -> void:
	core = RunStateCore.new(config, clock.as_callable(), logs.sink)
	recorder = Recorder.new(core)


## Drives the core into `state` through the public API; clears the recorder and the log afterwards.
func core_in(state: State) -> RunStateCore:
	match state:
		State.MENU:
			_to_menu()
		State.RUNNING:
			_to_running()
		State.PAUSED_INSIDE:
			_to_running()
			_to_paused()
		State.PAUSED_AFTER:
			_to_running()
			_to_paused()
			clock.advance_us(config.pause_input_guard_us())
			tick()
		State.RESUMING:
			_to_running()
			_to_paused()
			clock.advance_us(config.pause_input_guard_us())
			tick()
			core.request_resume()
			tick()
			anchor_us = clock.now_us
		State.HIT_LOCKED:
			_to_running()
			_to_hit()
		State.HIT_UNLOCKED:
			_to_running()
			_to_hit()
			clock.advance_us(config.restart_lock_us())
			tick()
	recorder.clear()
	logs.clear()
	return core


## Sends the named request: map_ready, start, hit (current run id), pause (button), pause_back,
## pause_app, pause_sensor, resume, restart, menu. A `press_us` of 0 means "the clock now".
func send(request: String, press_us: int = 0) -> void:
	var press: int = press_us if press_us != 0 else clock.now_us
	match request:
		"map_ready":
			core.request_map_ready()
		"start":
			core.request_start()
		"hit":
			core.request_hit(HAZARD_ID, core.run_id)
		"pause":
			core.request_pause(RunStateCore.PauseSource.BUTTON)
		"pause_back":
			core.request_pause(RunStateCore.PauseSource.BACK)
		"pause_app":
			core.request_pause(RunStateCore.PauseSource.APP_INTERRUPTED)
		"pause_sensor":
			core.request_pause(RunStateCore.PauseSource.SENSOR_LOST)
		"resume":
			core.request_resume()
		"restart":
			core.request_restart(press)
		"menu":
			core.request_menu(press)


## One 60 fps tick; returns `dt_eff`.
func tick() -> float:
	return core.tick(DT, DT)


func _to_menu() -> void:
	core.request_map_ready()
	tick()


func _to_running() -> void:
	_to_menu()
	core.request_start()
	tick() # accepts the start; the next tick is the settling tick
	tick() # settling tick
	tick() # a live tick, so run_time is 1/60 s


func _to_paused() -> void:
	core.request_pause(RunStateCore.PauseSource.BUTTON)
	tick()
	anchor_us = clock.now_us


func _to_hit() -> void:
	core.request_hit(HAZARD_ID, core.run_id)
	tick()
	anchor_us = clock.now_us
