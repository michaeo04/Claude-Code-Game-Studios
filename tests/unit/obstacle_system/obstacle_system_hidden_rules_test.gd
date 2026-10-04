## Story OBS-006: F4 hidden() (AC-34), HIDDEN_UNFAIR (AC-15), HIDDEN_CONTENT_FORBIDDEN (AC-36),
## EXIT_BEYOND_VISIBLE_ARC (AC-42).
extends GutTest

const HALF_TEST: float = PI / 2.0
const HALF_REAL: float = 1.0472
const SPAN_MIN_S: float = 36.0
const L: float = 12.0


func _hz(id: int, seg: int, pieces: Array, solutions: Array = []) -> PreflightHazard:
	return PreflightHazard.new(id, seg, PackedFloat64Array(pieces), PackedFloat64Array(solutions))


func _one(hz: PreflightHazard) -> Array[PreflightHazard]:
	var arr: Array[PreflightHazard] = [hz]
	return arr


func _narrow(id: int, s_start: float) -> PreflightHazard:
	return _hz(id, int(floor(s_start / L)), [2.9, 3.4, s_start, s_start + 0.3])


func _freq(a: float, b: float) -> Array[PreflightRecord]:
	var hazards: Array[PreflightHazard] = [_narrow(1, a), _narrow(2, b)]
	return ObstacleMath.validate_hidden_frequency(hazards, HALF_TEST, SPAN_MIN_S)


func test_hidden_rows_classify_as_listed() -> void:
	assert_false(ObstacleMath.hidden(-0.3, 0.3, HALF_TEST))
	assert_false(ObstacleMath.hidden(PI / 2.0, 2.5, HALF_TEST), "touching the visible arc is not hidden (strict >)")
	assert_true(ObstacleMath.hidden(PI / 2.0 + 1e-4, 2.5, HALF_TEST))
	assert_true(ObstacleMath.hidden(-2.5, -PI / 2.0 - 1e-4, HALF_TEST))
	assert_true(ObstacleMath.hidden(2.9, 3.4, HALF_TEST))
	assert_false(ObstacleMath.hidden(0.4127, 5.8705, HALF_TEST), "Wall")
	assert_false(ObstacleMath.hidden(1.2, 2.2, HALF_TEST))
	assert_false(ObstacleMath.hidden(5.8, 7.0, HALF_TEST), "arc containing THETA_REF across the seam")
	assert_false(ObstacleMath.hidden(-2.7053, 2.7053, HALF_TEST), "Near-Ring")


func test_hidden_seam_and_shifted_rows_are_identical() -> void:
	assert_eq(ObstacleMath.hidden(2.9, 3.6, HALF_TEST), ObstacleMath.hidden(-3.3832, -2.6832, HALF_TEST))
	assert_true(ObstacleMath.hidden(2.9, 3.6, HALF_TEST))


func test_hidden_is_not_centre_or_theta_min_based() -> void:
	# Wall centre is PI (far side) yet it is visible; (-0.3, 0.3) has theta_min inside yet a centre-only test agrees.
	assert_false(ObstacleMath.hidden(0.4127, 5.8705, HALF_TEST))
	# theta_min alone (5.8 > PI/2 away after wrap-around misuse) must not decide: the arc contains THETA_REF.
	assert_false(ObstacleMath.hidden(5.8, 7.0, HALF_TEST))
	# Centre 2.5 is far but the arc (1.2, 3.8) reaches into the visible arc? 1.2 < PI/2: not hidden.
	assert_false(ObstacleMath.hidden(1.2, 3.8, HALF_TEST))


func test_frequency_rows_48_60_and_48_72_rejected() -> void:
	var recs: Array[PreflightRecord] = _freq(48.0, 60.0)
	assert_eq(recs.size(), 1)
	assert_eq(recs[0].code, ObstacleMath.HIDDEN_UNFAIR)
	assert_eq(_freq(48.0, 72.0).size(), 1)


func test_frequency_exactly_36_accepted_and_just_short_rejected() -> void:
	assert_eq(_freq(48.0, 84.0).size(), 0)
	assert_eq(_freq(48.0, 83.999).size(), 1)


func test_frequency_ignores_visible_pieces() -> void:
	var hazards: Array[PreflightHazard] = [
		_hz(1, 4, [-0.3, 0.3, 48.0, 48.3]), _hz(2, 5, [-0.3, 0.3, 60.0, 60.3])
	]
	assert_eq(ObstacleMath.validate_hidden_frequency(hazards, HALF_TEST, SPAN_MIN_S).size(), 0)


func test_content_gate_rejects_hidden_piece_only() -> void:
	var recs: Array[PreflightRecord] = ObstacleMath.validate_hidden_content(_one(_narrow(1, 48.0)), HALF_TEST)
	assert_eq(recs.size(), 1)
	assert_eq(recs[0].code, ObstacleMath.HIDDEN_CONTENT_FORBIDDEN)
	assert_eq(recs[0].pieces[0], Vector2i(1, 0))


func test_content_gate_passes_wall_visible_piece_and_ring() -> void:
	var hazards: Array[PreflightHazard] = [
		_hz(301, 16, [0.4127, 5.8705, 200.0, 201.0], [0.0]),
		_hz(2, 4, [1.2, 2.2, 50.0, 50.3]),
		_hz(401, 25, [-2.7053, 2.7053, 300.0, 301.2], [PI]),
	]
	assert_eq(ObstacleMath.validate_hidden_content(hazards, HALF_TEST).size(), 0)


func test_content_gate_is_per_piece_for_two_piece_hazard() -> void:
	var gate: PreflightHazard = _hz(9, 4, [-0.3, 0.3, 50.0, 50.3, 2.9, 3.4, 50.0, 50.3])
	var recs: Array[PreflightRecord] = ObstacleMath.validate_hidden_content(_one(gate), HALF_TEST)
	assert_eq(recs.size(), 1)
	assert_eq(recs[0].pieces[0], Vector2i(9, 1))


func test_content_gate_rejects_despite_generous_spacing() -> void:
	var hazards: Array[PreflightHazard] = [_narrow(1, 48.0), _narrow(2, 480.0)]
	assert_eq(ObstacleMath.validate_hidden_frequency(hazards, HALF_TEST, SPAN_MIN_S).size(), 0)
	assert_eq(ObstacleMath.validate_hidden_content(hazards, HALF_TEST).size(), 2)


func _exit(gaps: Array) -> Array[PreflightRecord]:
	return ObstacleMath.validate_exit_rule(_one(_hz(1, 4, [0.4127, 5.8705, 50.0, 51.0], gaps)), 1.0472)


func test_exit_wall_gap_zero_passes_and_far_gaps_rejected() -> void:
	assert_eq(_exit([0.0]).size(), 0)
	assert_eq(_exit([1.2]).size(), 1)
	assert_eq(_exit([-1.2]).size(), 1)
	assert_eq(_exit([1.2])[0].code, ObstacleMath.EXIT_BEYOND_VISIBLE_ARC)


func test_exit_not_also_hidden_content_forbidden() -> void:
	var wall: Array[PreflightHazard] = _one(_hz(1, 4, [0.4127, 5.8705, 50.0, 51.0], [1.2]))
	assert_eq(ObstacleMath.validate_hidden_content(wall, HALF_REAL).size(), 0)


func test_exit_ring_pi_passes_and_3_0_rejected() -> void:
	assert_eq(_exit([PI]).size(), 0)
	assert_eq(_exit([3.0]).size(), 1)


func test_exit_boundary_is_strict() -> void:
	assert_eq(_exit([1.0472]).size(), 0)
	assert_eq(_exit([1.0473]).size(), 1)


func test_exit_double_gate_names_the_failing_gap_once() -> void:
	assert_eq(_exit([-0.8, 0.8]).size(), 0)
	var recs: Array[PreflightRecord] = _exit([0.8, 1.2])
	assert_eq(recs.size(), 1)
	assert_almost_eq(recs[0].angle, 1.2, 1e-9)


func test_exit_spike_without_solution_is_exempt() -> void:
	assert_eq(_exit([]).size(), 0)
