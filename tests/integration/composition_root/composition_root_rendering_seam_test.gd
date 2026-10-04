## Story CR-008: the boot rendering-method check through an injected getter (ADR-0003 Decision 1, ADR-0002 Decision 4).
extends GutTest

const Fakes = preload("res://tests/support/rebase_fakes.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")
const GAME_ROOT_PATH: String = "res://src/core/game_root.gd"
const PROJECT_PATH: String = "res://project.godot"

var _root: GameRoot
var _sink: LogSink
var _starts: Array[int] = []
var _clocks: Array[int] = []


class StartSpy extends RefCounted:
	var starts: Array[int]

	func _init(counter: Array[int]) -> void:
		starts = counter

	func start() -> void:
		starts.append(1)


func before_each() -> void:
	_sink = LogSink.new()
	_starts.clear()
	_clocks.clear()


func after_each() -> void:
	if _root != null:
		_root.free()
		_root = null


func _make_root(method: Variant) -> GameRoot:
	var getter: Callable = func() -> Variant: return method
	var root: GameRoot = GameRoot.new(func() -> int:
		_clocks.append(1)
		return 0, getter)
	root.quit_on_fatal = false
	root.configure(_factory())
	return root


func _factory() -> Dictionary:
	var ball: BallConfig = BallConfig.new()
	ball.v_max = 22.0
	ball.ball_diameter = 0.7
	var factory: Dictionary = {
		&"tube_config": TubeConfig.new(), &"ball_config": ball, &"world_frame_config": WorldFrameConfig.new(),
		&"slot_count": 20, &"log_sink": _sink.sink,
	}
	for step: StringName in GameRoot.CONSTRUCTION_ORDER:
		if step == &"preflight":
			continue
		factory[step] = func() -> Object: return Fakes.Stub.new()
	factory[&"run_state"] = func() -> Object:
		return RunStateCore.new(RunConfig.new(), func() -> int: return 0, Callable())
	factory[&"core_systems"] = func() -> Dictionary:
		var out: Dictionary = {}
		for key: StringName in [&"tilt_input", &"tilt_adapter", &"ball", &"tube_track", &"tube_view", &"obstacle",
				&"near_miss", &"camera"]:
			out[key] = Fakes.Stub.new()
		return out
	factory[&"map_loader"] = func(_config: MapLoaderConfig) -> Object: return StartSpy.new(_starts)
	return factory


func test_mobile_getter_lets_boot_continue() -> void:
	_root = _make_root("mobile")
	add_child(_root)
	remove_child(_root)
	assert_eq(_root.construction_trace.back(), &"map_loader.start")
	assert_eq(_starts.size(), 1)
	assert_eq(_sink.count(), 0, "no log line on a good boot")


func test_other_methods_refuse_boot_with_one_error_and_no_loop() -> void:
	for method: String in ["forward_plus", "gl_compatibility", ""]:
		_sink.clear()
		_starts.clear()
		var root: GameRoot = _make_root(method)
		assert_eq(root._construct(), ERR_UNAVAILABLE, "refused: '%s'" % method)
		assert_push_error("boot refused")
		assert_eq(_sink.count(), 1)
		assert_eq(_sink.level_at(0), LogLevel.ERROR)
		assert_eq(_sink.code_at(0), GameRoot.CODE_RENDERING_METHOD_REFUSED)
		assert_eq(root.construction_trace.size(), 0, "no construction step ran")
		root.free()


func test_refused_boot_never_starts_the_loader_or_the_loop() -> void:
	_root = _make_root("forward_plus")
	add_child(_root)
	assert_push_error("boot refused")
	remove_child(_root)
	assert_eq(_starts.size(), 0)
	_root._process(0.016)
	assert_eq(_clocks.size(), 0, "the loop never ticked")


func test_invalid_or_non_string_getter_refuses() -> void:
	_root = GameRoot.new(Callable(), Callable())
	_root.rendering_method_getter = Callable()
	_root.quit_on_fatal = false
	_root.configure(_factory())
	assert_eq(_root._construct(), ERR_UNAVAILABLE)
	assert_push_error("boot refused")
	_root.rendering_method_getter = func() -> Variant: return 3
	assert_eq(_root._construct(), ERR_UNAVAILABLE)
	assert_push_error("boot refused")


func test_default_getter_is_the_production_binding() -> void:
	var root: GameRoot = GameRoot.new()
	assert_true(root.rendering_method_getter.is_valid())
	assert_eq(root.rendering_method_getter.get_method(), &"_engine_rendering_method")
	root.free()


func test_real_getter_smoke_headless_reports_mobile() -> void:
	# T-1 evidence: the headless driver returned "mobile".
	assert_eq(RenderingServer.get_current_rendering_method(), GameRoot.REQUIRED_RENDERING_METHOD)


func test_the_real_getter_is_bound_in_one_place_only() -> void:
	var text: String = FileAccess.get_file_as_string(GAME_ROOT_PATH)
	assert_eq(text.count("RenderingServer.get_current_rendering_method()"), 1, "one call, in the production binding")
	var checked: int = 0
	for path: String in ["res://src/core/run_state", "res://src/core/map_loader"]:
		for file: String in DirAccess.get_files_at(path):
			if file.ends_with(".gd"):
				checked += 1
				assert_false(FileAccess.get_file_as_string(path + "/" + file).contains("get_current_rendering_method"))
	assert_gt(checked, 0)


func test_project_settings_pin_the_renderer_keys() -> void:
	var text: String = FileAccess.get_file_as_string(PROJECT_PATH)
	assert_true(text.contains("[rendering]"))
	var section: String = text.split("[rendering]")[1].split("\n[")[0]
	for line: String in [
		'renderer/rendering_method="mobile"', 'renderer/rendering_method.mobile="mobile"',
		'rendering_device/fallback_to_opengl3=false', 'rendering_device/driver.windows="vulkan"',
	]:
		assert_true(section.contains(line), "project.godot has %s" % line)
