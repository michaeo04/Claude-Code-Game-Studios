## Story ML-005: Phase B apply order and map_ready.
extends GutTest

const Fake = preload("res://tests/support/map_loader_fake_seams.gd")

var _fake: MapLoaderSeams
var _core: MapLoaderCore
var _def: MapDefinition


func before_each() -> void:
	_fake = Fake.new()
	_def = Fake.valid_definition()
	_fake.definitions = [_def]
	_core = MapLoaderCore.new(_fake, MapLoaderConfig.new())


func test_success_order_and_ready() -> void:
	assert_true(_core.attempt("p"))
	assert_eq(
		_fake.seam_calls(),
		["env", "obstacle", "pattern", "hazard_view", "tube_load", "map_ready"] as Array[String]
	)
	assert_eq(_core.status, MapLoaderCore.Status.READY)
	assert_eq(_fake.count("map_ready"), 1)


func test_payloads_are_validated_copy_and_from_map_result() -> void:
	_core.attempt("p")
	assert_ne(_fake.last_map.env, _def.env)
	assert_eq(_fake.last_map.env.fog_end_distance, _def.env.fog_end_distance)
	assert_eq(_fake.last_tube_cfg.fog_end_distance, _def.env.fog_end_distance)
	assert_eq(_fake.last_tube_cfg.rear_extent, 4.0)


func test_apply_failure_stops_sequence_per_step() -> void:
	var order: Array[String] = ["env", "obstacle", "pattern", "hazard_view"]
	for i: int in order.size():
		var fake: MapLoaderSeams = Fake.new()
		fake.definitions = [Fake.valid_definition()]
		fake.fail = {order[i]: true}
		var core: MapLoaderCore = MapLoaderCore.new(fake, MapLoaderConfig.new())
		assert_false(core.attempt("p"))
		assert_eq(core.last_codes, PackedStringArray(["MAP_APPLY_FAILED"]))
		assert_eq(core.status, MapLoaderCore.Status.FAILED)
		assert_eq(fake.seam_calls(), order.slice(0, i + 1))
		assert_eq(fake.log_lines[0][1], &"MAP_APPLY_FAILED")
		assert_eq(fake.log_lines[0][2], order[i])


func test_tube_load_rejection() -> void:
	_fake.fail = {"tube_load": true}
	assert_false(_core.attempt("p"))
	assert_eq(_core.last_codes, PackedStringArray(["TUBE_LOAD_REJECTED"]))
	assert_eq(_fake.count("map_ready"), 0)


func test_phase_a_failure_calls_no_phase_b_seam() -> void:
	_def.chunk_library = null
	assert_false(_core.attempt("p"))
	assert_eq(_fake.seam_calls(), [] as Array[String])


func test_seam_list_is_closed() -> void:
	var allowed: Array[String] = [
		"load_definition", "camera_geometry", "apply_env", "apply_obstacle", "apply_pattern", "apply_hazard_view",
		"tube_load", "send_map_ready", "base_tube_config", "log_sink",
	]
	var names: Array[String] = []
	for method: Dictionary in (MapLoaderSeams as Script).get_script_method_list():
		var method_name: String = method["name"] as String
		if not method_name.begins_with("_"):
			names.append(method_name)
	names.sort()
	allowed.sort()
	assert_eq(names, allowed)
