extends GutTest

const Sink = preload("res://tests/support/platform_log_sink.gd")
const Fixture = preload("res://tests/support/near_miss_fixture.gd")


func _cfg(angle: float, s: float) -> NearMissConfig:
	var c: NearMissConfig = NearMissConfig.new()
	c.near_miss_angle_coeff = angle
	c.near_miss_s_coeff = s
	return c


func test_angle_coeff_zero_logs_one_line() -> void:
	var sink: Sink = Sink.new()
	_cfg(0.0, 1.0).validated(sink.sink)
	assert_eq(sink.count(), 1)
	assert_eq(sink.code_at(0), NearMissConfig.NEAR_MISS_MARGIN_NONPOSITIVE)
	assert_eq(sink.key_at(0), "near_miss_angle_coeff")


func test_angle_coeff_negative_logs_one_line() -> void:
	var sink: Sink = Sink.new()
	var out: NearMissConfig = _cfg(-0.1, 1.0).validated(sink.sink)
	assert_eq(sink.count_code(NearMissConfig.NEAR_MISS_MARGIN_NONPOSITIVE), 1)
	assert_gt(out.near_miss_angle_coeff, 0.0)


func test_s_coeff_zero_and_negative_log_one_line_each() -> void:
	var sink: Sink = Sink.new()
	_cfg(1.0, 0.0).validated(sink.sink)
	assert_eq(sink.count(), 1)
	assert_eq(sink.key_at(0), "near_miss_s_coeff")
	sink.clear()
	_cfg(1.0, -0.1).validated(sink.sink)
	assert_eq(sink.count(), 1)
	assert_eq(sink.key_at(0), "near_miss_s_coeff")


func test_both_coeffs_bad_log_two_lines() -> void:
	var sink: Sink = Sink.new()
	_cfg(0.0, -1.0).validated(sink.sink)
	assert_eq(sink.count(), 2)
	assert_ne(sink.key_at(0), sink.key_at(1))


func test_floor_value_passes_with_zero_lines() -> void:
	var sink: Sink = Sink.new()
	var out: NearMissConfig = _cfg(0.5, 0.5).validated(sink.sink)
	assert_eq(sink.count(), 0)
	assert_eq(out.near_miss_angle_coeff, 0.5)
	assert_eq(out.near_miss_s_coeff, 0.5)


func test_validated_does_not_mutate_source() -> void:
	var src: NearMissConfig = _cfg(0.0, 1.0)
	src.validated(Callable())
	assert_eq(src.near_miss_angle_coeff, 0.0)


func test_fixture_derived_margins() -> void:
	var fx: RefCounted = Fixture.make_near_miss_fixture()
	assert_almost_eq(fx.get("ball_half_angle") as float, 0.1179, 1e-4)
	assert_almost_eq(fx.get("w") as float, 0.2358, 1e-4)
	assert_almost_eq(fx.get("gap_min") as float, 0.5896, 1e-4)
	assert_almost_eq(fx.get("angle_margin") as float, 0.1179, 1e-4)
	assert_almost_eq(fx.get("s_margin") as float, 0.4, 1e-6)
	assert_eq(Fixture.worked_raw(101).size(), 12)
	assert_eq(Fixture.worked_raw(202).size(), 8)
	assert_eq(Fixture.worked_raw(701).size(), 4)
