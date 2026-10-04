## Story TI-007: capture policy, conditional re-anchor and run-stop recording (AC-16, AC-16g, AC-22, AC-23).
extends GutTest

const Fixture = preload("res://tests/support/tilt_fixture.gd")

const DEG_TOL: float = 1e-3
const STEER_TOL: float = 1e-4
const HIT: TiltCore.PreviousPhase = TiltCore.PreviousPhase.HIT
const PAUSED: TiltCore.PreviousPhase = TiltCore.PreviousPhase.PAUSED


## live_core(5), 5 polls at 5, stop, then `polls` at `pose`; returns the fixture ready for the reset.
func _stopped(pose: float, polls: int = 60, sensitivity: float = 1.0) -> Fixture:
	var fx: Fixture = Fixture.new(null, sensitivity)
	fx.live_core(5.0)
	fx.tick(5.0, 5)
	fx.core.on_run_stopped()
	fx.tick(pose, polls)
	return fx


func test_pose_within_offset_inherits_and_keeps_the_filter_ac16a() -> void:
	for phase: TiltCore.PreviousPhase in [HIT, PAUSED]:
		var fx: Fixture = _stopped(12.0)
		var phi_f: float = fx.core.get_phi_f()
		fx.core.on_run_reset(phase)
		assert_almost_eq(fx.core.get_phi0(), 5.0, DEG_TOL)
		assert_eq(fx.core.get_phi_f(), phi_f, "filter not reset")
		fx.tick(12.0, 60)
		assert_almost_eq(fx.core.get_steer(), 0.234043, STEER_TOL)


func test_distant_steady_pose_recaptures_ac16b() -> void:
	for phase: TiltCore.PreviousPhase in [HIT, PAUSED]:
		var fx: Fixture = _stopped(20.0)
		fx.core.on_run_reset(phase)
		assert_almost_eq(fx.core.get_phi0(), 20.0, DEG_TOL)
		assert_eq(fx.core.get_phi_f(), 0.0)


func test_spread_decides_between_recapture_and_inherit_ac16c() -> void:
	for row: Array in [[22.0, 21.0], [24.0, 5.0]]:
		var fx: Fixture = Fixture.new()
		fx.live_core(5.0)
		fx.tick(5.0, 5)
		fx.core.on_run_stopped()
		for i: int in 60:
			fx.tick(20.0 if i % 2 == 0 else row[0] as float, 1)
		fx.core.on_run_reset(HIT)
		assert_almost_eq(fx.core.get_phi0(), row[1] as float, DEG_TOL, "alternating 20/%s" % row[0])


func test_menu_boot_unknown_and_resume_always_capture_ac16d() -> void:
	for kind: int in 4:
		var fx: Fixture = Fixture.new()
		fx.live_core(5.0)
		fx.tick(6.0, 60)
		match kind:
			0: fx.core.on_run_reset(TiltCore.PreviousPhase.MENU)
			1: fx.core.on_run_reset(TiltCore.PreviousPhase.BOOT)
			2: fx.core.on_run_reset(TiltCore.PreviousPhase.UNKNOWN)
			_: fx.core.on_run_resumed()
		assert_almost_eq(fx.core.get_phi0(), 6.0, DEG_TOL, "event kind %d" % kind)


func test_stale_neutral_routes_a_hit_reset_to_capture_not_reanchor_ac16e() -> void:
	# Partial AC-16e: the stale flag set by construction. The app-lifecycle setter belongs to Story 010.
	for phase: TiltCore.PreviousPhase in [HIT, PAUSED]:
		var fx: Fixture = Fixture.new()
		fx.tick(12.0, 1)
		assert_true(fx.core.get_neutral_stale())
		fx.core.on_run_stopped()
		fx.tick(12.0, 1)
		fx.core.on_run_reset(phase)
		assert_true(fx.core.get_neutral_pending(), "stale takes the capture path (too few samples: pending)")
		fx.tick(12.0, 5)
		assert_almost_eq(fx.core.get_phi0(), 12.0, DEG_TOL)
		assert_false(fx.core.get_neutral_stale())


func test_four_post_stop_samples_inherit_without_pending_ac16f() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(5.0)
	fx.tick(5.0, 5)
	fx.core.on_run_stopped()
	# Post-stop window [stop, t - 0.25 s] holds the stop sample plus 3 more = 4 samples, below N_min 5.
	fx.tick(20.0, 18)
	fx.core.on_run_reset(HIT)
	assert_almost_eq(fx.core.get_phi0(), 5.0, DEG_TOL)
	assert_false(fx.core.get_neutral_pending())
	fx.tick(20.0, 42)
	fx.core.on_run_reset(HIT)
	assert_almost_eq(fx.core.get_phi0(), 20.0, DEG_TOL, "with 60 polls the window is full")


func test_steady_death_tilt_inherits_ac16h() -> void:
	for phase: TiltCore.PreviousPhase in [HIT, PAUSED]:
		var fx: Fixture = Fixture.new()
		fx.live_core(5.0)
		fx.tick(25.0, 60)
		fx.core.on_run_stopped()
		fx.tick(25.0, 60)
		var phi_f: float = fx.core.get_phi_f()
		fx.core.on_run_reset(phase)
		assert_almost_eq(fx.core.get_phi0(), 5.0, DEG_TOL)
		assert_eq(fx.core.get_phi_f(), phi_f)


func test_short_post_stop_window_inherits_and_full_window_recaptures_ac16i() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(5.0)
	fx.tick(5.0, 5)
	fx.core.on_run_stopped()
	fx.tick(20.0, 18)
	assert_eq(fx.core.get_stop_us() + 300006, fx.clock.now_us)
	fx.core.on_run_reset(PAUSED)
	assert_almost_eq(fx.core.get_phi0(), 5.0, DEG_TOL, "4 samples inherit")
	var full: Fixture = _stopped(20.0, 60)
	full.core.on_run_reset(PAUSED)
	assert_almost_eq(full.core.get_phi0(), 20.0, DEG_TOL, "60 polls recapture")


func test_high_sensitivity_lowers_the_reanchor_offset_ac16j() -> void:
	var fx: Fixture = _stopped(12.0, 60, 2.0)
	fx.core.on_run_reset(HIT)
	assert_almost_eq(fx.core.get_phi0(), 12.0, DEG_TOL)


func test_median_beyond_phi_max_does_not_recapture_at_the_limit_ac16k() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(70.0)
	assert_eq(fx.count_code(&"POSTURE_UNSUPPORTED"), 1)
	fx.tick(70.0, 5)
	fx.core.on_run_stopped()
	fx.tick(90.0, 60)
	fx.core.on_run_reset(HIT)
	assert_almost_eq(fx.core.get_phi0(), 70.0, DEG_TOL)


func test_should_reanchor_boundaries_ac16g() -> void:
	# Arguments after the row: n, spread, median, phi0, phi_stop, n_min, ra_spread, ra_offset, fs_eff.
	var rows: Array[Array] = [
		["offset from phi0 exactly 12", false, 5, 0.0, 12.0, 0.0, 100.0, 5, 3.0, 12.0, 25.0],
		["offset from phi0 12.01", true, 5, 0.0, 12.01, 0.0, 100.0, 5, 3.0, 12.0, 25.0],
		["offset from phi_stop exactly 12", false, 5, 0.0, 12.0, 100.0, 0.0, 5, 3.0, 12.0, 25.0],
		["offset from phi_stop 12.01", true, 5, 0.0, 12.01, 100.0, 0.0, 5, 3.0, 12.0, 25.0],
		["spread 3.0", true, 5, 3.0, 20.0, 0.0, 0.0, 5, 3.0, 12.0, 25.0],
		["spread 3.01", false, 5, 3.01, 20.0, 0.0, 0.0, 5, 3.0, 12.0, 25.0],
		["n 4", false, 4, 0.0, 20.0, 0.0, 0.0, 5, 3.0, 12.0, 25.0],
		["n 5", true, 5, 0.0, 20.0, 0.0, 0.0, 5, 3.0, 12.0, 25.0],
		["phi_stop unknown", false, 5, 0.0, 20.0, 0.0, NAN, 5, 3.0, 12.0, 25.0],
		["offset -12.01", true, 5, 0.0, -12.01, 0.0, 0.0, 5, 3.0, 12.0, 25.0],
		["median 90 with phi0 70", false, 5, 0.0, 90.0, 70.0, 0.0, 5, 3.0, 12.0, 25.0],
		["RA_eff 6.25: 6.26", true, 5, 0.0, 6.26, 0.0, 0.0, 5, 3.0, 12.0, 12.5],
		["RA_eff 6.25: 6.25", false, 5, 0.0, 6.25, 0.0, 0.0, 5, 3.0, 12.0, 12.5],
	]
	for row: Array in rows:
		var got: bool = TiltMath.should_reanchor(row[2] as int, row[3] as float, row[4] as float, row[5] as float,
				row[6] as float, row[7] as int, row[8] as float, row[9] as float, row[10] as float)
		assert_eq(got, row[1] as bool, row[0] as String)


func test_run_started_changes_nothing_ac22() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(5.0)
	fx.tick(5.0, 5)
	fx.core.on_run_stopped()
	var before: Array = _snapshot(fx.core)
	fx.core.on_run_started()
	assert_eq(_snapshot(fx.core), before)


func test_stop_records_stamp_and_median_without_touching_the_rest_ac22() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(5.0)
	fx.tick(5.0, 5)
	var before: Array = _snapshot(fx.core)
	fx.core.on_run_stopped()
	var after: Array = _snapshot(fx.core)
	assert_eq(after[0], before[0], "phi0")
	assert_eq(after[1], before[1], "phi_f")
	assert_eq(after[2], before[2], "state")
	assert_eq(after[3], before[3], "sample_count")
	assert_eq(fx.core.get_stop_us(), fx.clock.now_us)
	assert_almost_eq(fx.core.get_phi_stop(), 5.0, DEG_TOL)


func test_stop_with_too_few_window_samples_leaves_phi_stop_unknown_ac22() -> void:
	var fx: Fixture = Fixture.new()
	fx.tick(5.0, 2)
	fx.core.on_run_stopped()
	assert_true(is_nan(fx.core.get_phi_stop()))


func test_clock_gap_leaves_only_post_gap_samples_ac23() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(2.0)
	fx.clock.advance_us(10000000)
	fx.tick(8.0, 37)
	assert_eq(fx.core.get_sample_count(), 37)
	fx.core.on_run_resumed()
	assert_almost_eq(fx.core.get_phi0(), 8.0, DEG_TOL)


func _snapshot(core: TiltCore) -> Array:
	return [core.get_phi0(), core.get_phi_f(), core.get_state(), core.get_sample_count(), core.get_stop_us(),
			core.get_phi_stop()]
