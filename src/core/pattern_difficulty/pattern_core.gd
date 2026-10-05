## Pattern & Difficulty as the `HazardContentProvider` (GDD Core Rules 1 to 6; ADR-0008 Decisions 6 to 8).
##
## Draws chunks from per-tier shuffled bags seeded from `run_id` and answers `hazards_for_segment(index)` with the
## shared (never copied) `HazardSpec`s of the chunk placed at that index. Tier is sampled when a new chunk is drawn,
## from the injected `run_time_provider() -> float`; a chunk in progress finishes when the tier changes.
## Padding is a seam only (`_padding_segments_for`, Story 010). Pure: no engine calls, no global randomness.
## Example: `var core: PatternCore = PatternCore.new(cfg, 12.0, Callable(stub, "get_value"))`.
class_name PatternCore
extends HazardContentProvider

var _config: PatternConfig = null
var _segment_length: float = 12.0
var _grace_zone_length: float = 11.0
var _run_time_provider: Callable = Callable()
var _log_sink: Callable = Callable()
var _shuffler: Callable = Callable()
var _library: CompiledLibrary = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _bags: Array[TierBag] = []
var _first_draw_pending: bool = true
var _chunk: CompiledChunk = null
var _chunk_base: int = 0
var _chunk_end: int = 0


## `config` is used as given (validate it first); `segment_length` is Tube Track's `L`; `run_time_provider` returns
## seconds of run time; `shuffler` optionally replaces the Fisher-Yates permutation source (tests).
func _init(
	config: PatternConfig,
	segment_length: float,
	run_time_provider: Callable,
	log_sink: Callable = Callable(),
	grace_zone_length: float = 11.0,
	shuffler: Callable = Callable()
) -> void:
	_config = config
	_segment_length = segment_length
	_run_time_provider = run_time_provider
	_log_sink = log_sink
	_grace_zone_length = grace_zone_length
	_shuffler = shuffler


## Configuration only (ADR-0004 phase B3): compiles `map.chunk_library` and stores the result. Emits nothing and
## starts nothing. Returns false (and keeps the previous library) when the compile fails; failures reach `log_sink`.
func apply_map(map: MapConfig) -> bool:
	if map == null or not (map.chunk_library is ChunkLibrary):
		if _log_sink.is_valid():
			_log_sink.call(LogLevel.ERROR, ChunkLibraryCompiler.CHUNK_MISSING, "chunk_library", "no chunk library")
		return false
	var compiled: CompiledLibrary = ChunkLibraryCompiler.compile(
		map.chunk_library as ChunkLibrary, _config, _segment_length, _log_sink
	)
	if compiled == null:
		return false
	set_library(compiled)
	return true


## Stores an already compiled library (also the path tests take).
func set_library(library: CompiledLibrary) -> void:
	_library = library
	_reset_state()


## `run_reset` handler (ADR-0002, rank 1): reseeds from `run_id`, reshuffles all three bags, drops chunk state.
func on_run_reset(run_id: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = run_id
	_reset_state()
	if _library == null:
		return
	for tier: int in [ChunkDef.Tier.INTRO, ChunkDef.Tier.RAMP, ChunkDef.Tier.FULL]:
		_bags.append(TierBag.new(_library.pool(tier as ChunkDef.Tier), _rng, _shuffler))


## The shared specs of the chunk placed at `segment_index`: empty for a negative index, a padding segment or an
## authored empty local segment.
func hazards_for_segment(segment_index: int) -> Array[HazardSpec]:
	var out: Array[HazardSpec] = []
	if segment_index < 0 or _bags.is_empty():
		return out
	if segment_index >= _chunk_end:
		_place_next(segment_index)
	if segment_index < _chunk_base:
		return out
	var local: int = segment_index - _chunk_base
	for spec: HazardSpec in _chunk.hazards:
		if spec.local_segment_index == local:
			out.append(spec)
	return out


## Id of the most recently placed chunk (`&""` before the first draw).
func last_chunk_id() -> StringName:
	return _chunk.chunk_id if _chunk != null else &""


## First segment index of the most recently placed chunk (after any padding).
func last_chunk_base() -> int:
	return _chunk_base


func _reset_state() -> void:
	_bags.clear()
	_first_draw_pending = true
	_chunk = null
	_chunk_base = 0
	_chunk_end = 0


func _place_next(segment_index: int) -> void:
	var run_time: float = _run_time_provider.call() as float
	if not is_finite(run_time):
		run_time = 0.0
	var tier: ChunkDef.Tier = PatternMath.tier_for(run_time, _config.tier_intro_duration, _config.tier_ramp_duration)
	var bag: TierBag = _bags[tier]
	var chunk: CompiledChunk
	if _first_draw_pending:
		_first_draw_pending = false
		chunk = bag.draw_first_matching(_grace_compliant)
	else:
		chunk = bag.draw()
	_chunk = chunk
	_chunk_base = segment_index + _padding_segments_for(chunk)
	_chunk_end = _chunk_base + chunk.segment_count


## Hazard-free segments to insert before `chunk` (F2c). Seam: Story 010 replaces the body.
func _padding_segments_for(_chunk_to_place: CompiledChunk) -> int:
	return 0


## True when no local-segment-0 piece starts inside the grace zone at `base = 0` (Core Rule 6).
func _grace_compliant(chunk: CompiledChunk) -> bool:
	for spec: HazardSpec in chunk.hazards:
		if spec.local_segment_index != 0:
			continue
		var pieces: PackedFloat64Array = spec.pieces
		for k: int in range(spec.piece_count()):
			if pieces[k * 4 + 2] < _grace_zone_length:
				return false
	return true
