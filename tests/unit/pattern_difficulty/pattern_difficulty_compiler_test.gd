extends GutTest

const Fixture = preload("res://tests/support/pattern_fixture.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")

const L: float = 12.0


func _compile(chunks: Array[ChunkDef], sink: RefCounted) -> CompiledLibrary:
	return ChunkLibraryCompiler.compile(
		Fixture.make_content_library(chunks), PatternConfig.new(), L, Callable(sink, "sink")
	)


func _intro(id: int, s_start: float) -> ChunkDef:
	return Fixture.make_chunk(id, ChunkDef.Tier.INTRO, 1, [Fixture.make_wall(0, s_start, s_start + 0.9)])


func _codes(sink: RefCounted) -> Array[StringName]:
	var out: Array[StringName] = []
	for i: int in range(sink.call("count") as int):
		out.append(sink.call("code_at", i) as StringName)
	return out


func test_one_grace_compliant_rejected_naming_count() -> void:
	var sink: RefCounted = LogSink.new()
	var chunks: Array[ChunkDef] = [_intro(1, 2.0), _intro(2, 5.0), _intro(3, 6.0), _intro(4, 11.0)]
	assert_null(_compile(chunks, sink))
	assert_eq(_codes(sink), [ChunkLibraryCompiler.GRACE_POOL_TOO_SMALL] as Array[StringName])
	assert_string_contains(sink.call("message_at", 0) as String, "1 grace-compliant")
	assert_eq(sink.call("level_at", 0), LogLevel.ERROR)


func test_zero_grace_compliant_rejected() -> void:
	var sink: RefCounted = LogSink.new()
	var chunks: Array[ChunkDef] = [_intro(1, 2.0), _intro(2, 5.0)]
	assert_null(_compile(chunks, sink))
	assert_string_contains(sink.call("message_at", 0) as String, "0 grace-compliant")


func test_two_grace_compliant_accepted() -> void:
	var sink: RefCounted = LogSink.new()
	var chunks: Array[ChunkDef] = [_intro(1, 2.0), _intro(2, 11.0), _intro(3, 11.05)]
	assert_not_null(_compile(chunks, sink))
	assert_eq(sink.call("count"), 0)


func test_empty_intro_pool_fails_non_empty_check_first() -> void:
	var sink: RefCounted = LogSink.new()
	var chunks: Array[ChunkDef] = []
	assert_null(_compile(chunks, sink))
	assert_true(_codes(sink).has(ChunkLibraryCompiler.EMPTY_TIER_POOL))
	assert_false(_codes(sink).has(ChunkLibraryCompiler.GRACE_POOL_TOO_SMALL))


func test_structural_segment_count_four_rejected() -> void:
	var sink: RefCounted = LogSink.new()
	var chunks: Array[ChunkDef] = Fixture.make_chunks()
	chunks.append(Fixture.make_chunk(9, ChunkDef.Tier.FULL, 4, [Fixture.make_wall(0, 20.0, 21.0)]))
	assert_null(_compile(chunks, sink))
	assert_true(_codes(sink).has(ChunkLibraryCompiler.SEGMENT_COUNT_INVALID))


func test_structural_nan_piece_rejected() -> void:
	var sink: RefCounted = LogSink.new()
	var chunks: Array[ChunkDef] = Fixture.make_chunks()
	chunks.append(Fixture.make_chunk(9, ChunkDef.Tier.FULL, 1, [Fixture.make_wall(0, NAN, 21.0)]))
	assert_null(_compile(chunks, sink))
	assert_true(_codes(sink).has(ObstacleMath.FOOTPRINT_NOT_FINITE))


func test_structural_local_segment_index_out_of_range_rejected() -> void:
	var sink: RefCounted = LogSink.new()
	var chunks: Array[ChunkDef] = Fixture.make_chunks()
	chunks.append(Fixture.make_chunk(9, ChunkDef.Tier.FULL, 1, [Fixture.make_wall(1, 14.0, 15.0)]))
	assert_null(_compile(chunks, sink))
	assert_true(_codes(sink).has(ChunkLibraryCompiler.LOCAL_SEGMENT_INDEX_OUT_OF_RANGE))


func test_structural_thirteen_pieces_in_one_segment_rejected() -> void:
	var sink: RefCounted = LogSink.new()
	var pieces: Array[HazardPiece] = []
	for i: int in range(13):
		pieces.append(Fixture.make_piece(0.0, 0.1, float(i) * 0.5, float(i) * 0.5 + 0.1))
	var big: HazardPlacement = Fixture.make_placement(
		HazardPlacement.HazardType.SPIKE, 0, pieces, PackedFloat64Array()
	)
	var chunks: Array[ChunkDef] = Fixture.make_chunks()
	chunks.append(Fixture.make_chunk(9, ChunkDef.Tier.FULL, 1, [big]))
	assert_null(_compile(chunks, sink))
	assert_true(_codes(sink).has(ObstacleMath.TOO_MANY_PIECES))


func test_structural_piece_outside_home_segment_rejected() -> void:
	var sink: RefCounted = LogSink.new()
	var chunks: Array[ChunkDef] = Fixture.make_chunks()
	chunks.append(Fixture.make_chunk(9, ChunkDef.Tier.FULL, 1, [Fixture.make_wall(0, 11.5, 12.5)]))
	assert_null(_compile(chunks, sink))
	assert_true(_codes(sink).has(ObstacleMath.HOME_SEGMENT_MISMATCH))


func test_fixture_pools_are_supersets_4_6_8() -> void:
	var sink: RefCounted = LogSink.new()
	var lib: CompiledLibrary = _compile(Fixture.make_chunks(), sink)
	assert_not_null(lib)
	assert_eq(sink.call("count"), 0)
	assert_eq(lib.pool_size(ChunkDef.Tier.INTRO), 4)
	assert_eq(lib.pool_size(ChunkDef.Tier.RAMP), 6)
	assert_eq(lib.pool_size(ChunkDef.Tier.FULL), 8)


func test_hazard_specs_shared_by_reference() -> void:
	var lib: CompiledLibrary = _compile(Fixture.make_chunks(), LogSink.new())
	var first: HazardSpec = lib.pool(ChunkDef.Tier.INTRO)[0].hazards[0]
	assert_same(lib.pool(ChunkDef.Tier.INTRO)[0].hazards[0], first)
	assert_same(lib.pool(ChunkDef.Tier.FULL)[0].hazards[0], first)
