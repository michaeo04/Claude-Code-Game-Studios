## Story TT-003: TubeConfig.validate() failure-code sets (AC-12, AC-13) and the ADR-0004 field-type guard.
extends GutTest

const V_MAX: float = 25.0
const D: float = 0.8


## Base map: defaults equal the GDD base map (F 84, F_read 46.00, A 9, B 2).
func _base() -> TubeConfig:
	return TubeConfig.new()


## Sets `f` and `f_read` together (the AC-12 "F = F_read" rows) and the configured A.
func _with_f(f: float, f_read: float, a: int) -> TubeConfig:
	var c: TubeConfig = _base()
	c.fog_end_distance = f
	c.readable_distance = f_read
	c.segments_ahead = a
	return c


func _codes(records: Array[Dictionary]) -> Array[String]:
	var s: Array[String] = []
	for r: Dictionary in records:
		var code: String = String(r["code"] as StringName)
		if not s.has(code):
			s.append(code)
	s.sort()
	return s


func _assert_codes(c: TubeConfig, want: Array[String], msg: String, v_max: float = V_MAX, d: float = D, raw: Dictionary = {}) -> void:
	want.sort()
	assert_eq(_codes(c.validate(v_max, d, raw)), want, msg)


func test_base_map_loads() -> void:
	assert_eq(_base().validate(V_MAX, D).size(), 0)


func test_ac12_f_boundaries_load() -> void:
	assert_eq(_with_f(45.5, 45.5, 5).validate(V_MAX, D).size(), 0)
	assert_eq(_with_f(84.0, 84.0, 9).validate(V_MAX, D).size(), 0)
	assert_eq(_with_f(129.5, 129.5, 12).validate(V_MAX, D).size(), 0)


func test_ac12_non_positive_f() -> void:
	for v: float in [0.0, -1.0]:
		_assert_codes(_with_f(v, v, 9), ["NOT_POSITIVE"], "F=%s" % v)


func test_ac12_non_finite_f() -> void:
	for v: float in [NAN, INF]:
		_assert_codes(_with_f(v, v, 9), ["NOT_FINITE"], "F=%s" % v)


func test_ac12_visibility_just_below_floor() -> void:
	_assert_codes(_with_f(45.49, 45.49, 5), ["VISIBILITY"], "45.49")


func test_ac12_f_above_max_gives_a_too_large_and_suppresses_a_too_small() -> void:
	_assert_codes(_with_f(129.51, 129.51, 12), ["A_TOO_LARGE"], "129.51")


func test_ac12_f_read_rows() -> void:
	for fr: float in [20.0, 45.0]:
		var c: TubeConfig = _base()
		c.readable_distance = fr
		_assert_codes(c, ["VISIBILITY"], "F_read=%s" % fr)
	var c2: TubeConfig = _base()
	c2.readable_distance = 90.0
	_assert_codes(c2, ["FOG_BEFORE_READ"], "F_read=90")
	var c3: TubeConfig = _base()
	c3.readable_distance = 46.0
	_assert_codes(c3, [], "F_read=46")


func test_ac12_fog_density_mode_range() -> void:
	var c: TubeConfig = _base()
	c.fog_density = 0.01
	_assert_codes(c, ["FOG_DENSITY"], "density")
	c = _base()
	c.fog_mode = TubeConfig.FogMode.EXPONENTIAL
	_assert_codes(c, ["FOG_MODE"], "mode")
	c = _base()
	c.fog_depth_begin = 84.0
	_assert_codes(c, ["FOG_RANGE"], "begin=84")


func test_ac12_window_a_rows() -> void:
	var c: TubeConfig = _base()
	c.segments_ahead = 8
	_assert_codes(c, ["A_TOO_SMALL"], "A=8")
	var records: Array[Dictionary] = c.validate(V_MAX, D)
	assert_eq(records[0]["required"] as int, 9)
	c = _base()
	c.segments_ahead = 13
	_assert_codes(c, ["A_OUT_OF_RANGE"], "A=13")


func test_ac12_v_max_rows() -> void:
	_assert_codes(_base(), ["NOT_POSITIVE"], "v_max=0", 0.0)
	_assert_codes(_base(), ["NOT_FINITE"], "v_max=NaN", NAN)
	_assert_codes(_base(), ["NOT_FINITE"], "v_max=INF", INF)


func test_ac12_empty_f_range_reports_only_no_valid_f_with_range() -> void:
	var c: TubeConfig = _with_f(93.5, 93.5, 12)
	c.segment_length = 9.0
	c.t_lat = 0.25
	c.t_vis_min = 2.5
	c.camera_distance = 31.0
	_assert_codes(c, ["NO_VALID_F"], "empty range")
	var rec: Dictionary = c.validate(V_MAX, D)[0]
	assert_almost_eq(rec["f_min"] as float, 93.5, 1e-9)
	assert_almost_eq(rec["f_max"] as float, 92.75, 1e-9)


func test_ac13_radius_range() -> void:
	for r: float in [2.4, 3.4]:
		var c: TubeConfig = _base()
		c.tube_radius = r
		_assert_codes(c, ["R_RANGE"], "R=%s" % r)
	for r: float in [2.5, 3.0, 3.3]:
		var c: TubeConfig = _base()
		c.tube_radius = r
		_assert_codes(c, [], "R=%s" % r)


func test_ac13_small_ball_rejects_small_radius_by_gap() -> void:
	var c: TubeConfig = _base()
	c.tube_radius = 2.5
	_assert_codes(c, ["R_RANGE"], "D=0.6 R=2.5", V_MAX, 0.6)


func test_ac13_l_invalid_rows() -> void:
	for l: float in [5.0, 12.5, 25.0, 8.0]:
		var c: TubeConfig = _base()
		c.segment_length = l
		_assert_codes(c, ["L_INVALID"], "L=%s" % l)
	var c8: TubeConfig = _base()
	c8.segment_length = 8.0
	assert_eq(c8.validate(V_MAX, D)[0]["l_min"] as int, 9)
	for l: float in [9.0, 12.0, 24.0]:
		var c: TubeConfig = _base()
		c.segment_length = l
		c.segments_ahead = 12 if l == 9.0 else 9
		assert_false(_codes(c.validate(V_MAX, D)).has("L_INVALID"), "L=%s" % l)


func test_ac13_l_9_with_a_11_loads() -> void:
	var c: TubeConfig = _base()
	c.segment_length = 9.0
	c.segments_ahead = 11
	_assert_codes(c, [], "L=9 A=11")


func test_ac13_n_seams_invalid_values() -> void:
	for n: Variant in [0, -1, 2.5]:
		_assert_codes(_base(), ["NOT_POSITIVE"], "n_seams=%s" % n, V_MAX, D, {"n_seams": n})


func test_ac13_n_seams_2_rejected_with_max_1_and_1_accepted() -> void:
	var c: TubeConfig = _base()
	c.n_seams = 2
	_assert_codes(c, ["SEAM_HZ"], "n_seams=2")
	assert_eq(c.validate(V_MAX, D)[0]["max_n_seams"] as int, 1)
	_assert_codes(_base(), [], "n_seams=1")


func test_ac13_b_below_required_and_above_max_rejected() -> void:
	for b: int in [0, 4]:
		var c: TubeConfig = _base()
		c.segments_behind = b
		_assert_codes(c, ["B_OUT_OF_RANGE"], "B=%s" % b)


func test_adr_0004_no_resource_array_or_dictionary_field() -> void:
	var banned: Array[int] = [TYPE_OBJECT, TYPE_ARRAY, TYPE_DICTIONARY, TYPE_PACKED_FLOAT32_ARRAY]
	for p: Dictionary in TubeConfig.new().get_property_list():
		if ((p["usage"] as int) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			assert_false(banned.has(p["type"] as int), "field %s has a forbidden type" % p["name"])
