## Story TI-003: TiltConfig defaults, validated() clamps, rule 14 order and the sensitivity hook (AC-4 [C], AC-8, AC-36).
extends GutTest

const TiltSink = preload("res://tests/support/tilt_log_sink.gd")

const LOG_CODE: StringName = &"KNOB_CLAMPED"

## Rows: [field, input, expected (null = no change expected), overrides applied first (Dictionary)].
## expected_logs is 1 when the value changes, else 0.
const RANGE_ROWS: Array[Array] = [
	[&"tilt_full_scale", 11.0, 12.0, {}], [&"tilt_full_scale", 46.0, 45.0, {}],
	[&"tilt_full_scale", 12.0, 12.0, {}], [&"tilt_full_scale", 45.0, 45.0, {}],
	[&"dead_zone", -1.0, 0.0, {}], [&"dead_zone", 5.0, 4.0, {&"tilt_full_scale": 30.0}],
	[&"dead_zone", 0.0, 0.0, {}], [&"dead_zone", 4.0, 4.0, {&"tilt_full_scale": 30.0}],
	[&"filter_tau", 0.01, 0.02, {}], [&"filter_tau", 0.11, 0.10, {}],
	[&"filter_tau", 0.02, 0.02, {}], [&"filter_tau", 0.10, 0.10, {}],
	[&"curve_exp", 0.5, 1.0, {}], [&"curve_exp", 2.5, 2.0, {}],
	[&"curve_exp", 1.0, 1.0, {}], [&"curve_exp", 2.0, 2.0, {}],
	[&"neutral_window", 0.1, 0.15, {&"neutral_min_samples": 3}], [&"neutral_window", 0.7, 0.6, {&"neutral_guard": 0.2, &"sensor_resume_settle": 0.1}],
	[&"neutral_window", 0.15, 0.15, {&"neutral_min_samples": 3}], [&"neutral_window", 0.6, 0.6, {&"neutral_guard": 0.2, &"sensor_resume_settle": 0.1}],
	[&"neutral_guard", 0.01, 0.05, {}], [&"neutral_guard", 0.4, 0.35, {}],
	[&"neutral_guard", 0.05, 0.05, {}], [&"neutral_guard", 0.35, 0.35, {}],
	[&"neutral_min_samples", 2, 3, {}], [&"neutral_min_samples", 7, 6, {&"neutral_window": 0.4}],
	[&"neutral_min_samples", 3, 3, {}], [&"neutral_min_samples", 6, 6, {&"neutral_window": 0.3}],
	[&"reanchor_offset", 7.0, 8.0, {}], [&"reanchor_offset", 17.0, 16.0, {}],
	[&"reanchor_offset", 8.0, 8.0, {}], [&"reanchor_offset", 16.0, 16.0, {}],
	[&"reanchor_spread", 0.5, 1.0, {}], [&"reanchor_spread", 7.0, 6.0, {}],
	[&"reanchor_spread", 1.0, 1.0, {}], [&"reanchor_spread", 6.0, 6.0, {}],
	[&"g_min", 0.5, 1.0, {}], [&"g_min", 8.0, 7.0, {}],
	[&"g_min", 1.0, 1.0, {}], [&"g_min", 7.0, 7.0, {}],
	[&"sensor_start_timeout", 0.1, 0.5, {}], [&"sensor_start_timeout", 6.0, 5.0, {}],
	[&"sensor_start_timeout", 0.5, 0.5, {}], [&"sensor_start_timeout", 5.0, 5.0, {}],
	[&"sensor_resume_settle", 0.05, 0.1, {}], [&"sensor_resume_settle", 1.0, 0.45, {}],
	[&"sensor_resume_settle", 0.1, 0.1, {}],
	[&"dropout_hold", -0.1, 0.0, {}], [&"dropout_hold", 0.4, 0.3, {}],
	[&"dropout_hold", 0.0, 0.0, {}], [&"dropout_hold", 0.3, 0.3, {}],
	[&"fallback_slew", 0.5, 1.0, {}], [&"fallback_slew", 21.0, 20.0, {}],
	[&"fallback_slew", 1.0, 1.0, {}], [&"fallback_slew", 20.0, 20.0, {}],
]


func _run(overrides: Dictionary) -> Array:
	var cfg: TiltConfig = TiltConfig.new()
	for k: StringName in overrides:
		cfg.set(k, overrides[k])
	var sink: RefCounted = TiltSink.new()
	var out: TiltConfig = cfg.validated(Callable(sink, "sink"))
	return [out, sink]


func _count(r: Array) -> int:
	return (r[1] as RefCounted).call("count") as int


func test_defaults_equal_tuning_knobs_table() -> void:
	var c: TiltConfig = TiltConfig.new()
	assert_eq(c.tilt_full_scale, 25.0)
	assert_eq(c.dead_zone, 1.5)
	assert_eq(c.filter_tau, 0.05)
	assert_eq(c.curve_exp, 1.0)
	assert_eq(c.neutral_window, 0.3)
	assert_eq(c.neutral_guard, 0.25)
	assert_eq(c.neutral_min_samples, 5)
	assert_eq(c.reanchor_offset, 12.0)
	assert_eq(c.reanchor_spread, 3.0)
	assert_eq(c.g_min, 3.0)
	assert_eq(c.sensor_start_timeout, 2.0)
	assert_eq(c.sensor_resume_settle, 0.3)
	assert_eq(c.dropout_hold, 0.1)
	assert_eq(c.fallback_slew, 4.0)
	assert_eq(c.sensor_sign, -1)


func test_defaults_validate_without_logs() -> void:
	assert_eq(_count(_run({})), 0)


func test_validated_leaves_loaded_resource_untouched() -> void:
	var cfg: TiltConfig = TiltConfig.new()
	cfg.filter_tau = 0.0
	var out: TiltConfig = cfg.validated(Callable())
	assert_eq(cfg.filter_tau, 0.0)
	assert_eq(out.filter_tau, 0.02)


func test_ac4_filter_tau_zero_or_negative_clamps_to_002_with_one_log() -> void:
	for v: float in [0.0, -1.0]:
		var r: Array = _run({&"filter_tau": v})
		assert_eq((r[0] as TiltConfig).filter_tau, 0.02, "tau=%s" % v)
		assert_eq(_count(r), 1)
		assert_eq((r[1] as RefCounted).call("code_at", 0) as StringName, LOG_CODE)
		assert_eq(((r[1] as RefCounted).get("entries") as Array)[0][0] as int, RateLimitedLog.Level.ERROR)


func test_ac8_sensitivity_table() -> void:
	var rows: Array[Array] = [
		[NAN, 1.0, 1], [INF, 1.0, 1], [0.0, 1.0, 1], [-1.0, 1.0, 1],
		[3.0, 2.0, 1], [0.1, 0.5, 1], [0.5, 0.5, 0], [2.0, 2.0, 0],
	]
	for row: Array in rows:
		var sink: RefCounted = TiltSink.new()
		var eff: float = TiltConfig.validated_sensitivity(row[0] as float, Callable(sink, "sink"))
		assert_eq(eff, row[1] as float, "sensitivity=%s" % row[0])
		assert_eq(sink.call("count") as int, row[2] as int, "logs for %s" % row[0])
		if (row[2] as int) == 1:
			assert_eq(sink.call("code_at", 0) as StringName, LOG_CODE)


func test_ac8_invalid_sensitivity_behaves_as_one_in_steer() -> void:
	var eff: float = TiltConfig.validated_sensitivity(NAN, Callable())
	assert_almost_eq(TiltMath.steer(14.0, 25.0, 1.5, 1.0, eff), 0.531915, 1e-4)


func test_ac36_range_rows_clamp_with_one_log_and_boundaries_none() -> void:
	for row: Array in RANGE_ROWS:
		var field: StringName = row[0] as StringName
		var ov: Dictionary = (row[3] as Dictionary).duplicate()
		ov[field] = row[1]
		var r: Array = _run(ov)
		var got: Variant = (r[0] as TiltConfig).get(field)
		var changed: bool = not is_equal_approx(float(row[1]), float(row[2]))
		assert_almost_eq(float(got), float(row[2]), 1e-9, "%s=%s" % [field, row[1]])
		assert_eq(_count(r), 1 if changed else 0, "logs for %s=%s" % [field, row[1]])


func test_ac36_nan_and_inf_take_the_default() -> void:
	for field: StringName in [&"tilt_full_scale", &"dead_zone", &"filter_tau", &"curve_exp", &"neutral_window",
			&"neutral_guard", &"reanchor_offset", &"reanchor_spread", &"g_min", &"sensor_start_timeout",
			&"sensor_resume_settle", &"dropout_hold", &"fallback_slew"]:
		for bad: float in [NAN, INF]:
			var r: Array = _run({field: bad})
			assert_eq((r[0] as TiltConfig).get(field), TiltConfig.new().get(field), "%s=%s" % [field, bad])
			assert_eq(_count(r), 1, "%s=%s logs once" % [field, bad])


func test_ac36_sensor_sign_other_than_plus_minus_one_gives_minus_one() -> void:
	for v: int in [0, 2]:
		var r: Array = _run({&"sensor_sign": v})
		assert_eq((r[0] as TiltConfig).sensor_sign, -1)
		assert_eq(_count(r), 1)
	assert_eq(_count(_run({&"sensor_sign": 1})), 0)
	assert_eq(_count(_run({&"sensor_sign": -1})), 0)


func test_ac36_window_015_with_nmin_5_gives_nmin_3() -> void:
	var r: Array = _run({&"neutral_window": 0.15, &"neutral_min_samples": 5})
	assert_eq((r[0] as TiltConfig).neutral_min_samples, 3)
	assert_eq(_count(r), 1)


func test_ac36_dead_zone_4_with_fs_12_gives_1_8() -> void:
	var r: Array = _run({&"dead_zone": 4.0, &"tilt_full_scale": 12.0})
	assert_almost_eq((r[0] as TiltConfig).dead_zone, 1.8, 1e-9)
	assert_eq(_count(r), 1)


func test_ac36_guard_035_window_06_gives_window_055() -> void:
	var r: Array = _run({&"neutral_guard": 0.35, &"neutral_window": 0.6, &"sensor_resume_settle": 0.1})
	assert_almost_eq((r[0] as TiltConfig).neutral_window, 0.55, 1e-9)
	assert_eq(_count(r), 1)


func test_ac36_settle_1_with_guard_025_window_03_gives_045() -> void:
	var r: Array = _run({&"sensor_resume_settle": 1.0})
	assert_almost_eq((r[0] as TiltConfig).sensor_resume_settle, 0.45, 1e-9)
	assert_eq(_count(r), 1)


func test_ac36_rule_14_order_window_reduced_before_nmin_and_settle() -> void:
	# Guard 0.35 + window 0.6 -> window 0.55 (1 log); settle 1.0 -> 0.1 (1 log); nmin 6 <= floor(0.55*20)=11 holds.
	var r: Array = _run({&"neutral_guard": 0.35, &"neutral_window": 0.6, &"sensor_resume_settle": 1.0})
	var out: TiltConfig = r[0] as TiltConfig
	assert_almost_eq(out.neutral_window, 0.55, 1e-9)
	assert_almost_eq(out.sensor_resume_settle, 0.1, 1e-9)
	assert_eq(_count(r), 2)


func test_ac36_reanchor_offset_7_and_17_clamp_8_and_16_do_not() -> void:
	assert_eq((_run({&"reanchor_offset": 7.0})[0] as TiltConfig).reanchor_offset, 8.0)
	assert_eq((_run({&"reanchor_offset": 17.0})[0] as TiltConfig).reanchor_offset, 16.0)
	assert_eq(_count(_run({&"reanchor_offset": 8.0})), 0)
	assert_eq(_count(_run({&"reanchor_offset": 16.0})), 0)
