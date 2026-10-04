extends GutTest


func test_score_floor_table_matches_expected() -> void:
	var rows: Array = [[0.0, 0], [9.999, 9], [10.0, 10], [10.5, 10], [1574.991, 1574], [1575.008, 1575], [777.3, 777]]
	for row: Array in rows:
		var r: int = ScoreMath.score(row[0])
		assert_eq(r, row[1], "score(%s)" % row[0])
		assert_eq(typeof(r), TYPE_INT)


func _check_monotone(seq: Array[float]) -> void:
	for i: int in range(1, seq.size()):
		var a: int = ScoreMath.score(seq[i - 1])
		var b: int = ScoreMath.score(seq[i])
		assert_true(b >= a, "non-decreasing at %d" % i)
		assert_true(b - a <= int(ceil(seq[i] - seq[i - 1])), "delta bound at %d" % i)


func test_score_flat_sequence_is_monotone() -> void:
	_check_monotone([3.2, 3.2, 3.2, 3.2])


func test_score_fractional_sequence_is_monotone() -> void:
	_check_monotone([0.1, 0.9, 1.05, 1.95, 2.0, 2.01, 9.999, 10.001])


func test_score_integer_boundary_sequence_is_monotone() -> void:
	_check_monotone([8.0, 9.0, 9.0, 10.0, 11.0, 11.0])


func test_is_new_best_table_matches_expected() -> void:
	var rows: Array = [[0, 0, false], [342, 0, true], [200, 342, false], [342, 342, false], [343, 342, true], [9001, 9000, true]]
	for row: Array in rows:
		assert_eq(ScoreMath.is_new_best(row[0], row[1]), row[2], "is_new_best(%d,%d)" % [row[0], row[1]])
