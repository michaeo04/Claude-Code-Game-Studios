## Story OBS-002: ObstacleConfig, sweep invariant (AC-13) and the shared fixtures.
extends GutTest

const Fixture = preload("res://tests/support/obstacle_fixture.gd")
const Sink = preload("res://tests/support/platform_log_sink.gd")

const TOL: float = 1e-6


func _validate(omega_max: float, dt_max: float) -> RefCounted:
	var sink: RefCounted = Sink.new()
	Fixture.make_config().validated(Callable(sink, "sink"), omega_max, dt_max)
	return sink


func test_sweep_invariant_defaults_validate_without_log() -> void:
	var sink: RefCounted = _validate(3.0, 0.1)

	assert_eq(sink.call("count") as int, 0)


func test_sweep_invariant_joint_safe_range_maxima_validate_without_log() -> void:
	var sink: RefCounted = _validate(4.0, 0.25)

	assert_eq(sink.call("count") as int, 0)


func test_sweep_invariant_illegal_row_logs_exactly_once() -> void:
	var sink: RefCounted = _validate(31.5, 0.1)

	assert_eq(sink.call("count") as int, 1)
	assert_eq(sink.call("count_code", ObstacleConfig.SWEEP_INVARIANT_VIOLATED) as int, 1)
	assert_eq(sink.call("level_at", 0) as int, LogLevel.ERROR)


func test_sweep_invariant_product_exactly_pi_is_rejected() -> void:
	var sink: RefCounted = _validate(PI, 1.0)

	assert_eq(sink.call("count_code", ObstacleConfig.SWEEP_INVARIANT_VIOLATED) as int, 1)


func test_sweep_invariant_non_finite_input_is_rejected() -> void:
	var sink: RefCounted = _validate(NAN, 0.1)

	assert_eq(sink.call("count_code", ObstacleConfig.SWEEP_INVARIANT_VIOLATED) as int, 1)


func test_config_validated_returns_clamped_copy_and_leaves_source() -> void:
	var cfg: ObstacleConfig = ObstacleConfig.new()
	cfg.gap_margin = 9.0
	cfg.max_pieces_per_segment = 100

	var out: ObstacleConfig = cfg.validated()

	assert_eq(out.gap_margin, 3.5)
	assert_eq(out.max_pieces_per_segment, 20)
	assert_eq(cfg.gap_margin, 9.0)
	assert_eq(cfg.max_pieces_per_segment, 100)
	assert_ne(out, cfg)


func test_config_validated_replaces_non_finite_gap_margin_with_default() -> void:
	var cfg: ObstacleConfig = ObstacleConfig.new()
	cfg.gap_margin = NAN

	assert_eq(cfg.validated().gap_margin, 2.5)


func test_fixture_derived_values_match_the_gdd() -> void:
	var fx: RefCounted = Fixture.make_obstacle_fixture()

	assert_almost_eq(fx.get("ball_half_angle") as float, 0.1179, 1e-4)
	assert_almost_eq(fx.get("w") as float, 0.2358, 1e-4)
	assert_almost_eq(fx.get("gap_min") as float, 0.5896, 1e-4)
	assert_almost_eq(fx.get("hidden_span_min_s") as float, 36.0, TOL)
	assert_eq(Fixture.VISIBLE_ARC_HALF_WIDTH_TEST, PI / 2.0)


func test_fixture_worked_hazards_exist() -> void:
	var piece_counts: Dictionary = {101: 3, 301: 1, 202: 2, 401: 1, 501: 1, 502: 1, 601: 1}
	for hazard_id: int in piece_counts:
		var spec: HazardSpec = Fixture.worked_hazard(hazard_id)
		assert_not_null(spec, "hazard %d" % hazard_id)
		assert_eq(spec.piece_count(), piece_counts[hazard_id] as int)
	assert_eq(Fixture.worked_hazard(202).solution_angles.size(), 2)
	assert_eq(Fixture.worked_hazard(101).solution_angles.size(), 0)


func test_fixture_ball_state_stub_holds_scripted_pair() -> void:
	var stub: Fixture.BallStateStub = Fixture.make_ball_state_stub(-0.2, 0.2, 199.0, 202.0)

	assert_eq(stub.theta_prev, -0.2)
	assert_eq(stub.theta, 0.2)
	assert_eq(stub.s_prev, 199.0)
	assert_eq(stub.s, 202.0)
