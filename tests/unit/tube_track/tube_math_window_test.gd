## Story TT-002: TubeMath segment index, window sizes and seam spacing (AC-7, AC-11, AC-14).
extends GutTest

const JUST_BELOW_12: float = 11.999999999999998
const V_MAX: float = 25.0
const T_LAT: float = 0.1
const C_B: float = 6.0
const M_CAM: float = 2.0


func test_ac7_segment_index_and_slot() -> void:
	var s_values: Array[float] = [-24.0, -1.0, 0.0, 11.999, JUST_BELOW_12, 12.0, 24.0]
	var want: Array[int] = [-2, -1, 0, 0, 0, 1, 2]
	for k: int in s_values.size():
		assert_eq(TubeMath.segment_index(s_values[k], 12.0), want[k], "s=%s" % s_values[k])
	assert_eq(TubeMath.slot_of(-1, 12), 11)
	assert_eq(TubeMath.slot_of(12, 12), 0)


func test_ac11_required_a_table() -> void:
	# [L, F, A required]
	var rows: Array[Array] = [
		[12.0, 37.5, 5], [12.0, 84.0, 9], [12.0, 129.5, 12], [6.0, 48.0, 10],
		[24.0, 37.5, 3], [9.0, 84.0, 11], [6.0, 100.0, 19], [12.0, 45.5, 5],
	]
	for r: Array in rows:
		assert_eq(TubeMath.required_a(r[1] as float, V_MAX, T_LAT, r[0] as float), r[2] as int, "L=%s F=%s" % [r[0], r[1]])


func test_ac11_required_b_and_caps() -> void:
	assert_eq(TubeMath.required_b(C_B, M_CAM, 12.0), 1)
	assert_eq(TubeMath.required_b(C_B, M_CAM, 6.0), 2)
	assert_eq(TubeMath.required_b(C_B, M_CAM, 24.0), 1)
	assert_true(TubeMath.required_a(100.0, V_MAX, T_LAT, 6.0) > TubeMath.A_MAX)
	assert_true(TubeMath.required_b(C_B, M_CAM, 2.0) > TubeMath.B_MAX)
	assert_true(9 + 2 + 1 <= TubeMath.N_MAX)
	assert_eq(TubeMath.A_MAX, 12)
	assert_eq(TubeMath.B_MAX, 3)
	assert_eq(TubeMath.N_MAX, 16)


func test_ac14_single_seam_gaps_and_frequency() -> void:
	assert_eq(TubeMath.seam_s(0, 0, 12.0, 1), 6.0)
	for i: int in 99:
		var gap: float = TubeMath.seam_s(i + 1, 0, 12.0, 1) - TubeMath.seam_s(i, 0, 12.0, 1)
		assert_almost_eq(gap, 12.0, 1e-9)
	assert_almost_eq(TubeMath.f_seam(V_MAX, 12.0, 1), 2.0833, 1e-4)
	assert_almost_eq(TubeMath.f_seam(V_MAX, 12.0, 1), 25.0 / 12.0, 1e-6)


func test_ac14_four_seams_positions_and_gaps_across_boundaries() -> void:
	var want: Array[float] = [1.5, 4.5, 7.5, 10.5]
	for j: int in 4:
		assert_almost_eq(TubeMath.seam_s(0, j, 12.0, 4), want[j], 1e-9)
	var prev: float = TubeMath.seam_s(0, 0, 12.0, 4)
	for i: int in 100:
		for j: int in 4:
			if i == 0 and j == 0:
				continue
			var cur: float = TubeMath.seam_s(i, j, 12.0, 4)
			assert_almost_eq(cur - prev, 3.0, 1e-9, "i=%d j=%d" % [i, j])
			prev = cur


func test_seam_limits_l_min_and_max_n_seams() -> void:
	assert_eq(TubeMath.l_min(25.0, 3.0), 9)
	assert_eq(TubeMath.l_min(25.0, 2.1), 12)
	assert_eq(TubeMath.l_min(40.0, 3.0), 14)
	assert_eq(TubeMath.max_n_seams(3.0, 12.0, 25.0), 1)
	assert_eq(TubeMath.max_n_seams(3.0, 24.0, 25.0), 2)
