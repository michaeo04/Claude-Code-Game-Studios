## Story ML-006: failure reporting, map_load_failed and Retry.
extends GutTest

const Fake = preload("res://tests/support/map_loader_fake_seams.gd")

var _fake: MapLoaderSeams
var _core: MapLoaderCore
var _emitted: Array = []


func before_each() -> void:
	_fake = Fake.new()
	_core = MapLoaderCore.new(_fake, MapLoaderConfig.new())
	_emitted = []
	_core.map_load_failed.connect(_on_failed)


func _on_failed(codes: PackedStringArray) -> void:
	_emitted.append([codes, _core.status, _core.last_codes])


func test_failure_emits_once_with_final_state() -> void:
	_fake.definitions = [null]
	_core.attempt("p")
	assert_eq(_emitted.size(), 1)
	assert_eq(_emitted[0][0], PackedStringArray(["MAP_RESOURCE_MISSING"]))
	assert_eq(_emitted[0][1], MapLoaderCore.Status.FAILED)
	assert_eq(_emitted[0][2], PackedStringArray(["MAP_RESOURCE_MISSING"]))


func test_each_code_logged_per_attempt() -> void:
	var def: MapDefinition = Fake.valid_definition()
	def.env = null
	def.chunk_library = null
	_fake.definitions = [def]
	_core.attempt("p")
	_core.retry()
	var codes: Array[StringName] = []
	for line: Array in _fake.log_lines:
		codes.append(line[1] as StringName)
	assert_eq(codes, [&"MAP_ENV_INVALID", &"MAP_LIBRARY_MISSING", &"MAP_ENV_INVALID", &"MAP_LIBRARY_MISSING"] as Array[StringName])
	assert_eq(_fake.log_lines[0][0], LogLevel.ERROR)


func test_success_emits_nothing_and_clears_codes() -> void:
	_fake.definitions = [Fake.valid_definition()]
	assert_true(_core.attempt("p"))
	assert_eq(_emitted.size(), 0)
	assert_eq(_core.last_codes.size(), 0)


func test_retry_rereads_and_recovers() -> void:
	_fake.definitions = [null, Fake.valid_definition()]
	assert_false(_core.attempt("p"))
	assert_true(_core.retry())
	assert_eq(_fake.reads, 2)
	assert_eq(_core.status, MapLoaderCore.Status.READY)
	assert_eq(_fake.count("map_ready"), 1)
	assert_eq(_core.last_codes.size(), 0)


func test_retry_in_ready_is_noop_with_one_log_line() -> void:
	_fake.definitions = [Fake.valid_definition()]
	_core.attempt("p")
	var calls_before: int = _fake.calls.size()
	var lines_before: int = _fake.log_lines.size()
	assert_false(_core.retry())
	assert_eq(_fake.calls.size(), calls_before)
	assert_eq(_fake.log_lines.size(), lines_before + 1)
	assert_eq(_fake.log_lines[lines_before][1], &"RETRY_IGNORED_READY")
	assert_eq(_fake.log_lines[lines_before][0], LogLevel.INFO)
	assert_eq(_emitted.size(), 0)


func test_retry_in_not_loaded_acts_as_attempt() -> void:
	_fake.definitions = [Fake.valid_definition()]
	assert_true(_core.retry())
	assert_eq(_core.status, MapLoaderCore.Status.READY)
	assert_eq(_fake.reads, 1)


func test_reentrant_call_from_seam_is_rejected() -> void:
	_fake.definitions = [Fake.valid_definition()]
	var inner: Array = []
	_fake.on_env = func() -> void:
		inner.append(_core.retry())
		inner.append(_core.attempt("q"))
	assert_true(_core.attempt("p"))
	assert_eq(inner, [false, false])
	assert_eq(_fake.reads, 1)
	assert_eq(_fake.count("map_ready"), 1)


func test_repeated_retry_on_bad_data_emits_every_time() -> void:
	_fake.definitions = [null]
	_core.attempt("p")
	for i: int in 5:
		_core.retry()
	assert_eq(_emitted.size(), 6)
	for entry: Array in _emitted:
		assert_eq(entry[0], PackedStringArray(["MAP_RESOURCE_MISSING"]))
