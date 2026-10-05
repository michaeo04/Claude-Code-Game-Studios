## Story 008: angular clustering fraction and pool advisories (GDD AC-28, AC-29b, AC-29, AC-21; F5, Core Rule 12).
extends GutTest

const Fx = preload("res://tests/support/pattern_fixture.gd")
const Sink = preload("res://tests/support/platform_log_sink.gd")
const THRESHOLD: float = PI / 2.0


func _angles(values: Array[float]) -> PackedFloat64Array:
	return PackedFloat64Array(values)


func _library_of(chunks: Array[ChunkDef]) -> CompiledLibrary:
	return ChunkLibraryCompiler.compile(Fx.make_content_library(chunks), PatternConfig.new(), Fx.L, Callable())


## Three INTRO chunks: A at 0, B and C at PI (pairs A-B and A-C oppose: 2/3). Walls start past the grace zone.
func _clustered_chunks() -> Array[ChunkDef]:
	var out: Array[ChunkDef] = []
	for k: int in range(3):
		var angle: float = 0.0 if k == 0 else PI
		var piece: HazardPiece = Fx.make_piece(Fx.WALL_THETA_MIN, Fx.WALL_THETA_MAX, 14.0, 15.0)
		var pieces: Array[HazardPiece] = [piece]
		var placement: HazardPlacement = Fx.make_placement(
			HazardPlacement.HazardType.WALL, 0, pieces, PackedFloat64Array([angle])
		)
		out.append(Fx.make_chunk(10 + k, ChunkDef.Tier.INTRO, 1, [placement]))
	return out


func test_fixture_pools_yield_exact_fractions() -> void:
	var lib: CompiledLibrary = Fx.make_compiled_library()
	var fractions: PackedFloat64Array = ChunkLibraryCompiler.advise(lib, PatternConfig.new(), Callable())
	assert_almost_eq(fractions[0], 0.0, 1e-6)
	assert_almost_eq(fractions[1], 0.0, 1e-6)
	assert_almost_eq(fractions[2], 11.0 / 21.0, 1e-6)
	assert_not_null(lib, "load succeeds")


func test_rev2_set_opposes_through_any_pair_rule() -> void:
	var rev2: PackedFloat64Array = _angles([0.0, PI])
	assert_almost_eq(PatternMath.opposing_pair_fraction([rev2, _angles([0.0])], THRESHOLD), 1.0, 1e-6)


func test_no_pool_pair_or_single_chunk_is_exactly_zero_not_nan() -> void:
	assert_eq(PatternMath.opposing_pair_fraction([], THRESHOLD), 0.0)
	assert_eq(PatternMath.opposing_pair_fraction([_angles([0.0])], THRESHOLD), 0.0)
	assert_false(is_nan(PatternMath.opposing_pair_fraction([_angles([PI])], THRESHOLD)))


func test_all_spike_intro_pool_is_accepted_with_zero_fraction() -> void:
	var lib: CompiledLibrary = CompiledLibrary.new()
	var spike: HazardSpec = HazardSpec.new(
		HazardPlacement.HazardType.SPIKE, 0, PackedFloat64Array([-0.05, 0.05, 14.0, 14.3]), PackedFloat64Array()
	)
	for k: int in range(3):
		var specs: Array[HazardSpec] = [spike]
		lib.add(CompiledChunk.new(StringName("s%d" % k), ChunkDef.Tier.INTRO, 1, specs))
	var fractions: PackedFloat64Array = ChunkLibraryCompiler.advise(lib, PatternConfig.new(), Callable())
	assert_eq(fractions[0], 0.0)
	assert_eq(fractions[2], 0.0)


func test_clustered_pool_logs_advisory_at_default_and_is_accepted() -> void:
	var sink: Sink = Sink.new()
	var lib: CompiledLibrary = ChunkLibraryCompiler.compile(
		Fx.make_content_library(_clustered_chunks()), PatternConfig.new(), Fx.L, Callable(),
	)
	# Only INTRO chunks: the compile fails the other tiers' emptiness, so check the advisory on a hand-built library.
	assert_null(lib)
	var built: CompiledLibrary = CompiledLibrary.new()
	for chunk: ChunkDef in _clustered_chunks():
		var specs: Array[HazardSpec] = []
		for placement: HazardPlacement in chunk.placements:
			var flat: PackedFloat64Array = PackedFloat64Array(
				[placement.pieces[0].theta_min, placement.pieces[0].theta_max, 14.0, 15.0]
			)
			specs.append(HazardSpec.new(placement.hazard_type, 0, flat, placement.solution_angles))
		built.add(CompiledChunk.new(chunk.chunk_id, chunk.tier, 1, specs))
	var fractions: PackedFloat64Array = ChunkLibraryCompiler.advise(built, PatternConfig.new(), Callable(sink, "sink"))
	assert_almost_eq(fractions[0], 2.0 / 3.0, 1e-6)
	assert_eq(sink.count_code(ChunkLibraryCompiler.EXCESSIVE_ANGULAR_CLUSTERING), 3, "one per tier pool")
	assert_eq(sink.level_at(0), LogLevel.WARNING)
	assert_eq(sink.key_at(0), "INTRO")
	assert_string_contains(sink.message_at(0), "0.667")
	sink.clear()
	var cfg: PatternConfig = PatternConfig.new()
	cfg.max_opposing_fraction = 0.7
	ChunkLibraryCompiler.advise(built, cfg, Callable(sink, "sink"))
	assert_eq(sink.count_code(ChunkLibraryCompiler.EXCESSIVE_ANGULAR_CLUSTERING), 0)


func test_one_chunk_intro_pool_logs_small_pool_advisory() -> void:
	var sink: Sink = Sink.new()
	var lib: CompiledLibrary = CompiledLibrary.new()
	lib.add(CompiledChunk.new(&"only", ChunkDef.Tier.INTRO, 1, [] as Array[HazardSpec]))
	ChunkLibraryCompiler.advise(lib, PatternConfig.new(), Callable(sink, "sink"))
	assert_eq(sink.count_code(ChunkLibraryCompiler.INTRO_POOL_SMALL), 1)
	assert_string_contains(sink.message_at(0), "INTRO pool size 1")
	assert_string_contains(sink.message_at(0), "15")
	assert_eq(sink.level_at(0), LogLevel.WARNING)


func test_compile_of_fixture_library_logs_no_advisory() -> void:
	var sink: Sink = Sink.new()
	var lib: CompiledLibrary = ChunkLibraryCompiler.compile(
		Fx.make_content_library(Fx.make_chunks()), PatternConfig.new(), Fx.L, Callable(sink, "sink")
	)
	assert_not_null(lib)
	assert_eq(sink.count(), 0)
