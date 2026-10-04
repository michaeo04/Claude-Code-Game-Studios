## Story OBS-001: authored Resource tree, enum ints and the `.tres` round trip (AC-1, AC-4). Loads a real file.
extends GutTest

const LIBRARY_PATH: String = "res://tests/support/data/obstacle_library_fixture.tres"


func test_resource_tree_enums_carry_explicit_ints() -> void:
	assert_eq(HazardPlacement.HazardType.WALL, 0)
	assert_eq(HazardPlacement.HazardType.SPIKE, 1)
	assert_eq(HazardPlacement.HazardType.DOUBLE_GATE, 2)
	assert_eq(HazardPlacement.HazardType.NEAR_RING, 3)
	assert_eq(ChunkDef.Tier.INTRO, 0)
	assert_eq(ChunkDef.Tier.RAMP, 1)
	assert_eq(ChunkDef.Tier.FULL, 2)


func test_resource_tree_built_in_code_has_typed_arrays() -> void:
	var piece: HazardPiece = HazardPiece.new()
	var placement: HazardPlacement = HazardPlacement.new()
	placement.pieces.append(piece)
	var chunk_a: ChunkDef = ChunkDef.new()
	var chunk_b: ChunkDef = ChunkDef.new()
	chunk_a.placements.append(placement)
	var library: ChunkLibrary = ChunkLibrary.new()
	library.chunks.append(chunk_a)
	library.chunks.append(chunk_b)

	assert_eq(library.chunks.size(), 2)
	assert_true(library.chunks.is_typed())
	assert_true(placement.pieces.is_typed())
	assert_true(chunk_a.placements.is_typed())
	assert_eq(chunk_a.segment_count, 1)


func test_tres_round_trip_keeps_float64_values_and_enum_ints() -> void:
	var library: ChunkLibrary = load(LIBRARY_PATH) as ChunkLibrary

	assert_not_null(library)
	assert_eq(library.chunks.size(), 2)
	var chunk: ChunkDef = library.chunks[0]
	assert_eq(chunk.chunk_id, &"fixture_a")
	assert_eq(int(chunk.tier), ChunkDef.Tier.FULL)
	assert_eq(chunk.segment_count, 2)
	var ring: HazardPlacement = chunk.placements[0]
	assert_eq(int(ring.hazard_type), HazardPlacement.HazardType.NEAR_RING)
	assert_eq(ring.local_segment_index, 1)
	var seam: HazardPiece = ring.pieces[0]
	assert_eq(seam.theta_min, 2.9)
	assert_eq(seam.theta_max, 3.6)
	assert_true(seam.theta_max > PI)
	assert_eq(seam.s_start, 12.5)
	assert_eq(ring.solution_angles[0], PI / 2.0)
	var spike: HazardPlacement = chunk.placements[1]
	assert_eq(int(spike.hazard_type), HazardPlacement.HazardType.SPIKE)
	assert_eq(spike.solution_angles.size(), 0)
	assert_eq(spike.pieces[0].theta_min, 1.0472)
	assert_eq(spike.pieces[0].theta_max, PI / 2.0)
	assert_eq(int(library.chunks[1].tier), ChunkDef.Tier.RAMP)
	assert_eq(library.chunks[1].placements.size(), 0)
