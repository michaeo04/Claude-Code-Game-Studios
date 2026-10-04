## Story ML-001: map types and loader seams.
extends GutTest

const CAMERA_NAMES: Array[String] = ["rear_extent", "camera_distance", "visible_arc_half_width"]


func _names_of(obj: Object) -> Array[String]:
	var out: Array[String] = []
	for prop: Dictionary in obj.get_property_list():
		out.append(prop["name"] as String)
	return out


func test_types_declared_defaults() -> void:
	var core: MapLoaderCore = MapLoaderCore.new(MapLoaderSeams.new(), MapLoaderConfig.new())
	assert_eq(core.status, MapLoaderCore.Status.NOT_LOADED)
	assert_eq(core.last_codes.size(), 0)
	var map: MapConfig = MapConfig.new()
	for field: String in ["map_id", "env", "chunk_library", "rear_extent", "camera_distance",
			"visible_arc_half_width", "hazard_style", "camera_far"]:
		assert_true(field in _names_of(map), field)
	assert_eq(MapLoaderCore.Status.keys(), ["NOT_LOADED", "READY", "FAILED"])
	assert_eq(MapLoaderConfig.new().log_window_us, RateLimitedLog.RATE_LIMIT_US)


func test_seams_defaults_are_failure_or_neutral() -> void:
	var seams: MapLoaderSeams = MapLoaderSeams.new()
	var map: MapConfig = MapConfig.new()
	assert_null(seams.load_definition("res://x.tres"))
	assert_eq(seams.camera_geometry().size(), 0)
	assert_false(seams.apply_env(map))
	assert_false(seams.apply_obstacle(map))
	assert_false(seams.apply_pattern(map))
	assert_false(seams.apply_hazard_view(map))
	assert_false(seams.tube_load(TubeConfig.new()))
	assert_not_null(seams.base_tube_config())
	seams.send_map_ready()
	seams.log_sink(LogLevel.INFO, &"X", "", "")
	pass_test("neutral calls return")


func test_definition_built_without_files() -> void:
	var def: MapDefinition = MapDefinition.new()
	def.map_id = &"map_01"
	def.env = EnvConfig.new()
	def.hazard_style = HazardStyle.new()
	assert_eq(def.map_id, &"map_01")
	assert_not_null(def.env)
	assert_null(def.chunk_library)
	assert_eq(def.env.fog_end_distance, 84.0)


func test_no_camera_fields_and_no_back_edge() -> void:
	var def_names: Array[String] = _names_of(MapDefinition.new())
	var env_names: Array[String] = _names_of(EnvConfig.new())
	for n: String in CAMERA_NAMES:
		assert_false(n in def_names, n)
		assert_false(n in env_names, n)
	for prop: Dictionary in EnvConfig.new().get_property_list():
		if (prop["type"] as int) == TYPE_OBJECT:
			var cls: String = prop["class_name"] as String
			assert_ne(cls, "MapDefinition")
			assert_ne(cls, "MapConfig")
