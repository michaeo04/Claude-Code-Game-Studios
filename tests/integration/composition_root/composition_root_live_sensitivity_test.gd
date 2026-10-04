## Story CRF-003: a Settings `tilt_sensitivity` change reaches `TiltCore` live, before the next poll.
extends GutTest

const Fixture = preload("res://tests/support/tilt_fixture.gd")
const Fx = preload("res://tests/support/settings_fixtures.gd")

const POSE_DEG: float = 4.0


var _getter: Fx.Spy
var _setter: Fx.Spy
var _logs: Fx.LogSpy


func _rig() -> Array:
	var fx: Fixture = Fixture.new()
	fx.live_core(0.0)
	fx.tick(POSE_DEG, 80)
	_getter = Fx.make_get_value_stub({})
	_setter = Fx.make_set_value_stub()
	_logs = Fx.make_log_spy()
	var settings: SettingsCore = SettingsCore.new(_getter.get_value, _setter.set_value, _logs.record)
	var adapter: TiltSettingsAdapter = TiltSettingsAdapter.new(fx.core)
	settings.setting_changed.connect(adapter.on_setting_changed)
	return [fx, settings, adapter]


func test_mid_run_change_scales_next_steer_and_nothing_else() -> void:
	var rig: Array = _rig()
	var fx: Fixture = rig[0]
	var settings: SettingsCore = rig[1]
	var core: TiltCore = fx.core
	var steer_before: float = core.get_steer()
	var phi0: float = core.get_phi0()
	var count: int = core.get_sample_count()
	settings.set_value("tilt_sensitivity", 2.0)
	assert_eq(core.get_steer(), steer_before, "published steer is unchanged until the next poll")
	assert_eq(core.get_phi0(), phi0)
	assert_eq(core.get_sample_count(), count)
	fx.tick(POSE_DEG, 1)
	var cfg: TiltConfig = TiltConfig.new()
	var expected: float = TiltMath.steer(core.get_phi_f(), cfg.tilt_full_scale, cfg.dead_zone, cfg.curve_exp, 2.0)
	assert_almost_eq(core.get_steer(), expected, 1e-6)
	assert_gt(core.get_steer(), steer_before)
	assert_eq(core.get_phi0(), phi0)
	assert_true(core.get_valid())


func test_set_sensitivity_out_of_range_clamps_with_one_log() -> void:
	var fx: Fixture = Fixture.new()
	fx.live_core(0.0)
	fx.tick(POSE_DEG, 10)
	var count: int = fx.core.get_sample_count()
	var before: int = fx.sink.count()
	fx.core.set_sensitivity(5.0)
	assert_eq(fx.sink.count(), before + 1)
	assert_eq(fx.sink.entries[before][1], &"SETTING_CLAMPED")
	assert_eq(fx.core.get_sample_count(), count)
	fx.core.set_sensitivity(NAN)
	assert_eq(fx.sink.count(), before + 2)


func test_other_keys_are_ignored() -> void:
	var rig: Array = _rig()
	var fx: Fixture = rig[0]
	var settings: SettingsCore = rig[1]
	settings.set_value("haptics_intensity", 0.3)
	fx.tick(POSE_DEG, 1)
	var cfg: TiltConfig = TiltConfig.new()
	assert_almost_eq(fx.core.get_steer(), TiltMath.steer(fx.core.get_phi_f(), cfg.tilt_full_scale, cfg.dead_zone, cfg.curve_exp, 1.0), 1e-6)
