## One tier's shuffled bag (GDD Core Rule 3, F4): draws without replacement, reshuffles when empty, and never lets
## a reshuffled bag start with the chunk that ended the previous one (waived at N = 1).
##
## The permutation source is injectable: `shuffler(items: Array) -> void` reorders in place. The default is
## `fisher_yates` over the seeded `RandomNumberGenerator` (integer path `randi_range` only; never `randf`,
## `randomize` or `Array.shuffle`). Pure: no engine calls beyond the injected generator.
## Example: `var bag: TierBag = TierBag.new(pool, rng)`; `var chunk: CompiledChunk = bag.draw()`.
class_name TierBag
extends RefCounted

var _pool: Array[CompiledChunk] = []
var _rng: RandomNumberGenerator = null
var _shuffler: Callable = Callable()
var _bag: Array[CompiledChunk] = []
var _cursor: int = 0
var _last_id: StringName = &""
var _has_last: bool = false


## `rng` must already carry its explicit seed. `shuffler` is optional (default Fisher-Yates over `rng`).
func _init(pool: Array[CompiledChunk], rng: RandomNumberGenerator, shuffler: Callable = Callable()) -> void:
	_pool = pool
	_rng = rng
	_shuffler = shuffler
	_refill()


## Number of chunks in the pool.
func size() -> int:
	return _pool.size()


## Draws the next chunk (reshuffling first when the bag is empty). Returns `null` for an empty pool.
func draw() -> CompiledChunk:
	if _pool.is_empty():
		return null
	if _cursor >= _bag.size():
		_refill()
	return _take(_cursor)


## Draws the first chunk in the current bag order that satisfies `predicate(chunk) -> bool`, leaving the order of the
## rest untouched (Core Rule 6 first draw). Falls back to `draw()` when none matches.
func draw_first_matching(predicate: Callable) -> CompiledChunk:
	if _pool.is_empty():
		return null
	if _cursor >= _bag.size():
		_refill()
	for i: int in range(_cursor, _bag.size()):
		if predicate.call(_bag[i]) as bool:
			return _take(i)
	return _take(_cursor)


## In-place Fisher-Yates over `rng` (`randi_range` only).
static func fisher_yates(items: Array, rng: RandomNumberGenerator) -> void:
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp


func _take(index: int) -> CompiledChunk:
	var chunk: CompiledChunk = _bag[index]
	if index != _cursor:
		_bag.remove_at(index)
		_bag.insert(_cursor, chunk)
	_cursor += 1
	_last_id = chunk.chunk_id
	_has_last = true
	return chunk


func _refill() -> void:
	_bag = _pool.duplicate()
	if _shuffler.is_valid():
		_shuffler.call(_bag)
	else:
		fisher_yates(_bag, _rng)
	_cursor = 0
	# Never a back-to-back repeat across the reshuffle boundary: swap the colliding first draw with a later slot.
	if _has_last and _bag.size() > 1 and _bag[0].chunk_id == _last_id:
		var k: int = _rng.randi_range(1, _bag.size() - 1)
		var tmp: CompiledChunk = _bag[0]
		_bag[0] = _bag[k]
		_bag[k] = tmp
