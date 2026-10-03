## Story TT-001: TubeMath frame, angle wrap and lane/facet formulas (AC-1 to AC-6, AC-16).
extends GutTest

const Frame = preload("res://tests/support/tube_logical_frame.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")

const R: float = 3.0
const JUST_BELOW_MINUS_PI: float = -3.141592653589793 - 4.44e-16


func _new_sink() -> RefCounted:
	return LogSink.new()


func _count(sink: RefCounted) -> int:
	return sink.call("count") as int


## Number of sink entries at `level`.
func _count_level(sink: RefCounted, level: int) -> int:
	var n: int = 0
	var entries: Array = sink.get("entries") as Array
	for e: Array in entries:
		if (e[0] as int) == level:
			n += 1
	return n


func test_ac1_frame_points_match_reference() -> void:
	var cases: Array[Array] = [
		[0.0, 0.0, 0.0, Vector3(0, 3, 0)],
		[PI / 2.0, 0.0, 0.0, Vector3(3, 0, 0)],
		[PI, 0.0, 0.5, Vector3(0, -3.5, 0)],
		[0.0, 50.0, 0.0, Vector3(0, 3, -50)],
	]
	for c: Array in cases:
		var xy: Vector2 = TubeMath.local_point(c[0] as float, c[2] as float, R)
		var want: Vector3 = c[3] as Vector3
		assert_almost_eq(xy.x, want.x, 1e-6)
		assert_almost_eq(xy.y, want.y, 1e-6)
		var ref: Vector3 = Frame.logical_p(c[0] as float, c[1] as float, c[2] as float, R)
		assert_almost_eq(ref.z, want.z, 1e-6)
		assert_almost_eq(xy.x, ref.x, 1e-6)
		assert_almost_eq(xy.y, ref.y, 1e-6)


func test_ac2_negative_h_equals_zero_h_with_one_warning() -> void:
	var sink: RefCounted = _new_sink()
	var neg: Vector2 = TubeMath.frame_xy(1.0, -0.5, R, Callable(sink, "sink"))
	assert_eq(neg, TubeMath.frame_xy(1.0, 0.0, R))
	assert_eq(_count(sink), 1)
	assert_eq(_count_level(sink, RateLimitedLog.Level.ERROR), 0)


func test_ac2_zero_h_logs_nothing() -> void:
	var sink: RefCounted = _new_sink()
	TubeMath.frame_xy(1.0, 0.0, R, Callable(sink, "sink"))
	assert_eq(_count(sink), 0)


func test_ac2_nan_and_inf_h_clamp_to_zero_with_one_error() -> void:
	for bad: float in [NAN, INF]:
		var sink: RefCounted = _new_sink()
		var p: Vector2 = TubeMath.frame_xy(1.0, bad, R, Callable(sink, "sink"))
		assert_eq(p, TubeMath.frame_xy(1.0, 0.0, R), "h=%s" % bad)
		assert_eq(_count_level(sink, RateLimitedLog.Level.ERROR), 1)
		assert_eq(_count(sink), 1)


func test_ac3_wrap_constants() -> void:
	assert_eq(TubeMath.wrap_angle(PI), -PI)
	assert_eq(TubeMath.wrap_angle(-PI), -PI)
	assert_almost_eq(TubeMath.wrap_angle(3.0 * PI / 2.0), -PI / 2.0, 1e-12)
	var r: float = TubeMath.wrap_angle(JUST_BELOW_MINUS_PI)
	assert_true(r >= -PI and r < PI, "just below -PI stays in range")
	assert_lt(absf(absf(r) - PI), 1e-9)
	assert_eq(TubeMath.delta_theta(0.0, PI), -PI)
	assert_almost_eq(TubeMath.delta_theta(-3.0, 3.0), 0.2832, 1e-4)


func test_ac4_grid_range_and_sine_invariants() -> void:
	var bad: int = 0
	for i: int in 10001:
		var x: float = -100.0 + 0.02 * float(i)
		var w: float = TubeMath.wrap_angle(x)
		var d: float = TubeMath.delta_theta(x, x + PI)
		var ok: bool = w >= -PI and w < PI and d >= -PI and d < PI
		ok = ok and absf(sin(w) - sin(x)) < 1e-9 and absf(absf(d) - PI) < 1e-9
		if not ok:
			bad += 1
	assert_eq(bad, 0, "grid points violating an invariant")


func test_ac5_seam_straddle() -> void:
	assert_almost_eq(TubeMath.delta_theta(PI - 0.05, -PI + 0.05), -0.1, 1e-9)
	assert_almost_eq(TubeMath.delta_theta(-PI + 0.05, PI - 0.05), 0.1, 1e-9)


func test_ac6_non_finite_theta_wrap_returns_zero_with_one_error() -> void:
	for bad: float in [NAN, INF, -INF]:
		var sink: RefCounted = _new_sink()
		assert_eq(TubeMath.wrap_angle(bad, Callable(sink, "sink")), 0.0)
		assert_eq(_count(sink), 1, "theta=%s" % bad)
		assert_eq(_count_level(sink, RateLimitedLog.Level.ERROR), 1)


func test_ac6_p_with_non_finite_theta_equals_p_at_zero() -> void:
	for bad: float in [NAN, INF, -INF]:
		var sink: RefCounted = _new_sink()
		var p: Vector3 = Frame.p_reference(bad, 5.0, 0.5, R, Callable(sink, "sink"))
		assert_eq(p, Frame.p_reference(0.0, 5.0, 0.5, R))
		assert_eq(_count(sink), 1)


func test_ac6_p_with_non_finite_s_is_finite_with_one_error() -> void:
	for bad: float in [NAN, INF, -INF]:
		var sink: RefCounted = _new_sink()
		var p: Vector3 = Frame.p_reference(1.0, bad, 0.5, R, Callable(sink, "sink"))
		assert_true(is_finite(p.x) and is_finite(p.y) and is_finite(p.z))
		assert_eq(_count(sink), 1)


func test_delta_theta_non_finite_returns_zero_with_one_error() -> void:
	var sink: RefCounted = _new_sink()
	assert_eq(TubeMath.delta_theta(NAN, 1.0, Callable(sink, "sink")), 0.0)
	assert_eq(_count(sink), 1)


func test_ac16_lane_width_and_count() -> void:
	assert_almost_eq(TubeMath.lane_width_deg(3.0, 0.8), 13.5, 0.05)
	assert_eq(TubeMath.lane_count(3.0, 0.8), 26)
	assert_eq(TubeMath.lane_count(2.5, 0.8), 22)


func test_ac16_facet_gap_limit() -> void:
	for r: float in [2.5, 3.0, 3.3]:
		assert_true(TubeMath.facet_gap(r) <= 0.02 * 0.8, "R=%s" % r)
	assert_true(TubeMath.facet_gap(3.4) > 0.02 * 0.8)
	assert_almost_eq(TubeMath.facet_gap(3.0), 0.0144, 1e-4)
