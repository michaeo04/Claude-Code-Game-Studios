## Story ML-007: the shipped map_01.tres round trip (ADR-0004 Validation).
extends GutTest

const Fake = preload("res://tests/support/map_loader_fake_seams.gd")
const PATH: String = "res://assets/data/maps/map_01.tres"


func _load() -> MapDefinition:
	return ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as MapDefinition


func test_map_01_loads_with_expected_classes() -> void:
	var def: MapDefinition = _load()

	assert_not_null(def)
	assert_ne(String(def.map_id), "")
	assert_true(def.env is EnvConfig)
	assert_true(def.hazard_style is HazardStyle)
	assert_not_null(def.chunk_library)


func test_map_01_chunk_library_is_a_chunk_library() -> void:
	# MapDefinition.chunk_library is typed ChunkLibrary now that ADR-0008 exists.
	assert_true(_load().chunk_library is ChunkLibrary)


func test_map_01_env_values_match_environment_gdd() -> void:
	var env: EnvConfig = _load().env

	assert_eq(env.fog_depth_begin, 44.0)
	assert_eq(env.fog_end_distance, 84.0)
	assert_eq(env.fog_depth_curve, 1.0)
	assert_eq(env.fog_density, 1.0)
	assert_almost_eq(env.readable_distance, 46.22, 1e-6)
	assert_true(env.fog_color.is_equal_approx(Color.html("#E6EDF5")))
	assert_true(env.tube_color.is_equal_approx(Color.html("#A9BFB0")))
	assert_true(env.sky_top_color.is_equal_approx(Color.html("#C4D2E6")))
	assert_true(env.sky_bottom_color.is_equal_approx(Color.html("#E6EDF5")))


func test_map_01_hazard_style_has_adr_0014_defaults() -> void:
	var style: HazardStyle = _load().hazard_style as HazardStyle

	assert_eq(style.height_d_wall, 1.0)
	assert_eq(style.height_d_double_gate, 1.0)
	assert_eq(style.height_d_near_ring, 1.0)
	assert_eq(style.height_d_spike, 1.6)
	assert_true(style.face_color.is_equal_approx(Color.html("#A0101A")))
	assert_true(style.shade_color.is_equal_approx(Color.html("#5C0A12")))


func test_map_01_passes_phase_a_with_real_configs() -> void:
	var fake: MapLoaderSeams = Fake.new()
	fake.definitions = [_load()]
	var core: MapLoaderCore = MapLoaderCore.new(fake, MapLoaderConfig.new())

	var ok: bool = core.attempt(PATH)

	assert_eq(core.last_codes, PackedStringArray())
	assert_true(ok)


func test_map_01_file_has_no_camera_keys() -> void:
	var text: String = FileAccess.get_file_as_string(PATH)

	assert_false(text.contains("rear_extent"))
	assert_false(text.contains("camera_distance"))
	assert_false(text.contains("visible_arc_half_width"))
