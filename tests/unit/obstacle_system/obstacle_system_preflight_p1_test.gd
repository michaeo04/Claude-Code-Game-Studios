## Story OBS-011: ContentPreflight P1, exhaustive and deterministic (AC-32, AC-37, SOLUTION_NOT_IN_GAP).
extends GutTest


func _piece(theta_min: float, theta_max: float, s_start: float, s_end: float) -> HazardPiece:
	var p: HazardPiece = HazardPiece.new()
	p.theta_min = theta_min
	p.theta_max = theta_max
	p.s_start = s_start
	p.s_end = s_end
	return p


func _place(segment: int, pieces: Array[HazardPiece], solutions: PackedFloat64Array) -> HazardPlacement:
	var pl: HazardPlacement = HazardPlacement.new()
	pl.hazard_type = HazardPlacement.HazardType.WALL
	pl.local_segment_index = segment
	pl.pieces = pieces
	pl.solution_angles = solutions
	return pl


func _library(chunks: Array[ChunkDef]) -> ChunkLibrary:
	var lib: ChunkLibrary = ChunkLibrary.new()
	lib.chunks = chunks
	return lib


func _chunk(id: StringName, placements: Array[HazardPlacement]) -> ChunkDef:
	var c: ChunkDef = ChunkDef.new()
	c.chunk_id = id
	c.segment_count = 2
	c.placements = placements
	return c


## Segment 0: a piece with `s_end < s_start`. Segment 1: a near full-ring piece that leaves no safe gap.
func _two_failure_library() -> ChunkLibrary:
	var bad_order: HazardPlacement = _place(0, [_piece(-0.05, 0.05, 5.0, 4.0)] as Array[HazardPiece], PackedFloat64Array())
	var ring: HazardPlacement = _place(1, [_piece(-3.0, 3.0, 14.0, 15.0)] as Array[HazardPiece], PackedFloat64Array())
	return _library([_chunk(&"bad", [bad_order, ring] as Array[HazardPlacement])] as Array[ChunkDef])


func _codes(records: Array[Dictionary]) -> Array[StringName]:
	var out: Array[StringName] = []
	for r: Dictionary in records:
		out.append(r["code"] as StringName)
	return out


func test_ac32_both_failures_reported_in_one_call() -> void:
	var records: Array[Dictionary] = ContentPreflight.run(_two_failure_library(), ContentPreflightConfig.new())
	var codes: Array[StringName] = _codes(records)
	assert_true(codes.has(ObstacleMath.FOOTPRINT_INVALID_ORDER), "invalid order: %s" % [codes])
	assert_true(codes.has(ObstacleMath.NO_SAFE_GAP), "no safe gap: %s" % [codes])
	for r: Dictionary in records:
		assert_eq(r["chunk_id"], &"bad")
		assert_true(r.has("other_chunk_id") and r.has("detail"))


func test_ac37_two_independent_runs_report_identical_records() -> void:
	var a: Array[Dictionary] = ContentPreflight.run(_two_failure_library(), ContentPreflightConfig.new())
	var b: Array[Dictionary] = ContentPreflight.run(_two_failure_library(), ContentPreflightConfig.new())
	assert_gt(a.size(), 1)
	assert_eq(a, b)


func test_chunks_are_ordered_by_chunk_id_not_by_library_order() -> void:
	var bad: HazardPlacement = _place(1, [_piece(-3.0, 3.0, 14.0, 15.0)] as Array[HazardPiece], PackedFloat64Array())
	var lib: ChunkLibrary = _library([
		_chunk(&"zeta", [bad] as Array[HazardPlacement]), _chunk(&"alpha", [bad] as Array[HazardPlacement])
	] as Array[ChunkDef])
	var records: Array[Dictionary] = ContentPreflight.run(lib, ContentPreflightConfig.new())
	assert_eq(records[0]["chunk_id"], &"alpha")
	assert_eq(records[records.size() - 1]["chunk_id"], &"zeta")


func test_solution_inside_an_occupied_arc_is_reported() -> void:
	var wall: HazardPlacement = _place(1, [_piece(0.5, 1.5, 14.0, 15.0)] as Array[HazardPiece], PackedFloat64Array([1.0]))
	var lib: ChunkLibrary = _library([_chunk(&"sol", [wall] as Array[HazardPlacement])] as Array[ChunkDef])
	var records: Array[Dictionary] = ContentPreflight.run(lib, ContentPreflightConfig.new())
	var found: int = 0
	for r: Dictionary in records:
		if r["code"] == ContentPreflight.SOLUTION_NOT_IN_GAP:
			found += 1
			assert_eq(r["chunk_id"], &"sol")
	assert_eq(found, 1)


func test_clean_chunk_and_empty_inputs_report_nothing() -> void:
	var wall: HazardPlacement = _place(1, [_piece(0.5, 1.0, 14.0, 15.0)] as Array[HazardPiece], PackedFloat64Array([PI]))
	var lib: ChunkLibrary = _library([_chunk(&"ok", [wall] as Array[HazardPlacement])] as Array[ChunkDef])
	var records: Array[Dictionary] = ContentPreflight.run(lib, ContentPreflightConfig.new())
	assert_eq(_codes(records), [] as Array[StringName], "no record for a clean chunk: %s" % [records])
	assert_eq(ContentPreflight.run(null, ContentPreflightConfig.new()).size(), 0)
	assert_eq(ContentPreflight.run(_library([] as Array[ChunkDef]), ContentPreflightConfig.new()).size(), 0)
