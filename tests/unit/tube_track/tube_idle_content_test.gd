## Story TT-008: idle scroll step and deterministic segment content (AC-17, AC-18).
extends GutTest

const Spy = preload("res://tests/support/tube_window_spy.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")


func _make(spy: RefCounted) -> TubeWindow:
	var w: TubeWindow = TubeWindow.new(LogSink.new().sink, spy.binder)
	spy.attach(w)
	w.load_map(TubeConfig.new(), 25.0, 0.8)
	return w


## Last bound segment per slot, as a Dictionary slot -> segment.
func _slot_map(spy: RefCounted) -> Dictionary:
	var m: Dictionary = {}
	for b: Array in spy.binds:
		m[b[0]] = b[1]
	return m


func _window_seams(w: TubeWindow, cfg: TubeConfig) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(w.get_first_index(), w.get_last_index() + 1):
		out.append(TubeMath.segment_content(cfg, i))
	return out


func test_idle_step_increments() -> void:
	assert_almost_eq(TubeMath.idle_step(0.0, 1.5, 1.0 / 60.0, 0.1, 12.0), 0.025, 1e-9)
	assert_almost_eq(TubeMath.idle_step(0.0, 1.5, 0.5, 0.1, 12.0), 0.15, 1e-9)
	assert_eq(TubeMath.idle_step(1.0, 1.5, -1.0, 0.1, 12.0), 1.0)
	assert_eq(TubeMath.idle_step(1.0, 1.5, NAN, 0.1, 12.0), 1.0)
	assert_eq(TubeMath.idle_step(1.0, 1.5, INF, 0.1, 12.0), 1.0)


func test_idle_step_wraps_at_segment_length() -> void:
	assert_almost_eq(TubeMath.idle_step(11.99, 1.5, 1.0 / 60.0, 0.1, 12.0), 0.015, 1e-9)


func test_idle_step_result_stays_below_l() -> void:
	var r: float = TubeMath.idle_step(-1e-20, 1.5, 0.0, 0.1, 12.0)
	assert_true(r >= 0.0 and r < 12.0)


func test_tick_idle_minute_gives_zero_run_distance_and_wrapped_offset() -> void:
	var w: TubeWindow = _make(Spy.new())
	for i: int in range(3840):
		w.tick_idle(1.0 / 64.0)
	assert_eq(w.get_s(), 0.0)
	assert_almost_eq(w.get_s_idle(), 6.0, 1e-9)
	for i: int in range(3840):
		w.tick_idle(1.0 / 64.0)
	assert_true(w.get_s_idle() >= 0.0 and w.get_s_idle() < 12.0)


func test_tick_idle_emits_nothing_and_begin_run_discards_offset() -> void:
	var spy: RefCounted = Spy.new()
	var w: TubeWindow = _make(spy)
	spy.clear()
	for i: int in range(100):
		w.tick_idle(1.0 / 60.0)
	assert_eq(spy.events.size(), 0)
	assert_eq(spy.segs.size(), 0)
	assert_gt(w.get_s_idle(), 0.0)
	w.begin_run()
	assert_eq(w.get_s(), 0.0)


func test_segment_content_equal_across_instances() -> void:
	var a: Dictionary = TubeMath.segment_content(TubeConfig.new(), 102)
	var b: Dictionary = TubeMath.segment_content(TubeConfig.new(), 102)
	assert_eq(a, b)
	assert_eq(a["index"], 102)
	assert_almost_eq((a["seam_s"] as Array[float])[0], 102.0 * 12.0 + 6.0, 1e-9)
	assert_eq(TubeMath.segment_content(TubeConfig.new(), -2), TubeMath.segment_content(TubeConfig.new(), -2))


func test_continuous_run_and_reprime_give_same_binds_and_seams() -> void:
	var cfg: TubeConfig = TubeConfig.new()
	var spy_a: RefCounted = Spy.new()
	var wa: TubeWindow = _make(spy_a)
	wa.begin_run()
	var s: float = 0.0
	while s < 1234.5:
		s = minf(s + 2.5, 1234.5)
		wa.advance(s)
	var spy_b: RefCounted = Spy.new()
	var wb: TubeWindow = _make(spy_b)
	wb.begin_run()
	wb.advance(1234.5)
	assert_eq(wa.get_first_index(), 100)
	assert_eq(wb.get_first_index(), 100)
	assert_eq(_slot_map(spy_a), _slot_map(spy_b))
	assert_eq(_window_seams(wa, cfg), _window_seams(wb, cfg))


func test_two_begin_run_cycles_give_identical_binds() -> void:
	var spy: RefCounted = Spy.new()
	var w: TubeWindow = _make(spy)
	spy.clear()
	w.begin_run()
	var first: Array[Array] = spy.binds.duplicate()
	spy.clear()
	w.begin_run()
	assert_eq(spy.binds, first)



func test_tube_track_sources_contain_no_randomness() -> void:
	var scripts: Array[GDScript] = [TubeMath, TubeWindow, TubeConfig]
	for script: GDScript in scripts:
		var text: String = script.source_code
		assert_gt(text.length(), 0, "source readable")
		assert_false(text.contains("randf") or text.contains("RandomNumberGenerator") or text.contains("randi("), script.resource_path)
