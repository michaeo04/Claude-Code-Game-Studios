## Story OBS-001: HazardSpec immutability and shared instances (AC-2, AC-3).
extends GutTest

const Fixture = preload("res://tests/support/obstacle_fixture.gd")


func test_hazard_spec_fields_unchanged_after_provider_round() -> void:
	var spec: HazardSpec = Fixture.worked_hazard(101)
	var pieces_before: PackedFloat64Array = spec.pieces.duplicate()
	var solutions_before: PackedFloat64Array = spec.solution_angles.duplicate()
	var type_before: int = spec.hazard_type
	var local_before: int = spec.local_segment_index
	var provider: Fixture.FakeProvider = Fixture.make_content_provider({4: [spec]})

	var first: Array[HazardSpec] = provider.hazards_for_segment(4)
	var local_pieces: PackedFloat64Array = first[0].pieces
	local_pieces[0] = 99.0  # a copy-on-write local, must not reach the spec

	assert_eq(spec.pieces, pieces_before)
	assert_eq(spec.solution_angles, solutions_before)
	assert_eq(spec.hazard_type, type_before)
	assert_eq(spec.local_segment_index, local_before)
	assert_eq(spec.piece_count(), 3)


func test_hazard_spec_has_no_setters() -> void:
	var spec: HazardSpec = Fixture.worked_hazard(301)
	for field: String in ["hazard_type", "local_segment_index", "pieces", "solution_angles"]:
		assert_false(spec.has_method("set_" + field), "no setter for %s" % field)


func test_hazard_provider_repeat_reads_return_same_instances() -> void:
	var spec_a: HazardSpec = Fixture.worked_hazard(101)
	var spec_b: HazardSpec = Fixture.worked_hazard(601)
	var provider: Fixture.FakeProvider = Fixture.make_content_provider({4: [spec_a, spec_b]})

	var first: Array[HazardSpec] = provider.hazards_for_segment(4)
	var second: Array[HazardSpec] = provider.hazards_for_segment(4)

	assert_eq(first.size(), 2)
	assert_true(first[0] == spec_a and second[0] == spec_a, "same object reference")
	assert_true(first[1] == spec_b and second[1] == spec_b, "same object reference")
	assert_eq(provider.calls, 2)


func test_hazard_provider_base_returns_empty_array() -> void:
	var base: HazardContentProvider = HazardContentProvider.new()

	assert_eq(base.hazards_for_segment(4).size(), 0)


func test_hazard_provider_unknown_segment_returns_empty_array() -> void:
	var provider: Fixture.FakeProvider = Fixture.make_content_provider({4: [Fixture.worked_hazard(101)]})

	assert_eq(provider.hazards_for_segment(5).size(), 0)
