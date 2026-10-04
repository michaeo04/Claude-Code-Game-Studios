## HapticsConfig validation and shipped defaults (platform-services story 003; GDD AC-7, AC-18).
extends GutTest

const Rig = preload("res://tests/support/platform_rig.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")


func _validate(c: HapticsConfig, sink: LogSink) -> HapticsConfig:
	return c.validated(sink.sink)


func _assert_one_clamp(sink: LogSink, key: String) -> void:
	assert_eq(sink.count(), 1, "one log for " + key)
	if sink.count() == 1:
		assert_eq(sink.entries[0][0], LogLevel.ERROR)
		assert_eq(sink.entries[0][1], RateLimitedLog.KNOB_CLAMPED)
		assert_eq(sink.entries[0][2], key)


func test_min_interval_out_of_range_clamps_with_one_error() -> void:
	for pair: Array in [[-0.01, 0.0], [0.51, 0.5]]:
		var c: HapticsConfig = Rig.haptics_config()
		c.haptic_min_interval = pair[0]
		var sink: LogSink = LogSink.new()
		assert_almost_eq(_validate(c, sink).haptic_min_interval, pair[1] as float, 1e-6)
		_assert_one_clamp(sink, "HAPTIC_MIN_INTERVAL")


func test_max_ms_out_of_range_clamps_with_one_error() -> void:
	for pair: Array in [[49.0, 50.0], [501.0, 500.0]]:
		var c: HapticsConfig = Rig.haptics_config()
		c.haptic_max_ms = pair[0]
		c.hit_duration_ms = 40.0  # below the cap so only the knob itself is clamped
		var sink: LogSink = LogSink.new()
		var v: HapticsConfig = _validate(c, sink)
		assert_eq(v.max_ms(), int(pair[1]))
		_assert_one_clamp(sink, "HAPTIC_MAX_MS")


func test_kind_duration_out_of_range_clamps_with_one_error() -> void:
	var cases: Array = [
		["NEAR_MISS", HapticsConfig.Kind.NEAR_MISS, 9.0, 10], ["NEAR_MISS", HapticsConfig.Kind.NEAR_MISS, 201.0, 200],
		["HIT", HapticsConfig.Kind.HIT, 9.0, 10], ["HIT", HapticsConfig.Kind.HIT, 201.0, 200],
		["UI_TAP", HapticsConfig.Kind.UI_TAP, -1.0, 0], ["UI_TAP", HapticsConfig.Kind.UI_TAP, 201.0, 200],
	]
	for row: Array in cases:
		var c: HapticsConfig = Rig.haptics_config()
		_set_duration(c, row[1], row[2])
		var sink: LogSink = LogSink.new()
		assert_eq(_validate(c, sink).duration_ms(row[1]), row[3], "%s %s" % [row[0], row[2]])
		_assert_one_clamp(sink, row[0] + ".duration_ms")


func test_kind_amplitude_out_of_range_clamps_with_one_error() -> void:
	for kind: int in [HapticsConfig.Kind.NEAR_MISS, HapticsConfig.Kind.HIT, HapticsConfig.Kind.UI_TAP]:
		for pair: Array in [[1.1, 1.0], [-0.5, 0.0]]:
			var c: HapticsConfig = Rig.haptics_config()
			_set_amplitude(c, kind, pair[0])
			var sink: LogSink = LogSink.new()
			assert_almost_eq(_validate(c, sink).amplitude(kind), pair[1] as float, 1e-6)
			_assert_one_clamp(sink, HapticsConfig.kind_name(kind) + ".amplitude")


func test_kind_priority_out_of_range_clamps_with_one_error() -> void:
	for kind: int in [HapticsConfig.Kind.NEAR_MISS, HapticsConfig.Kind.HIT, HapticsConfig.Kind.UI_TAP]:
		for pair: Array in [[-1, 0], [10, 9]]:
			var c: HapticsConfig = Rig.haptics_config()
			_set_priority(c, kind, pair[0])
			var sink: LogSink = LogSink.new()
			assert_eq(_validate(c, sink).priority(kind), pair[1])
			_assert_one_clamp(sink, HapticsConfig.kind_name(kind) + ".priority")


func test_boundary_values_log_nothing() -> void:
	var c: HapticsConfig = Rig.haptics_config()
	c.haptic_min_interval = 0.5
	c.haptic_max_ms = 50.0
	c.near_miss_duration_ms = 10.0
	c.hit_duration_ms = 50.0
	c.ui_tap_duration_ms = 0.0
	c.near_miss_amplitude = 0.0
	c.hit_amplitude = 1.0
	c.near_miss_priority = 0
	c.hit_priority = 9
	var sink: LogSink = LogSink.new()
	_validate(c, sink)
	assert_eq(sink.count(), 0)
	c.haptic_min_interval = 0.0
	c.haptic_max_ms = 500.0
	c.hit_duration_ms = 500.0
	_validate(c, sink)
	assert_eq(sink.count(), 0)


func test_fractional_duration_rounds_without_error() -> void:
	var c: HapticsConfig = Rig.haptics_config()
	c.hit_duration_ms = 80.4
	var sink: LogSink = LogSink.new()
	assert_eq(_validate(c, sink).duration_ms(HapticsConfig.Kind.HIT), 80)
	assert_eq(sink.count(), 0)


func test_nan_and_infinite_take_the_default_with_one_error() -> void:
	var def: HapticsConfig = HapticsConfig.new()
	for bad: float in [NAN, INF, -INF]:
		var c: HapticsConfig = Rig.haptics_config()
		c.haptic_max_ms = bad
		var sink: LogSink = LogSink.new()
		assert_eq(_validate(c, sink).max_ms(), 200)
		_assert_one_clamp(sink, "HAPTIC_MAX_MS")
		c = Rig.haptics_config()
		c.haptic_min_interval = bad
		sink = LogSink.new()
		assert_almost_eq(_validate(c, sink).haptic_min_interval, def.haptic_min_interval, 1e-6)
		_assert_one_clamp(sink, "HAPTIC_MIN_INTERVAL")
		c = Rig.haptics_config()
		c.hit_duration_ms = bad
		sink = LogSink.new()
		assert_eq(_validate(c, sink).duration_ms(HapticsConfig.Kind.HIT), 80)
		_assert_one_clamp(sink, "HIT.duration_ms")
		c = Rig.haptics_config()
		c.near_miss_amplitude = bad
		sink = LogSink.new()
		assert_almost_eq(_validate(c, sink).near_miss_amplitude, 0.5, 1e-6)
		_assert_one_clamp(sink, "NEAR_MISS.amplitude")


func test_max_ms_is_validated_first_and_bounds_hit() -> void:
	var c: HapticsConfig = Rig.haptics_config()
	c.haptic_max_ms = 50.0
	var sink: LogSink = LogSink.new()
	var v: HapticsConfig = _validate(c, sink)
	assert_eq(v.duration_ms(HapticsConfig.Kind.HIT), 50)
	_assert_one_clamp(sink, "HIT.duration_ms")
	var rig: Rig = Rig.new(true, v)
	assert_true(rig.core.haptic(HapticsConfig.Kind.HIT))
	assert_eq(rig.vibrations[0][0], 50)


func test_validation_does_not_mutate_the_source_resource() -> void:
	var c: HapticsConfig = Rig.haptics_config()
	c.hit_priority = 10
	var sink: LogSink = LogSink.new()
	var v: HapticsConfig = _validate(c, sink)
	assert_eq(c.hit_priority, 10)
	assert_eq(v.hit_priority, 9)
	assert_ne(v, c)


## ADVISORY (AC-18): shipped defaults equal the Tuning Knobs table.
func test_shipped_defaults_match_tuning_knobs() -> void:
	var d: HapticsConfig = HapticsConfig.new()
	assert_almost_eq(d.haptic_min_interval, 0.08, 1e-6)
	assert_eq(d.max_ms(), 200)
	assert_eq(d.duration_ms(HapticsConfig.Kind.NEAR_MISS), 30)
	assert_almost_eq(d.amplitude(HapticsConfig.Kind.NEAR_MISS), 0.5, 1e-6)
	assert_eq(d.priority(HapticsConfig.Kind.NEAR_MISS), 1)
	assert_eq(d.duration_ms(HapticsConfig.Kind.HIT), 80)
	assert_almost_eq(d.amplitude(HapticsConfig.Kind.HIT), 1.0, 1e-6)
	assert_eq(d.priority(HapticsConfig.Kind.HIT), 2)
	assert_eq(d.duration_ms(HapticsConfig.Kind.UI_TAP), 15)
	assert_almost_eq(d.amplitude(HapticsConfig.Kind.UI_TAP), 0.3, 1e-6)
	assert_eq(d.priority(HapticsConfig.Kind.UI_TAP), 0)
	assert_ne(Rig.haptics_config().haptic_min_interval, d.haptic_min_interval, "fixture differs from shipped")
	var sink: LogSink = LogSink.new()
	d.validated(sink.sink)
	assert_eq(sink.count(), 0, "shipped defaults are valid")


func _set_duration(c: HapticsConfig, kind: int, v: float) -> void:
	match kind:
		HapticsConfig.Kind.NEAR_MISS:
			c.near_miss_duration_ms = v
		HapticsConfig.Kind.HIT:
			c.hit_duration_ms = v
		HapticsConfig.Kind.UI_TAP:
			c.ui_tap_duration_ms = v


func _set_amplitude(c: HapticsConfig, kind: int, v: float) -> void:
	match kind:
		HapticsConfig.Kind.NEAR_MISS:
			c.near_miss_amplitude = v
		HapticsConfig.Kind.HIT:
			c.hit_amplitude = v
		HapticsConfig.Kind.UI_TAP:
			c.ui_tap_amplitude = v


func _set_priority(c: HapticsConfig, kind: int, v: int) -> void:
	match kind:
		HapticsConfig.Kind.NEAR_MISS:
			c.near_miss_priority = v
		HapticsConfig.Kind.HIT:
			c.hit_priority = v
		HapticsConfig.Kind.UI_TAP:
			c.ui_tap_priority = v
