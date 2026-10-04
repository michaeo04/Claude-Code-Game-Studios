## Story TI-009: sensor-loss dropout hold F6 (AC-30, AC-31, AC-44).
extends GutTest

const Fixture = preload("res://tests/support/tilt_fixture.gd")

const S = TiltCore.State
const STEER_TOL: float = 1e-4
const DEG_TOL: float = 1e-6


## Live core at 50 Hz with neutral 0 and 50 ticks at 20.3 deg (steer 0.8).
func _steady_50hz() -> Fixture:
	var fx: Fixture = Fixture.new()
	fx.step_us = 20000
	fx.live_core(0.0)
	fx.tick(20.3, 50)
	return fx


func _config(hold: float) -> TiltConfig:
	var cfg: TiltConfig = TiltConfig.new()
	cfg.sensor_sign = 1
	cfg.dropout_hold = hold
	return cfg


func test_hold_through_the_fifth_invalid_poll_then_unavailable_ac30() -> void:
	var fx: Fixture = _steady_50hz()
	assert_almost_eq(fx.core.get_steer(), 0.8, STEER_TOL)
	var held: float = fx.core.get_steer()
	fx.availability.clear()
	for i: int in 5:
		fx.tick_invalid(1)
		assert_eq(fx.core.get_steer(), held, "poll %d" % (i + 1))
		assert_true(fx.core.get_valid())
		assert_eq(fx.core.get_state(), S.LIVE)
	assert_eq(fx.core.get_invalid_us(), 100000)
	assert_eq(fx.availability.size(), 0)
	fx.tick_invalid(1)
	assert_eq(fx.core.get_invalid_us(), 120000)
	assert_eq(fx.core.get_state(), S.UNAVAILABLE)
	assert_false(fx.core.get_valid())
	assert_eq(fx.core.get_steer(), 0.0)
	assert_true(fx.core.get_neutral_stale())
	assert_eq(fx.availability, [false] as Array[bool])
	fx.tick_invalid(3)
	assert_eq(fx.availability.size(), 1, "no second signal")


func test_single_invalid_poll_changes_nothing_ac30() -> void:
	var fx: Fixture = _steady_50hz()
	var held: float = fx.core.get_steer()
	fx.availability.clear()
	fx.tick_invalid(1)
	assert_eq(fx.core.get_steer(), held)
	assert_true(fx.core.get_valid())
	assert_eq(fx.availability.size(), 0)


func test_return_within_hold_continues_the_filter_ac31() -> void:
	var fx: Fixture = Fixture.new()
	fx.step_us = 20000
	fx.live_core(0.0)
	fx.tick(20.3, 5)
	var before: float = fx.core.get_phi_f()
	fx.tick_invalid(3)
	assert_eq(fx.core.get_phi_f(), before, "invalid polls do not move phi_f")
	fx.tick(20.3, 1)
	var alpha: float = 1.0 - exp(-0.02 / 0.05)
	assert_almost_eq(fx.core.get_phi_f(), before + alpha * (20.3 - before), DEG_TOL)
	assert_eq(fx.core.get_invalid_polls(), 0)
	assert_eq(fx.core.get_invalid_us(), 0)


func test_return_from_unavailable_restarts_the_filter_ac31() -> void:
	var fx: Fixture = Fixture.new()
	fx.step_us = 20000
	fx.live_core(0.0)
	fx.tick(20.3, 5)
	fx.tick_invalid(8)
	assert_eq(fx.core.get_state(), S.UNAVAILABLE)
	fx.availability.clear()
	fx.tick(10.0, 1)
	assert_eq(fx.core.get_state(), S.LIVE)
	assert_eq(fx.availability, [true] as Array[bool])
	assert_almost_eq(fx.core.get_phi_f(), 10.0, DEG_TOL)
	assert_true(fx.core.get_neutral_stale(), "no capture without a capture event")


func test_invalid_polls_advance_the_previous_stamp_ac31() -> void:
	var fx: Fixture = Fixture.new()
	fx.step_us = 20000
	fx.live_core(0.0)
	fx.tick_invalid(2)
	fx.tick(10.0, 1)
	assert_almost_eq(fx.core.get_last_dt(), 0.02, DEG_TOL)


func test_single_invalid_poll_after_a_long_gap_stays_live_ac44a() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(0.0)
	fx.clock.advance_us(200000 - fx.step_us)
	fx.tick_invalid(1)
	assert_eq(fx.core.get_state(), S.LIVE)
	assert_true(fx.core.get_valid())
	assert_eq(fx.core.get_invalid_us(), 100000)
	assert_eq(fx.core.get_invalid_polls(), 1)


func test_three_polls_a_tenth_apart_give_unavailable_on_the_third_ac44b() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(0.0)
	fx.step_us = 100000
	fx.tick_invalid(2)
	assert_eq(fx.core.get_state(), S.LIVE)
	fx.tick_invalid(1)
	assert_eq(fx.core.get_invalid_us(), 300000)
	assert_eq(fx.core.get_state(), S.UNAVAILABLE)


func test_zero_hold_needs_three_polls_ac44c() -> void:
	var fx: Fixture = Fixture.new(_config(0.0))
	fx.live_core(0.0)
	fx.tick_invalid(1)
	assert_eq(fx.core.get_state(), S.LIVE)
	fx.tick_invalid(1)
	assert_eq(fx.core.get_state(), S.LIVE)
	fx.tick_invalid(1)
	assert_eq(fx.core.get_state(), S.UNAVAILABLE)


func test_hitch_counts_as_at_most_dt_max_and_one_poll_ac44d() -> void:
	var fx: Fixture = Fixture.new(_config(0.3))
	fx.live_core(0.0)
	fx.clock.advance_us(500000 - fx.step_us)
	fx.tick_invalid(1)
	assert_eq(fx.core.get_invalid_us(), 100000)
	fx.step_us = 20000
	fx.tick_invalid(2)
	assert_eq(fx.core.get_invalid_us(), 140000)
	assert_eq(fx.core.get_invalid_polls(), 3)
	assert_eq(fx.core.get_state(), S.LIVE)


func test_stamp_rule_reject_counts_nothing_ac44d() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(0.0)
	fx.tick_invalid(1)
	fx.core.poll()
	fx.core.poll()
	assert_eq(fx.core.get_invalid_polls(), 1)
	assert_eq(fx.core.get_invalid_us(), fx.step_us)
