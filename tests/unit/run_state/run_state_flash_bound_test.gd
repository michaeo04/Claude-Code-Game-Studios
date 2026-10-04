## Story RS-011: flash bound bot (GDD AC-24) and contract doubles (AC-25).
##
## Deterministic: injected microsecond clock, a fixed tick length per fps, no randomness. The bot hits on the
## first live tick after the settling tick and restarts at the earliest allowed press (`press_us = hit_us +
## RESTART_LOCK_us`). A cycle is: restart tick, settling tick, hit tick, then ticks until the lock ends.
extends GutTest

const ClockStub = preload("res://tests/support/clock_stub.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")
const Doubles = preload("res://tests/support/run_state_doubles.gd")

const START_US: int = 1_000_000
const CYCLES: int = 300
const WINDOW_US: int = 1_000_000
const HAZARD_ID: int = 4


class Rig:
	extends RefCounted
	var core: RunStateCore
	var clock: ClockStub = ClockStub.new(START_US)
	var logs: LogSink = LogSink.new()
	var tick_us: int = 0
	var lock_us: int = 0

	func _init(lock_s: float, fps: int) -> void:
		var cfg: RunConfig = RunConfig.new()
		cfg.restart_lock = lock_s
		core = RunStateCore.new(cfg, clock.as_callable(), logs.sink)
		tick_us = roundi(1_000_000.0 / float(fps))
		lock_us = RunStateMath.seconds_to_us(lock_s)

	func tick() -> void:
		clock.advance_us(tick_us)
		core.tick(float(tick_us) / 1_000_000.0, float(tick_us) / 1_000_000.0)

	## Menu -> Running: map_ready, start, then the start tick.
	func boot_and_start() -> void:
		core.request_map_ready()
		tick()
		core.request_start()
		tick()

	## One cycle from the restart/start tick just done: settling tick, hit tick, wait, earliest restart.
	## Returns the hit time in microseconds.
	func hit_and_restart() -> int:
		tick() # settling tick: a hit here would be ignored
		core.request_hit(HAZARD_ID, core.run_id)
		tick()
		var hit_us: int = clock.now_us
		while true:
			clock.advance_us(tick_us)
			if clock.now_us >= hit_us + lock_us:
				core.request_restart(hit_us + lock_us)
				core.tick(float(tick_us) / 1_000_000.0, float(tick_us) / 1_000_000.0)
				break
			core.tick(float(tick_us) / 1_000_000.0, float(tick_us) / 1_000_000.0)
		return hit_us


## Runs `cycles` bot cycles; returns the hit times (us).
func _run_bot(rig: Rig, cycles: int) -> Array[int]:
	var hits: Array[int] = []
	rig.boot_and_start()
	for _i in range(cycles):
		hits.append(rig.hit_and_restart())
	return hits


## Largest number of timestamps inside any closed window of `window_us` (both ends included).
func _max_in_closed_window(times: Array[int], window_us: int) -> int:
	var best: int = 0
	for i in range(times.size()):
		var count: int = 0
		for j in range(i, times.size()):
			if times[j] - times[i] <= window_us:
				count += 1
			else:
				break
		best = maxi(best, count)
	return best


func test_flash_window_helper_includes_both_ends() -> void:
	var times: Array[int] = [0, 500_000, 1_000_000, 1_000_001]
	assert_eq(_max_in_closed_window(times, WINDOW_US), 3, "0, 0.5 and 1.0 s are in one closed window")


func test_flash_bot_default_lock_60fps_is_exactly_32_ticks_and_2_per_window() -> void:
	var rig: Rig = Rig.new(0.5, 60)
	var hits: Array[int] = _run_bot(rig, CYCLES)
	assert_eq(hits.size(), CYCLES)
	for i in range(1, hits.size()):
		assert_eq(hits[i] - hits[i - 1], 32 * rig.tick_us, "cycle %d is 32 ticks" % i)
	assert_eq(_max_in_closed_window(hits, WINDOW_US), 2)


func test_flash_bot_minimum_lock_60fps_is_exactly_29_ticks_and_3_per_window() -> void:
	var rig: Rig = Rig.new(0.45, 60)
	var hits: Array[int] = _run_bot(rig, CYCLES)
	for i in range(1, hits.size()):
		assert_eq(hits[i] - hits[i - 1], 29 * rig.tick_us, "cycle %d is 29 ticks" % i)
	assert_eq(_max_in_closed_window(hits, WINDOW_US), 3)


func test_flash_bot_sweep_every_interval_exceeds_the_lock_and_windows_hold() -> void:
	for lock_s: float in [0.45, 0.5, 0.6]:
		for fps: int in [30, 60, 120]:
			var rig: Rig = Rig.new(lock_s, fps)
			var hits: Array[int] = _run_bot(rig, CYCLES)
			var label: String = "lock=%s fps=%d" % [lock_s, fps]
			assert_eq(hits.size(), CYCLES, label)
			for i in range(1, hits.size()):
				assert_true(hits[i] - hits[i - 1] > rig.lock_us, "%s interval %d" % [label, i])
			var bound: int = 3 if lock_s < 0.5 else 2
			assert_true(_max_in_closed_window(hits, WINDOW_US) <= bound, label)
			assert_eq(rig.core.run_id, CYCLES + 1, label + " every restart was accepted at the earliest press")
			assert_eq(rig.logs.count_code(RunStateMath.LOG_REQUEST_LOCKED), 0, label + " no press was inside the lock")


func test_flash_bot_run_ended_count_equals_cycles() -> void:
	var rig: Rig = Rig.new(0.5, 60)
	var ended: Array[int] = [0]
	rig.core.run_ended.connect(func(_id: int, _hz: int, _ms: int) -> void: ended[0] += 1)
	_run_bot(rig, CYCLES)
	assert_eq(ended[0], CYCLES)


func _connection_total(core: RunStateCore) -> int:
	var total: int = 0
	for sig: Signal in [
		core.run_reset, core.run_started, core.run_paused, core.run_resuming, core.run_resumed,
		core.run_ended, core.run_abandoned, core.restart_unlocked, core.phase_changed
	]:
		total += sig.get_connections().size()
	return total


func test_doubles_get_exactly_one_reset_per_run_over_1000_cycles() -> void:
	var rig: Rig = Rig.new(0.5, 60)
	var doubles: Array = []
	for kind: String in ["ball", "obstacle", "juice", "scoring"]:
		doubles.append(Doubles.new(rig.core, kind))
	var connections_before: int = _connection_total(rig.core)
	var cycles: int = 1000
	_run_bot(rig, cycles)
	var runs: int = cycles + 1 # the first start plus one restart per cycle
	for d in doubles:
		assert_eq(d.resets, runs, "%s resets" % d.kind)
		assert_eq(d.starts, runs, "%s starts" % d.kind)
		assert_eq(d.ends, cycles, "%s ends" % d.kind)
		assert_true(d.sequence_ok, "%s saw run ids +1 each time" % d.kind)
	assert_eq(_connection_total(rig.core), connections_before, "connection count is constant")
	assert_eq(connections_before, 4 * 3, "four doubles connect to three signals each")


func test_doubles_hit_from_a_run_started_handler_is_rejected() -> void:
	var rig: Rig = Rig.new(0.5, 60)
	var offender: Object = Doubles.new(rig.core, "obstacle")
	offender.hit_on_started = true
	var ended: Array[int] = [0]
	rig.core.run_ended.connect(func(_id: int, _hz: int, _ms: int) -> void: ended[0] += 1)
	rig.core.request_map_ready()
	rig.tick()
	rig.core.request_start()
	rig.tick() # run_started handler sends request_hit: rejected
	rig.tick() # settling tick
	rig.tick() # live tick: nothing queued
	assert_eq(rig.core.nested_request_rejections, 1)
	assert_eq(rig.logs.count_code(RunStateMath.LOG_REQUEST_NESTED), 1)
	assert_eq(ended[0], 0, "the rejected hit never ends the run")
	assert_eq(rig.core.phase, RunStateCore.Phase.RUNNING)
