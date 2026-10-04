## Story ML-002: HazardStyle validation and TubeConfig.from_map.
extends GutTest

const LogSink = preload("res://tests/support/platform_log_sink.gd")

var _log: RefCounted


func before_each() -> void:
	_log = LogSink.new()


func _snapshot(res: Resource) -> Dictionary:
	var out: Dictionary = {}
	for prop: Dictionary in res.get_property_list():
		if ((prop["usage"] as int) & PROPERTY_USAGE_STORAGE) != 0:
			out[prop["name"]] = res.get(prop["name"] as String)
	return out


func test_hazard_style_clamps_and_leaves_input() -> void:
	var style: HazardStyle = HazardStyle.new()
	style.height_d_spike = 9.0
	var copy: HazardStyle = style.validated(Callable(_log, "sink"))
	assert_eq(copy.height_d_spike, 3.0)
	assert_eq(style.height_d_spike, 9.0)
	assert_eq(_log.count(), 1)
	assert_eq(_log.code_at(0), &"KNOB_CLAMPED")


func test_hazard_style_bounds_unchanged() -> void:
	var style: HazardStyle = HazardStyle.new()
	style.height_d_wall = 1.0
	style.height_d_double_gate = 3.0
	style.height_d_near_ring = 3.0
	style.height_d_spike = 1.5
	var copy: HazardStyle = style.validated(Callable(_log, "sink"))
	assert_eq(_log.count(), 0)
	assert_eq(copy.height_d_double_gate, 3.0)
	assert_eq(copy.height_d_spike, 1.5)
	assert_eq(HazardStyle.new().height_d_spike, 1.6)


func test_hazard_style_below_range_clamps_up() -> void:
	var style: HazardStyle = HazardStyle.new()
	style.height_d_wall = 0.2
	assert_eq(style.validated(Callable(_log, "sink")).height_d_wall, 1.0)


func test_hazard_style_fatal_returns_null() -> void:
	var same: HazardStyle = HazardStyle.new()
	same.shade_color = same.face_color
	assert_null(same.validated(Callable(_log, "sink")))
	var nan_style: HazardStyle = HazardStyle.new()
	nan_style.height_d_wall = NAN
	assert_null(nan_style.validated(Callable(_log, "sink")))
	var inf_style: HazardStyle = HazardStyle.new()
	inf_style.height_d_spike = INF
	assert_null(inf_style.validated(Callable(_log, "sink")))


func test_from_map_sets_map_fields_only() -> void:
	var base: TubeConfig = TubeConfig.new()
	var before: Dictionary = _snapshot(base)
	var env: EnvConfig = EnvConfig.new()
	env.fog_depth_begin = 11.0
	env.fog_end_distance = 77.0
	env.fog_depth_curve = 1.5
	env.fog_density = 1.0
	env.readable_distance = 55.0
	var map: MapConfig = MapConfig.new()
	map.env = env
	map.rear_extent = 5.5
	map.camera_distance = 7.84
	var out: TubeConfig = TubeConfig.from_map(base, map)
	assert_ne(out, base)
	assert_eq(out.fog_depth_begin, 11.0)
	assert_eq(out.fog_end_distance, 77.0)
	assert_eq(out.fog_depth_curve, 1.5)
	assert_eq(out.readable_distance, 55.0)
	assert_eq(out.rear_extent, 5.5)
	assert_eq(out.camera_distance, 7.84)
	assert_eq(out.tube_radius, base.tube_radius)
	assert_eq(_snapshot(base), before)


func test_configs_are_scalar_only() -> void:
	for res: Resource in [TubeConfig.new(), EnvConfig.new(), HazardStyle.new()]:
		for prop: Dictionary in res.get_property_list():
			if ((prop["usage"] as int) & PROPERTY_USAGE_STORAGE) == 0 or prop["name"] == "script":
				continue
			var t: int = prop["type"] as int
			assert_false(t == TYPE_OBJECT or t == TYPE_ARRAY or t == TYPE_DICTIONARY, "%s.%s" % [res.get_class(), prop["name"]])


func test_env_validated_twice_leaves_loaded_instance() -> void:
	var env: EnvConfig = EnvConfig.new()
	env.fog_depth_curve = 99.0
	var before: Dictionary = _snapshot(env)
	var first: EnvConfig = env.validated(Callable(_log, "sink"))
	var second: EnvConfig = env.validated(Callable(_log, "sink"))
	assert_eq(_snapshot(env), before)
	assert_eq(env.fog_depth_curve, 99.0)
	assert_eq(first.fog_depth_curve, EnvConfig.FOG_CURVE_MAX)
	assert_eq(_snapshot(first), _snapshot(second))
	assert_ne(first, second)
