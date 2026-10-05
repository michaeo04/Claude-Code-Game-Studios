## Story SA-011 (AC-19): a real `SaveCore` over the real `ConfigFile` fs (per-test directory under user://) bound to
## `SettingsCore` through the real `get_value` / `set_value` seams round-trips every setting across a cold restart.
extends GutTest

const Fixture = preload("res://tests/support/save_fixture.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")
const Fx = preload("res://tests/support/settings_fixtures.gd")

var _dir: String = ""
var _sink: LogSink
var _settings_logs: Fx.LogSpy


class Session:
	extends RefCounted
	var save: SaveCore
	var settings: SettingsCore


func before_each() -> void:
	_dir = "user://sa011_test_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_dir)
	_sink = LogSink.new()
	_settings_logs = Fx.make_log_spy()


func after_each() -> void:
	var access: DirAccess = DirAccess.open(_dir)
	if access != null:
		for file_name: String in access.get_files():
			DirAccess.remove_absolute(_dir + "/" + file_name)
	DirAccess.remove_absolute(_dir)


func _boot(dir: String) -> Session:
	var session: Session = Session.new()
	var fs: SaveService.RealSaveFs = SaveService.RealSaveFs.new(dir)
	session.save = SaveCore.new(fs, func() -> float: return 0.0, func() -> int: return 100, _sink.sink,
			Fixture.make_save_fixture())
	session.save.boot_load()
	session.settings = SettingsCore.new(session.save.get_value, session.save.set_value, _settings_logs.record)
	return session


func test_all_five_settings_round_trip_a_cold_restart() -> void:
	var first: Session = _boot(_dir)
	assert_true(first.settings.set_value("haptics_enabled", false))
	assert_true(first.settings.set_value("haptics_intensity", 0.5))
	assert_true(first.settings.set_value("tilt_sensitivity", 1.5))
	assert_true(first.settings.set_value("reduced_motion_enabled", true))
	assert_true(first.settings.set_value("colorblind_safe_enabled", true))
	var second: Session = _boot(_dir)
	assert_eq(second.settings.get_haptics_enabled(), false)
	assert_almost_eq(second.settings.get_haptics_intensity(), 0.5, 1e-6)
	assert_almost_eq(second.settings.get_tilt_sensitivity(), 1.5, 1e-6)
	assert_eq(second.settings.get_reduced_motion_enabled(), true)
	assert_eq(second.settings.get_colorblind_safe_enabled(), true)
	assert_eq(second.settings.get_seam_contrast_scale(), 0.0)
	for entry: Array in _sink.entries:
		assert_ne(entry[1], &"TYPE_MISMATCH", "floats must round-trip as floats")


func test_deleted_file_between_sessions_returns_the_five_defaults() -> void:
	var first: Session = _boot(_dir)
	first.settings.set_value("tilt_sensitivity", 1.5)
	first.settings.set_value("haptics_enabled", false)
	var access: DirAccess = DirAccess.open(_dir)
	for file_name: String in access.get_files():
		DirAccess.remove_absolute(_dir + "/" + file_name)
	var second: Session = _boot(_dir)
	assert_eq(second.settings.get_haptics_enabled(), true)
	assert_almost_eq(second.settings.get_haptics_intensity(), 1.0, 1e-6)
	assert_almost_eq(second.settings.get_tilt_sensitivity(), 1.0, 1e-6)
	assert_eq(second.settings.get_reduced_motion_enabled(), false)
	assert_eq(second.settings.get_colorblind_safe_enabled(), false)


func test_failed_write_keeps_value_this_session_and_loses_it_on_restart() -> void:
	var missing_dir: String = _dir + "/does_not_exist"
	var first: Session = _boot(missing_dir)
	assert_true(first.settings.set_value("tilt_sensitivity", 1.5))
	assert_almost_eq(first.settings.get_tilt_sensitivity(), 1.5, 1e-6)
	var codes: Array[StringName] = []
	for entry: Array in _sink.entries:
		codes.append(entry[1] as StringName)
	assert_true(codes.has(&"WRITE_FAILED"), "the failed write is logged by Save")
	var second: Session = _boot(missing_dir)
	assert_almost_eq(second.settings.get_tilt_sensitivity(), 1.0, 1e-6)
