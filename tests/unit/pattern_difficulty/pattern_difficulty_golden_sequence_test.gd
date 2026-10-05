## Story PD-013: golden chunk-order table (ADR-0008 Decision 8). The library is reloaded from disk for every seed.
## First 10 segments at run time 0 s (INTRO), the next 10 at 20 s (RAMP), the rest at 120 s (FULL). Each entry is
## `chunk_id@base`. Re-run on every engine upgrade and on an Android device build.
extends GutTest

const Golden = preload("res://tests/support/pattern_golden.gd")

const SEEDS: Array[int] = [1, 2, 42, 506964459]
const EXPECTED: Dictionary = {
	1: ["3@0", "4@2", "1@3", "2@4", "4@5", "3@6", "1@8", "2@9", "1@10", "3@11", "4@13", "2@14", "6@15", "5@17",
		"1@18", "5@19", "5@20", "6@21", "1@23", "3@24", "8@26", "2@29"],
	2: ["4@0", "2@1", "1@2", "3@3", "1@5", "2@6", "3@7", "4@9", "4@10", "5@11", "2@12", "6@13", "1@15", "3@16",
		"5@18", "3@19", "4@21", "6@22", "2@24", "3@25", "7@27", "8@29"],
	42: ["3@0", "1@2", "4@3", "2@4", "1@5", "3@6", "2@8", "4@9", "4@10", "5@11", "6@12", "1@14", "3@15", "2@17",
		"1@18", "3@19", "7@21", "4@23", "1@24", "8@25", "3@28"],
	506964459: ["4@0", "1@1", "2@2", "3@3", "2@5", "3@6", "1@8", "4@9", "4@10", "3@11", "6@13", "1@15", "5@16",
		"2@17", "1@18", "5@19", "7@20", "1@22", "6@23", "2@25", "8@26", "3@29"],
}


func test_golden_sequences_match_the_hardcoded_table_for_every_seed() -> void:
	for run_id: int in SEEDS:
		var actual: Array[String] = Golden.sequence_for(run_id)
		var expected: Array[String] = []
		expected.assign(EXPECTED[run_id] as Array)
		assert_eq(actual, expected, "golden sequence for seed %d" % run_id)


func test_golden_sequence_is_identical_on_a_second_reload_from_disk() -> void:
	for run_id: int in SEEDS:
		assert_eq(Golden.sequence_for(run_id), Golden.sequence_for(run_id), "reload replay for seed %d" % run_id)


func test_golden_sequences_differ_between_distinct_seeds() -> void:
	assert_ne(Golden.sequence_for(1), Golden.sequence_for(2))
	assert_ne(Golden.sequence_for(42), Golden.sequence_for(506964459))
