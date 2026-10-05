## Story 007: run_reset reseed, determinism and no side effects (GDD AC-17, AC-18, AC-20; Core Rule 11).
extends GutTest

const Fx = preload("res://tests/support/pattern_fixture.gd")
const Recorder = preload("res://tests/support/pattern_call_recorder.gd")
const RunIds = preload("res://tests/support/data/pattern_run_ids.gd")
## Run times (s) of the scripted calls, cycling through the three tiers.
const SCRIPT_TIMES: Array[float] = [0.0, 5.0, 20.0, 50.0, 95.0, 120.0, 10.0, 200.0]


func _make(run_id: int, rec: Recorder, grace: float = 11.0, order: Array[int] = []) -> PatternCore:
	var shuffler: Fx.ScriptedShuffler = Fx.make_scripted_shuffler(order)
	var shuffle: Callable = Callable(shuffler, "shuffle") if not order.is_empty() else Callable()
	var core: PatternCore = PatternCore.new(
		PatternConfig.new(), Fx.L, Callable(rec, "run_time"), Callable(), grace, shuffle
	)
	core.set_meta(&"rec", rec)
	core.set_meta(&"shuffler", shuffler)
	core.set_library(Fx.make_compiled_library())
	core.on_run_reset(run_id)
	return core


## 40 scripted calls: segment 0..19 twice with a changing run time; a reset with the same id at call 20.
func _run_script(core: PatternCore, rec: Recorder, run_id: int) -> Array[String]:
	var out: Array[String] = []
	for i: int in range(40):
		if i == 20:
			core.on_run_reset(run_id)
		rec.value = SCRIPT_TIMES[i % SCRIPT_TIMES.size()]
		var seg: int = i % 20
		var specs: Array[HazardSpec] = core.hazards_for_segment(seg)
		var line: String = "%d:%s:%d" % [seg, core.last_chunk_id(), core.last_chunk_base()]
		for spec: HazardSpec in specs:
			line += ":%s:%s" % [spec.hazard_type, spec.pieces]
		out.append(line)
	return out


func _opening(core: PatternCore, rec: Recorder, count: int, run_time: float) -> Array[String]:
	var out: Array[String] = []
	for seg: int in range(count):
		rec.value = run_time
		core.hazards_for_segment(seg)
		out.append("%s:%d" % [core.last_chunk_id(), core.last_chunk_base()])
	return out


func test_same_run_id_script_is_bit_identical() -> void:
	var rec_a: Recorder = Recorder.new()
	var rec_b: Recorder = Recorder.new()
	var a: Array[String] = _run_script(_make(RunIds.RUN_IDS[0], rec_a), rec_a, RunIds.RUN_IDS[0])
	var b: Array[String] = _run_script(_make(RunIds.RUN_IDS[0], rec_b), rec_b, RunIds.RUN_IDS[0])
	assert_eq(a.size(), 40)
	assert_eq(a, b)


func test_mid_sequence_reset_with_same_id_reproduces_the_opening() -> void:
	var rec: Recorder = Recorder.new()
	var core: PatternCore = _make(RunIds.RUN_IDS[3], rec)
	var first: Array[String] = _opening(core, rec, 10, 5.0)
	core.on_run_reset(RunIds.RUN_IDS[3])
	var again: Array[String] = _opening(core, rec, 10, 5.0)
	assert_eq(again, first)


func test_different_run_id_differs_in_first_draw_for_some_pair() -> void:
	var differing: int = 0
	for k: int in range(10):
		var a: PatternCore = _make(RunIds.RUN_IDS[2 * k], Recorder.new())
		var b: PatternCore = _make(RunIds.RUN_IDS[2 * k + 1], Recorder.new())
		a.hazards_for_segment(0)
		b.hazards_for_segment(0)
		if a.last_chunk_id() != b.last_chunk_id():
			differing += 1
	assert_gt(differing, 0)


func test_scripts_call_only_read_accessors() -> void:
	var rec: Recorder = Recorder.new()
	var core: PatternCore = _make(RunIds.RUN_IDS[1], rec)
	_run_script(core, rec, RunIds.RUN_IDS[1])
	assert_gt(rec.calls.size(), 0)
	assert_true(rec.only_called([&"run_time"]))


func test_repeated_index_does_not_advance_state() -> void:
	var single: PatternCore = _make(RunIds.RUN_IDS[5], Recorder.new())
	var repeated: PatternCore = _make(RunIds.RUN_IDS[5], Recorder.new())
	var ids_single: Array[String] = []
	var ids_repeated: Array[String] = []
	for seg: int in range(12):
		single.hazards_for_segment(seg)
		ids_single.append(str(single.last_chunk_id()))
		repeated.hazards_for_segment(seg)
		repeated.hazards_for_segment(seg)
		ids_repeated.append(str(repeated.last_chunk_id()))
	assert_eq(ids_repeated, ids_single)


func test_reset_mid_rev2_draws_fresh_intro_without_residue() -> void:
	var rec: Recorder = Recorder.new()
	rec.value = 100.0
	var core: PatternCore = _make(RunIds.RUN_IDS[7], rec, 0.0, [8])
	var first_specs: Array[HazardSpec] = core.hazards_for_segment(0)
	core.hazards_for_segment(1)
	assert_eq(core.last_chunk_id(), &"8", "REV2 was delivered (indices 0 and 1)")
	assert_eq(first_specs.size(), 1)
	core.on_run_reset(RunIds.RUN_IDS[8])
	var fresh_rec: Recorder = Recorder.new()
	var fresh: PatternCore = _make(RunIds.RUN_IDS[8], fresh_rec, 0.0, [8])
	var got: Array[String] = _opening(core, rec, 6, 0.0)
	var want: Array[String] = _opening(fresh, fresh_rec, 6, 0.0)
	assert_eq(got, want)
	assert_true(["1", "2", "3", "4"].has(got[0].split(":")[0]), "fresh INTRO draw, no REV2 residue")
