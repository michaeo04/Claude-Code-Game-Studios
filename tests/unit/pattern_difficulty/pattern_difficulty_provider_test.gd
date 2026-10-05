extends GutTest

const Fixture = preload("res://tests/support/pattern_fixture.gd")

const L: float = 12.0
const SEEDS_30: Array[int] = [
	1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30
]


## Walks the segments one by one for `draws` chunk placements and returns the chunk ids in order.
func _walk(core: PatternCore, draws: int) -> Array[int]:
	var out: Array[int] = []
	var index: int = 0
	for n: int in range(draws):
		core.hazards_for_segment(index)
		var id: int = String(core.last_chunk_id()).to_int()
		out.append(id)
		var length: int = (Fixture.make_chunks()[id - 1] as ChunkDef).segment_count
		for k: int in range(1, length):
			core.hazards_for_segment(index + k)
		index += length
	return out


func _first_s(spec: HazardSpec) -> float:
	return spec.pieces[2]


func test_w3_at_base_five_translates_and_leaves_first_segment_empty() -> void:
	var order: Array[int] = [3]
	var core: PatternCore = Fixture.make_core(
		Fixture.make_run_time_stub(0.0), 1, order
	)
	assert_eq(core.hazards_for_segment(5).size(), 0)
	assert_eq(core.last_chunk_id(), &"3")
	var specs: Array[HazardSpec] = core.hazards_for_segment(6)
	assert_eq(specs.size(), 1)
	var p: PackedFloat64Array = specs[0].pieces
	var world_start: float = p[2] + float(core.last_chunk_base()) * L
	assert_almost_eq(p[0], 0.4127, 1e-6)
	assert_almost_eq(p[1], 5.8705, 1e-6)
	assert_almost_eq(world_start, 74.0, 1e-6)
	assert_almost_eq(p[3] + float(core.last_chunk_base()) * L, 75.0, 1e-6)


func test_rev2_at_base_ten_wall_empty_near_ring() -> void:
	var stub: Fixture.ValueStub = Fixture.make_run_time_stub(0.0)
	var order: Array[int] = [8]
	var core: PatternCore = Fixture.make_core(stub, 1, order)
	core.hazards_for_segment(0)  # grace-restricted opening chunk (never REV2)
	stub.value = 300.0
	var at10: Array[HazardSpec] = core.hazards_for_segment(10)
	assert_eq(core.last_chunk_id(), &"8")
	assert_eq(at10.size(), 1)
	assert_almost_eq(_first_s(at10[0]) + 10.0 * L, 120.5, 1e-6)
	assert_eq(core.hazards_for_segment(11).size(), 0)
	var at12: Array[HazardSpec] = core.hazards_for_segment(12)
	assert_eq(at12.size(), 1)
	assert_almost_eq(_first_s(at12[0]) + 10.0 * L, 147.1, 1e-6)
	assert_almost_eq(at12[0].pieces[3] + 10.0 * L, 148.3, 1e-6)


func test_tier_pools_by_run_time() -> void:
	var cases: Array = [[8.0, 4], [47.0, 6], [300.0, 8]]
	for c: Array in cases:
		var stub: Fixture.ValueStub = Fixture.make_run_time_stub(c[0] as float)
		var core: PatternCore = Fixture.make_core(stub, 11)
		var seen: Dictionary = {}
		for id: int in _walk(core, 50):
			seen[id] = true
			assert_lte(id, c[1] as int, "run_time %s drew %d" % [c[0], id])
		assert_eq(seen.size(), c[1] as int, "every id of the tier appears at run_time %s" % c[0])


func test_full_tier_shows_every_chunk_within_one_bag() -> void:
	var core: PatternCore = Fixture.make_core(Fixture.make_run_time_stub(300.0), 5)
	var seen: Dictionary = {}
	for id: int in _walk(core, 8):
		seen[id] = true
	assert_eq(seen.size(), 8)


func test_every_fixture_chunk_pieces_stay_in_their_home_segment_at_any_base() -> void:
	for chunk_index: int in range(8):
		for base: int in [0, 1, 5, 100]:
			var stub: Fixture.ValueStub = Fixture.make_run_time_stub(300.0)
			var order: Array[int] = [chunk_index + 1]
			var core: PatternCore = Fixture.make_core(
				stub, 3, order, 0.0
			)
			var chunk: ChunkDef = Fixture.make_chunks()[chunk_index]
			for k: int in range(chunk.segment_count):
				for spec: HazardSpec in core.hazards_for_segment(base + k):
					for n: int in range(spec.piece_count()):
						var s0: float = spec.pieces[n * 4 + 2] + float(base) * L
						var s1: float = spec.pieces[n * 4 + 3] + float(base) * L
						assert_eq(floori(s0 / L), base + k)
						assert_eq(floori(s1 / L), base + k)


func test_piece_outside_home_segment_rejected_by_compile() -> void:
	var bad: ChunkDef = Fixture.make_chunk(1, ChunkDef.Tier.INTRO, 2, [Fixture.make_wall(1, 11.5, 12.5)])
	var lines: Array = []
	var sink: Callable = func(_level: int, code: StringName, _key: String, _message: String) -> void: lines.append(code)
	var lib: CompiledLibrary = ChunkLibraryCompiler.compile(
		Fixture.make_content_library([bad] as Array[ChunkDef]), PatternConfig.new(), L, sink
	)
	assert_null(lib)
	assert_true(lines.has(ObstacleMath.HOME_SEGMENT_MISMATCH))


func test_negative_indices_empty_and_zero_returns_content() -> void:
	var core: PatternCore = Fixture.make_core(Fixture.make_run_time_stub(0.0), 2)
	assert_eq(core.hazards_for_segment(-1).size(), 0)
	assert_eq(core.hazards_for_segment(-50).size(), 0)
	assert_eq(core.last_chunk_id(), &"")
	assert_eq(core.hazards_for_segment(0).size(), 1)
	assert_eq(core.last_chunk_id(), &"4")


func test_first_draw_is_grace_compliant_and_later_draws_unrestricted() -> void:
	var first_ids: Dictionary = {}
	var second_ids: Dictionary = {}
	for run_id: int in SEEDS_30:
		var core: PatternCore = Fixture.make_core(Fixture.make_run_time_stub(8.0), run_id)
		for spec: HazardSpec in core.hazards_for_segment(0):
			assert_gte(_first_s(spec), 11.0)
		var first: StringName = core.last_chunk_id()
		first_ids[first] = true
		var length: int = (Fixture.make_chunks()[String(first).to_int() - 1] as ChunkDef).segment_count
		for k: int in range(1, length):
			core.hazards_for_segment(k)
		core.hazards_for_segment(length)
		second_ids[core.last_chunk_id()] = true
	assert_true(first_ids.has(&"3") and first_ids.has(&"4"))
	assert_false(first_ids.has(&"1") or first_ids.has(&"2"))
	assert_true(second_ids.has(&"1") and second_ids.has(&"2"))


func test_tier_transition_near_repeat_is_accepted() -> void:
	var stub: Fixture.ValueStub = Fixture.make_run_time_stub(0.0)
	var order: Array[int] = [3]
	var core: PatternCore = Fixture.make_core(stub, 1, order)
	core.hazards_for_segment(0)
	assert_eq(core.last_chunk_id(), &"3")
	core.hazards_for_segment(1)
	stub.value = 20.0
	core.hazards_for_segment(2)
	assert_eq(core.last_chunk_id(), &"3")


func test_chunk_in_progress_finishes_when_tier_changes() -> void:
	var stub: Fixture.ValueStub = Fixture.make_run_time_stub(0.0)
	var order: Array[int] = [3]
	var core: PatternCore = Fixture.make_core(stub, 1, order)
	core.hazards_for_segment(0)
	stub.value = 300.0
	assert_eq(core.hazards_for_segment(1).size(), 1)
	assert_eq(core.last_chunk_id(), &"3")


func test_returned_specs_are_the_shared_compiled_objects() -> void:
	var lib: CompiledLibrary = Fixture.make_compiled_library()
	var core: PatternCore = PatternCore.new(PatternConfig.new(), L, func() -> float: return 0.0, Callable(), 0.0)
	core.set_library(lib)
	core.on_run_reset(2)
	var first: Array[HazardSpec] = core.hazards_for_segment(0)
	var again: Array[HazardSpec] = core.hazards_for_segment(0)
	assert_eq(first.size(), 1)
	assert_same(first[0], again[0])


func test_run_reset_reproduces_the_sequence() -> void:
	var stub: Fixture.ValueStub = Fixture.make_run_time_stub(300.0)
	var core: PatternCore = Fixture.make_core(stub, 9)
	var a: Array[int] = _walk(core, 12)
	core.on_run_reset(9)
	assert_eq(_walk(core, 12), a)


func test_apply_map_compiles_library_and_reports_failure() -> void:
	var map: MapConfig = MapConfig.new()
	map.chunk_library = Fixture.make_content_library(Fixture.make_chunks())
	var core: PatternCore = PatternCore.new(PatternConfig.new(), L, func() -> float: return 0.0)
	assert_true(core.apply_map(map))
	core.on_run_reset(2)
	assert_eq(core.hazards_for_segment(0).size(), 1)
	var bad: MapConfig = MapConfig.new()
	bad.chunk_library = Fixture.make_content_library([] as Array[ChunkDef])
	assert_false(core.apply_map(bad))
	assert_false(PatternCore.new(PatternConfig.new(), L, func() -> float: return 0.0).apply_map(null))
