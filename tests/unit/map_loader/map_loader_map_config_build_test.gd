## Story ML-003: MapConfig.build, camera values, camera_far; plus the real WorldGeometry.
extends GutTest


func _camera() -> Dictionary:
	return {"rear_extent": 5.5, "camera_distance": 7.84, "visible_arc_half_width": 1.2, "L": 12.0}


func _build(env: EnvConfig, camera: Dictionary, codes: Array[StringName], library: Resource = null) -> MapConfig:
	return MapConfig.build(&"map_01", env, library, HazardStyle.new(), camera, codes)


func test_build_copies_and_shares_library() -> void:
	var env: EnvConfig = EnvConfig.new()
	var library: Resource = Resource.new()
	var style: HazardStyle = HazardStyle.new()
	var codes: Array[StringName] = []
	var map: MapConfig = MapConfig.build(&"map_01", env, library, style, _camera(), codes)
	assert_eq(codes.size(), 0)
	assert_eq(map.map_id, &"map_01")
	assert_same(map.env, env)
	assert_same(map.chunk_library, library)
	assert_same(map.hazard_style, style)
	assert_eq(map.rear_extent, 5.5)
	assert_eq(map.camera_distance, 7.84)
	assert_eq(map.visible_arc_half_width, 1.2)


func test_camera_far_is_fog_end_plus_l() -> void:
	var codes: Array[StringName] = []
	assert_almost_eq(_build(EnvConfig.new(), _camera(), codes).camera_far, 96.0, 1e-6)
	var env: EnvConfig = EnvConfig.new()
	env.fog_end_distance = 60.0
	assert_almost_eq(_build(env, _camera(), codes).camera_far, 72.0, 1e-6)


func test_invalid_camera_geometry_gives_code() -> void:
	var bad: Array[Dictionary] = []
	var nan_cam: Dictionary = _camera()
	nan_cam["camera_distance"] = NAN
	bad.append(nan_cam)
	var inf_cam: Dictionary = _camera()
	inf_cam["rear_extent"] = INF
	bad.append(inf_cam)
	var missing: Dictionary = _camera()
	missing.erase("visible_arc_half_width")
	bad.append(missing)
	var negative: Dictionary = _camera()
	negative["camera_distance"] = -1.0
	bad.append(negative)
	var too_wide: Dictionary = _camera()
	too_wide["visible_arc_half_width"] = 4.0
	bad.append(too_wide)
	for cam: Dictionary in bad:
		var codes: Array[StringName] = []
		assert_null(_build(EnvConfig.new(), cam, codes))
		assert_eq(codes, [MapConfig.MAP_CAMERA_INVALID] as Array[StringName])


func test_bad_l_or_far_gives_code() -> void:
	var codes: Array[StringName] = []
	var zero_l: Dictionary = _camera()
	zero_l["L"] = 0.0
	assert_null(_build(EnvConfig.new(), zero_l, codes))
	var env: EnvConfig = EnvConfig.new()
	env.fog_end_distance = INF
	assert_null(_build(env, _camera(), codes))
	assert_eq(codes, [MapConfig.MAP_CAMERA_INVALID, MapConfig.MAP_CAMERA_INVALID] as Array[StringName])


func test_two_builds_are_independent() -> void:
	var codes: Array[StringName] = []
	var a: MapConfig = _build(EnvConfig.new(), _camera(), codes)
	var b: MapConfig = _build(EnvConfig.new(), _camera(), codes)
	assert_eq(a.camera_far, b.camera_far)
	a.camera_far = 1.0
	a.rear_extent = 99.0
	assert_eq(b.camera_far, 96.0)
	assert_eq(b.rear_extent, 5.5)


func test_world_geometry_from_configs_and_validate() -> void:
	var geo: WorldGeometry = WorldGeometry.from_configs(TubeConfig.new(), BallConfig.new(), 20)
	assert_eq(geo.r, 3.0)
	assert_eq(geo.d, 0.8)
	assert_eq(geo.n_f, 20)
	assert_eq(geo.l, 12.0)
	assert_eq(geo.a_segments, 9)
	assert_eq(WorldGeometry.validate(geo, WorldFrameConfig.new()), [] as Array[String])
	var bad: WorldGeometry = WorldGeometry.new(3.0, NAN, 20, 12.0, 9)
	assert_eq(WorldGeometry.validate(bad, WorldFrameConfig.new()), [WorldGeometry.CODE_INVALID] as Array[String])
	var wide: WorldGeometry = WorldGeometry.new(3.0, 0.8, 20, 24.0, 9)
	assert_eq(WorldGeometry.validate(wide, WorldFrameConfig.new()), [WorldFrame.CODE_BUDGET] as Array[String])
