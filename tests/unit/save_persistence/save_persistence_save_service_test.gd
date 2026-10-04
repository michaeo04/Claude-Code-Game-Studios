## Story SP-008: flush no-op and SaveService node wiring (AC-7, AC-18, AC-19).
extends GutTest

const FakeFs = preload("res://tests/support/fake_save_fs.gd")
const Fixture = preload("res://tests/support/save_fixture.gd")
const SinkStub = preload("res://tests/support/platform_log_sink.gd")
const CoreSpy = preload("res://tests/support/save_core_spy.gd")
const SignalStub = preload("res://tests/support/platform_signal_stub.gd")

var _fs: FakeFs
var _sink: SinkStub


func before_each() -> void:
	_fs = FakeFs.new()
	_sink = SinkStub.new()
	_fs.returns["size"] = 120


func _real_core() -> SaveCore:
	return SaveCore.new(
		_fs, func() -> float: return 0.0, func() -> int: return 0, _sink.sink, Fixture.make_save_fixture()
	)


func _spy() -> CoreSpy:
	return CoreSpy.new(
		_fs, func() -> float: return 0.0, func() -> int: return 0, _sink.sink, Fixture.make_save_fixture()
	)


func test_flush_with_nothing_pending_makes_zero_seam_calls() -> void:
	var core: SaveCore = _real_core()
	core.flush()
	assert_eq(_fs.calls.size(), 0)


func test_flush_after_failed_set_value_makes_no_further_call() -> void:
	var core: SaveCore = _real_core()
	_fs.returns["write_config"] = false
	core.set_value("settings", "tilt_sensitivity", 1.5)
	var before: int = _fs.calls.size()
	core.flush()
	assert_eq(_fs.calls.size(), before)


func test_flush_after_successful_set_value_makes_no_further_call() -> void:
	var core: SaveCore = _real_core()
	_fs.returns["write_config"] = true
	_fs.returns["rename"] = true
	core.set_value("settings", "tilt_sensitivity", 1.5)
	var before: int = _fs.calls.size()
	core.flush()
	assert_eq(_fs.calls.size(), before)


func test_app_backgrounded_flushes_once_and_other_signals_do_not() -> void:
	var spy: CoreSpy = _spy()
	var source: SignalStub = SignalStub.new()
	var service: SaveService = SaveService.new(spy, source)
	source.app_foregrounded.emit()
	source.app_interrupted.emit()
	source.app_returned.emit()
	assert_eq(spy.flush_count, 0)
	source.app_backgrounded.emit()
	assert_eq(spy.flush_count, 1)
	source.app_foregrounded.emit()
	source.app_interrupted.emit()
	source.app_returned.emit()
	assert_eq(spy.flush_count, 1)
	service.free()


func test_two_app_backgrounded_emissions_flush_twice() -> void:
	var spy: CoreSpy = _spy()
	var source: SignalStub = SignalStub.new()
	var service: SaveService = SaveService.new(spy, source)
	source.app_backgrounded.emit()
	source.app_backgrounded.emit()
	assert_eq(spy.flush_count, 2)
	service.free()


func test_construction_boot_loads_exactly_once_before_entering_the_tree() -> void:
	var spy: CoreSpy = _spy()
	var service: SaveService = SaveService.new(spy, SignalStub.new())
	assert_eq(spy.boot_count, 1, "loaded at construction, before any _ready")
	add_child_autofree(service)
	assert_eq(spy.boot_count, 1, "entering the tree does not load again")
	assert_same(service.get_core(), spy)


func test_clock_us_converts_to_float_seconds() -> void:
	assert_eq(SaveService.us_to_seconds(1_500_000), 1.5)
	assert_eq(SaveService.us_to_seconds(0), 0.0)
	assert_almost_eq(SaveService.us_to_seconds(1), 1e-6, 1e-12)
