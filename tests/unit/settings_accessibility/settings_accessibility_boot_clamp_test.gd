## Story ST-003: boot-time tilt sensitivity validation and logging (GDD AC-3, AC-7). Fixture range 0.4 / 2.6 / 1.3.
extends GutTest

const Fx = preload("res://tests/support/settings_fixtures.gd")


func _boot(raw: float) -> Array:
	var getter: Fx.Spy = Fx.make_get_value_stub({"tilt_sensitivity": raw})
	var log_spy: Fx.LogSpy = Fx.make_log_spy()
	var core: SettingsCore = Fx.make_settings_core(getter, Fx.make_set_value_stub(), log_spy)
	return [core, log_spy]


func _assert_one_clamp(log_spy: Fx.LogSpy) -> void:
	assert_eq(log_spy.entries.size(), 1)
	assert_eq(log_spy.entries[0][0], SettingsCore.LEVEL_WARNING)
	assert_eq(log_spy.entries[0][1], &"SETTING_CLAMPED")
	assert_eq(log_spy.entries[0][2], "tilt_sensitivity")


func test_in_range_rows_log_nothing() -> void:
	for raw: float in [1.5, 0.4, 2.6]:
		var booted: Array = _boot(raw)
		assert_eq((booted[1] as Fx.LogSpy).entries.size(), 0, "raw %s" % raw)
		assert_almost_eq((booted[0] as SettingsCore).get_tilt_sensitivity(), raw, 1e-6)


func test_out_of_range_rows_clamp_to_bound_with_one_warning() -> void:
	var rows: Array = [[0.1, 0.4], [3.0, 2.6]]
	for row: Array in rows:
		var booted: Array = _boot(row[0] as float)
		assert_almost_eq((booted[0] as SettingsCore).get_tilt_sensitivity(), row[1] as float, 1e-6)
		_assert_one_clamp(booted[1] as Fx.LogSpy)


func test_invalid_rows_fall_back_to_default_with_one_warning() -> void:
	for raw: float in [NAN, INF, -INF, 0.0, -1.0]:
		var booted: Array = _boot(raw)
		assert_almost_eq((booted[0] as SettingsCore).get_tilt_sensitivity(), Fx.FIXTURE_DEFAULT, 1e-6)
		_assert_one_clamp(booted[1] as Fx.LogSpy)


func test_stored_above_max_clamps_once_and_getters_never_relog() -> void:
	var booted: Array = _boot(5.0)
	var core: SettingsCore = booted[0] as SettingsCore
	for i: int in 10:
		assert_almost_eq(core.get_tilt_sensitivity(), 2.6, 1e-6)
	_assert_one_clamp(booted[1] as Fx.LogSpy)
