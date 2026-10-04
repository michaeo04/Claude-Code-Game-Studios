## Story RS-002: phase machine and validation by phase (GDD AC-1, AC-6; test plan section 4).
extends GutTest

const Factory = preload("res://tests/support/run_state_factory.gd")

const S = Factory.State
## Log classes of the test plan: "A" accepted, "D" debug, "W" warning.
const DEBUG_LEVEL: int = LogLevel.DEBUG
const WARNING_LEVEL: int = LogLevel.WARNING

## Phase reached by each accepted request.
const _RESULT_PHASE: Dictionary = {
	"map_ready": RunStateCore.Phase.MENU,
	"start": RunStateCore.Phase.RUNNING,
	"hit": RunStateCore.Phase.HIT,
	"pause": RunStateCore.Phase.PAUSED,
	"resume": RunStateCore.Phase.RESUMING,
	"restart": RunStateCore.Phase.RUNNING,
	"menu": RunStateCore.Phase.MENU,
}

## The 46 cases: [factory state, request, expected class, press mode ("" none, "inside", "after")].
const _ROWS: Array = [
	[S.BOOT, "map_ready", "A", ""], [S.BOOT, "start", "W", ""], [S.BOOT, "hit", "W", ""],
	[S.BOOT, "pause", "W", ""], [S.BOOT, "resume", "W", ""], [S.BOOT, "restart", "W", ""],
	[S.BOOT, "menu", "W", ""],
	[S.MENU, "map_ready", "W", ""], [S.MENU, "start", "A", ""], [S.MENU, "hit", "W", ""],
	[S.MENU, "pause", "W", ""], [S.MENU, "resume", "W", ""], [S.MENU, "restart", "W", ""],
	[S.MENU, "menu", "W", ""],
	[S.RUNNING, "map_ready", "W", ""], [S.RUNNING, "start", "W", ""], [S.RUNNING, "hit", "A", ""],
	[S.RUNNING, "pause", "A", ""], [S.RUNNING, "resume", "W", ""], [S.RUNNING, "restart", "D", ""],
	[S.RUNNING, "menu", "W", ""],
	[S.PAUSED_INSIDE, "map_ready", "W", ""], [S.PAUSED_INSIDE, "start", "W", ""],
	[S.PAUSED_INSIDE, "hit", "D", ""], [S.PAUSED_INSIDE, "pause", "D", ""],
	[S.PAUSED_INSIDE, "resume", "A", ""],
	[S.PAUSED_INSIDE, "restart", "D", "inside"], [S.PAUSED_INSIDE, "menu", "D", "inside"],
	[S.PAUSED_AFTER, "restart", "A", "after"], [S.PAUSED_AFTER, "menu", "A", "after"],
	[S.RESUMING, "map_ready", "W", ""], [S.RESUMING, "start", "W", ""], [S.RESUMING, "hit", "D", ""],
	[S.RESUMING, "pause", "A", ""], [S.RESUMING, "resume", "D", ""], [S.RESUMING, "restart", "W", ""],
	[S.RESUMING, "menu", "W", ""],
	[S.HIT_LOCKED, "map_ready", "W", ""], [S.HIT_LOCKED, "start", "W", ""], [S.HIT_LOCKED, "hit", "D", ""],
	[S.HIT_LOCKED, "pause", "W", ""], [S.HIT_LOCKED, "resume", "W", ""],
	[S.HIT_LOCKED, "restart", "D", "inside"], [S.HIT_LOCKED, "menu", "D", "inside"],
	[S.HIT_UNLOCKED, "restart", "A", "after"], [S.HIT_UNLOCKED, "menu", "A", "after"],
]


func _limit_us(rig: Factory, state: int) -> int:
	if state == S.HIT_LOCKED or state == S.HIT_UNLOCKED:
		return rig.config.restart_lock_us()
	return rig.config.pause_input_guard_us()


## Sends one matrix request (with its press stamp) and ticks once with a world step of 0, so that
## `run_time` of a Running core stays comparable.
func _drive_row(rig: Factory, state: int, request: String, mode: String) -> void:
	var press: int = 0
	if mode == "inside":
		rig.clock.now_us = rig.anchor_us + _limit_us(rig, state) - 1
		press = rig.clock.now_us
	elif mode == "after":
		press = rig.anchor_us + _limit_us(rig, state)
	rig.send(request, press)
	rig.core.tick(0.0, Factory.DT)


func test_matrix_has_46_cases_with_10_accepted_10_debug_26_warning() -> void:
	var counts: Dictionary = {"A": 0, "D": 0, "W": 0}
	for row: Array in _ROWS:
		counts[row[2]] += 1
	assert_eq(_ROWS.size(), 46)
	assert_eq(counts["A"], 10)
	assert_eq(counts["D"], 10)
	assert_eq(counts["W"], 26)


func test_acceptance_matrix_accepts_ten_pairs_and_rejects_36_with_no_trace() -> void:
	var accepted: int = 0
	var rejected: int = 0
	for row: Array in _ROWS:
		var state: int = row[0]
		var request: String = row[1]
		var expected: String = row[2]
		var mode: String = row[3]
		var label: String = "state %s, request %s, %s" % [S.keys()[state], request, mode]
		var rig: Factory = Factory.new()
		rig.core_in(state as Factory.State)
		var phase_before: int = rig.core.phase
		var id_before: int = rig.core.run_id
		var time_before: float = rig.core.run_time
		_drive_row(rig, state, request, mode)
		if expected == "A":
			accepted += 1
			assert_eq(rig.core.phase, _RESULT_PHASE[request], "accepted phase: " + label)
			assert_true(rig.recorder.events.size() > 0, "accepted emits: " + label)
			continue
		rejected += 1
		assert_eq(rig.core.phase, phase_before, "phase unchanged: " + label)
		assert_eq(rig.core.run_id, id_before, "run_id unchanged: " + label)
		assert_eq(rig.core.run_time, time_before, "run_time unchanged: " + label)
		assert_eq(rig.recorder.events.size(), 0, "no event incl. phase_changed: " + label)
		assert_eq(rig.logs.count(), 1, "exactly one log line: " + label)
		if rig.logs.count() == 1:
			var want: int = DEBUG_LEVEL if expected == "D" else WARNING_LEVEL
			assert_eq(rig.logs.level_at(0), want, "log level: " + label)
	assert_eq(accepted, 10)
	assert_eq(rejected, 36)


func test_lock_boundary_one_microsecond_before_is_rejected_at_limit_is_accepted() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(Factory.State.HIT_LOCKED)
	var limit: int = rig.config.restart_lock_us()
	rig.clock.now_us = rig.anchor_us + limit
	rig.send("restart", rig.anchor_us + limit - 1)
	rig.tick()
	assert_eq(rig.core.phase, RunStateCore.Phase.HIT, "press stamped one us early is rejected even when processed late")
	rig.send("restart", rig.anchor_us + limit)
	rig.tick()
	assert_eq(rig.core.phase, RunStateCore.Phase.RUNNING)


func test_guard_boundary_in_paused_applies_to_menu_the_same_way() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(Factory.State.PAUSED_INSIDE)
	var guard: int = rig.config.pause_input_guard_us()
	rig.clock.now_us = rig.anchor_us + guard
	rig.send("menu", rig.anchor_us + guard - 1)
	rig.tick()
	assert_eq(rig.core.phase, RunStateCore.Phase.PAUSED)
	rig.send("menu", rig.anchor_us + guard)
	rig.tick()
	assert_eq(rig.core.phase, RunStateCore.Phase.MENU)


func test_queued_request_has_no_effect_before_the_tick() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(Factory.State.MENU)
	rig.send("start")
	assert_eq(rig.core.phase, RunStateCore.Phase.MENU)
	assert_eq(rig.core.run_id, 0)
	assert_eq(rig.recorder.events.size(), 0)
	rig.tick()
	assert_eq(rig.core.phase, RunStateCore.Phase.RUNNING)


func test_clock_never_starts_at_zero() -> void:
	var rig: Factory = Factory.new()
	assert_eq(rig.clock.now_us, 1_000_000)


func test_run_id_is_zero_in_boot_and_in_menu_before_the_first_reset() -> void:
	var rig: Factory = Factory.new()
	assert_eq(rig.core.run_id, 0)
	rig.core_in(Factory.State.MENU)
	assert_eq(rig.core.run_id, 0)


func test_run_id_increments_only_on_run_reset_and_holds_through_pause_resume_abandon_hit_menu() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(Factory.State.MENU)
	rig.send("start")
	rig.tick()
	assert_eq(rig.core.run_id, 1, "start")
	rig.tick()
	rig.send("pause")
	rig.tick()
	assert_eq(rig.core.run_id, 1, "pause")
	rig.clock.advance_us(rig.config.pause_input_guard_us())
	rig.send("resume")
	rig.tick()
	assert_eq(rig.core.run_id, 1, "resume request")
	rig.clock.advance_us(rig.config.resume_countdown_us())
	rig.tick()
	assert_eq(rig.core.phase, RunStateCore.Phase.RUNNING)
	assert_eq(rig.core.run_id, 1, "resumed")
	rig.tick()
	rig.send("pause")
	rig.tick()
	rig.clock.advance_us(rig.config.pause_input_guard_us())
	rig.send("menu")
	rig.tick()
	assert_eq(rig.core.phase, RunStateCore.Phase.MENU)
	assert_eq(rig.core.run_id, 1, "abandon to menu holds the last id")
	rig.send("start")
	rig.tick()
	assert_eq(rig.core.run_id, 2, "second start")
	rig.tick()
	rig.tick()
	rig.send("hit")
	rig.tick()
	assert_eq(rig.core.run_id, 2, "hit")
	rig.clock.advance_us(rig.config.restart_lock_us())
	rig.send("menu")
	rig.tick()
	assert_eq(rig.core.phase, RunStateCore.Phase.MENU)
	assert_eq(rig.core.run_id, 2, "hit to menu")


func test_run_id_is_strictly_increasing_over_1000_restarts() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(Factory.State.RUNNING)
	var previous: int = rig.core.run_id
	var strictly: bool = true
	var exact: bool = true
	for cycle: int in 1000:
		rig.send("hit")
		rig.tick()
		rig.clock.advance_us(rig.config.restart_lock_us())
		rig.send("restart")
		rig.tick()
		if rig.core.run_id != previous + 1:
			exact = false
		if rig.core.run_id <= previous:
			strictly = false
		previous = rig.core.run_id
		rig.tick() # settling tick
		rig.tick() # live tick, so the next hit is accepted
	assert_true(strictly)
	assert_true(exact, "+1 on every restart")
	assert_eq(rig.core.run_id, 1001)


func test_double_tap_restart_increases_run_id_once() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(Factory.State.HIT_UNLOCKED)
	rig.send("restart")
	rig.send("restart")
	rig.tick()
	assert_eq(rig.core.run_id, 2)
	assert_eq(rig.recorder.names().count("run_reset"), 1)
	assert_eq(rig.logs.count(), 1, "the second tap is a repeated tap: one debug line")
	assert_eq(rig.logs.level_at(0), DEBUG_LEVEL)


func test_run_time_is_zero_after_reset_and_advances_only_in_running() -> void:
	var rig: Factory = Factory.new()
	rig.core_in(Factory.State.MENU)
	rig.core.tick(0.016, 0.016)
	assert_eq(rig.core.run_time, 0.0, "Menu")
	rig.send("start")
	rig.tick()
	assert_eq(rig.core.run_time, 0.0, "after reset")
	rig.core.tick(0.016, 0.016) # settling tick
	assert_eq(rig.core.run_time, 0.0, "settling")
	var dt_eff: float = rig.core.tick(0.016, 0.016)
	assert_almost_eq(dt_eff, 0.016, 1e-6)
	assert_almost_eq(rig.core.run_time, 0.016, 1e-6, "Running")
	rig.send("pause")
	rig.core.tick(0.016, 0.016)
	assert_almost_eq(rig.core.run_time, 0.016, 1e-6, "Paused")
	rig.core.tick(0.016, 0.016)
	assert_almost_eq(rig.core.run_time, 0.016, 1e-6, "Paused, later tick")
	rig.clock.advance_us(rig.config.pause_input_guard_us())
	rig.send("resume")
	rig.core.tick(0.016, 0.016)
	rig.core.tick(0.016, 0.016)
	assert_almost_eq(rig.core.run_time, 0.016, 1e-6, "Resuming")
	rig.clock.advance_us(rig.config.restart_lock_us() + rig.config.resume_countdown_us())
	rig.core.tick(0.016, 0.016)
	assert_eq(rig.core.phase, RunStateCore.Phase.RUNNING)
	rig.send("hit")
	rig.core.tick(0.016, 0.016) # settling tick after run_resumed: hit ignored
	rig.core.tick(0.016, 0.016)
	assert_almost_eq(rig.core.run_time, 0.032, 1e-6, "Running again continues where it stopped")
	rig.send("hit")
	rig.core.tick(0.016, 0.016)
	var frozen: float = rig.core.run_time
	rig.core.tick(0.016, 0.016)
	assert_eq(rig.core.run_time, frozen, "Hit")
	rig.clock.advance_us(rig.config.restart_lock_us())
	rig.send("restart")
	rig.core.tick(0.016, 0.016)
	assert_eq(rig.core.run_time, 0.0, "run_time resets on run_reset")
