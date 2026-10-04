## Story ML-004: Phase A validation sequence.
extends GutTest

const Fake = preload("res://tests/support/map_loader_fake_seams.gd")

var _fake: MapLoaderSeams
var _core: MapLoaderCore


func before_each() -> void:
	_fake = Fake.new()
	_core = MapLoaderCore.new(_fake, MapLoaderConfig.new())


func _run(def: Variant) -> PackedStringArray:
	_fake.definitions = [def]
	_core.attempt("res://x.tres")
	return _core.last_codes


func _assert_no_side_effects() -> void:
	assert_eq(_fake.seam_calls(), [] as Array[String])


func test_null_definition_gives_resource_missing() -> void:
	assert_eq(_run(null), PackedStringArray(["MAP_RESOURCE_MISSING"]))
	_assert_no_side_effects()


func test_wrong_type_gives_resource_type() -> void:
	assert_eq(_run(Resource.new()), PackedStringArray(["MAP_RESOURCE_TYPE"]))
	_assert_no_side_effects()


func test_null_env_gives_env_invalid_without_crash() -> void:
	var def: MapDefinition = Fake.valid_definition()
	def.env = null
	assert_eq(_run(def), PackedStringArray(["MAP_ENV_INVALID"]))


func test_fatal_env_gives_env_invalid() -> void:
	var def: MapDefinition = Fake.valid_definition()
	def.env.fog_end_distance = NAN
	assert_eq(_run(def), PackedStringArray(["MAP_ENV_INVALID"]))


func test_null_style_gives_style_invalid() -> void:
	var def: MapDefinition = Fake.valid_definition()
	def.hazard_style = null
	assert_eq(_run(def), PackedStringArray(["HAZARD_STYLE_INVALID"]))


func test_fatal_style_gives_style_invalid() -> void:
	var def: MapDefinition = Fake.valid_definition()
	var style: HazardStyle = def.hazard_style as HazardStyle
	style.shade_color = style.face_color
	assert_eq(_run(def), PackedStringArray(["HAZARD_STYLE_INVALID"]))


func test_null_library_gives_library_missing() -> void:
	var def: MapDefinition = Fake.valid_definition()
	def.chunk_library = null
	assert_eq(_run(def), PackedStringArray(["MAP_LIBRARY_MISSING"]))
	_assert_no_side_effects()


func test_nan_camera_gives_camera_invalid() -> void:
	_fake.camera = {"rear_extent": NAN, "camera_distance": 6.0, "visible_arc_half_width": 1.0, "L": 12.0}
	assert_eq(_run(Fake.valid_definition()), PackedStringArray(["MAP_CAMERA_INVALID"]))
	_assert_no_side_effects()


func test_tube_code_passes_through_unchanged() -> void:
	var def: MapDefinition = Fake.valid_definition()
	def.env.readable_distance = 90.0
	def.env.fog_end_distance = 84.0
	var codes: PackedStringArray = _run(def)
	assert_true(codes.has("FOG_BEFORE_READ"))
	assert_false(codes.has("MAP_CAMERA_INVALID"))
	_assert_no_side_effects()


func test_several_failures_return_whole_set_in_stable_order() -> void:
	for i: int in 3:
		var def: MapDefinition = Fake.valid_definition()
		def.env = null
		def.chunk_library = null
		def.hazard_style = null
		assert_eq(
			_run(def),
			PackedStringArray(["MAP_ENV_INVALID", "HAZARD_STYLE_INVALID", "MAP_LIBRARY_MISSING"])
		)


func test_valid_definition_passes_phase_a() -> void:
	_fake.definitions = [Fake.valid_definition()]
	assert_true(_core.attempt("p"))
