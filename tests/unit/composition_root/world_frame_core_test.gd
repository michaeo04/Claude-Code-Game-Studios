## Story CR-003: WorldFrame, WorldFrameConfig and the render-origin math.
extends GutTest

const LogSink = preload("res://tests/support/run_state_log_sink.gd")
const L: float = 12.0

var _geometry: WorldGeometry
var _config: WorldFrameConfig
var _frame: WorldFrame


func before_each() -> void:
	_geometry = WorldGeometry.new(3.0, 2.0, 20, L, 9)
	_config = WorldFrameConfig.new()
	_frame = WorldFrame.new(_config, _geometry)


func test_render_z_is_minus_s_minus_origin() -> void:
	for origin: float in [0.0, 12.0, 1008.0]:
		_frame.origin_s = origin
		for s: float in [origin, origin + 5.5, origin + 100.25]:
			assert_eq(_frame.render_z(s), -(s - origin))


func test_render_z_float64_beyond_9e9() -> void:
	var s: float = 9.0e9 + 0.125
	_frame.origin_s = 9.0e9 - fmod(9.0e9, L)
	assert_eq(_frame.render_z(s), -(s - _frame.origin_s))
	assert_eq(_frame.budget_violations, 0)


func test_render_z_at_zero_is_zero_magnitude() -> void:
	assert_eq(absf(_frame.render_z(0.0)), 0.0)


func test_rebase_below_threshold_is_false() -> void:
	assert_false(_frame.maybe_rebase(1008.0 - 0.000001))
	assert_eq(_frame.origin_s, 0.0)


func test_rebase_at_threshold_moves_origin_once() -> void:
	assert_true(_frame.maybe_rebase(1008.0))
	assert_eq(_frame.origin_s, 1008.0)
	assert_false(_frame.maybe_rebase(1008.0), "second call in the same tick")


func test_rebase_keeps_multiple_of_l_and_remainder_in_segment() -> void:
	assert_true(_frame.maybe_rebase(1019.999999999999))
	assert_eq(_frame.origin_s, 1008.0)
	var rem: float = 1019.999999999999 - _frame.origin_s
	assert_true(rem >= 0.0 and rem < L)
	assert_eq(fmod(_frame.origin_s, L), 0.0)


func test_rebase_one_ulp_below_multiple_has_remainder_in_range() -> void:
	var s: float = 1199.9999999999998 # 1200 minus one ulp
	assert_true(_frame.maybe_rebase(s))
	var rem: float = s - _frame.origin_s
	assert_true(rem >= 0.0 and rem < L, "remainder %s" % rem)
	assert_eq(_frame.origin_s, 1188.0)


func test_rebase_skipping_several_segments_lands_on_correct_one() -> void:
	assert_true(_frame.maybe_rebase(2500.5))
	assert_eq(_frame.origin_s, 2496.0)


func test_on_run_reset_and_reset_zero_origin() -> void:
	_frame.origin_s = 1008.0
	_frame.on_run_reset(7)
	assert_eq(_frame.origin_s, 0.0)
	_frame.origin_s = 1008.0
	_frame.reset()
	assert_eq(_frame.origin_s, 0.0)


func test_config_clamps_rebase_segments_and_logs() -> void:
	var sink: LogSink = LogSink.new()
	_config.rebase_segments = 10
	assert_eq(_config.validated(sink.sink).rebase_segments, 24)
	_config.rebase_segments = 200
	assert_eq(_config.validated(sink.sink).rebase_segments, 128)
	assert_eq(sink.count(), 2)


func test_config_validated_returns_copy_without_mutating_original() -> void:
	_config.rebase_segments = 200
	var copy: WorldFrameConfig = _config.validated(Callable())
	assert_ne(copy, _config)
	assert_eq(_config.rebase_segments, 200)
	assert_eq(copy.rebase_segments, 128)


func test_config_in_range_value_is_unchanged_and_silent() -> void:
	var sink: LogSink = LogSink.new()
	assert_eq(_config.validated(sink.sink).rebase_segments, 84)
	assert_eq(sink.count(), 0)


func test_budget_defaults_pass() -> void:
	assert_eq(WorldFrame.validate(_config, _geometry).size(), 0)


func test_budget_128_segments_at_l24_fails() -> void:
	_config.rebase_segments = 128
	var codes: Array[String] = WorldFrame.validate(_config, WorldGeometry.new(3.0, 2.0, 20, 24.0, 9))
	assert_eq(codes, ["REBASE_Z_EXCEEDS_BUDGET"] as Array[String])


func test_stale_origin_trips_debug_bound() -> void:
	_frame.report_violations = false
	_frame.render_z(5000.0) # raw s with origin 0: |z| = 5000 > 4096
	assert_eq(_frame.budget_violations, 1)
	_frame.render_z(1100.0)
	assert_eq(_frame.budget_violations, 1, "in-range z does not count")


func test_bound_predicate() -> void:
	assert_true(WorldFrame.z_within_bound(4096.0))
	assert_true(WorldFrame.z_within_bound(-4096.0))
	assert_false(WorldFrame.z_within_bound(4096.5))
