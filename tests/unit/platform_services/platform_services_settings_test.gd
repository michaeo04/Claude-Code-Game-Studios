## PlatformSettings manifest and mismatches() (platform-services story 007; GDD AC-11).
extends GutTest

const ClockStub = preload("res://tests/support/clock_stub.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")

const GRAVITY: String = "input_devices/sensors/enable_gravity"
const ORIENTATION: String = "display/window/handheld/orientation"
const MAX_FPS: String = "application/run/max_fps"
const QUIT: String = "application/config/quit_on_go_back"

var _values: Dictionary = {}


func _good() -> Dictionary:
	var d: Dictionary = {}
	for e: Dictionary in PlatformSettings.manifest():
		if e["runtime"]:
			d[e["key"]] = e["expected"]
	return d


func _read(key: String, default: Variant) -> Variant:
	return _values.get(key, default)


func _mismatches() -> Array[String]:
	return PlatformSettings.mismatches(PlatformSettings.manifest(), _read)


func test_all_correct_gives_none() -> void:
	_values = _good()
	assert_eq(_mismatches().size(), 0)


func test_one_wrong_key_gives_one_entry() -> void:
	_values = _good()
	_values[MAX_FPS] = 30
	assert_eq(_mismatches(), [MAX_FPS] as Array[String])


func test_n_wrong_keys_give_n_entries_with_key_as_detail() -> void:
	_values = _good()
	_values[ORIENTATION] = 0
	_values[MAX_FPS] = 120
	_values[QUIT] = true
	_values[GRAVITY] = false
	var bad: Array[String] = _mismatches()
	assert_eq(bad.size(), 4)
	assert_eq(bad[0], GRAVITY, "enable_gravity is reported first")
	assert_true(bad.has(ORIENTATION) and bad.has(MAX_FPS) and bad.has(QUIT))


func test_missing_key_is_a_mismatch() -> void:
	_values = _good()
	_values.erase(GRAVITY)
	assert_eq(_mismatches(), [GRAVITY] as Array[String])


func test_default_orientation_and_quit_true_are_flagged() -> void:
	_values = _good()
	_values[ORIENTATION] = 0
	_values[QUIT] = true
	assert_eq(_mismatches().size(), 2)


func test_preset_entries_are_excluded() -> void:
	_values = _good()
	var presets: int = 0
	for e: Dictionary in PlatformSettings.manifest():
		if not e["runtime"]:
			presets += 1
			assert_false(_values.has(e["key"]), "preset key not readable")
	assert_gt(presets, 0)
	assert_eq(_mismatches().size(), 0)


func test_manifest_never_lists_accelerometer_and_gravity_is_first() -> void:
	var m: Array[Dictionary] = PlatformSettings.manifest()
	assert_eq(m[0]["key"], GRAVITY)
	for e: Dictionary in m:
		assert_false((e["key"] as String).contains("accelerometer"))


func test_report_logs_one_error_per_key() -> void:
	_values = _good()
	_values[MAX_FPS] = 30
	_values[QUIT] = true
	var sink: LogSink = LogSink.new()
	var clock: ClockStub = ClockStub.new(0)
	var log: RateLimitedLog = RateLimitedLog.new(sink.sink, clock.as_callable())
	PlatformSettings.report(PlatformSettings.manifest(), _read, log)
	assert_eq(sink.count(), 2)
	assert_eq(sink.entries[0][0], LogLevel.ERROR)
	assert_eq(sink.entries[0][1], RateLimitedLog.SETTINGS_MISMATCH)
	assert_eq(sink.entries[0][2], MAX_FPS)
	assert_eq(sink.entries[1][2], QUIT)
