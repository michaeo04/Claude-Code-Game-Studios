## Story PS-001: PlatformMath pure functions (F2 haptic gate, F3 effective, interval, F4 fps).
extends GutTest

const TOL: float = 1e-6
const MIN_INTERVAL_S: float = 0.05
const HAPTIC_MAX_MS: int = 200
const MIN_US: int = 50000
const NONE: int = PlatformMath.NO_LAST_US


## Gate with a pulse played at 0 that ends at 30000 with priority 1.
func _gate(now: int, prio: int, dur: int = 30, min_us: int = MIN_US, last_end: int = 30000) -> bool:
	return PlatformMath.haptic_gate(true, true, dur, prio, now, 0, last_end, 1, min_us)


func test_gate_interval_boundary_49999_drops_50000_and_50001_play() -> void:
	assert_false(_gate(49999, 1))
	assert_true(_gate(50000, 1))
	assert_true(_gate(50001, 1))


func test_gate_pulse_end_boundary_60000_drops_80000_plays() -> void:
	# last pulse 80 ms ends at 80000; the interval (50000) has already elapsed at 60000.
	assert_false(_gate(60000, 1, 30, MIN_US, 80000))
	assert_true(_gate(80000, 1, 30, MIN_US, 80000))


func test_gate_priority_bypass_2_plays_1_and_0_drop() -> void:
	assert_true(_gate(20000, 2))
	assert_false(_gate(20000, 1))
	assert_false(_gate(20000, 0))


func test_gate_first_pulse_with_no_last_plays() -> void:
	assert_true(PlatformMath.haptic_gate(true, true, 30, 0, 0, NONE, 0, 0, MIN_US))


func test_gate_clock_anomaly_now_before_last_plays() -> void:
	assert_true(PlatformMath.haptic_gate(true, true, 30, 0, 1000, 5000, 90000, 9, MIN_US))


func test_gate_min_us_zero_still_waits_for_pulse_end() -> void:
	assert_false(_gate(129999, 1, 30, 0, 130000))
	assert_true(_gate(130000, 1, 30, 0, 130000))


func test_gate_disabled_or_inattentive_drops_even_with_prio_9() -> void:
	assert_false(PlatformMath.haptic_gate(false, true, 30, 9, 100000, 0, 30000, 1, MIN_US))
	assert_false(PlatformMath.haptic_gate(true, false, 30, 9, 100000, 0, 30000, 1, MIN_US))


func test_gate_zero_or_negative_duration_drops_even_with_prio_9() -> void:
	assert_false(PlatformMath.haptic_gate(true, true, 0, 9, 100000, NONE, 0, 0, MIN_US))
	assert_false(PlatformMath.haptic_gate(true, true, -1, 9, 100000, NONE, 0, 0, MIN_US))


func test_gate_gdd_example_sequence() -> void:
	# NEAR_MISS at 0 plays; HIT (80 ms, prio 2) at 20000 plays; NEAR_MISS at 60000 drops; at 100000 plays.
	assert_true(PlatformMath.haptic_gate(true, true, 30, 1, 0, NONE, 0, 0, MIN_US))
	assert_true(PlatformMath.haptic_gate(true, true, 80, 2, 20000, 0, 30000, 1, MIN_US))
	assert_false(PlatformMath.haptic_gate(true, true, 30, 1, 60000, 20000, 100000, 2, MIN_US))
	assert_true(PlatformMath.haptic_gate(true, true, 30, 1, 100000, 20000, 100000, 2, MIN_US))


func test_interval_us_converts_seconds_once() -> void:
	assert_eq(PlatformMath.interval_us(MIN_INTERVAL_S), 50000)
	assert_eq(PlatformMath.interval_us(0.08), 80000)
	assert_eq(PlatformMath.interval_us(0.5), 500000)
	assert_eq(PlatformMath.interval_us(0.0), 0)


func test_effective_duration_exact_values() -> void:
	var expected: Array[int] = [200, 200, 200, 1, 0, 0]
	var inputs: Array[int] = [500, 201, 200, 1, 0, -5]
	for i: int in inputs.size():
		assert_eq(int(PlatformMath.effective(inputs[i], 0.5, HAPTIC_MAX_MS).x), expected[i], "dur %d" % inputs[i])


func test_effective_amplitude_exact_values() -> void:
	var inputs: Array[float] = [0.5, 0.0, 1.0, 1.0000001, 2.0, -0.0001, -1.0]
	var expected: Array[float] = [0.5, 0.0, 1.0, 1.0, 1.0, -1.0, -1.0]
	for i: int in inputs.size():
		assert_eq(PlatformMath.effective(100, inputs[i], HAPTIC_MAX_MS).y, expected[i], "amp %s" % inputs[i])


func test_effective_max_50_clamps_dur_80_to_50() -> void:
	assert_eq(int(PlatformMath.effective(80, 0.5, 50).x), 50)


func test_fps_eff_gdd_table() -> void:
	assert_almost_eq(PlatformMath.fps_eff(60.0, 60.0), 60.0, TOL)
	assert_almost_eq(PlatformMath.fps_eff(60.0, 120.0), 60.0, TOL)
	assert_almost_eq(PlatformMath.fps_eff(60.0, 30.0), 30.0, TOL)
	assert_almost_eq(PlatformMath.fps_eff(60.0, 59.94), 59.94, TOL)
	assert_almost_eq(PlatformMath.fps_eff(0.0, 120.0), 120.0, TOL)
	assert_almost_eq(PlatformMath.fps_eff(-1.0, 120.0), 120.0, TOL)


func test_fps_eff_unknown_refresh_gives_max_fps() -> void:
	for hz: float in [0.0, -1.0, NAN, INF]:
		assert_almost_eq(PlatformMath.fps_eff(60.0, hz), 60.0, TOL)


func test_fps_eff_both_unknown_gives_zero_and_frame_time_zero() -> void:
	assert_eq(PlatformMath.fps_eff(0.0, 0.0), 0.0)
	assert_eq(PlatformMath.fps_eff(0.0, INF), 0.0)
	assert_eq(PlatformMath.frame_time(PlatformMath.fps_eff(0.0, 0.0)), 0.0)


func test_frame_time_is_1000_over_fps_not_rounded() -> void:
	assert_almost_eq(PlatformMath.frame_time(30.0), 1000.0 / 30.0, TOL)
	assert_almost_eq(PlatformMath.frame_time(59.94), 1000.0 / 59.94, TOL)
	assert_true(absf(PlatformMath.frame_time(59.94) - 16.683) > 1e-5)
