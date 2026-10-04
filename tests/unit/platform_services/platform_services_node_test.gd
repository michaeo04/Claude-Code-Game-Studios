## Story PS-008: PlatformServices node mapping, boot and thread rule (AC-19, AC-20, ADR-0006 PS-12 test half).
extends GutTest

const LogSink = preload("res://tests/support/platform_log_sink.gd")
const Spy = preload("res://tests/support/platform_core_spy.gd")

var _spy: Spy
var _node: PlatformServices
var _keep_on_calls: Array[bool] = []
var _reads: Array[String] = []
var _caller: Array[int] = [1]
var _settings: Dictionary = {}
var _sink: LogSink = LogSink.new()


func before_each() -> void:
	_spy = Spy.new()
	_keep_on_calls.clear()
	_reads.clear()
	_caller[0] = 1
	_settings = _good_settings()
	_node = PlatformServices.new()
	_node.configure(_spy, _keep_on, _read, _caller_id, _main_id, _sink.sink)


func after_each() -> void:
	if is_instance_valid(_node):
		if _node.is_inside_tree():
			remove_child(_node)
		_node.free()


func test_each_notification_calls_exactly_its_core_method() -> void:
	add_child(_node)
	var table: Array = [
		[Node.NOTIFICATION_APPLICATION_FOCUS_OUT, "on_focus_out"],
		[Node.NOTIFICATION_APPLICATION_FOCUS_IN, "on_focus_in"],
		[Node.NOTIFICATION_APPLICATION_PAUSED, "on_paused"],
		[Node.NOTIFICATION_APPLICATION_RESUMED, "on_resumed"],
		[Node.NOTIFICATION_WM_GO_BACK_REQUEST, "on_back_requested"],
	]
	for row: Array in table:
		_spy.calls.clear()
		_node._notification(row[0])
		assert_eq(_spy.calls, [row[1]] as Array[String], "notification %d" % row[0])


func test_fis_for_platform_is_true_only_for_android() -> void:
	assert_true(PlatformMath.fis_for_platform("Android"))
	for os_name: String in ["Windows", "macOS", "Linux", "Web", ""]:
		assert_false(PlatformMath.fis_for_platform(os_name), os_name)


func test_boot_keeps_screen_on_once_and_checks_the_manifest_with_the_injected_reader() -> void:
	add_child(_node)
	assert_eq(_keep_on_calls, [true] as Array[bool])
	assert_eq(_node.boot_mismatches(), [] as Array[String])
	assert_gt(_reads.size(), 0, "the injected reader was used")
	assert_false(get_tree().quit_on_go_back, "quit_on_go_back is false")


func test_boot_wrong_setting_is_reported_and_not_repaired() -> void:
	_settings["application/run/max_fps"] = 30
	add_child(_node)
	assert_eq(_node.boot_mismatches(), ["application/run/max_fps"] as Array[String])
	assert_eq(_settings["application/run/max_fps"], 30)
	assert_eq(_sink.count_code(RateLimitedLog.SETTINGS_MISMATCH), 1)
	assert_eq(_keep_on_calls, [true] as Array[bool], "never keep_on(false)")


func test_main_thread_handler_calls_the_core_synchronously() -> void:
	add_child(_node)
	_node._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(_spy.calls, ["on_focus_out"] as Array[String])


func test_off_thread_handler_is_deferred() -> void:
	add_child(_node)
	_caller[0] = 2
	_node._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(_spy.calls.size(), 0, "not called synchronously")
	await get_tree().process_frame
	assert_eq(_spy.calls, ["on_focus_out"] as Array[String], "called after the deferred flush")


func _keep_on(enabled: bool) -> void:
	_keep_on_calls.append(enabled)


func _read(key: String, default: Variant) -> Variant:
	_reads.append(key)
	return _settings.get(key, default)


func _caller_id() -> int:
	return _caller[0]


func _main_id() -> int:
	return 1


func _good_settings() -> Dictionary:
	var out: Dictionary = {}
	for e: Dictionary in PlatformSettings.manifest():
		if e["runtime"]:
			out[e["key"]] = e["expected"]
	return out
