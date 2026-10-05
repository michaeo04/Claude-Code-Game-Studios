## Story SA-012 (AC-20 and GDD Core Rules 6 and 8): `GameRoot` builds Platform, Save, Settings in order, pushes the
## haptics values once before Run State exists, and live consumers (fakes written against the published getters)
## see every runtime change. Tube Track, Tilt and Environment consumers are fakes: see
## production/qa/evidence/settings-accessibility-consumers.md for the pending real-consumer rows.
extends GutTest

const Fakes = preload("res://tests/support/rebase_fakes.gd")
const Fx = preload("res://tests/support/settings_fixtures.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")


## Platform fake: records the order of construction and every haptics setter call.
class FakePlatform:
	extends RefCounted
	var calls: Array[Array] = []
	var run_state_built: Array[bool] = [false]
	var built_before_run_state: Array[bool] = []

	func set_haptics_enabled(enabled: bool) -> void:
		calls.append([&"enabled", enabled])
		built_before_run_state.append(not run_state_built[0])

	func set_haptics_intensity(intensity: float) -> void:
		calls.append([&"intensity", intensity])
		built_before_run_state.append(not run_state_built[0])


## Tube Track fake: pulls the seam scale every frame and writes its "material" only on change.
class FakeTubeTrack:
	extends RefCounted
	var settings: SettingsCore
	var material_scale: float = -1.0
	var material_writes: int = 0

	func frame() -> void:
		var scale_now: float = settings.get_seam_contrast_scale()
		if scale_now != material_scale:
			material_scale = scale_now
			material_writes += 1


## Environment fake: reads `colorblind_safe_enabled` at map load, then follows `setting_changed`.
class FakeEnvironment:
	extends RefCounted
	var palette_safe: bool = false

	func load_map(settings: SettingsCore) -> void:
		palette_safe = settings.get_colorblind_safe_enabled()

	func on_setting_changed(key: String, value: Variant) -> void:
		if key == "colorblind_safe_enabled":
			palette_safe = value as bool


var _root: GameRoot
var _platform: FakePlatform
var _getter: Fx.Spy
var _setter: Fx.Spy
var _logs: Fx.LogSpy
var _sink: LogSink
var _rs: RunStateCore
var _settings: SettingsCore
var _trace: Array[StringName] = []


func before_each() -> void:
	_sink = LogSink.new()
	_logs = Fx.make_log_spy()
	_platform = FakePlatform.new()
	_trace = []
	_settings = null
	_rs = RunStateCore.new(RunConfig.new(), func() -> int: return 0, Callable())
	_root = GameRoot.new(Callable(), func() -> String: return "mobile")
	_root.quit_on_fatal = false


func after_each() -> void:
	_root.free()


func _factory(stored: Dictionary) -> Dictionary:
	_getter = Fx.make_get_value_stub(stored)
	_setter = Fx.make_set_value_stub()
	var factory: Dictionary = {
		&"tube_config": TubeConfig.new(), &"ball_config": _ball_config(), &"world_frame_config": WorldFrameConfig.new(),
		&"slot_count": 20, &"log_sink": _sink.sink,
	}
	for step: StringName in GameRoot.CONSTRUCTION_ORDER:
		if step == &"preflight":
			continue
		factory[step] = func() -> Object:
			_trace.append(step)
			return Fakes.Stub.new()
	factory[&"platform"] = func() -> Object:
		_trace.append(&"platform")
		return _platform
	factory[&"settings"] = func() -> Object:
		_trace.append(&"settings")
		_settings = SettingsCore.new(_getter.get_value, _setter.set_value, _logs.record)
		return _settings
	factory[&"run_state"] = func() -> Object:
		_trace.append(&"run_state")
		_platform.run_state_built[0] = true
		return _rs
	factory[&"core_systems"] = func() -> Dictionary:
		var out: Dictionary = {}
		for key: StringName in [&"tilt_input", &"tilt_adapter", &"ball", &"tube_track", &"tube_view", &"obstacle",
				&"near_miss", &"camera"]:
			out[key] = Fakes.Stub.new()
		return out
	return factory


func _ball_config() -> BallConfig:
	var ball: BallConfig = BallConfig.new()
	ball.v_max = 22.0
	ball.ball_diameter = 0.7
	return ball


func _compose(stored: Dictionary) -> void:
	_root.configure(_factory(stored))
	assert_eq(_root._construct(), OK)
	assert_eq(_root._wire(), OK)


func test_construction_order_is_platform_save_settings_then_haptics_pushed_once_before_run_state() -> void:
	_root.configure(_factory({}))
	assert_eq(_root._construct(), OK)
	var trace: Array[StringName] = _root.construction_trace
	assert_eq(trace.find(&"platform"), 0)
	assert_eq(trace.find(&"save"), 1)
	assert_eq(trace.find(&"settings"), 2)
	assert_eq(_platform.calls, [[&"enabled", true], [&"intensity", 1.0]] as Array[Array], "pushed once, boot values")
	assert_eq(_platform.built_before_run_state, [true, true] as Array[bool], "before Run State exists")


func test_stored_haptics_values_are_pushed_at_construction() -> void:
	_root.configure(_factory({"haptics_enabled": false, "haptics_intensity": 0.4}))
	assert_eq(_root._construct(), OK)
	assert_eq(_platform.calls[0], [&"enabled", false])
	assert_almost_eq(_platform.calls[1][1] as float, 0.4, 1e-6)


func test_haptics_change_reaches_platform_live_after_wire() -> void:
	_compose({})
	_platform.calls.clear()
	_settings.set_value("haptics_enabled", false)
	_settings.set_value("haptics_intensity", 0.5)
	assert_eq(_platform.calls.size(), 2)
	assert_eq(_platform.calls[0], [&"enabled", false])
	assert_almost_eq(_platform.calls[1][1] as float, 0.5, 1e-6)
	assert_eq(_settings.get_haptics_enabled(), false, "Platform consumer reading the getter agrees")


func test_unwire_removes_the_haptics_connection() -> void:
	_compose({})
	_root.unwire()
	_platform.calls.clear()
	_settings.set_value("haptics_enabled", false)
	assert_eq(_platform.calls.size(), 0)


func test_tilt_sensitivity_change_is_read_live_under_its_own_name() -> void:
	_compose({})
	var sensitivity: Array[float] = [_settings.get_tilt_sensitivity()]
	assert_almost_eq(sensitivity[0], 1.0, 1e-6)
	_settings.set_value("tilt_sensitivity", 1.5)
	sensitivity[0] = _settings.get_tilt_sensitivity()
	assert_almost_eq(sensitivity[0], 1.5, 1e-6)


func test_stored_reduced_motion_gives_seam_scale_zero_on_the_first_frame() -> void:
	_compose({"reduced_motion_enabled": true})
	var track: FakeTubeTrack = FakeTubeTrack.new()
	track.settings = _settings
	track.frame()
	assert_eq(track.material_scale, 0.0)
	assert_eq(track.material_writes, 1)


func test_runtime_reduced_motion_change_updates_tube_track_without_the_signal() -> void:
	_compose({})
	var track: FakeTubeTrack = FakeTubeTrack.new()
	track.settings = _settings
	track.frame()
	track.frame()
	assert_eq(track.material_scale, 1.0)
	assert_eq(track.material_writes, 1, "written only on change")
	_settings.set_value("reduced_motion_enabled", true)
	track.frame()
	assert_eq(track.material_scale, 0.0)
	assert_eq(track.material_writes, 2)
	_settings.set_value("reduced_motion_enabled", false)
	track.frame()
	assert_eq(track.material_scale, 1.0)


func test_environment_reads_getter_at_load_and_follows_runtime_change() -> void:
	_compose({"colorblind_safe_enabled": true})
	var env: FakeEnvironment = FakeEnvironment.new()
	_settings.setting_changed.connect(env.on_setting_changed)
	env.load_map(_settings)
	assert_true(env.palette_safe, "getter at load covers a signal that was missed before wiring")
	_settings.set_value("colorblind_safe_enabled", false)
	assert_false(env.palette_safe)
	assert_eq(_settings.get_colorblind_safe_enabled(), false)
