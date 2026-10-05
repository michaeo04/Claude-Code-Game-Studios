extends GutTest

const Fixture = preload("res://tests/support/pattern_fixture.gd")

const SEED: int = 1


func _bag(tier: ChunkDef.Tier, seed_value: int, shuffler: Callable = Callable()) -> TierBag:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return TierBag.new(Fixture.make_compiled_library().pool(tier), rng, shuffler)


func _draw_ids(bag: TierBag, count: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in range(count):
		out.append(String(bag.draw().chunk_id).to_int())
	return out


## Distances in draws between consecutive occurrences of the same id.
func _gaps(ids: Array[int]) -> Array[int]:
	var last: Dictionary = {}
	var out: Array[int] = []
	for i: int in range(ids.size()):
		if last.has(ids[i]):
			out.append(i - (last[ids[i]] as int))
		last[ids[i]] = i
	return out


func _chunk(id: int) -> CompiledChunk:
	return CompiledChunk.new(StringName(str(id)), ChunkDef.Tier.INTRO, 1, [] as Array[HazardSpec])


func test_full_first_eight_draws_are_a_permutation() -> void:
	var ids: Array[int] = _draw_ids(_bag(ChunkDef.Tier.FULL, SEED), 8)
	ids.sort()
	assert_eq(ids, [1, 2, 3, 4, 5, 6, 7, 8] as Array[int])


func test_single_chunk_pool_repeats_without_violation() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var bag: TierBag = TierBag.new([_chunk(1)] as Array[CompiledChunk], rng)
	assert_eq(_draw_ids(bag, 10), [1, 1, 1, 1, 1, 1, 1, 1, 1, 1] as Array[int])


class StubShuffler:
	extends RefCounted
	var orders: Array = []
	var calls: int = 0

	func shuffle(items: Array) -> void:
		var wanted: Array = orders[calls]
		calls += 1
		var sorted: Array = []
		for id: int in wanted:
			for item: Variant in items:
				if (item as CompiledChunk).chunk_id == StringName(str(id)):
					sorted.append(item)
		items.assign(sorted)


func test_reshuffle_collision_corrected_to_gap_at_least_two() -> void:
	var stub: StubShuffler = StubShuffler.new()
	stub.orders = [[3, 1, 4, 2], [2, 4, 1, 3]]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var pool: Array[CompiledChunk] = [_chunk(1), _chunk(2), _chunk(3), _chunk(4)]
	var bag: TierBag = TierBag.new(pool, rng, Callable(stub, "shuffle"))
	var ids: Array[int] = _draw_ids(bag, 8)
	assert_eq(ids.slice(0, 4), [3, 1, 4, 2] as Array[int])
	# Mutation check: the naive second bag would start with 2 right after the 2 that ended bag 1 (gap 1).
	assert_ne(ids[4], 2)
	for g: int in _gaps(ids):
		assert_gte(g, 2)


func test_intro_gaps_within_bounds_and_both_bounds_reached() -> void:
	var ids20: Array[int] = _draw_ids(_bag(ChunkDef.Tier.INTRO, SEED), 20)
	var gaps20: Array[int] = _gaps(ids20)
	for g: int in gaps20:
		assert_true(g >= 2 and g <= 7, "gap %d" % g)
	assert_true(gaps20.has(2))
	var gaps40: Array[int] = _gaps(_draw_ids(_bag(ChunkDef.Tier.INTRO, SEED), 40))
	assert_true(gaps40.has(7))
	for g: int in gaps40:
		assert_true(g >= 2 and g <= 7, "gap %d" % g)


func test_two_chunk_pool_alternates_strictly() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var bag: TierBag = TierBag.new([_chunk(1), _chunk(2)] as Array[CompiledChunk], rng)
	var ids: Array[int] = _draw_ids(bag, 20)
	for i: int in range(2, ids.size()):
		assert_eq(ids[i], ids[i - 2])
	for g: int in _gaps(ids):
		assert_eq(g, 2)
	assert_ne(ids[0], ids[1])


func test_same_seed_reproduces_sequence_and_other_seed_differs() -> void:
	var a: Array[int] = _draw_ids(_bag(ChunkDef.Tier.FULL, 7), 24)
	var b: Array[int] = _draw_ids(_bag(ChunkDef.Tier.FULL, 7), 24)
	var c: Array[int] = _draw_ids(_bag(ChunkDef.Tier.FULL, 8), 24)
	assert_eq(a, b)
	assert_ne(a, c)


func test_draw_first_matching_takes_first_match_and_keeps_rest_in_order() -> void:
	var stub: StubShuffler = StubShuffler.new()
	stub.orders = [[1, 2, 3, 4]]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var pool: Array[CompiledChunk] = [_chunk(1), _chunk(2), _chunk(3), _chunk(4)]
	var bag: TierBag = TierBag.new(pool, rng, Callable(stub, "shuffle"))
	var first: CompiledChunk = bag.draw_first_matching(func(c: CompiledChunk) -> bool: return c.chunk_id == &"3")
	assert_eq(first.chunk_id, &"3")
	assert_eq(_draw_ids(bag, 3), [1, 2, 4] as Array[int])
