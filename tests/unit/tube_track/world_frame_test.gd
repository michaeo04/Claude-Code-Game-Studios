## Story TT-004: Tube Track conformance test for WorldFrame (AC-15, ADR-0013 VC-1 to VC-3).
extends GutTest

const L: float = 12.0
const STEP: float = 1.0 / 60.0
const V_MAX: float = 25.0
## One float64 ulp for values in [512, 1024).
const ULP_512_1024: float = 1.1368683772161603e-13

var _frame: WorldFrame
var _codes: Array[String] = []


func before_each() -> void:
	_codes.clear()
	_frame = _make(84, 12.0)
	_frame.report_violations = false


func _make(segments: int, length: float) -> WorldFrame:
	var config: WorldFrameConfig = WorldFrameConfig.new()
	config.rebase_segments = segments
	return WorldFrame.new(config, WorldGeometry.new(3.0, 0.8, 20, length, 9))


## Documentation check of the float32 spacing: 2^(floor(log2(x)) - 23).
func _ulp32(x: float) -> float:
	return pow(2.0, floorf(log(x) / log(2.0)) - 23.0)


func test_render_z_equals_negated_distance_from_origin_in_float64() -> void:
	_frame.origin_s = 1008.0
	assert_eq(_frame.render_z(1010.5), -(1010.5 - 1008.0))
	assert_eq(_frame.render_z(1000.0), 8.0, "behind the ball is positive")
	var s: float = 123456789.123456
	_frame.origin_s = 0.0
	assert_eq(_frame.render_z(s), -s, "no float32 narrowing")


func test_rebase_at_threshold_sets_origin_multiple_of_l_and_fires_once() -> void:
	assert_false(_frame.maybe_rebase(1007.999), "below 84 * 12")
	assert_eq(_frame.origin_s, 0.0)
	assert_true(_frame.maybe_rebase(1008.0))
	assert_eq(_frame.origin_s, 1008.0)
	assert_eq(fmod(_frame.origin_s, L), 0.0)
	assert_false(_frame.maybe_rebase(1008.0), "once per crossing")
	assert_false(_frame.maybe_rebase(1015.0), "remainder below threshold")
	assert_eq(_frame.origin_s, 1008.0)


func test_rebase_keeps_remainder_inside_zero_to_l() -> void:
	for s: float in [1008.0, 1008.0 + 11.9, 1500.3, 99999.97]:
		var f: WorldFrame = _make(84, 12.0)
		assert_true(f.maybe_rebase(s))
		var rem: float = s - f.origin_s
		assert_true(rem >= 0.0 and rem < L, "remainder %f in [0, L) for s=%f" % [rem, s])
		assert_eq(fmod(f.origin_s, L), 0.0)


func test_one_ulp_below_a_multiple_of_l_does_not_misround() -> void:
	var s: float = 11.999999999999998
	var f: WorldFrame = _make(24, 12.0)
	var big: float = 24.0 * L + s # a rebase happens at a whole-segment crossing later
	assert_true(f.maybe_rebase(big))
	assert_true(big - f.origin_s >= 0.0 and big - f.origin_s < L)
	assert_false(_frame.maybe_rebase(1008.0 - ULP_512_1024), "one ulp below the threshold does not fire")
	assert_true(_frame.maybe_rebase(1008.0))
	assert_eq(_frame.origin_s, 1008.0)
	var g: WorldFrame = _make(24, 12.0)
	var just_below: float = 576.0 - ULP_512_1024
	assert_true(g.maybe_rebase(just_below))
	assert_true(just_below - g.origin_s >= 0.0, "remainder never negative")
	assert_eq(g.origin_s, 47.0 * L, "floor of 47.999.. segments is 47, never 48")


func test_on_run_reset_and_reset_zero_the_origin() -> void:
	_frame.maybe_rebase(5000.0)
	assert_gt(_frame.origin_s, 0.0)
	_frame.on_run_reset(7)
	assert_eq(_frame.origin_s, 0.0)
	_frame.maybe_rebase(5000.0)
	_frame.reset()
	assert_eq(_frame.origin_s, 0.0)


func test_validate_flags_the_budget_for_128_segments_at_l_24() -> void:
	var config: WorldFrameConfig = WorldFrameConfig.new()
	config.rebase_segments = 128
	var codes: Array[String] = WorldFrame.validate(config, WorldGeometry.new(3.0, 0.8, 20, 24.0, 9))
	assert_eq(codes, [WorldFrame.CODE_BUDGET] as Array[String])
	assert_eq(WorldFrame.validate(WorldFrameConfig.new(), WorldGeometry.new(3.0, 0.8, 20, 12.0, 9)).size(), 0, "defaults fit")


func test_soak_3600_seconds_at_v_max_keeps_z_below_budget_both_signs() -> void:
	var s: float = 0.0
	var max_ahead: float = 0.0
	var max_behind: float = 0.0
	var rebases: int = 0
	for _i: int in 216000:
		s += V_MAX * STEP
		if _frame.maybe_rebase(s):
			rebases += 1
		max_ahead = maxf(max_ahead, absf(_frame.render_z(s + 10.0 * L)))
		max_behind = maxf(max_behind, absf(_frame.render_z(s - 3.0 * L)))
	assert_gt(rebases, 50, "rebased repeatedly")
	assert_lt(max_ahead, WorldFrameConfig.Z_RENDER_MAX)
	assert_lt(max_behind, WorldFrameConfig.Z_RENDER_MAX)
	assert_eq(_frame.budget_violations, 0)


func test_ulp32_derivation_rows_are_kept_as_documentation() -> void:
	assert_almost_eq(_ulp32(700.0), 6.1e-5, 1e-6)
	assert_almost_eq(_ulp32(7500.0), 4.9e-4, 1e-5)
	assert_almost_eq(_ulp32(16384.0), 1.95e-3, 1e-5)
	assert_almost_eq(_ulp32(1.0e6), 0.0625, 1e-9)
