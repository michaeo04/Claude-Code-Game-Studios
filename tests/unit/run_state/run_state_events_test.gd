## Story RS-003: event emission order, two-step start and re-entrancy guard (GDD AC-3, AC-4, AC-5, AC-17).
extends GutTest

const Factory = preload("res://tests/support/run_state_factory.gd")
const Recorder = preload("res://tests/support/run_state_recorder.gd")
const ClockStub = preload("res://tests/support/clock_stub.gd")
const LogSink = preload("res://tests/support/run_state_log_sink.gd")

const S = Factory.State
const P = RunStateCore.Phase
const ERROR_LEVEL: int = RunStateMath.LogLevel.ERROR

## Every request the nested-call test attempts from inside a handler (7 requests, pause with 4 sources).
const _ATTEMPTS: Array[String] = [
	"map_ready", "start", "hit", "pause", "pause_back", "pause_app", "pause_sensor", "resume", "restart", "menu",
]


func _event_list(rig: Factory) -> Array[Array]:
	return rig.recorder.events


# ---- AC-3: event sequences -------------------------------------------------------------------------

func test_menu_to_running_emits_reset_started_then_phase_changed() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.MENU)
	rig.send("start")
	rig.tick()
	assert_eq(_event_list(rig), [["run_reset", [1]], ["run_started", [1]], ["phase_changed", [P.RUNNING, P.MENU]]])


func test_hit_to_running_emits_reset_started_without_abandoned() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.HIT_UNLOCKED)
	rig.send("restart")
	rig.tick()
	assert_eq(_event_list(rig), [["run_reset", [2]], ["run_started", [2]], ["phase_changed", [P.RUNNING, P.HIT]]])


func test_running_to_hit_emits_run_ended_with_id_hazard_and_ms() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RUNNING)
	rig.send("hit")
	rig.tick()
	assert_eq(_event_list(rig), [["run_ended", [1, Factory.HAZARD_ID, 17]], ["phase_changed", [P.HIT, P.RUNNING]]])


func test_pause_from_running_emits_run_paused_for_each_of_four_sources() -> void:
	var cases: Array = [
		["pause", RunStateCore.PauseSource.BUTTON],
		["pause_back", RunStateCore.PauseSource.BACK],
		["pause_app", RunStateCore.PauseSource.APP_INTERRUPTED],
		["pause_sensor", RunStateCore.PauseSource.SENSOR_LOST],
	]
	for entry: Array in cases:
		var rig: Factory = Factory.new()
		rig.core_in(S.RUNNING)
		rig.send(entry[0] as String)
		rig.tick()
		assert_eq(_event_list(rig), [["run_paused", [entry[1]]], ["phase_changed", [P.PAUSED, P.RUNNING]]], entry[0])


func test_pause_from_resuming_emits_run_paused_for_each_of_four_sources() -> void:
	var cases: Array = [
		["pause", RunStateCore.PauseSource.BUTTON],
		["pause_back", RunStateCore.PauseSource.BACK],
		["pause_app", RunStateCore.PauseSource.APP_INTERRUPTED],
		["pause_sensor", RunStateCore.PauseSource.SENSOR_LOST],
	]
	for entry: Array in cases:
		var rig: Factory = Factory.new()
		rig.core_in(S.RESUMING)
		rig.send(entry[0] as String)
		rig.tick()
		assert_eq(_event_list(rig), [["run_paused", [entry[1]]], ["phase_changed", [P.PAUSED, P.RESUMING]]], entry[0])


func test_app_interrupted_is_emitted_when_sent_before_any_tick() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RUNNING)
	rig.send("pause_app")
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(_event_list(rig), [["run_paused", [RunStateCore.PauseSource.APP_INTERRUPTED]], ["phase_changed", [P.PAUSED, P.RUNNING]]])


func test_paused_to_resuming_emits_run_resuming_2000() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.PAUSED_AFTER)
	rig.send("resume")
	rig.tick()
	assert_eq(_event_list(rig), [["run_resuming", [2000]], ["phase_changed", [P.RESUMING, P.PAUSED]]])


func test_resuming_to_running_emits_run_resumed() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RESUMING)
	rig.clock.advance_us(rig.config.resume_countdown_us())
	rig.tick()
	assert_eq(_event_list(rig), [["run_resumed", [1]], ["phase_changed", [P.RUNNING, P.RESUMING]]])


func test_paused_to_running_emits_abandoned_then_reset_and_started() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.PAUSED_AFTER)
	rig.send("restart", rig.anchor_us + rig.config.pause_input_guard_us())
	rig.tick()
	assert_eq(_event_list(rig), [
		["run_abandoned", [1, 17]], ["run_reset", [2]], ["run_started", [2]], ["phase_changed", [P.RUNNING, P.PAUSED]],
	])


func test_paused_to_menu_emits_abandoned_then_phase_changed() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.PAUSED_AFTER)
	rig.send("menu", rig.anchor_us + rig.config.pause_input_guard_us())
	rig.tick()
	assert_eq(_event_list(rig), [["run_abandoned", [1, 17]], ["phase_changed", [P.MENU, P.PAUSED]]])


func test_boot_to_menu_emits_phase_changed_only() -> void:
	var rig: Factory = Factory.new()
	rig.send("map_ready")
	rig.tick()
	assert_eq(_event_list(rig), [["phase_changed", [P.MENU, P.BOOT]]])


func test_hit_to_menu_emits_phase_changed_only() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.HIT_UNLOCKED)
	rig.send("menu")
	rig.tick()
	assert_eq(_event_list(rig), [["phase_changed", [P.MENU, P.HIT]]])


func test_restart_unlocked_comes_alone_once_per_hit() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.HIT_LOCKED)
	rig.clock.advance_us(rig.config.restart_lock_us() - 1)
	rig.tick()
	assert_eq(_event_list(rig).size(), 0, "one us before the lock ends")
	rig.clock.advance_us(1)
	rig.tick()
	assert_eq(_event_list(rig), [["restart_unlocked", [1]]])
	rig.tick()
	rig.clock.advance_us(5_000_000)
	rig.tick()
	assert_eq(_event_list(rig).size(), 1, "never twice in one Hit, and Hit never times out")
	assert_eq(rig.core.phase, P.HIT)


func test_restart_unlocked_is_not_emitted_on_a_tick_that_leaves_hit() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.HIT_LOCKED)
	rig.clock.advance_us(rig.config.restart_lock_us())
	rig.send("menu")
	rig.tick()
	assert_eq(_event_list(rig), [["phase_changed", [P.MENU, P.HIT]]])


# ---- AC-4: handler contract ------------------------------------------------------------------------

func test_run_reset_handlers_all_return_before_run_started_with_the_same_id() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.MENU)
	var shared: Array[Array] = []
	var doubles: Array[Recorder] = []
	for label: int in 3:
		var double: Recorder = Recorder.new(rig.core, shared)
		double.hook = func(event_name: String) -> void:
			if event_name == "run_reset":
				shared.append(["marker", [label]])
		doubles.append(double)
	rig.send("start")
	assert_eq(shared.size(), 0, "nothing before the tick")
	rig.tick()
	var first_started: int = -1
	var last_marker: int = -1
	var reset_ids: Array[int] = []
	var started_ids: Array[int] = []
	for i: int in shared.size():
		var name: String = shared[i][0]
		if name == "run_started" and first_started < 0:
			first_started = i
		if name == "marker":
			last_marker = i
		if name == "run_reset":
			reset_ids.append((shared[i][1] as Array)[0])
		if name == "run_started":
			started_ids.append((shared[i][1] as Array)[0])
	assert_eq(reset_ids, [1, 1, 1])
	assert_eq(started_ids, [1, 1, 1])
	assert_eq(last_marker, 5, "markers are the 2nd, 4th and 6th entries of the reset phase")
	assert_true(last_marker < first_started, "every return marker precedes run_started")
	for double: Recorder in doubles:
		for phase_seen: int in double.phases_seen:
			assert_eq(phase_seen, P.RUNNING, "phase already reads the new phase inside every handler")


func test_phase_reads_new_phase_inside_every_handler() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.PAUSED_AFTER)
	rig.send("restart", rig.anchor_us + rig.config.pause_input_guard_us())
	rig.tick()
	for phase_seen: int in rig.recorder.phases_seen:
		assert_eq(phase_seen, P.RUNNING, "abandon to restart: run_abandoned, run_reset, run_started, phase_changed")
	assert_eq(rig.recorder.phases_seen.size(), 4)


func test_run_resumed_is_emitted_before_the_first_tick_of_the_resumed_run() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RESUMING)
	rig.clock.advance_us(rig.config.resume_countdown_us())
	var step_of_that_tick: float = rig.tick()
	assert_eq(step_of_that_tick, 0.0)
	assert_eq(rig.recorder.names(), ["run_resumed", "phase_changed"] as Array[String])
	var settling: float = rig.tick()
	assert_eq(settling, 0.0, "the first tick after run_resumed settles")


# ---- AC-5: no nesting ------------------------------------------------------------------------------

## Builds the rig that provokes `event_name`, sends the trigger and returns it (not yet ticked).
func _rig_for_event(event_name: String) -> Factory:
	var rig: Factory = Factory.new()
	match event_name:
		"run_reset", "run_started":
			rig.core_in(S.MENU)
			rig.send("start")
		"phase_changed":
			rig.core_in(S.RUNNING)
			rig.send("hit")
		"run_paused":
			rig.core_in(S.RUNNING)
			rig.send("pause")
		"run_resuming":
			rig.core_in(S.PAUSED_AFTER)
			rig.send("resume")
		"run_resumed":
			rig.core_in(S.RESUMING)
			rig.clock.advance_us(rig.config.resume_countdown_us())
		"run_ended":
			rig.core_in(S.RUNNING)
			rig.send("hit")
		"run_abandoned":
			rig.core_in(S.PAUSED_AFTER)
			rig.send("menu", rig.anchor_us + rig.config.pause_input_guard_us())
		"restart_unlocked":
			rig.core_in(S.HIT_LOCKED)
			rig.clock.advance_us(rig.config.restart_lock_us())
	return rig


func test_request_sent_from_a_handler_of_each_of_the_nine_events_is_rejected_with_one_error() -> void:
	var event_names: Array[String] = [
		"run_reset", "run_started", "run_paused", "run_resuming", "run_resumed",
		"run_ended", "run_abandoned", "restart_unlocked", "phase_changed",
	]
	for event_name: String in event_names:
		var rig: Factory = _rig_for_event(event_name)
		var fired: Array[int] = [0]
		var errors_at_fire: Array[int] = []
		var phase_drift: Array[int] = [0]
		var attempts: Array[String] = _ATTEMPTS
		var rig_ref: Factory = rig
		rig.recorder.hook = func(name: String) -> void:
			if name != event_name or fired[0] > 0:
				return
			fired[0] += 1
			var phase_before: int = rig_ref.core.phase
			for attempt: String in attempts:
				var before: int = rig_ref.logs.count()
				rig_ref.send(attempt, rig_ref.clock.now_us)
				errors_at_fire.append(rig_ref.logs.count() - before)
			var before_tick: int = rig_ref.logs.count()
			rig_ref.core.tick(0.016, 0.016)
			errors_at_fire.append(rig_ref.logs.count() - before_tick)
			if rig_ref.core.phase != phase_before:
				phase_drift[0] += 1
		rig.tick()
		assert_eq(fired[0], 1, "%s fired" % event_name)
		assert_eq(errors_at_fire.size(), _ATTEMPTS.size() + 1, event_name)
		for count: int in errors_at_fire:
			assert_eq(count, 1, "%s: one log line per attempt" % event_name)
		assert_eq(rig.logs.count_level(ERROR_LEVEL), _ATTEMPTS.size() + 1, "%s: all attempts at error level" % event_name)
		assert_eq(rig.logs.count(), _ATTEMPTS.size() + 1, "%s: nothing else logged" % event_name)
		assert_eq(phase_drift[0], 0, "%s: no attempt changed the phase" % event_name)


func test_rejected_nested_requests_change_nothing_and_leave_the_queue_empty() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RUNNING)
	rig.send("pause")
	var attempts: Array[String] = _ATTEMPTS
	var rig_ref: Factory = rig
	rig.recorder.hook = func(name: String) -> void:
		if name == "run_paused":
			for attempt: String in attempts:
				rig_ref.send(attempt, rig_ref.clock.now_us)
	rig.tick()
	assert_eq(rig.core.phase, P.PAUSED)
	assert_eq(rig.recorder.names(), ["run_paused", "phase_changed"] as Array[String], "no extra event")
	rig.recorder.hook = Callable()
	rig.tick()
	assert_eq(rig.core.phase, P.PAUSED, "no nested request was queued")
	assert_eq(rig.recorder.events.size(), 2)


func test_same_request_after_the_handler_returns_gives_the_ac1_outcome() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.RUNNING)
	rig.send("pause")
	var rig_ref: Factory = rig
	rig.recorder.hook = func(name: String) -> void:
		if name == "run_paused":
			rig_ref.send("resume")
	rig.tick()
	rig.recorder.hook = Callable()
	assert_eq(rig.logs.count_level(ERROR_LEVEL), 1)
	rig.clock.advance_us(rig.config.pause_input_guard_us())
	rig.send("resume")
	rig.tick()
	assert_eq(rig.core.phase, P.RESUMING, "resume from Paused is accepted once the handler has returned")


func test_request_sent_from_the_injected_clock_during_a_tick_is_rejected() -> void:
	var clock: ClockStub = ClockStub.new(Factory.START_US)
	var logs: LogSink = LogSink.new()
	var holder: Array[RunStateCore] = []
	var armed: Array[bool] = [false]
	var clock_fn: Callable = func() -> int:
		if armed[0]:
			armed[0] = false
			holder[0].request_start()
			holder[0].request_pause(RunStateCore.PauseSource.APP_INTERRUPTED)
		return clock.now_us
	var core: RunStateCore = RunStateCore.new(RunConfig.new(), clock_fn, logs.sink)
	holder.append(core)
	core.request_map_ready()
	core.tick(0.016, 0.016)
	armed[0] = true
	core.tick(0.016, 0.016)
	assert_eq(logs.count_level(ERROR_LEVEL), 2, "both attempts from inside the tick are rejected")
	assert_eq(core.phase, P.MENU)
	core.tick(0.016, 0.016)
	assert_eq(core.phase, P.MENU, "nothing was queued")
	holder.clear()


# ---- AC-17: clock jump inside a handler ------------------------------------------------------------

func test_clock_advanced_5s_in_run_reset_handler_still_yields_run_started_and_a_settling_next_tick() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(S.HIT_UNLOCKED)
	var clock_ref: ClockStub = rig.clock
	rig.recorder.hook = func(name: String) -> void:
		if name == "run_reset":
			clock_ref.advance_s(5.0)
	rig.send("restart")
	rig.tick()
	assert_eq(rig.recorder.names(), ["run_reset", "run_started", "phase_changed"] as Array[String])
	assert_eq(rig.core.phase, P.RUNNING)
	assert_eq(rig.logs.count(), 0, "no timer was re-evaluated and nothing was logged in that tick")
	var settling: float = rig.core.tick(0.016, 5.0)
	assert_eq(settling, 0.0, "the next tick settles and absorbs the hitch")
	assert_eq(rig.core.run_time, 0.0)
	assert_eq(rig.core.phase, P.RUNNING)
	var live: float = rig.core.tick(0.016, 0.016)
	assert_almost_eq(live, 0.016, 1e-6)
