## Story CRF-006: construction order, the WorldGeometry/WorldFrame preflight and strong references (ADR-0002 Decision 5).
extends GutTest

const Fakes = preload("res://tests/support/rebase_fakes.gd")
const RecorderScript = preload("res://tests/support/run_state_recorder.gd")

var _spy_log: Array[String] = []
var _events: Array[Array] = []
var _refs: Dictionary = {}
var _geometry_ok_at_view: Array[bool] = []
var _root: GameRoot
var _starts: Array[int] = []


func before_each() -> void:
	_spy_log.clear()
	_events.clear()
	_refs.clear()
	_geometry_ok_at_view.clear()
	_starts.clear()
	_root = GameRoot.new(Callable())
	_root.quit_on_fatal = false


func after_each() -> void:
	_root.free()


func _build(step: String) -> Object:
	_spy_log.append(step)
	if GameRoot.VIEW_STEPS.has(StringName(step)):
		_geometry_ok_at_view.append(_root.geometry_validated)
	var obj: Object = Fakes.Stub.new()
	_refs[step] = weakref(obj)
	return obj


func _factory(frame_segments: int = 84, segment_length: float = 12.0) -> Dictionary:
	var tube: TubeConfig = TubeConfig.new()
	tube.segment_length = segment_length
	var frame_cfg: WorldFrameConfig = WorldFrameConfig.new()
	frame_cfg.rebase_segments = frame_segments
	var ball: BallConfig = BallConfig.new()
	ball.v_max = 22.0
	ball.ball_diameter = 0.7
	var factory: Dictionary = {
		&"tube_config": tube, &"ball_config": ball, &"world_frame_config": frame_cfg, &"slot_count": 20,
	}
	for step: StringName in GameRoot.CONSTRUCTION_ORDER:
		if step == &"preflight" or step == &"run_state" or step == &"core_systems":
			continue
		factory[step] = func() -> Object: return _build(String(step))
	factory[&"run_state"] = func() -> Object:
		_spy_log.append("run_state")
		var core: RunStateCore = RunStateCore.new(RunConfig.new(), func() -> int: return 0, Callable())
		RecorderScript.new(core, _events)
		_refs["run_state"] = weakref(core)
		return core
	factory[&"core_systems"] = func() -> Dictionary:
		_spy_log.append("core_systems")
		var out: Dictionary = {}
		for key: StringName in [&"tilt_input", &"tilt_adapter", &"ball", &"tube_track", &"tube_view", &"obstacle",
				&"near_miss", &"camera"]:
			out[key] = Fakes.Stub.new()
		_refs["core_systems"] = weakref(out[&"ball"] as Object)
		return out
	factory[&"map_loader"] = func(config: MapLoaderConfig) -> Object:
		_spy_log.append("map_loader")
		return MapLoaderSpy.new(_starts, config)
	return factory


class MapLoaderSpy extends RefCounted:
	var config: MapLoaderConfig
	var _starts: Array[int]

	func _init(starts: Array[int], map_config: MapLoaderConfig) -> void:
		_starts = starts
		config = map_config

	func start() -> void:
		_starts.append(1)


func test_construct_order_equals_decision_5_list_and_preflight_precedes_views() -> void:
	_root.configure(_factory())
	assert_eq(_root._construct(), OK)
	assert_eq(_root.construction_trace, GameRoot.CONSTRUCTION_ORDER, "each step finished in order")
	var expected: Array[String] = ["platform", "save", "settings", "run_state", "scoring", "core_systems",
			"environment_view", "world_chroma", "ball_view", "hazard_view", "environment", "juice", "hud", "menus"]
	assert_eq(_spy_log, expected, "factory calls, preflight is run by GameRoot between scoring and core_systems")
	assert_eq(_geometry_ok_at_view.size(), GameRoot.VIEW_STEPS.size())
	assert_false(_geometry_ok_at_view.has(false), "geometry was validated before every view was built")
	assert_lt(GameRoot.CONSTRUCTION_ORDER.find(&"preflight"), GameRoot.CONSTRUCTION_ORDER.find(&"environment_view"))


func test_construct_emits_no_signal_after_run_state_exists() -> void:
	_root.configure(_factory())
	assert_eq(_root._construct(), OK)
	assert_eq(_events.size(), 0, "nothing emitted by the rest of construction (core construction itself: run_state_core_shape_test)")
	assert_eq((_root._run_state as RunStateCore).phase, RunStateCore.Phase.BOOT)


func test_construct_budget_failure_is_fatal_and_builds_no_view() -> void:
	_root.configure(_factory(128, 24.0))
	assert_eq(_root._construct(), ERR_INVALID_DATA)
	assert_push_error("REBASE_Z_EXCEEDS_BUDGET")
	assert_false(_root.geometry_validated)
	for step: String in _spy_log:
		assert_false(GameRoot.VIEW_STEPS.has(StringName(step)), "no view built: %s" % step)
	assert_false(_spy_log.has("core_systems"), "boot stopped at the preflight")


func test_construct_overrides_map_loader_config_from_the_ball_config() -> void:
	_root.configure(_factory())
	assert_eq(_root._construct(), OK)
	assert_eq(_root.map_loader_config.v_max, 22.0)
	assert_almost_eq(_root.map_loader_config.ball_diameter, 0.7, 1e-6)


func test_construct_game_root_holds_every_core_strongly() -> void:
	_root.configure(_factory())
	assert_eq(_root._construct(), OK)
	_root._factory = {}
	await get_tree().process_frame
	for key: String in _refs.keys():
		var ref: WeakRef = _refs[key] as WeakRef
		assert_not_null(ref.get_ref(), "%s is still alive" % key)
		assert_true(is_instance_valid(ref.get_ref() as Object))
	assert_not_null(_root._world_frame)


func test_ready_runs_construct_then_wire_then_map_loader_start() -> void:
	_root.configure(_factory())
	add_child(_root)
	assert_eq(_root.construction_trace.slice(-3), [&"wire", &"map_loader", &"map_loader.start"] as Array[StringName])
	assert_eq(_root.construction_trace.find(&"menus") < _root.construction_trace.find(&"wire"), true)
	assert_eq(_starts.size(), 1)
	assert_eq(_spy_log.back(), "map_loader")
	remove_child(_root)
