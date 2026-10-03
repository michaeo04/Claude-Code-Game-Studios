## Story BM-006: anchor, resume re-base, 2 PI shift, published previous values and inertness
## (AC-4, AC-10, AC-11, AC-12a, AC-13, AC-23). GDD AC-12 (accumulation oracle) is an Open Gap and not tested here.
extends GutTest

const Fixtures = preload("res://tests/support/ball_fixtures.gd")

const TOL: float = 1e-6
const SENSOR: int = BallCore.InputSource.SENSOR
const DT60: float = 1.0 / 60.0


func _core() -> BallCore:
	return Fixtures.make_core(Fixtures.make_ball_fixture())


func _assert_same_pose(a: BallCore, b: BallCore) -> void:
	assert_eq(a.phi, b.phi)
	assert_eq(a.phi_anchor, b.phi_anchor)
	assert_eq(a.theta, b.theta)
	assert_eq(a.s, b.s)
	assert_eq(a.t_run, b.t_run)
	assert_eq(a.speed, b.speed)


func _steer_at(i: int) -> float:
	return 0.8 if i % 2 == 0 else -0.6


# AC-4

func test_zero_dt_frames_are_bit_identical_and_moving_frames_continue() -> void:
	var gapped: BallCore = _core()
	var plain: BallCore = _core()
	for i: int in 10:
		gapped.step(DT60, _steer_at(i), true, SENSOR)
		plain.step(DT60, _steer_at(i), true, SENSOR)
	var snapshot: BallCore = _core()
	for i: int in 10:
		snapshot.step(DT60, _steer_at(i), true, SENSOR)
	for i: int in 300:
		gapped.step(0.0, float(i % 3) - 1.0, true, SENSOR)
		_assert_same_pose(gapped, snapshot)
	for i: int in range(10, 20):
		gapped.step(DT60, _steer_at(i), true, SENSOR)
		plain.step(DT60, _steer_at(i), true, SENSOR)
	_assert_same_pose(gapped, plain)


func test_on_resumed_then_zero_dt_moves_nothing_and_keeps_rebase_armed() -> void:
	var core: BallCore = _core()
	for _i: int in 20:
		core.step(DT60, 1.0, true, SENSOR)
	var anchor_before: float = core.phi_anchor
	var phi_before: float = core.phi
	core.on_resumed()
	core.step(0.0, 0.3, true, SENSOR)
	assert_eq(core.phi, phi_before)
	assert_eq(core.phi_anchor, anchor_before, "zero-dt step does not consume the re-base")
	core.step(DT60, 0.5, true, SENSOR)
	assert_almost_eq(core.phi_anchor, phi_before - PI * 0.5, TOL)


# AC-10

func test_reset_glide_steer_half_reaches_half_pi_exactly_at_frame_72() -> void:
	var core: BallCore = _core()
	var previous_theta: float = 0.0
	for frame: int in range(1, 73):
		core.step(DT60, 0.5, true, SENSOR)
		if frame == 1:
			assert_almost_eq(core.theta, 0.05, TOL)
		assert_gt(core.theta, previous_theta, "monotone at frame %s" % frame)
		assert_true(core.theta - previous_theta <= 0.05 + 1e-9, "move <= 0.05 at frame %s" % frame)
		if frame < 72:
			assert_true(core.phi != PI / 2.0, "not yet at frame %s" % frame)
		previous_theta = core.theta
	assert_eq(core.phi, PI / 2.0)


func test_reset_after_nonzero_anchor_returns_anchor_to_zero() -> void:
	var core: BallCore = _core()
	core.step(DT60, 1.0, true, SENSOR)
	core.on_resumed()
	core.step(DT60, 0.2, true, SENSOR)
	assert_true(core.phi_anchor != 0.0)
	core.reset()
	assert_eq(core.phi_anchor, 0.0)
	assert_eq(core.phi, 0.0)


# AC-11

func test_resume_rebase_sets_anchor_without_moving_and_does_not_repeat() -> void:
	var core: BallCore = _core()
	for _i: int in 120:
		core.step(DT60, 1.0, true, SENSOR)
	assert_almost_eq(core.phi, PI, TOL)
	var phi_snapped: float = core.phi
	core.on_resumed()
	core.step(0.0, 0.3, true, SENSOR)
	assert_eq(core.phi_anchor, 0.0)
	core.step(DT60, 0.5, true, SENSOR)
	assert_almost_eq(core.phi_anchor, PI / 2.0, TOL)
	assert_eq(core.phi, phi_snapped)
	assert_eq(core.omega, 0.0)
	# The next step uses that anchor; steer 1 now targets anchor + PI = 1.5 PI and does not re-base again.
	core.step(DT60, 1.0, true, SENSOR)
	assert_almost_eq(core.phi_anchor, PI / 2.0, TOL)
	assert_almost_eq(core.phi, phi_snapped + 0.05, TOL)


func test_resume_then_reset_then_steer_half_targets_half_arc() -> void:
	var core: BallCore = _core()
	for _i: int in 120:
		core.step(DT60, 1.0, true, SENSOR)
	core.on_resumed()
	core.reset()
	for _i: int in 120:
		core.step(DT60, 0.5, true, SENSOR)
	assert_eq(core.phi_anchor, 0.0, "reset disarmed the re-base")
	assert_eq(core.phi, PI / 2.0)


func test_rebase_with_invalid_steer_uses_held_steer() -> void:
	var core: BallCore = _core()
	for _i: int in 120:
		core.step(DT60, 1.0, true, SENSOR)
	var phi: float = core.phi
	core.on_resumed()
	core.step(DT60, NAN, true, SENSOR)
	assert_almost_eq(core.phi_anchor, phi - PI, TOL, "held steer 1 used")
	assert_eq(core.phi, phi)


# AC-12a

## Runs `cycles` of (resume, re-base at steer 0, steer `sign` for 70 steps) and checks the shift invariant at
## every step where the anchor moves outside a re-base. Returns the number of shifts seen.
func _drive_and_check_shifts(sign: float, cycles: int) -> int:
	var core: BallCore = _core()
	var shifts: int = 0
	for _c: int in cycles:
		core.on_resumed()
		core.step(DT60, 0.0, true, SENSOR)
		for _i: int in 70:
			var phi_before: float = core.phi
			var anchor_before: float = core.phi_anchor
			core.step(DT60, sign, true, SENSOR)
			if core.phi_anchor == anchor_before:
				continue
			shifts += 1
			var k: float = roundf((anchor_before - core.phi_anchor) / TAU)
			assert_true(absf(k) >= 1.0)
			assert_almost_eq(anchor_before - core.phi_anchor, k * TAU, 1e-9)
			var phi_unshifted: float = core.phi + k * TAU
			assert_true(absf(phi_unshifted) > TAU, "shift only past 2 PI")
			assert_almost_eq(phi_unshifted - core.phi, k * TAU, 1e-9, "same k for phi")
			assert_almost_eq(
				core.phi - core.phi_anchor, phi_unshifted - anchor_before, 1e-9, "phi - phi_anchor preserved"
			)
			assert_almost_eq(core.omega, (phi_unshifted - phi_before) / DT60, 1e-9, "omega from pre-shift phi")
			assert_almost_eq(core.theta, BallMath.wrap_angle(phi_unshifted), 1e-9, "theta unaffected")
			assert_true(absf(core.phi) <= TAU)
	return shifts


func test_shift_invariant_holds_going_up() -> void:
	assert_gt(_drive_and_check_shifts(1.0, 5), 0, "a shift occurred")


func test_shift_invariant_holds_going_down() -> void:
	assert_gt(_drive_and_check_shifts(-1.0, 5), 0, "a shift occurred")


# AC-13

func _settle(steer: float) -> BallCore:
	var core: BallCore = _core()
	for _i: int in 200:
		core.step(DT60, steer, true, SENSOR)
	return core


func test_full_lock_positive_ends_with_theta_minus_pi() -> void:
	assert_eq(_settle(1.0).theta, -PI)


func test_full_lock_negative_ends_with_theta_minus_pi() -> void:
	assert_eq(_settle(-1.0).theta, -PI)


func test_seam_chain_after_resume_crosses_the_seam() -> void:
	var core: BallCore = _core()
	for _i: int in 200:
		core.step(DT60, 0.95, true, SENSOR)
	core.on_resumed()
	core.step(DT60, 0.5, true, SENSOR)
	for _i: int in 3:
		core.step(DT60, 1.0, true, SENSOR)
	assert_almost_eq(core.theta, 3.134513, TOL)
	core.step(DT60, 1.0, true, SENSOR)
	assert_almost_eq(core.theta_prev, 3.134513, TOL)
	assert_almost_eq(core.theta, -3.098672, TOL)


# AC-23

func test_previous_values_equal_prior_current_over_300_steps_including_seam() -> void:
	var core: BallCore = _core()
	var theta_last: float = core.theta
	var s_last: float = core.s
	var seam_crossed: bool = false
	for i: int in 300:
		core.step(DT60, 1.0 if (i / 100) % 2 == 0 else -1.0, true, SENSOR)
		assert_eq(core.theta_prev, theta_last)
		assert_eq(core.s_prev, s_last)
		if signf(core.theta) != signf(core.theta_prev) and absf(core.theta) > 3.0:
			seam_crossed = true
		theta_last = core.theta
		s_last = core.s
	assert_true(seam_crossed, "the run includes a seam crossing")


func test_swept_step_at_dt_max_late_in_the_ramp_is_two_and_a_half_units() -> void:
	var core: BallCore = _core()
	for i: int in 905:
		core.step(0.1, 1.0 if (i / 3) % 2 == 0 else -1.0, true, SENSOR)
		if core.t_run >= 90.0 + 1e-9 and i > 901:
			assert_almost_eq(absf(core.s - core.s_prev), 2.5, 1e-9)
		assert_true(absf(BallMath.wrap_angle(core.theta - core.theta_prev)) <= 0.3 + 1e-9)
	assert_gte(core.t_run, 90.0)


func test_radius_is_point_four_and_omega_is_zero_at_zero_dt() -> void:
	var core: BallCore = _core()
	core.step(DT60, 1.0, true, SENSOR)
	assert_almost_eq(core.radius, 0.4, 1e-9)
	core.step(0.0, 1.0, true, SENSOR)
	assert_eq(core.omega, 0.0)


func test_omega_on_snap_frame_is_applied_step_over_dt() -> void:
	var core: BallCore = _core()
	var snapped: bool = false
	for _i: int in 120:
		var before: float = core.phi
		core.step(DT60, 0.5, true, SENSOR)
		assert_almost_eq(core.omega, (core.phi - before) / DT60, 1e-4)
		if core.phi == PI / 2.0 and before != PI / 2.0:
			snapped = true
	assert_true(snapped, "a snap frame occurred")
