## Story PD-013: Pattern wiring (AC-25, AC-26). AC-25 drives the composition-root `_wire()` rows with a real
## `RunStateCore`; AC-26 drives a real `TubeWindow` and a real `ObstacleCore` over a recording provider.
extends GutTest

const Fakes = preload("res://tests/support/rebase_fakes.gd")
const Golden = preload("res://tests/support/pattern_golden.gd")
const Recorder = preload("res://tests/support/pattern_recording_provider.gd")
const ObstacleFixture = preload("res://tests/support/obstacle_fixture.gd")

var _stub: Golden.TimeStub
var _pattern: PatternCore
var _rs: RunStateCore
var _root: GameRoot
var _probe_ids: Array[StringName] = []


func before_each() -> void:
	_stub = Golden.TimeStub.new()
	_pattern = _make_pattern(Golden.SEGMENT_LENGTH)
	_probe_ids.clear()


func after_each() -> void:
	if _root != null:
		_root.free()
		_root = null


func _make_pattern(segment_length: float) -> PatternCore:
	var core: PatternCore = PatternCore.new(PatternConfig.new(), segment_length, Callable(_stub, "get_value"))
	var map: MapConfig = MapConfig.new()
	map.chunk_library = load(Golden.LIBRARY_PATH) as ChunkLibrary
	core.apply_map(map)
	return core


func _wire_root() -> void:
	_rs = RunStateCore.new(RunConfig.new(), func() -> int: return 0, Callable())
	var frame: WorldFrame = WorldFrame.new(WorldFrameConfig.new(), WorldGeometry.new())
	var view: Fakes.View = Fakes.View.new(frame, "v", [] as Array[String])
	_root = GameRoot.new(Callable())
	var overrides: Dictionary = {&"pattern": _pattern}
	assert_true(_root.inject_systems(Fakes.systems(_rs, Fakes.Stub.new(), frame, view, view, overrides)))
	# Rank 2 probe: draws segment 0 and records the chunk id; empty when Pattern was not reseeded first.
	_root.add_wire_row(_rs.run_reset, _probe, GameRoot.RANK_TUBE_OBSTACLE)
	assert_eq(_root._wire(), OK)


func _probe(_run_id: int) -> void:
	_pattern.hazards_for_segment(0)
	_probe_ids.append(_pattern.last_chunk_id())


func _ids_after_reset(run_id: int) -> Array[StringName]:
	_rs.run_reset.emit(run_id)
	var ids: Array[StringName] = [_pattern.last_chunk_id()]
	for index: int in range(1, Golden.INTRO_UNTIL):
		_pattern.hazards_for_segment(index)
		ids.append(_pattern.last_chunk_id())
	return ids


func test_ac25_run_reset_reaches_pattern_before_rank_two_subscribers() -> void:
	_wire_root()
	_rs.run_reset.emit(1)
	assert_eq(_probe_ids.size(), 1, "probe ran once")
	assert_ne(_probe_ids[0], &"", "Pattern was reseeded before the rank 2 probe drew segment 0")


func test_ac25_same_run_id_replays_the_same_chunk_sequence() -> void:
	_wire_root()
	var first: Array[StringName] = _ids_after_reset(7)
	var other: Array[StringName] = _ids_after_reset(8)
	var replay: Array[StringName] = _ids_after_reset(7)
	assert_eq(replay, first, "run_id 7 replays")
	assert_ne(other, first, "run_id 8 differs from run_id 7")


func test_ac25_run_time_drives_the_tier() -> void:
	_wire_root()
	_stub.value = 0.0
	_rs.run_reset.emit(42)
	_pattern.hazards_for_segment(0)
	var intro_id: StringName = _pattern.last_chunk_id()
	_stub.value = Golden.FULL_TIME
	_rs.run_reset.emit(42)
	_pattern.hazards_for_segment(0)
	var full_id: StringName = _pattern.last_chunk_id()
	assert_ne(intro_id, &"")
	assert_ne(full_id, &"")
	var library: ChunkLibrary = load(Golden.LIBRARY_PATH) as ChunkLibrary
	var tiers: Dictionary = {}
	for chunk: ChunkDef in library.chunks:
		tiers[chunk.chunk_id] = chunk.tier
	assert_eq(tiers[intro_id], ChunkDef.Tier.INTRO, "run time 0 draws an INTRO chunk")
	assert_eq(tiers[full_id], ChunkDef.Tier.FULL, "run time 120 draws a FULL chunk")


func test_ac26_provider_called_once_per_entered_segment_in_ascending_order() -> void:
	var cfg: TubeConfig = TubeConfig.new()
	var pattern: PatternCore = _make_pattern(cfg.segment_length)
	pattern.on_run_reset(42)
	var recorder: Recorder = Recorder.new(pattern)
	var obstacle: ObstacleCore = ObstacleFixture.make_core(ObstacleFixture.make_config(), recorder)
	var window: TubeWindow = TubeWindow.new(Callable(), Callable())
	window.load_map(cfg, 25.0, 0.8)
	window.window_primed.connect(obstacle.on_window_primed)
	window.segment_entered_window.connect(obstacle.on_segment_entered_window)
	window.segment_left_window.connect(obstacle.on_segment_left_window)
	# Specs and offsets are read at bind time: the hazards are released once their segment leaves the window.
	var bound_specs: Array[HazardSpec] = []
	var bound_homes: Array[int] = []
	obstacle.hazard_bound.connect(func(hazard_id: int, _footprint: PackedFloat64Array) -> void:
		var spec: HazardSpec = obstacle.spec_of(hazard_id)
		bound_specs.append(spec)
		bound_homes.append(roundi(obstacle.s_offset_of(hazard_id) / cfg.segment_length) + spec.local_segment_index))

	window.begin_run()
	# One segment per call: a jump of N or more segments re-primes instead of recycling.
	for k: int in range(1, 21):
		window.advance(float(k) * cfg.segment_length)

	var first: int = -cfg.segments_behind
	var last: int = 20 + cfg.segments_ahead
	assert_eq(window.get_last_index(), last)
	assert_eq(recorder.queried.size(), last - first + 1, "one call per primed or entered segment")
	for i: int in recorder.queried.size():
		assert_eq(recorder.queried[i], first + i, "ascending, never repeated (call %d)" % i)

	# Hazards bound by Obstacle match the chunk placement: same shared specs, in order, at the right offset.
	assert_gt(bound_specs.size(), 0, "the fixture library places hazards")
	assert_eq(bound_specs.size(), recorder.returned.size(), "every returned spec was bound once")
	for i: int in bound_specs.size():
		assert_same(bound_specs[i], recorder.returned[i], "bound spec %d is the placed spec" % i)
		assert_true(bound_homes[i] >= first and bound_homes[i] <= last, "hazard %d homes inside the range" % i)
