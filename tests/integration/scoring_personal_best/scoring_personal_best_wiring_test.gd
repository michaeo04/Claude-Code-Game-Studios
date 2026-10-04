## Story SPB-011: Composition Root builds Scoring, wires its rows, calls its step once per tick, refuses bad milestones.
## Also the source-text companions of SPB-009 AC-19 (no `static var` of its own class, no singleton registration).
extends GutTest

const Fakes = preload("res://tests/support/rebase_fakes.gd")
const WireSpy = preload("res://tests/support/wire_spy.gd")
const SystemSpy = preload("res://tests/support/system_spy.gd")
const Fixtures = preload("res://tests/support/scoring_fixtures.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")

var _log: Array[String] = []
var _rs: RunStateCore
var _root: GameRoot
var _sink: LogSink
var _built: Array[ScoreCore] = []


func before_each() -> void:
	_log.clear()
	_built.clear()
	_sink = LogSink.new()
	_rs = RunStateCore.new(RunConfig.new(), func() -> int: return 0, Callable())
	_root = GameRoot.new(Callable())
	_root.quit_on_fatal = false


func after_each() -> void:
	_root.free()


func _make_service() -> ScoreService:
	var s_stub: Fixtures.SStub = Fixtures.make_s_stub([])
	var save: Fixtures.SaveStub = Fixtures.make_save_stub(0)
	var service: ScoreService = ScoreService.new(Fixtures.make_core(s_stub, save), null)
	autofree(service)
	return service


func _factory(milestones: Array[int]) -> Dictionary:
	var tube: TubeConfig = TubeConfig.new()
	var frame_cfg: WorldFrameConfig = WorldFrameConfig.new()
	var ball: BallConfig = BallConfig.new()
	ball.v_max = 22.0
	ball.ball_diameter = 0.7
	var config: ScoringConfig = ScoringConfig.new()
	config.milestone_distances = milestones
	var factory: Dictionary = {
		&"tube_config": tube, &"ball_config": ball, &"world_frame_config": frame_cfg, &"slot_count": 20,
		&"scoring_config": config, &"log_sink": _sink.sink,
	}
	for step: StringName in GameRoot.CONSTRUCTION_ORDER:
		if step == &"preflight" or step == &"run_state" or step == &"core_systems" or step == &"scoring":
			continue
		factory[step] = func() -> Object: return Fakes.Stub.new()
	factory[&"run_state"] = func() -> Object: return _rs
	factory[&"scoring"] = func() -> Object:
		var s_stub: Fixtures.SStub = Fixtures.make_s_stub([])
		var save: Fixtures.SaveStub = Fixtures.make_save_stub(0)
		var core: ScoreCore = Fixtures.make_core(s_stub, save, config.milestone_distances)
		_built.append(core)
		return ScoreService.new(core, null)
	factory[&"core_systems"] = func() -> Dictionary:
		var out: Dictionary = {}
		for key: StringName in [&"tilt_input", &"tilt_adapter", &"ball", &"tube_track", &"tube_view", &"obstacle",
				&"near_miss", &"camera"]:
			out[key] = Fakes.Stub.new()
		return out
	return factory


func _inject_with(service: ScoreService, juice: WireSpy) -> void:
	var frame: WorldFrame = WorldFrame.new(WorldFrameConfig.new(), WorldGeometry.new())
	var view: Fakes.View = Fakes.View.new(frame, "v", _log)
	assert_true(_root.inject_systems(Fakes.systems(_rs, Fakes.Stub.new(), frame, view, view,
			{&"scoring": service, &"juice": juice})))


func test_construct_builds_scoring_after_save_and_settings_with_run_state() -> void:
	_root.configure(_factory([100, 250] as Array[int]))
	assert_eq(_root._construct(), OK)
	var trace: Array[StringName] = _root.construction_trace
	assert_lt(trace.find(&"save"), trace.find(&"scoring"))
	assert_lt(trace.find(&"settings"), trace.find(&"scoring"))
	assert_eq(trace.find(&"scoring") - trace.find(&"run_state"), 1, "built together with Run State")
	assert_lt(trace.find(&"scoring"), trace.find(&"environment_view"))
	assert_true(_root._scoring is ScoreService)
	assert_eq(_built.size(), 1)
	(_root._scoring as Node).free()


func test_wire_places_scoring_second_on_run_ended_and_run_abandoned() -> void:
	var service: ScoreService = _make_service()
	var juice: WireSpy = WireSpy.new("juice", _log)
	var hud: WireSpy = WireSpy.new("hud", _log)
	_inject_with(service, juice)
	_root.add_wire_row(_rs.run_ended, hud.on_run_ended, GameRoot.RANK_HUD)
	_root.add_wire_row(_rs.run_ended, juice.on_run_ended, GameRoot.RANK_JUICE)
	_root.add_wire_row(_rs.run_abandoned, juice.on_run_abandoned, GameRoot.RANK_JUICE)
	var by_signal: Dictionary = {}
	for row: Array in _root._build_rows():
		if (row[1] as Callable).get_object() == service:
			by_signal[(row[0] as Signal).get_name()] = row[2]
	assert_eq(by_signal[&"run_reset"], GameRoot.RANK_REST)
	assert_eq(by_signal[&"run_ended"], GameRoot.RANK_SCORING)
	assert_eq(by_signal[&"run_abandoned"], GameRoot.RANK_SCORING)
	assert_lt(GameRoot.RANK_JUICE, GameRoot.RANK_SCORING)
	assert_lt(GameRoot.RANK_SCORING, GameRoot.RANK_HUD)
	assert_eq(_root._wire(), OK)
	var core: ScoreCore = service.get_core()
	core.current_score = 9
	_rs.run_ended.emit(1, 2, 3)
	assert_eq(core.final_score, 9, "the Scoring row ran on run_ended")
	assert_eq(_log, ["juice.run_ended", "hud.run_ended"] as Array[String], "Juice before HUD")
	core.current_score = 11
	_rs.run_abandoned.emit(1, 3)
	assert_eq(core.final_score, 11, "the Scoring row ran on run_abandoned")
	_rs.run_reset.emit(2)
	assert_eq(core.current_score, 0, "the Scoring row ran on run_reset")


func test_wire_rejects_juice_ranked_after_scoring() -> void:
	var service: ScoreService = _make_service()
	var juice: WireSpy = WireSpy.new("juice", _log)
	_inject_with(service, juice)
	_root.add_wire_row(_rs.run_ended, juice.on_run_ended, GameRoot.RANK_HUD)
	assert_eq(_root._wire(), ERR_INVALID_DATA)
	assert_push_error(GameRoot.CODE_JUICE_AFTER_SCORING)


func test_tick_calls_scoring_step_once_after_ball_step_and_near_miss_step() -> void:
	var systems: Dictionary = {}
	for key: StringName in GameRoot.SYSTEM_KEYS:
		systems[key] = SystemSpy.new(String(key), _log)
	(systems[&"run_state"] as SystemSpy).phase = RunStateCore.Phase.MENU
	var s_calls: Array[int] = [0]
	var tick_log: Array[String] = _log
	var s_seam: Callable = func() -> float:
		s_calls[0] += 1
		tick_log.append("scoring.step")
		return 0.0
	var save: Fixtures.SaveStub = Fixtures.make_save_stub(0)
	var core: ScoreCore = ScoreCore.new(s_seam, save.get_value, save.set_value, [] as Array[int])
	var service: ScoreService = ScoreService.new(core, null)
	autofree(service)
	systems[&"scoring"] = service
	assert_true(_root.inject_systems(systems))
	_root._tick(0.016, 0.016)
	assert_eq(s_calls[0], 1, "one step per tick")
	var ball_at: int = _log.find("ball.step")
	var near_at: int = _log.find("near_miss.step")
	var score_at: int = _log.find("scoring.step")
	assert_true(ball_at >= 0 and near_at >= 0 and score_at >= 0, str(_log))
	assert_lt(ball_at, near_at)
	assert_lt(near_at, score_at)
	assert_false(service.has_method(&"_process"))


func test_milestone_preflight_refuses_descending_and_builds_empty_or_ascending() -> void:
	_root.configure(_factory([250, 100] as Array[int]))
	assert_eq(_root._construct(), ERR_INVALID_DATA)
	assert_push_error(String(GameRoot.CODE_SCORING_MILESTONES_INVALID))
	assert_eq(_built.size(), 0, "ScoreCore never built")
	assert_eq(_sink.code_at(0), GameRoot.CODE_SCORING_MILESTONES_INVALID)
	assert_eq(_sink.level_at(0), LogLevel.ERROR)
	assert_false(_root.construction_trace.has(&"scoring"))
	assert_eq(_root._connected.size(), 0, "nothing connected")
	var valid_sets: Array[Array] = [[], [100, 250]]
	for milestones: Array in valid_sets:
		var typed: Array[int] = []
		for m: Variant in milestones:
			typed.append(m as int)
		var root: GameRoot = GameRoot.new(Callable())
		root.quit_on_fatal = false
		root.configure(_factory(typed))
		assert_eq(root._construct(), OK, str(milestones))
		(root._scoring as Node).free()
		root.free()
	assert_eq(_built.size(), 2)


func test_scoring_sources_have_no_static_self_var_or_singleton_registration() -> void:
	for path: String in ["res://src/core/scoring_personal_best/score_service.gd",
			"res://src/core/scoring_personal_best/score_core.gd"]:
		var text: String = FileAccess.get_file_as_string(path)
		var own_class: String = "ScoreService" if path.ends_with("score_service.gd") else "ScoreCore"
		assert_false(text.contains("static var") and text.contains(": " + own_class), path)
		assert_false(text.contains("register_singleton"), path)
