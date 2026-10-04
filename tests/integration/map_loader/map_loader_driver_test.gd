## Story ML-008: the real `MapLoader` driver against the file system (ADR-0004 Validation).
extends GutTest

const Fake = preload("res://tests/support/map_loader_fake_seams.gd")
const MAP_01: String = "res://assets/data/maps/map_01.tres"
const WRONG_TYPE: String = "res://tests/integration/map_loader/fixtures/wrong_type.tres"
const TEMP_PATH: String = "user://ml008_retry_fixture.tres"
const DRIVER_SOURCE: String = "res://src/core/map_loader/map_loader.gd"

var _fake: Fake
var _loader: MapLoader


func before_each() -> void:
	_fake = Fake.new()
	_loader = MapLoader.new(MapLoaderConfig.new(), _fake)


func after_each() -> void:
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))


func test_missing_path_gives_resource_missing() -> void:
	assert_false(_loader.attempt("res://nope.tres"))

	assert_eq(_loader.core.status, MapLoaderCore.Status.FAILED)
	assert_eq(_loader.core.last_codes, PackedStringArray(["MAP_RESOURCE_MISSING"]))
	assert_eq(_fake.seam_calls().size(), 0, "no Phase B step ran")


func test_wrong_type_resource_gives_resource_type() -> void:
	assert_false(_loader.attempt(WRONG_TYPE))

	assert_eq(_loader.core.last_codes, PackedStringArray(["MAP_RESOURCE_TYPE"]))


func test_map_01_loads_and_applies() -> void:
	assert_true(_loader.attempt(MAP_01))

	assert_eq(_loader.core.status, MapLoaderCore.Status.READY)
	assert_not_null(_fake.last_map)
	assert_not_null(_fake.last_map.env)
	assert_not_null(_fake.last_map.chunk_library)
	assert_eq(_fake.count("map_ready"), 1)


func test_start_uses_the_boot_config_path() -> void:
	var cfg: MapLoaderConfig = MapLoaderConfig.new()
	assert_eq(cfg.map_path, MAP_01)
	cfg.map_path = "res://nope.tres"
	var loader: MapLoader = MapLoader.new(cfg, _fake)

	assert_false(loader.start())
	assert_eq(loader.core.last_codes, PackedStringArray(["MAP_RESOURCE_MISSING"]))


func test_retry_rereads_a_file_rewritten_between_attempts() -> void:
	assert_eq(ResourceSaver.save(Resource.new(), TEMP_PATH), OK)
	assert_false(_loader.attempt(TEMP_PATH))
	assert_eq(_loader.core.last_codes, PackedStringArray(["MAP_RESOURCE_TYPE"]))
	assert_eq(ResourceSaver.save(Fake.valid_definition(), TEMP_PATH), OK)

	assert_true(_loader.retry(), "second result reflects the new content")
	assert_eq(_loader.core.status, MapLoaderCore.Status.READY)


func test_failure_signal_is_forwarded() -> void:
	var seen: Array[PackedStringArray] = []
	_loader.map_load_failed.connect(func(codes: PackedStringArray) -> void: seen.append(codes))

	_loader.attempt("res://nope.tres")

	assert_eq(seen.size(), 1)
	assert_eq(seen[0], PackedStringArray(["MAP_RESOURCE_MISSING"]))


func test_driver_source_has_no_threaded_or_direct_file_access() -> void:
	var text: String = FileAccess.get_file_as_string(DRIVER_SOURCE)

	assert_ne(text, "")
	for banned: String in ["load_threaded_request", "FileAccess", "DirAccess", "duplicate_deep"]:
		var code_lines: int = 0
		for line: String in text.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			if line.contains(banned):
				code_lines += 1
		assert_eq(code_lines, 0, "%s absent from code" % banned)
