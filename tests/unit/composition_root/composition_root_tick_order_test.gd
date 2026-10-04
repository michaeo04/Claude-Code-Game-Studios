## Story CR-002: fixed per-frame order in GameRoot._tick() (spy test).
extends GutTest

const Spy = preload("res://tests/support/system_spy.gd")
const P = RunStateCore.Phase

const FRONT: Array[String] = [
	"TiltInput.poll", "TiltRunAdapter.flush", "RunState.tick", "Ball.step",
]
const MIDDLE: Array[String] = [
	"Obstacle.step", "NearMiss.step", "Scoring.step",
]
const TAIL: Array[String] = [
	"Camera.step", "BallView.tick", "Environment.tick", "Juice.tick", "HUD.tick", "Menus.tick",
]
const ALL_PHASES: Array[int] = [P.RUNNING, P.MENU, P.PAUSED, P.HIT, P.RESUMING]

var _log: Array[String] = []
var _spies: Dictionary = {}
var _root: GameRoot


func before_each() -> void:
	_log = []
	_spies = {}
	var names: Dictionary = {
		&"tilt_input": "TiltInput", &"tilt_adapter": "TiltRunAdapter", &"run_state": "RunState",
		&"ball": "Ball", &"tube_track": "TubeTrack", &"world_frame": "WorldFrame",
		&"tube_view": "TubeView", &"hazard_view": "HazardView", &"obstacle": "Obstacle",
		&"near_miss": "NearMiss", &"scoring": "Scoring", &"camera": "Camera",
		&"ball_view": "BallView", &"environment": "Environment", &"juice": "Juice",
		&"hud": "HUD", &"menus": "Menus",
	}
	for key: StringName in names:
		_spies[key] = Spy.new(names[key] as String, _log)
	# Strict signatures of the real APIs (ADR-0002 Decision 6).
	(_spies[&"run_state"] as Object).call(&"set_signature", "tick", [TYPE_FLOAT, TYPE_FLOAT] as Array[int])
	(_spies[&"ball"] as Object).call(&"set_signature", "step",
			[TYPE_FLOAT, TYPE_FLOAT, TYPE_BOOL, TYPE_INT] as Array[int])
	_root = GameRoot.new()
	autofree(_root)
	assert_true(_root.inject_systems(_spies))


func _tick_in(phase: int, rebase: bool = false) -> Array[String]:
	(_spies[&"run_state"] as Object).set(&"phase", phase)
	(_spies[&"world_frame"] as Object).set(&"rebase_result", rebase)
	_log.clear()
	_root._tick(0.016, 0.016)
	return _log.duplicate()


func _expected(phase: int, rebase: bool = false) -> Array[String]:
	var out: Array[String] = FRONT.duplicate()
	if phase == P.RUNNING:
		out.append("TubeTrack.advance")
		out.append("WorldFrame.maybe_rebase")
		if rebase:
			out.append("TubeView.rebase")
			out.append("HazardView.rebase")
	out.append_array(MIDDLE)
	if phase == P.MENU:
		out.append("TubeView.idle_step")
	out.append_array(TAIL)
	return out


func test_running_tick_log_matches_adr_order_exactly() -> void:
	assert_eq(_tick_in(P.RUNNING), _expected(P.RUNNING))


func test_world_frame_step_between_advance_and_obstacle() -> void:
	var log: Array[String] = _tick_in(P.RUNNING)
	var adv: int = log.find("TubeTrack.advance")
	assert_eq(log.find("WorldFrame.maybe_rebase"), adv + 1)
	assert_eq(log.find("Obstacle.step"), adv + 2)


func test_ball_view_immediately_after_camera() -> void:
	for phase: int in ALL_PHASES:
		var log: Array[String] = _tick_in(phase)
		assert_eq(log.find("BallView.tick"), log.find("Camera.step") + 1)


func test_idle_step_only_in_menu() -> void:
	for phase: int in ALL_PHASES:
		assert_eq(_tick_in(phase).has("TubeView.idle_step"), phase == P.MENU, "phase %d" % phase)


func test_advance_and_rebase_only_when_running() -> void:
	for phase: int in [P.MENU, P.PAUSED, P.HIT, P.RESUMING]:
		var log: Array[String] = _tick_in(phase, true)
		assert_false(log.has("TubeTrack.advance"), "phase %d" % phase)
		assert_false(log.has("WorldFrame.maybe_rebase"), "phase %d" % phase)
		assert_false(log.has("TubeView.rebase"), "phase %d" % phase)
		assert_eq(log, _expected(phase, true))


func test_rebase_true_calls_tube_then_hazard_once() -> void:
	var log: Array[String] = _tick_in(P.RUNNING, true)
	assert_eq(log, _expected(P.RUNNING, true))
	assert_eq(log.count("TubeView.rebase"), 1)
	assert_eq(log.count("HazardView.rebase"), 1)
	assert_lt(log.find("TubeView.rebase"), log.find("HazardView.rebase"))
	assert_lt(log.find("HazardView.rebase"), log.find("Obstacle.step"))


func test_rebase_false_calls_neither() -> void:
	var log: Array[String] = _tick_in(P.RUNNING, false)
	assert_false(log.has("TubeView.rebase"))
	assert_false(log.has("HazardView.rebase"))


func test_tail_runs_last_in_every_phase() -> void:
	var tail: Array[String] = ["Juice.tick", "HUD.tick", "Menus.tick"]
	for phase: int in ALL_PHASES:
		var log: Array[String] = _tick_in(phase)
		assert_eq(log.slice(log.size() - 3), tail)


func test_missing_system_is_rejected() -> void:
	var partial: Dictionary = _spies.duplicate()
	partial.erase(&"hud")
	var root: GameRoot = GameRoot.new()
	autofree(root)
	assert_false(root.inject_systems(partial))
	assert_push_error("missing system")


func test_hundred_ticks_with_scripted_phases_are_deterministic() -> void:
	var phases: Array[int] = [P.MENU, P.RUNNING, P.RUNNING, P.PAUSED, P.RESUMING, P.RUNNING, P.HIT]
	var run_a: Array[String] = []
	var run_b: Array[String] = []
	for i: int in range(100):
		run_a.append_array(_tick_in(phases[i % phases.size()], i % 3 == 0))
	for i: int in range(100):
		run_b.append_array(_tick_in(phases[i % phases.size()], i % 3 == 0))
	assert_eq(run_a, run_b)
	assert_gt(run_a.size(), 1000)


func _all_errors() -> Array[String]:
	var out: Array[String] = []
	for key: StringName in _spies:
		out.append_array((_spies[key] as Object).get(&"errors") as Array[String])
	return out


func test_every_call_matches_the_strict_real_signatures() -> void:
	for phase: int in ALL_PHASES:
		_tick_in(phase, true)
	assert_eq(_all_errors(), [] as Array[String])


func test_ball_receives_dt_eff_and_tilt_outputs_not_world_dt() -> void:
	(_spies[&"run_state"] as Object).set(&"dt_eff_result", 0.0)
	(_spies[&"tilt_input"] as Object).set(&"steer_result", -0.25)
	(_spies[&"tilt_input"] as Object).set(&"valid_result", false)
	(_spies[&"tilt_input"] as Object).set(&"input_source_result", 1)
	for phase: int in [P.PAUSED, P.HIT, P.RESUMING, P.RUNNING]:
		_tick_in(phase)
		var args: Array = (_spies[&"ball"] as Object).get(&"last_args")["step"]
		assert_eq(args, [0.0, -0.25, false, 1] as Array, "phase %d" % phase)
	(_spies[&"run_state"] as Object).set(&"dt_eff_result", 0.0125)
	_tick_in(P.RUNNING)
	assert_eq(((_spies[&"ball"] as Object).get(&"last_args")["step"] as Array)[0], 0.0125)


func test_tube_track_and_world_frame_receive_ball_s_in_running_only() -> void:
	(_spies[&"ball"] as Object).set(&"s", 123.5)
	_tick_in(P.RUNNING)
	assert_eq(((_spies[&"tube_track"] as Object).get(&"last_args")["advance"] as Array), [123.5] as Array)
	assert_eq(((_spies[&"world_frame"] as Object).get(&"last_args")["maybe_rebase"] as Array), [123.5] as Array)


func test_strict_spy_records_a_wrong_call() -> void:
	var spy: RefCounted = Spy.new("X", _log)
	spy.call(&"advance", 1)
	spy.call(&"advance", 1.0, 2.0)
	assert_eq((spy.get(&"errors") as Array[String]).size(), 2)
