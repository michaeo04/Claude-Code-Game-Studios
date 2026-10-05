extends GutTest

const Fixture = preload("res://tests/support/pattern_fixture.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")


func _validate(intro: float, ramp: float, threshold: float = PI / 2.0) -> Array:
	var cfg: PatternConfig = PatternConfig.new()
	cfg.tier_intro_duration = intro
	cfg.tier_ramp_duration = ramp
	cfg.angular_reversal_threshold = threshold
	var sink: RefCounted = LogSink.new()
	var out: PatternConfig = cfg.validated(Callable(sink, "sink"))
	return [out, sink]


func _codes(sink: RefCounted) -> Array[StringName]:
	var codes: Array[StringName] = []
	for i: int in range(sink.call("count") as int):
		codes.append(sink.call("code_at", i) as StringName)
	return codes


func test_tier_boundaries_upper_inclusive() -> void:
	var fx: RefCounted = Fixture.make_pattern_fixture()
	var c: PatternConfig = fx.get("cfg") as PatternConfig
	var i: float = c.tier_intro_duration
	var r: float = c.tier_ramp_duration
	assert_eq(PatternMath.tier_for(8.0, i, r), ChunkDef.Tier.INTRO)
	assert_eq(PatternMath.tier_for(14.999, i, r), ChunkDef.Tier.INTRO)
	assert_eq(PatternMath.tier_for(15.0, i, r), ChunkDef.Tier.RAMP)
	assert_eq(PatternMath.tier_for(47.0, i, r), ChunkDef.Tier.RAMP)
	assert_eq(PatternMath.tier_for(90.0, i, r), ChunkDef.Tier.FULL)
	assert_eq(PatternMath.tier_for(300.0, i, r), ChunkDef.Tier.FULL)


func test_tier_order_equal_or_inverted_rejected_with_order_code() -> void:
	# The order guard runs independently of the range guards (intro 90 is also out of range, so both codes appear).
	for pair: Array in [[90.0, 90.0], [91.0, 90.0]]:
		var codes: Array[StringName] = _codes(_validate(pair[0] as float, pair[1] as float)[1] as RefCounted)
		assert_true(codes.has(PatternConfig.TIER_ORDER_INVALID), "pair %s" % [pair])


func test_tier_order_strictly_less_not_flagged_as_order() -> void:
	var codes: Array[StringName] = _codes(_validate(89.999, 90.0)[1] as RefCounted)
	assert_false(codes.has(PatternConfig.TIER_ORDER_INVALID))


func test_tier_order_valid_defaults_log_nothing() -> void:
	assert_eq(_codes(_validate(15.0, 90.0)[1] as RefCounted).size(), 0)
	assert_eq(_codes(_validate(20.0, 45.0)[1] as RefCounted).size(), 0)


func test_threshold_range_ends_accepted() -> void:
	assert_eq(_codes(_validate(15.0, 90.0, PI / 3.0)[1] as RefCounted).size(), 0)
	assert_eq(_codes(_validate(15.0, 90.0, 2.0 * PI / 3.0)[1] as RefCounted).size(), 0)


func test_threshold_outside_range_rejected() -> void:
	for bad: float in [PI / 3.0 - 0.001, 2.0 * PI / 3.0 + 0.001, 0.0, PI]:
		var res: Array = _validate(15.0, 90.0, bad)
		var codes: Array[StringName] = _codes(res[1] as RefCounted)
		assert_eq(codes, [PatternConfig.ANGULAR_THRESHOLD_OUT_OF_RANGE] as Array[StringName], "threshold %s" % bad)
		assert_eq((res[0] as PatternConfig).angular_reversal_threshold, PI / 2.0)


func test_intro_duration_range() -> void:
	for ok_value: float in [8.0, 20.0]:
		assert_eq(_codes(_validate(ok_value, 90.0)[1] as RefCounted).size(), 0, "intro %s" % ok_value)
	for bad: float in [7.999, 20.001, 0.0]:
		var res: Array = _validate(bad, 90.0)
		assert_eq(_codes(res[1] as RefCounted), [PatternConfig.TIER_DURATION_OUT_OF_RANGE] as Array[StringName])
		assert_eq((res[1] as RefCounted).call("key_at", 0), "tier_intro_duration")


func test_ramp_duration_range() -> void:
	for ok_value: float in [45.0, 240.0]:
		assert_eq(_codes(_validate(15.0, ok_value)[1] as RefCounted).size(), 0, "ramp %s" % ok_value)
	for bad: float in [44.999, 240.001]:
		var res: Array = _validate(15.0, bad)
		assert_eq(_codes(res[1] as RefCounted), [PatternConfig.TIER_DURATION_OUT_OF_RANGE] as Array[StringName])
		assert_eq((res[1] as RefCounted).call("key_at", 0), "tier_ramp_duration")


func test_validated_leaves_loaded_resource_untouched() -> void:
	var cfg: PatternConfig = PatternConfig.new()
	cfg.tier_intro_duration = 99.0
	var out: PatternConfig = cfg.validated()
	assert_eq(cfg.tier_intro_duration, 99.0)
	assert_eq(out.tier_intro_duration, 15.0)
