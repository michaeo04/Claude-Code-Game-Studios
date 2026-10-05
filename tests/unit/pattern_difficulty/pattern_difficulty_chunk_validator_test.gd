extends GutTest

const Fixture = preload("res://tests/support/pattern_fixture.gd")

const HALF: float = PI / 2.0
const THRESHOLD: float = PI / 2.0
const DODGE_S: float = 26.6


func _hazard(theta_min: float, theta_max: float, s: float, solution: PackedFloat64Array) -> HazardPlacement:
	var pieces: Array[HazardPiece] = [Fixture.make_piece(theta_min, theta_max, s, s + 0.9)]
	return Fixture.make_placement(HazardPlacement.HazardType.WALL, 0, pieces, solution)


func _chunk(placements: Array[HazardPlacement], segments: int = 3) -> ChunkDef:
	return Fixture.make_chunk(9, ChunkDef.Tier.FULL, segments, placements)


func _codes(chunk: ChunkDef, half: float = HALF, dodge: float = DODGE_S) -> Array[StringName]:
	var out: Array[StringName] = []
	for rec: Dictionary in ChunkValidator.validate_chunk(chunk, half, THRESHOLD, dodge):
		out.append(rec["code"] as StringName)
	return out


func _wall_at(segment: int, s: float, angle: float) -> HazardPlacement:
	var w: HazardPlacement = Fixture.make_wall(segment, s, s + 0.9)
	w.solution_angles = PackedFloat64Array([angle])
	return w


func test_hidden_piece_rejected() -> void:
	var c: ChunkDef = _chunk([_hazard(2.9, 3.4, 2.0, PackedFloat64Array())])
	assert_eq(_codes(c), [ObstacleMath.HIDDEN_CONTENT_FORBIDDEN] as Array[StringName])


func test_fixture_wall_and_whole_library_not_rejected() -> void:
	assert_eq(_codes(_chunk([Fixture.make_wall(0, 2.0, 3.0)])), [] as Array[StringName])
	var records: Array[Dictionary] = ChunkValidator.validate(Fixture.make_chunks(), HALF, THRESHOLD, DODGE_S)
	assert_eq(records.size(), 0)


func test_visible_piece_not_rejected() -> void:
	assert_eq(_codes(_chunk([_hazard(1.2, 2.2, 2.0, PackedFloat64Array())])), [] as Array[StringName])


func test_two_piece_hazard_rejected_per_piece() -> void:
	var pieces: Array[HazardPiece] = [Fixture.make_piece(-0.3, 0.3, 2.0, 2.9), Fixture.make_piece(2.9, 3.4, 2.0, 2.9)]
	var h: HazardPlacement = Fixture.make_placement(
		HazardPlacement.HazardType.WALL, 0, pieces, PackedFloat64Array()
	)
	var recs: Array[Dictionary] = ChunkValidator.validate_chunk(_chunk([h]), HALF, THRESHOLD, DODGE_S)
	assert_eq(recs.size(), 1)
	assert_eq(recs[0]["code"], ObstacleMath.HIDDEN_CONTENT_FORBIDDEN)
	assert_string_contains(recs[0]["detail"] as String, "piece 1")


func test_exit_beyond_visible_arc_rejected_though_not_hidden() -> void:
	var c: ChunkDef = _chunk([_wall_at(0, 2.0, 1.2)])
	assert_eq(_codes(c, 1.0472), [ObstacleMath.EXIT_BEYOND_VISIBLE_ARC] as Array[StringName])
	assert_eq(_codes(c, HALF), [] as Array[StringName])


func test_near_ring_at_pi_passes_exit_rule() -> void:
	var ring: HazardPlacement = Fixture.make_chunks()[6].placements[0]
	assert_eq(_codes(_chunk([ring]), 1.0472), [] as Array[StringName])


func test_rev2_accepted_at_exact_boundary() -> void:
	assert_eq(_codes(Fixture.make_chunks()[7]), [] as Array[StringName])


func test_too_close_rejected_naming_chunk_and_pair() -> void:
	var ring_pieces: Array[HazardPiece] = [Fixture.make_piece(-Fixture.RING_HALF, Fixture.RING_HALF, 20.5, 21.7)]
	var ring: HazardPlacement = Fixture.make_placement(
		HazardPlacement.HazardType.NEAR_RING, 1, ring_pieces, PackedFloat64Array([PI])
	)
	var c: ChunkDef = _chunk([Fixture.make_wall(0, 0.5, 1.5), ring])
	var recs: Array[Dictionary] = ChunkValidator.validate_chunk(c, HALF, THRESHOLD, DODGE_S)
	assert_eq(recs.size(), 1)
	assert_eq(recs[0]["code"], ChunkValidator.DODGE_RECOVERY_VIOLATION)
	assert_eq(recs[0]["chunk_id"], &"9")
	assert_string_contains(recs[0]["detail"] as String, "hazards 0 and 1")


func test_twin_wall_same_direction_accepted() -> void:
	var c: ChunkDef = _chunk([Fixture.make_wall(0, 2.0, 2.9), Fixture.make_wall(0, 8.5, 9.4)])
	assert_eq(_codes(c), [] as Array[StringName])


func test_spike_exempt_from_opposing_check() -> void:
	var spike: HazardPlacement = Fixture.make_chunks()[4].placements[0]
	var c: ChunkDef = _chunk([_wall_at(0, 0.5, 0.0), spike])
	assert_eq(_codes(c), [] as Array[StringName])


func _double_gate_chunk(second_s: float) -> ChunkDef:
	var dg_pieces: Array[HazardPiece] = [Fixture.make_piece(-1.2, -0.4, 1.0, 2.2), Fixture.make_piece(0.4, 1.2, 1.0, 2.2)]
	var dg: HazardPlacement = Fixture.make_placement(
		HazardPlacement.HazardType.DOUBLE_GATE, 0, dg_pieces, PackedFloat64Array([-0.8, 0.8])
	)
	return _chunk([dg, _wall_at(2, second_s, 1.0)])


func test_double_gate_any_pair_accepted_at_boundary() -> void:
	assert_eq(_codes(_double_gate_chunk(1.0 + 26.6)), [] as Array[StringName])


func test_double_gate_any_pair_rejected_below_boundary() -> void:
	assert_eq(_codes(_double_gate_chunk(1.0 + 26.5)), [ChunkValidator.DODGE_RECOVERY_VIOLATION] as Array[StringName])


func test_double_gate_average_angle_would_wrongly_accept() -> void:
	# The mutation compares the mean angle 0.0 with 1.0 (not opposing); the real any-pair rule must still reject.
	assert_false(PatternMath.opposing(PackedFloat64Array([0.0]), PackedFloat64Array([1.0]), THRESHOLD))
	assert_true(PatternMath.opposing(PackedFloat64Array([-0.8, 0.8]), PackedFloat64Array([1.0]), THRESHOLD))
	assert_eq(_codes(_double_gate_chunk(1.0 + 26.5)).size(), 1)
