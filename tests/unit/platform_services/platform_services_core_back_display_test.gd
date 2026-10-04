## PlatformCore Back signal and display facts (platform-services story 006; GDD AC-9, AC-10).
extends GutTest

const Rig = preload("res://tests/support/platform_rig.gd")

var _seen_refresh: Array[float] = []


func _facts(safe: Rect2i, refresh: float) -> Dictionary:
	return {
		"safe_area": safe,
		"screen_size": Vector2i(1080, 1920),
		"viewport_size": Vector2i(540, 960),
		"refresh_rate": refresh,
	}


func _rig_with(facts: Dictionary, fis: bool) -> Rig:
	var rig: Rig = Rig.new(fis)
	rig.facts = facts
	rig.core = PlatformCore.new(fis, rig.clock.as_callable(), rig.sink.sink, rig.vibrate, rig.display, Rig.haptics_config())
	rig.core.app_interrupted.connect(rig._on_interrupted)
	rig.core.app_backgrounded.connect(rig._on_backgrounded)
	rig.core.app_foregrounded.connect(rig._on_foregrounded)
	rig.core.app_returned.connect(rig._on_returned)
	rig.order.clear()
	rig.signals.clear()
	return rig


func _count_back(core: PlatformCore) -> Array[int]:
	var counter: Array[int] = [0]
	core.back_pressed.connect(func() -> void: counter[0] += 1)
	return counter


func _enter_state(core: PlatformCore, state: int) -> void:
	match state:
		1:
			core.on_focus_out()
		2:
			core.on_paused()
		3:
			core.on_focus_out()
			core.on_paused()


func test_back_emits_once_per_call_in_all_four_states() -> void:
	for state: int in 4:
		var rig: Rig = Rig.new(false)
		_enter_state(rig.core, state)
		var a: Array[int] = _count_back(rig.core)
		var b: Array[int] = _count_back(rig.core)
		var att: bool = rig.core.attentive
		var sus: bool = rig.core.suspended
		rig.take()
		rig.core.on_back_requested()
		assert_eq(a[0], 1, "state %d first call" % state)
		rig.core.on_back_requested()
		assert_eq(a[0], 2, "state %d two calls" % state)
		assert_eq(b[0], 2, "state %d second listener" % state)
		assert_eq(rig.core.attentive, att)
		assert_eq(rig.core.suspended, sus)
		assert_eq(rig.take(), "-", "no lifecycle signal")


func test_back_does_not_change_lifecycle_sequence() -> void:
	var with_back: Rig = Rig.new(false)
	var without: Rig = Rig.new(false)
	for r: Rig in [with_back, without]:
		r.core.on_focus_out()
		if r == with_back:
			r.core.on_back_requested()
		r.core.on_paused()
		if r == with_back:
			r.core.on_back_requested()
		r.core.on_resumed()
		r.core.on_focus_in()
	assert_eq(with_back.order, without.order)


func test_display_read_once_at_construction_without_signal() -> void:
	var rig: Rig = Rig.new(true)
	rig.facts = _facts(Rect2i(0, 132, 1080, 1788), 120.0)
	rig.order.clear()
	var core: PlatformCore = PlatformCore.new(true, rig.clock.as_callable(), rig.sink.sink, rig.vibrate, rig.display, Rig.haptics_config())
	assert_eq(rig.order, ["read"] as Array[String])
	assert_eq(core.refresh_rate, 120.0)
	assert_eq(core.screen_size, Vector2i(1080, 1920))


func test_no_regaining_edge_reads_nothing() -> void:
	var rig: Rig = _rig_with(_facts(Rect2i(), 60.0), true)
	rig.core.on_focus_out()
	rig.core.on_focus_out()
	rig.core.on_paused()
	assert_eq(rig.order, ["INT", "BG"] as Array[String])


func test_regaining_edge_reads_once_before_signals() -> void:
	var rig: Rig = _rig_with(_facts(Rect2i(), 60.0), true)
	rig.core.on_focus_out()
	rig.order.clear()
	rig.core.on_focus_in()
	assert_eq(rig.order, ["read", "FG", "RET"] as Array[String])


func test_fis_false_focus_in_gives_read_then_ret() -> void:
	var rig: Rig = _rig_with(_facts(Rect2i(), 60.0), false)
	rig.core.on_focus_out()
	rig.order.clear()
	rig.core.on_focus_in()
	assert_eq(rig.order, ["read", "RET"] as Array[String])


func _on_ret_record(core: PlatformCore) -> void:
	_seen_refresh.append(core.refresh_rate)


func test_handler_sees_new_values() -> void:
	var rig: Rig = _rig_with(_facts(Rect2i(), 120.0), true)
	assert_eq(rig.core.refresh_rate, 120.0)
	rig.core.on_focus_out()
	rig.facts = _facts(Rect2i(), 60.0)
	_seen_refresh.clear()
	rig.core.app_returned.connect(_on_ret_record.bind(rig.core))
	rig.core.on_focus_in()
	assert_eq(_seen_refresh, [60.0] as Array[float])


func test_empty_safe_area_becomes_full_screen() -> void:
	var rig: Rig = _rig_with(_facts(Rect2i(), 60.0), true)
	assert_eq(rig.core.safe_area, Rect2i(0, 0, 1080, 1920))


func test_non_empty_safe_area_unchanged_and_viewport_unconverted() -> void:
	var rig: Rig = _rig_with(_facts(Rect2i(0, 132, 1080, 1788), 60.0), true)
	assert_eq(rig.core.safe_area, Rect2i(0, 132, 1080, 1788))
	assert_eq(rig.core.viewport_size, Vector2i(540, 960))
	assert_eq(rig.core.screen_size, Vector2i(1080, 1920))


func test_unknown_refresh_exposed_raw_and_f4_gives_max_fps() -> void:
	for hz: float in [0.0, -1.0]:
		var rig: Rig = _rig_with(_facts(Rect2i(), hz), true)
		assert_eq(rig.core.refresh_rate, hz)
		assert_almost_eq(PlatformMath.fps_eff(60.0, rig.core.refresh_rate), 60.0, 1e-6)
