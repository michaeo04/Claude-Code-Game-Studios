## Within-chunk validators of Pattern & Difficulty (GDD Core Rules 7 and 8; ADR-0008 Decision 5, P1).
##
## Checks every chunk ALONE and returns every violation, exhaustively, in a deterministic order (chunk id, then
## code, then pair). The hidden-side and exit rules are delegated to `ObstacleMath` (F4), not reimplemented.
## Record shape: `{code, chunk_id, other_chunk_id, detail}`. Pure: no engine calls, chunks are never mutated.
## Example: `ChunkValidator.validate(chunks, PI / 2.0, PI / 2.0, 26.6)`.
class_name ChunkValidator
extends RefCounted

const DODGE_RECOVERY_VIOLATION: StringName = &"DODGE_RECOVERY_VIOLATION"
## Tolerance of the `>=` boundary compare on `s` distances (float64 sums of authored decimals).
const S_TOLERANCE: float = 1e-6


## All violations of `chunks`: `HIDDEN_CONTENT_FORBIDDEN` (per piece), `EXIT_BEYOND_VISIBLE_ARC` (per solution
## angle) and `DODGE_RECOVERY_VIOLATION` (per opposing read pair closer than `dodge_recovery_s`).
static func validate(
	chunks: Array[ChunkDef], visible_half: float, reversal_threshold: float, dodge_recovery_s: float
) -> Array[Dictionary]:
	var sorted: Array[ChunkDef] = []
	for chunk: ChunkDef in chunks:
		if chunk != null:
			sorted.append(chunk)
	sorted.sort_custom(func(a: ChunkDef, b: ChunkDef) -> bool: return String(a.chunk_id) < String(b.chunk_id))
	var out: Array[Dictionary] = []
	for chunk: ChunkDef in sorted:
		out.append_array(validate_chunk(chunk, visible_half, reversal_threshold, dodge_recovery_s))
	return out


## The violations of one chunk, in the order hidden, exit, dodge-recovery.
static func validate_chunk(
	chunk: ChunkDef, visible_half: float, reversal_threshold: float, dodge_recovery_s: float
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hazards: Array[PreflightHazard] = _to_hazards(chunk)
	for rec: PreflightRecord in ObstacleMath.validate_hidden_content(hazards, visible_half):
		out.append(_record(rec.code, chunk, "hazard %d piece %d" % [rec.pieces[0].x, rec.pieces[0].y]))
	for rec: PreflightRecord in ObstacleMath.validate_exit_rule(hazards, visible_half):
		out.append(_record(rec.code, chunk, "hazard %d angle %s" % [rec.pieces[0].x, rec.angle]))
	out.append_array(_dodge_recovery(chunk, hazards, reversal_threshold, dodge_recovery_s))
	return out


## The `s_start` of a read: its earliest piece `s_start` (chunk-local, already inclusive of the segment offset).
static func read_s_start(hazard: PreflightHazard) -> float:
	var best: float = INF
	for k: int in range(hazard.piece_count()):
		best = minf(best, hazard.pieces[k * 4 + 2])
	return best


static func _dodge_recovery(
	chunk: ChunkDef, hazards: Array[PreflightHazard], threshold: float, dodge_recovery_s: float
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(hazards.size()):
		var a: PreflightHazard = hazards[i]
		if a.solution_angles.is_empty() or a.piece_count() == 0:
			continue  # Spike: no theta_solution, exempt from the opposing check (Rule 8).
		for j: int in range(i + 1, hazards.size()):
			var b: PreflightHazard = hazards[j]
			if b.solution_angles.is_empty() or b.piece_count() == 0:
				continue
			if not PatternMath.opposing(a.solution_angles, b.solution_angles, threshold):
				continue
			var distance: float = absf(read_s_start(b) - read_s_start(a))
			if distance < dodge_recovery_s - S_TOLERANCE:
				var detail: String = "hazards %d and %d are %s u apart, needs %s" % [
					a.hazard_id, b.hazard_id, distance, dodge_recovery_s
				]
				out.append(_record(DODGE_RECOVERY_VIOLATION, chunk, detail))
	return out


static func _to_hazards(chunk: ChunkDef) -> Array[PreflightHazard]:
	var hazards: Array[PreflightHazard] = []
	var id: int = 0
	for placement: HazardPlacement in chunk.placements:
		if placement == null:
			continue
		var data: PackedFloat64Array = PackedFloat64Array()
		for piece: HazardPiece in placement.pieces:
			if piece != null:
				data.append_array(PackedFloat64Array([piece.theta_min, piece.theta_max, piece.s_start, piece.s_end]))
		hazards.append(PreflightHazard.new(id, placement.local_segment_index, data, placement.solution_angles))
		id += 1
	return hazards


static func _record(code: StringName, chunk: ChunkDef, detail: String) -> Dictionary:
	return {"code": code, "chunk_id": chunk.chunk_id, "other_chunk_id": chunk.chunk_id, "detail": detail}
