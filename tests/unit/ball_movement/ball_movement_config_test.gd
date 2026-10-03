## Story BM-002/BM-003: BallConfig defaults, fixtures, validated() clamps and the derived T_DODGE_180 check
## (AC-1, AC-3, AC-19, AC-19b, AC-19c). Oracles: tools/reference-sim/ball_movement.js.
extends GutTest

const Fixtures = preload("res://tests/support/ball_fixtures.gd")
const SteerTables = preload("res://tests/support/ball_steer_tables.gd")

const TOL: float = 1e-6
const T_DODGE_180_MAX: float = 1.14
const TAU_AT_CEILING_2_75: float = 0.046964
const KNOB_FIELDS: Array[StringName] = [
	&"steer_arc", &"ball_lag_tau", &"omega_max", &"v_start", &"v_max", &"t_ramp", &"ball_diameter"
]


## Validates `cfg`; returns `[validated: BallConfig, sink: RefCounted]`.
func _validate(cfg: BallConfig) -> Array:
	var sink: RefCounted = Fixtures.make_sink()
	var out: BallConfig = cfg.validated(sink.sink)
	return [out, sink]


## Overrides one field on the fixture (all other knobs stay at the fixture) and validates.
func _with(field: StringName, value: Variant) -> Array:
	var cfg: BallConfig = Fixtures.make_ball_fixture()
	cfg.set(field, value)
	return _validate(cfg)


func _log_count(result: Array) -> int:
	var sink: RefCounted = result[1] as RefCounted
	return sink.call("count") as int


func _field(result: Array, field: StringName) -> float:
	var out: BallConfig = result[0] as BallConfig
	return out.get(field) as float


func _assert_clamped(field: StringName, input: float, expected: float) -> void:
	var r: Array = _with(field, input)
	var sink: RefCounted = r[1] as RefCounted
	assert_eq(_log_count(r), 1, "%s=%s logs once" % [field, input])
	assert_eq(sink.call("code_at", 0) as StringName, BallConfig.LOG_KNOB_CLAMPED)
	assert_eq(sink.call("level_at", 0) as int, RateLimitedLog.Level.ERROR)
	assert_almost_eq(_field(r, field), expected, 1e-12, "%s=%s" % [field, input])


func _assert_accepted(field: StringName, input: float) -> void:
	var r: Array = _with(field, input)
	assert_eq(_log_count(r), 0, "%s=%s logs nothing" % [field, input])
	assert_eq(_field(r, field), input)


# ---- AC-1 defaults ----

func test_defaults_equal_tuning_knobs_table() -> void:
	var cfg: BallConfig = BallConfig.new()
	assert_eq(cfg.steer_arc, PI)
	assert_eq(cfg.ball_lag_tau, 0.06)
	assert_eq(cfg.omega_max, 3.0)
	assert_eq(cfg.mapping_mode, BallConfig.MappingMode.POSITION)
	assert_eq(cfg.v_start, 10.0)
	assert_eq(cfg.v_max, 25.0)
	assert_eq(cfg.t_ramp, 90.0)
	assert_eq(cfg.ball_diameter, 0.8)


func test_mapping_mode_enum_values_are_explicit() -> void:
	assert_eq(int(BallConfig.MappingMode.POSITION), 0)
	assert_eq(int(BallConfig.MappingMode.RATE), 1)


# ---- AC-3 fixtures ----

func test_fixture_equals_defaults() -> void:
	var fixture: BallConfig = Fixtures.make_ball_fixture()
	var defaults: BallConfig = BallConfig.new()
	for field: StringName in KNOB_FIELDS:
		assert_eq(fixture.get(field) as float, defaults.get(field) as float, String(field))
	assert_eq(fixture.mapping_mode, defaults.mapping_mode)


func test_sink_records_level_code_message_in_order() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	sink.call("sink", 1, &"BAD_DT", "first")
	sink.call("sink", 0, &"BAD_STEER", "second")
	assert_eq(sink.call("count") as int, 2)
	assert_eq(sink.call("level_at", 0) as int, 1)
	assert_eq(sink.call("code_at", 0) as StringName, &"BAD_DT")
	assert_eq(sink.call("message_at", 0) as String, "first")
	assert_eq(sink.call("level_at", 1) as int, 0)
	assert_eq(sink.call("code_at", 1) as StringName, &"BAD_STEER")
	assert_eq(sink.call("message_at", 1) as String, "second")


func test_lcg_table_is_identical_on_repeated_calls_and_in_range() -> void:
	var a: PackedFloat64Array = SteerTables.lcg_steer(64)
	var b: PackedFloat64Array = SteerTables.lcg_steer(64)
	assert_eq(a, b)
	for v: float in a:
		assert_true(v >= -1.0 and v <= 1.0)


# ---- AC-19 knob rows ----

func test_steer_arc_below_range_clamps_to_2_09() -> void:
	_assert_clamped(&"steer_arc", 2.0, 2.09)


func test_steer_arc_above_range_clamps_to_pi() -> void:
	_assert_clamped(&"steer_arc", 3.2, PI)


func test_steer_arc_boundaries_are_accepted() -> void:
	_assert_accepted(&"steer_arc", 2.09)
	_assert_accepted(&"steer_arc", PI)


func test_tau_below_range_clamps_to_zero() -> void:
	_assert_clamped(&"ball_lag_tau", -0.01, 0.0)


func test_tau_above_range_clamps_to_0_072() -> void:
	_assert_clamped(&"ball_lag_tau", 0.073, 0.072)


func test_tau_boundaries_are_accepted() -> void:
	_assert_accepted(&"ball_lag_tau", 0.0)
	_assert_accepted(&"ball_lag_tau", 0.072)


func test_omega_max_below_range_clamps_to_2_75() -> void:
	# tau 0.03 keeps T(PI, 0.05) under the ceiling at omega 2.75 (the default tau 0.06 would also trip Rule 13).
	var cfg: BallConfig = Fixtures.make_ball_fixture()
	cfg.ball_lag_tau = 0.03
	cfg.omega_max = 2.7
	var r: Array = _validate(cfg)
	var sink: RefCounted = r[1] as RefCounted
	assert_eq(_log_count(r), 1)
	assert_eq(sink.call("code_at", 0) as StringName, BallConfig.LOG_KNOB_CLAMPED)
	assert_eq(_field(r, &"omega_max"), 2.75)


func test_omega_max_above_range_clamps_to_4() -> void:
	_assert_clamped(&"omega_max", 4.1, 4.0)


func test_omega_max_boundaries_are_accepted() -> void:
	_assert_accepted(&"omega_max", 4.0)
	var cfg: BallConfig = Fixtures.make_ball_fixture()
	cfg.ball_lag_tau = 0.03
	cfg.omega_max = 2.75
	var r: Array = _validate(cfg)
	assert_eq(_log_count(r), 0)
	assert_eq(_field(r, &"omega_max"), 2.75)


func test_v_start_below_range_clamps_to_6() -> void:
	_assert_clamped(&"v_start", 5.9, 6.0)


func test_v_start_above_range_clamps_to_14() -> void:
	_assert_clamped(&"v_start", 14.1, 14.0)


func test_v_start_boundaries_are_accepted() -> void:
	_assert_accepted(&"v_start", 6.0)
	_assert_accepted(&"v_start", 14.0)


func test_v_max_below_range_clamps_to_18() -> void:
	_assert_clamped(&"v_max", 17.9, 18.0)


func test_v_max_above_range_clamps_to_30() -> void:
	_assert_clamped(&"v_max", 30.1, 30.0)


func test_v_max_boundaries_are_accepted() -> void:
	_assert_accepted(&"v_max", 18.0)
	_assert_accepted(&"v_max", 30.0)


func test_t_ramp_between_zero_and_45_clamps_to_45() -> void:
	_assert_clamped(&"t_ramp", 44.0, 45.0)


func test_t_ramp_tiny_positive_clamps_to_45() -> void:
	_assert_clamped(&"t_ramp", 0.001, 45.0)


func test_t_ramp_above_range_clamps_to_240() -> void:
	_assert_clamped(&"t_ramp", 241.0, 240.0)


func test_t_ramp_boundaries_are_accepted() -> void:
	_assert_accepted(&"t_ramp", 45.0)
	_assert_accepted(&"t_ramp", 240.0)


func test_t_ramp_zero_sentinel_is_accepted_without_log() -> void:
	_assert_accepted(&"t_ramp", 0.0)


func test_t_ramp_negative_sentinel_is_accepted_without_log() -> void:
	_assert_accepted(&"t_ramp", -5.0)


func test_ball_diameter_below_range_clamps_to_0_6() -> void:
	_assert_clamped(&"ball_diameter", 0.59, 0.6)


func test_ball_diameter_above_range_clamps_to_1() -> void:
	_assert_clamped(&"ball_diameter", 1.01, 1.0)


func test_ball_diameter_boundaries_are_accepted() -> void:
	_assert_accepted(&"ball_diameter", 0.6)
	_assert_accepted(&"ball_diameter", 1.0)


func test_non_finite_knobs_take_the_default_with_one_line() -> void:
	var defaults: BallConfig = BallConfig.new()
	for field: StringName in KNOB_FIELDS:
		for bad: float in [NAN, INF, -INF]:
			var r: Array = _with(field, bad)
			assert_eq(_log_count(r), 1, "%s=%s" % [field, bad])
			var sink: RefCounted = r[1] as RefCounted
			assert_eq(sink.call("code_at", 0) as StringName, BallConfig.LOG_KNOB_CLAMPED)
			assert_eq(_field(r, field), defaults.get(field) as float, "%s=%s" % [field, bad])


func test_mapping_mode_unrecognized_becomes_position_with_one_line() -> void:
	var r: Array = _with(&"mapping_mode", 7)
	var sink: RefCounted = r[1] as RefCounted
	assert_eq(_log_count(r), 1)
	assert_eq(sink.call("code_at", 0) as StringName, BallConfig.LOG_KNOB_CLAMPED)
	assert_eq((r[0] as BallConfig).mapping_mode, BallConfig.MappingMode.POSITION)


func test_mapping_mode_rate_is_accepted() -> void:
	var r: Array = _with(&"mapping_mode", BallConfig.MappingMode.RATE)
	assert_eq(_log_count(r), 0)
	assert_eq((r[0] as BallConfig).mapping_mode, BallConfig.MappingMode.RATE)


func test_dt_max_zero_negative_nan_inf_fall_back_to_0_1_with_one_line() -> void:
	for bad: float in [0.0, -1.0, NAN, INF]:
		var sink: RefCounted = Fixtures.make_sink()
		assert_eq(BallConfig.validated_dt_max(bad, sink.sink), 0.1, "dt_max=%s" % bad)
		assert_eq(sink.call("count") as int, 1)
		assert_eq(sink.call("code_at", 0) as StringName, BallConfig.LOG_KNOB_CLAMPED)


func test_dt_max_valid_value_passes_through_silently() -> void:
	var sink: RefCounted = Fixtures.make_sink()
	assert_eq(BallConfig.validated_dt_max(0.05, sink.sink), 0.05)
	assert_eq(sink.call("count") as int, 0)


func test_validated_returns_a_copy_and_leaves_the_source_unchanged() -> void:
	var cfg: BallConfig = Fixtures.make_ball_fixture()
	cfg.v_start = 99.0
	cfg.ball_lag_tau = 0.5
	var out: BallConfig = cfg.validated(Fixtures.make_sink().sink)
	assert_ne(out, cfg)
	assert_eq(cfg.v_start, 99.0)
	assert_eq(cfg.ball_lag_tau, 0.5)
	assert_eq(out.v_start, 14.0)
	assert_eq(out.ball_lag_tau, 0.072)


func test_validated_with_invalid_sink_does_not_crash() -> void:
	var cfg: BallConfig = Fixtures.make_ball_fixture()
	cfg.v_max = 99.0
	assert_eq(cfg.validated(Callable()).v_max, 30.0)


func test_each_changed_value_logs_exactly_once_across_knobs() -> void:
	var cfg: BallConfig = Fixtures.make_ball_fixture()
	cfg.v_start = 5.0
	cfg.v_max = 40.0
	cfg.ball_diameter = 2.0
	assert_eq(_log_count(_validate(cfg)), 3)


# ---- AC-19b derived T_DODGE_180 check ----

func test_derived_check_worked_example_corrects_tau_to_0_046964() -> void:
	var cfg: BallConfig = Fixtures.make_ball_fixture()
	cfg.omega_max = 2.75
	cfg.ball_lag_tau = 0.072
	assert_almost_eq(BallMath.T(PI, 0.05, 2.75, 0.072), 1.169487, TOL)
	var r: Array = _validate(cfg)
	var out: BallConfig = r[0] as BallConfig
	var sink: RefCounted = r[1] as RefCounted
	assert_eq(_log_count(r), 1)
	assert_eq(sink.call("code_at", 0) as StringName, BallConfig.LOG_KNOB_CLAMPED)
	assert_almost_eq(out.ball_lag_tau, TAU_AT_CEILING_2_75, TOL)
	assert_almost_eq(BallMath.T(PI, 0.05, out.omega_max, out.ball_lag_tau), T_DODGE_180_MAX, 1e-9)
	assert_lt(out.ball_lag_tau, 0.072)
	assert_eq(out.omega_max, 2.75)


func test_derived_check_invariant_over_a_grid_of_pairs() -> void:
	var corrected_any: bool = false
	for i: int in 11:
		for j: int in 13:
			var omega: float = 2.75 + 0.125 * float(i)
			var tau: float = 0.072 * float(j) / 12.0
			var before: float = BallMath.T(PI, 0.05, omega, tau)
			var cfg: BallConfig = Fixtures.make_ball_fixture()
			cfg.omega_max = omega
			cfg.ball_lag_tau = tau
			var r: Array = _validate(cfg)
			var out: BallConfig = r[0] as BallConfig
			assert_eq(out.omega_max, omega, "omega_max bit-identical")
			if before > T_DODGE_180_MAX:
				corrected_any = true
				assert_eq(_log_count(r), 1, "omega %s tau %s" % [omega, tau])
				assert_almost_eq(BallMath.T(PI, 0.05, out.omega_max, out.ball_lag_tau), T_DODGE_180_MAX, 1e-9)
				assert_lt(out.ball_lag_tau, tau)
			else:
				assert_eq(_log_count(r), 0, "omega %s tau %s" % [omega, tau])
				assert_eq(out.ball_lag_tau, tau)
	assert_true(corrected_any)


func test_pair_within_the_ceiling_triggers_no_correction() -> void:
	var r: Array = _with(&"ball_lag_tau", 0.072)
	assert_eq(_log_count(r), 0)
	assert_eq(_field(r, &"ball_lag_tau"), 0.072)


func test_clamp_then_derived_check_logs_both() -> void:
	var cfg: BallConfig = Fixtures.make_ball_fixture()
	cfg.omega_max = 2.75
	cfg.ball_lag_tau = 0.2
	var r: Array = _validate(cfg)
	assert_eq(_log_count(r), 2)
	assert_almost_eq((r[0] as BallConfig).ball_lag_tau, TAU_AT_CEILING_2_75, TOL)


# ---- AC-19c boundary pair ----

func test_boundary_pair_just_below_ceiling_logs_nothing() -> void:
	var cfg: BallConfig = Fixtures.make_ball_fixture()
	cfg.omega_max = 2.75
	cfg.ball_lag_tau = TAU_AT_CEILING_2_75 - 1e-6
	assert_lt(BallMath.T(PI, 0.05, 2.75, cfg.ball_lag_tau), T_DODGE_180_MAX)
	var r: Array = _validate(cfg)
	assert_eq(_log_count(r), 0)
	assert_eq((r[0] as BallConfig).ball_lag_tau, cfg.ball_lag_tau)


func test_boundary_pair_just_above_ceiling_logs_once() -> void:
	var cfg: BallConfig = Fixtures.make_ball_fixture()
	cfg.omega_max = 2.75
	cfg.ball_lag_tau = TAU_AT_CEILING_2_75 + 1e-6
	assert_gt(BallMath.T(PI, 0.05, 2.75, cfg.ball_lag_tau), T_DODGE_180_MAX)
	var r: Array = _validate(cfg)
	var sink: RefCounted = r[1] as RefCounted
	assert_eq(_log_count(r), 1)
	assert_eq(sink.call("code_at", 0) as StringName, BallConfig.LOG_KNOB_CLAMPED)
