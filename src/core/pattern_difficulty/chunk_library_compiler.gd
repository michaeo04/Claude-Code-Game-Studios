## Compiles a `ChunkLibrary` into a `CompiledLibrary` after the cheap structural checks (ADR-0008 Decision 2).
##
## Every failure is logged ERROR through `log_sink(level, code, key, message)`; all failures are collected, then
## `compile` returns `null`. Pure: no engine calls, the library is never copied or mutated.
class_name ChunkLibraryCompiler
extends RefCounted

const SEGMENT_COUNT_INVALID: StringName = &"SEGMENT_COUNT_INVALID"
const LOCAL_SEGMENT_INDEX_OUT_OF_RANGE: StringName = &"LOCAL_SEGMENT_INDEX_OUT_OF_RANGE"
const CHUNK_MISSING: StringName = &"CHUNK_MISSING"
const EMPTY_TIER_POOL: StringName = &"EMPTY_TIER_POOL"
const GRACE_POOL_TOO_SMALL: StringName = &"GRACE_POOL_TOO_SMALL"
## Fewest grace-compliant INTRO chunks (Core Rule 6).
const GRACE_POOL_MIN_SIZE: int = 2
## ADVISORY (WARNING): a tier pool's opposing pair fraction exceeds `MAX_OPPOSING_FRACTION` (Core Rule 12).
const EXCESSIVE_ANGULAR_CLUSTERING: StringName = &"EXCESSIVE_ANGULAR_CLUSTERING"
## ADVISORY (WARNING): the INTRO pool has fewer than 2 chunks and may repeat every draw.
const INTRO_POOL_SMALL: StringName = &"INTRO_POOL_SMALL"
const _TIER_NAMES: Array[String] = ["INTRO", "RAMP", "FULL"]


## Compiles `library`; `obstacle_config` supplies `max_pieces_per_segment` and `grace_zone_length`
## (defaults when null). Returns `null` on any structural failure.
static func compile(
	library: ChunkLibrary,
	config: PatternConfig,
	segment_length: float,
	log_sink: Callable,
	obstacle_config: ObstacleConfig = null
) -> CompiledLibrary:
	var ocfg: ObstacleConfig = obstacle_config if obstacle_config != null else ObstacleConfig.new()
	var ok: bool = true
	var out: CompiledLibrary = CompiledLibrary.new()
	var grace_ok: int = 0
	if library != null:
		for chunk: ChunkDef in library.chunks:
			if chunk == null:
				_fail(log_sink, CHUNK_MISSING, "chunks", "null chunk entry")
				ok = false
				continue
			var compiled: CompiledChunk = _compile_chunk(chunk, segment_length, ocfg, log_sink)
			if compiled == null:
				ok = false
				continue
			out.add(compiled)
			if compiled.tier == ChunkDef.Tier.INTRO and _grace_compliant(chunk, ocfg.grace_zone_length):
				grace_ok += 1
	if ok:
		for tier: int in [ChunkDef.Tier.INTRO, ChunkDef.Tier.RAMP, ChunkDef.Tier.FULL]:
			if out.pool_size(tier as ChunkDef.Tier) == 0:
				_fail(log_sink, EMPTY_TIER_POOL, "tier_%d" % tier, "tier pool %d is empty" % tier)
				ok = false
	if ok and grace_ok < GRACE_POOL_MIN_SIZE:
		_fail(
			log_sink,
			GRACE_POOL_TOO_SMALL,
			"intro_pool",
			"INTRO pool has %d grace-compliant chunks, needs %d" % [grace_ok, GRACE_POOL_MIN_SIZE]
		)
		ok = false
	if not ok:
		return null
	advise(out, config, log_sink)
	return out


## Advisory checks on a compiled library (never reject): per-tier `EXCESSIVE_ANGULAR_CLUSTERING` (F5, over non-Spike
## chunks) and `INTRO_POOL_SMALL`. Both log WARNING through `log_sink`. Returns the fraction of each tier, INTRO first.
static func advise(library: CompiledLibrary, config: PatternConfig, log_sink: Callable) -> PackedFloat64Array:
	var cfg: PatternConfig = config if config != null else PatternConfig.new()
	var fractions: PackedFloat64Array = PackedFloat64Array()
	for tier: int in [ChunkDef.Tier.INTRO, ChunkDef.Tier.RAMP, ChunkDef.Tier.FULL]:
		var sets: Array = []
		for chunk: CompiledChunk in library.pool(tier as ChunkDef.Tier):
			var angles: PackedFloat64Array = _read_angles(chunk)
			if not angles.is_empty():
				sets.append(angles)
		var fraction: float = PatternMath.opposing_pair_fraction(sets, cfg.angular_reversal_threshold)
		fractions.append(fraction)
		if fraction > cfg.max_opposing_fraction and log_sink.is_valid():
			log_sink.call(
				LogLevel.WARNING,
				EXCESSIVE_ANGULAR_CLUSTERING,
				_TIER_NAMES[tier],
				"%s pool opposing pair fraction %.3f exceeds %s" % [_TIER_NAMES[tier], fraction, cfg.max_opposing_fraction]
			)
	var intro_size: int = library.pool_size(ChunkDef.Tier.INTRO)
	if intro_size < 2 and log_sink.is_valid():
		log_sink.call(
			LogLevel.WARNING,
			INTRO_POOL_SMALL,
			"INTRO",
			"INTRO pool size %d may repeat every draw for up to %s s of a run" % [intro_size, cfg.tier_intro_duration]
		)
	return fractions


## Solution angles of every non-Spike hazard of `chunk` (empty when the chunk has no non-Spike read).
static func _read_angles(chunk: CompiledChunk) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	for spec: HazardSpec in chunk.hazards:
		if spec.hazard_type != HazardPlacement.HazardType.SPIKE:
			out.append_array(spec.solution_angles)
	return out


static func _compile_chunk(chunk: ChunkDef, seg_len: float, ocfg: ObstacleConfig, log_sink: Callable) -> CompiledChunk:
	var key: String = String(chunk.chunk_id)
	var ok: bool = true
	if chunk.segment_count < 1 or chunk.segment_count > 3:
		_fail(log_sink, SEGMENT_COUNT_INVALID, key, "segment_count %d outside 1 to 3" % chunk.segment_count)
		return null
	var hazards: Array[PreflightHazard] = []
	var specs: Array[HazardSpec] = []
	var id: int = 0
	for placement: HazardPlacement in chunk.placements:
		id += 1
		if placement == null:
			_fail(log_sink, CHUNK_MISSING, key, "null placement")
			ok = false
			continue
		if placement.local_segment_index < 0 or placement.local_segment_index >= chunk.segment_count:
			_fail(
				log_sink,
				LOCAL_SEGMENT_INDEX_OUT_OF_RANGE,
				key,
				"local_segment_index %d" % placement.local_segment_index
			)
			ok = false
			continue
		var flat: PackedFloat64Array = PackedFloat64Array()
		for piece: HazardPiece in placement.pieces:
			flat.append_array(PackedFloat64Array([piece.theta_min, piece.theta_max, piece.s_start, piece.s_end]))
		hazards.append(PreflightHazard.new(id, placement.local_segment_index, flat, placement.solution_angles))
		specs.append(HazardSpec.new(placement.hazard_type, placement.local_segment_index, flat, placement.solution_angles))
	var records: Array[PreflightRecord] = []
	records.append_array(ObstacleMath.validate_footprints(hazards))
	for hz: PreflightHazard in hazards:
		for k: int in range(hz.piece_count()):
			var b: int = k * 4
			if is_finite(hz.pieces[b]) and is_finite(hz.pieces[b + 1]):
				var wcode: StringName = ObstacleMath.width_code(hz.pieces[b], hz.pieces[b + 1], 0.0)
				if wcode != &"":
					records.append(PreflightRecord.new(wcode, hz.home_segment, hz.pieces[b + 2]))
	records.append_array(ObstacleMath.validate_home_segments(hazards, seg_len))
	records.append_array(ObstacleMath.validate_piece_counts(hazards, ocfg.max_pieces_per_segment))
	for rec: PreflightRecord in records:
		_fail(log_sink, rec.code, key, "chunk %s segment %d s %s" % [key, rec.segment_index, rec.s0])
		ok = false
	if not ok:
		return null
	return CompiledChunk.new(chunk.chunk_id, chunk.tier, chunk.segment_count, specs)


static func _grace_compliant(chunk: ChunkDef, grace_length: float) -> bool:
	for placement: HazardPlacement in chunk.placements:
		if placement.local_segment_index != 0:
			continue
		for piece: HazardPiece in placement.pieces:
			if piece.s_start < grace_length:
				return false
	return true


static func _fail(log_sink: Callable, code: StringName, key: String, message: String) -> void:
	if log_sink.is_valid():
		log_sink.call(LogLevel.ERROR, code, key, message)
