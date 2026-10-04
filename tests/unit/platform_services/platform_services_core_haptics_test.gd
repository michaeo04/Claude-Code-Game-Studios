## PlatformCore haptic call flow, drop causes and counters (platform-services story 005; GDD AC-4).
extends GutTest

const Rig = preload("res://tests/support/platform_rig.gd")

const NEAR: int = HapticsConfig.Kind.NEAR_MISS
const HIT: int = HapticsConfig.Kind.HIT
const TAP: int = HapticsConfig.Kind.UI_TAP


func _at(rig: Rig, us: int, kind: int) -> bool:
	rig.clock.now_us = us
	return rig.core.haptic(kind)


func _drops(rig: Rig) -> Array[int]:
	var out: Array[int] = []
	for cause in range(5):
		out.append(rig.core.haptic_drops(cause))
	return out


func test_hit_plays_with_config_values() -> void:
	var rig: Rig = Rig.new(true)
	assert_true(_at(rig, 0, HIT))
	assert_eq(rig.vibrations.size(), 1)
	assert_eq(rig.vibrations[0][0], 80)
	assert_almost_eq(rig.vibrations[0][1] as float, 1.0, 1e-6)
	assert_eq(rig.core.last_played_us, 0)
	assert_eq(rig.core.last_end_us, 80000)


func test_near_miss_after_hit_is_throttled_until_pulse_ends() -> void:
	var rig: Rig = Rig.new(true)
	_at(rig, 0, HIT)
	assert_false(_at(rig, 30000, NEAR))
	assert_eq(rig.core.haptic_drops(PlatformCore.DropCause.THROTTLED), 1)
	assert_eq(rig.core.last_played_us, 0)
	assert_false(_at(rig, 79999, NEAR))
	assert_true(_at(rig, 80000, NEAR))
	assert_eq(rig.vibrations.size(), 2)


func test_hit_preempts_near_miss_then_equal_priority_drops() -> void:
	var rig: Rig = Rig.new(true)
	assert_true(_at(rig, 0, NEAR))
	assert_true(_at(rig, 20000, HIT))
	assert_eq(rig.vibrations[1][0], 80)
	assert_almost_eq(rig.vibrations[1][1] as float, 1.0, 1e-6)
	assert_false(_at(rig, 40000, HIT))
	assert_false(_at(rig, 60000, NEAR))
	assert_eq(rig.core.haptic_drops(PlatformCore.DropCause.THROTTLED), 2)
	assert_eq(rig.vibrations.size(), 2)


func test_same_priority_respects_interval_and_ui_tap_is_dropped_inside() -> void:
	var rig: Rig = Rig.new(true)
	assert_true(_at(rig, 0, NEAR))
	assert_false(_at(rig, 40000, NEAR))
	assert_true(_at(rig, 50000, NEAR))
	var rig2: Rig = Rig.new(true)
	_at(rig2, 0, NEAR)
	assert_false(_at(rig2, 10000, TAP))
	assert_eq(rig2.core.haptic_drops(PlatformCore.DropCause.THROTTLED), 1)


func test_unknown_kind_drops_logs_once_and_does_not_vibrate() -> void:
	var rig: Rig = Rig.new(true)
	assert_false(_at(rig, 0, 99))
	assert_eq(_drops(rig), [1, 0, 0, 0, 0] as Array[int])
	assert_eq(rig.vibrations.size(), 0)
	assert_eq(rig.sink.count(), 1)
	assert_eq(rig.sink.entries[0][0], LogLevel.ERROR)
	assert_eq(rig.sink.entries[0][1], RateLimitedLog.UNKNOWN_HAPTIC_KIND)
	assert_eq(rig.sink.entries[0][2], "99")
	assert_true(_at(rig, 0, HIT), "allowed call at the same stamp plays")
	assert_eq(rig.core.last_played_us, 0)


func test_disabled_drops_without_log_then_plays_when_enabled() -> void:
	var rig: Rig = Rig.new(true)
	rig.core.set_haptics_enabled(false)
	assert_false(_at(rig, 0, HIT))
	assert_eq(_drops(rig), [0, 1, 0, 0, 0] as Array[int])
	assert_eq(rig.sink.count(), 0)
	rig.core.set_haptics_enabled(true)
	assert_true(_at(rig, 0, HIT))


func test_not_attentive_drops_without_log_and_is_never_queued() -> void:
	var rig: Rig = Rig.new(true)
	rig.core.on_focus_out()
	assert_false(_at(rig, 0, HIT))
	assert_eq(_drops(rig), [0, 0, 1, 0, 0] as Array[int])
	assert_eq(rig.sink.count(), 0)
	rig.core.on_focus_in()
	assert_eq(rig.vibrations.size(), 0, "nothing queued across the interruption")
	assert_true(_at(rig, 0, HIT))


func test_zero_duration_drops_without_log() -> void:
	var cfg: HapticsConfig = Rig.haptics_config()
	cfg.ui_tap_duration_ms = 0.0
	var rig: Rig = Rig.new(true, cfg)
	assert_false(_at(rig, 0, TAP))
	assert_eq(_drops(rig), [0, 0, 0, 1, 0] as Array[int])
	assert_eq(rig.sink.count(), 0)
	assert_true(_at(rig, 0, HIT))


func test_drop_order_unknown_before_disabled_before_not_attentive() -> void:
	var rig: Rig = Rig.new(true)
	rig.core.set_haptics_enabled(false)
	rig.core.on_focus_out()
	_at(rig, 0, 99)
	assert_eq(_drops(rig), [1, 0, 0, 0, 0] as Array[int])
	_at(rig, 0, HIT)
	assert_eq(_drops(rig), [1, 1, 0, 0, 0] as Array[int])
	rig.core.set_haptics_enabled(true)
	_at(rig, 0, HIT)
	assert_eq(_drops(rig), [1, 1, 1, 0, 0] as Array[int])
	rig.core.on_focus_in()
	var cfg: HapticsConfig = Rig.haptics_config()
	cfg.hit_duration_ms = 10.0
	assert_eq(rig.core.haptic_drops(99), 0, "unknown cause reads 0")


func test_zero_duration_is_checked_before_throttle() -> void:
	var cfg: HapticsConfig = Rig.haptics_config()
	cfg.ui_tap_duration_ms = 0.0
	var rig: Rig = Rig.new(true, cfg)
	_at(rig, 0, HIT)
	_at(rig, 10000, TAP)
	assert_eq(_drops(rig), [0, 0, 0, 1, 0] as Array[int])


func test_clock_anomaly_plays_and_rebases_stamps() -> void:
	var rig: Rig = Rig.new(true)
	_at(rig, 100000, HIT)
	assert_true(_at(rig, 99999, NEAR))
	assert_eq(rig.core.last_played_us, 99999)
	assert_eq(rig.core.last_end_us, 99999 + 30000)
	assert_eq(rig.core.last_prio, 1)


func test_disabling_mid_pulse_makes_no_extra_vibrate_call() -> void:
	var rig: Rig = Rig.new(true)
	_at(rig, 0, HIT)
	rig.core.set_haptics_enabled(false)
	assert_eq(rig.vibrations.size(), 1)


func test_intensity_scales_amplitude() -> void:
	var rig: Rig = Rig.new(true)
	rig.core.set_haptics_intensity(0.5)
	_at(rig, 0, NEAR)
	assert_almost_eq(rig.vibrations[0][1] as float, 0.25, 1e-6)


func test_unknown_kind_1000_consecutive_calls_log_one_line_per_window() -> void:
	var rig: Rig = Rig.new(true)
	for i: int in range(1000):
		_at(rig, i * 1000, 99)
	assert_eq(rig.core.haptic_drops(PlatformCore.DropCause.UNKNOWN_KIND), 1000, "every call is still counted as a drop")
	assert_eq(rig.sink.count(), 1, "1000 calls over 0.999 s are one window: one line")
	_at(rig, 1_000_000, 99)
	assert_eq(rig.sink.count(), 2, "the next window logs again")
