## Story TI-013: the TiltInput node (AC-28 [I], node interface, editor-only source, project.godot smoke check).
extends GutTest

const ClockStub = preload("res://tests/support/clock_stub.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")

const KEY_GRAVITY: String = "input_devices/sensors/enable_gravity"
const KEY_ORIENTATION: String = "display/window/handheld/orientation"

var _clock: ClockStub
var _sink: LogSink
var _config: TiltConfig
var _reads: Array[int] = []
var _gravity: Vector3 = Vector3(0.0, -9.81, 0.0)
var _saved_gravity: Variant
var _saved_orientation: Variant


func before_each() -> void:
	_clock = ClockStub.new(0)
	_sink = LogSink.new()
	_config = TiltConfig.new()
	_config.sensor_sign = 1
	_reads = [0]
	_gravity = Vector3(0.0, -9.81, 0.0)
	_saved_gravity = ProjectSettings.get_setting(KEY_GRAVITY, null)
	_saved_orientation = ProjectSettings.get_setting(KEY_ORIENTATION, null)


func after_each() -> void:
	ProjectSettings.set_setting(KEY_GRAVITY, _saved_gravity)
	ProjectSettings.set_setting(KEY_ORIENTATION, _saved_orientation)


func _source() -> Vector3:
	_reads[0] += 1
	return _gravity


func _node(is_debug: bool, is_editor: bool = false) -> TiltInput:
	var node: TiltInput = TiltInput.new()
	add_child_autofree(node)
	node.setup(_config, _clock.as_callable(), _sink.sink, 1.0, is_debug, is_editor, _source)
	return node


func _count(code: StringName) -> int:
	var n: int = 0
	for entry: Array in _sink.entries:
		if entry[1] == code:
			n += 1
	return n


func test_sensors_enabled_gives_acquiring_without_error_ac28() -> void:
	ProjectSettings.set_setting(KEY_GRAVITY, true)
	ProjectSettings.set_setting(KEY_ORIENTATION, 1)
	var node: TiltInput = _node(false)
	assert_eq(node.get_core().get_state(), TiltCore.State.ACQUIRING)
	assert_eq(_sink.count(), 0)
	assert_false(node.valid)


func test_sensors_disabled_debug_gives_live_fallback_with_one_error_ac28() -> void:
	ProjectSettings.set_setting(KEY_GRAVITY, false)
	var node: TiltInput = _node(true)
	assert_true(node.valid)
	assert_eq(node.input_source, TiltCore.InputSource.FALLBACK)
	assert_eq(_count(TiltCore.LOG_SENSORS_DISABLED), 1)


func test_sensors_disabled_release_gives_unavailable_with_one_error_ac28() -> void:
	ProjectSettings.set_setting(KEY_GRAVITY, false)
	var node: TiltInput = _node(false)
	assert_false(node.valid)
	assert_eq(node.get_core().get_state(), TiltCore.State.UNAVAILABLE)
	assert_eq(_count(TiltCore.LOG_SENSORS_DISABLED), 1)


func test_missing_sensor_setting_reads_as_disabled_ac28() -> void:
	ProjectSettings.set_setting(KEY_GRAVITY, null)
	var node: TiltInput = _node(false)
	assert_eq(node.get_core().get_state(), TiltCore.State.UNAVAILABLE)
	assert_eq(_count(TiltCore.LOG_SENSORS_DISABLED), 1)


func test_landscape_orientation_logs_one_diagnostic() -> void:
	ProjectSettings.set_setting(KEY_GRAVITY, true)
	ProjectSettings.set_setting(KEY_ORIENTATION, 0)
	_node(false)
	assert_eq(_count(TiltCore.LOG_NOT_PORTRAIT), 1)


func test_poll_reads_once_per_call_and_getters_match_the_core() -> void:
	ProjectSettings.set_setting(KEY_GRAVITY, true)
	ProjectSettings.set_setting(KEY_ORIENTATION, 1)
	var node: TiltInput = _node(false)
	var core: TiltCore = node.get_core()
	for i: int in 60:
		node.poll()
		_clock.advance_us(16667)
	assert_eq(_reads[0], 60)
	core.on_run_reset(TiltCore.PreviousPhase.MENU)
	var r: float = deg_to_rad(25.0)
	_gravity = Vector3(9.81 * sin(r), -9.81 * cos(r), 0.0)
	for i: int in 30:
		node.poll()
		_clock.advance_us(16667)
	assert_eq(_reads[0], 90)
	assert_gt(node.steer, 0.0)
	assert_eq(node.steer, core.get_steer())
	assert_eq(node.valid, core.get_valid())
	assert_eq(node.input_source, core.get_input_source())
	assert_eq(node.input_source, TiltCore.InputSource.SENSOR)


func test_poll_passes_the_raw_vector_unfiltered() -> void:
	ProjectSettings.set_setting(KEY_GRAVITY, true)
	ProjectSettings.set_setting(KEY_ORIENTATION, 1)
	_gravity = Vector3(0.0, 0.0, 0.0)
	var node: TiltInput = _node(false)
	node.poll()
	assert_eq(node.get_core().get_sample_count(), 0, "the core rejects a zero vector; the node did not touch it")
	assert_eq(_reads[0], 1)


func test_synthetic_gravity_gives_a_fixed_roll_per_direction() -> void:
	for sensor_sign: int in [1, -1]:
		assert_eq(TiltInput.synthetic_gravity(0, 20.0, sensor_sign), Vector3(0.0, -9.81, 0.0))
		assert_almost_eq(TiltMath.roll_deg(TiltInput.synthetic_gravity(1, 20.0, sensor_sign), sensor_sign), 20.0, 1e-4)
		assert_almost_eq(TiltMath.roll_deg(TiltInput.synthetic_gravity(-1, 20.0, sensor_sign), sensor_sign), -20.0, 1e-4)
		assert_almost_eq(TiltMath.roll_deg(TiltInput.synthetic_gravity(5, 20.0, sensor_sign), sensor_sign), 20.0, 1e-4)


func test_editor_source_replaces_the_injected_one_only_in_the_editor() -> void:
	ProjectSettings.set_setting(KEY_GRAVITY, true)
	ProjectSettings.set_setting(KEY_ORIENTATION, 1)
	var plain: TiltInput = _node(false, false)
	plain.poll()
	assert_eq(_reads[0], 1, "outside the editor the injected source is read")
	var editor: TiltInput = _node(false, true)
	editor.poll()
	assert_eq(_reads[0], 1, "in the editor the synthetic source replaces it")
	assert_eq(editor.get_core().get_sample_count(), 1, "no key held gives a valid level vector")
	assert_eq(editor.get_core().get_state(), TiltCore.State.LIVE)
	assert_eq(editor.input_source, TiltCore.InputSource.SENSOR)


func test_project_godot_carries_the_required_settings_smoke() -> void:
	assert_eq(int(ProjectSettings.get_setting(KEY_ORIENTATION, 0)), 1)
	assert_true(bool(ProjectSettings.get_setting(KEY_GRAVITY, false)))
	for flag: String in ["enable_accelerometer", "enable_gyroscope", "enable_magnetometer"]:
		assert_false(bool(ProjectSettings.get_setting("input_devices/sensors/" + flag, false)), flag)
	assert_true(InputMap.has_action(TiltInput.ACTION_LEFT))
	assert_true(InputMap.has_action(TiltInput.ACTION_RIGHT))
