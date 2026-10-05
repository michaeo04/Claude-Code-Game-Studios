## Offline content preflight P1 (ADR-0008 Decision 5; GDD AC-32, AC-37): checks every chunk ALONE, exhaustively and
## in a deterministic order, and returns structured records `{code, chunk_id, other_chunk_id, s0, detail}`. Pure
## RefCounted, no engine call; never run on a device in a release build.
## `NEAR_ZONE_OVERLAP` and `DODGE_RECOVERY_VIOLATION` are composed when the near-miss and pattern validators exist.
## Example: `var records: Array[Dictionary] = ContentPreflight.run(library, ContentPreflightConfig.new())`.
class_name ContentPreflight
extends RefCounted

const SOLUTION_NOT_IN_GAP: StringName = &"SOLUTION_NOT_IN_GAP"


## P1 over every chunk of `library`. Chunks are visited by chunk id; within a chunk records are sorted by code, then `s0`.
static func run(library: ChunkLibrary, cfg: ContentPreflightConfig) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if library == null or cfg == null:
		return out
	var chunks: Array[ChunkDef] = []
	for chunk: ChunkDef in library.chunks:
		if chunk != null:
			chunks.append(chunk)
	chunks.sort_custom(func(a: ChunkDef, b: ChunkDef) -> bool: return String(a.chunk_id) < String(b.chunk_id))
	for chunk: ChunkDef in chunks:
		var rows: Array[Dictionary] = _check_chunk(chunk, cfg)
		rows.sort_custom(_record_before)
		out.append_array(rows)
	return out


static func _record_before(a: Dictionary, b: Dictionary) -> bool:
	var ca: String = String(a["code"])
	var cb: String = String(b["code"])
	if ca != cb:
		return ca < cb
	return (a["s0"] as float) < (b["s0"] as float)


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


static func _check_chunk(chunk: ChunkDef, cfg: ContentPreflightConfig) -> Array[Dictionary]:
	var hazards: Array[PreflightHazard] = _to_hazards(chunk)
	var half: float = ObstacleMath.ball_half_angle(cfg.tube_radius, cfg.ball_diameter)
	var records: Array[PreflightRecord] = []
	records.append_array(ObstacleMath.validate_footprints(hazards))
	records.append_array(ObstacleMath.validate_home_segments(hazards, cfg.segment_length))
	records.append_array(ObstacleMath.validate_grace_zone(hazards, cfg.grace_zone_length))
	records.append_array(ObstacleMath.validate_piece_counts(hazards, cfg.max_pieces_per_segment))
	records.append_array(ObstacleMath.validate_gaps(hazards, cfg.tube_radius, cfg.ball_diameter, cfg.gap_margin))
	records.append_array(ObstacleMath.validate_overlaps(hazards, cfg.tube_radius, cfg.ball_diameter))
	records.append_array(ObstacleMath.validate_spacing(hazards, cfg.min_spacing))
	records.append_array(ObstacleMath.validate_hidden_content(hazards, cfg.visible_arc_half_width))
	records.append_array(
		ObstacleMath.validate_hidden_frequency(hazards, cfg.visible_arc_half_width, cfg.hidden_span_min_s)
	)
	records.append_array(ObstacleMath.validate_exit_rule(hazards, cfg.visible_arc_half_width))
	var near_cfg: NearMissConfig = cfg.near_miss if cfg.near_miss != null else NearMissConfig.new()
	records.append_array(NearMissMath.validate_near_zone_overlap(hazards, cfg.tube_radius, cfg.ball_diameter, near_cfg))
	var out: Array[Dictionary] = []
	for rec: PreflightRecord in records:
		out.append(_dict(chunk, rec.code, rec.s0, _detail(rec)))
	for dodge: Dictionary in ChunkValidator.validate_chunk(
		chunk, cfg.visible_arc_half_width, cfg.angular_reversal_threshold, cfg.dodge_recovery_s
	):
		if dodge["code"] == ChunkValidator.DODGE_RECOVERY_VIOLATION:
			out.append(_dict(chunk, dodge["code"] as StringName, 0.0, dodge["detail"] as String))
	for hz: PreflightHazard in hazards:
		for k: int in range(hz.piece_count()):
			var w_code: StringName = ObstacleMath.width_code(hz.pieces[k * 4], hz.pieces[k * 4 + 1], half)
			if w_code != &"":
				out.append(_dict(chunk, w_code, hz.pieces[k * 4 + 2], "hazard %d piece %d" % [hz.hazard_id, k]))
		for angle: float in hz.solution_angles:
			if is_finite(angle) and _inside_occupied_arc(hazards, angle, half):
				out.append(_dict(chunk, SOLUTION_NOT_IN_GAP, 0.0, "hazard %d angle %s" % [hz.hazard_id, angle]))
	return out


static func _inside_occupied_arc(hazards: Array[PreflightHazard], angle: float, half: float) -> bool:
	for hz: PreflightHazard in hazards:
		for k: int in range(hz.piece_count()):
			var lo: float = hz.pieces[k * 4] - half
			var hi: float = hz.pieces[k * 4 + 1] + half
			if not (is_finite(lo) and is_finite(hi)):
				continue
			for turn: int in range(-1, 2):
				var a: float = angle + float(turn) * TAU
				if a >= lo and a <= hi:
					return true
	return false


static func _dict(chunk: ChunkDef, code: StringName, s0: float, detail: String) -> Dictionary:
	return {"code": code, "chunk_id": chunk.chunk_id, "other_chunk_id": &"", "s0": s0, "detail": detail}


static func _detail(rec: PreflightRecord) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for p: Vector2i in rec.pieces:
		parts.append("%d:%d" % [p.x, p.y])
	return "segment %d pieces [%s] count %d" % [rec.segment_index, ",".join(parts), rec.count]
