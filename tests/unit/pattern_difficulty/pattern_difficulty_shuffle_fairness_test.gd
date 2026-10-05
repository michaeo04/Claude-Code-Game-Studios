extends GutTest

const Fixture = preload("res://tests/support/pattern_fixture.gd")
const RunIds = preload("res://tests/support/data/pattern_run_ids.gd")

## Chi-square critical value for 7 degrees of freedom at p = 0.01.
const CHI_SQUARE_CRITICAL: float = 18.475


## ADVISORY (GDD AC-23): the first FULL-tier draw is uniform over the 8 chunks across 500 fixed run ids.
func test_first_full_draw_is_uniform_over_500_run_ids() -> void:
	var counts: Dictionary = {}
	for run_id: int in RunIds.RUN_IDS:
		var stub: Fixture.ValueStub = Fixture.make_run_time_stub(0.0)
		var core: PatternCore = Fixture.make_core(stub, run_id)
		core.hazards_for_segment(0)  # the grace-restricted opening draw, taken from the INTRO bag
		stub.value = 300.0
		core.hazards_for_segment(10)
		var id: StringName = core.last_chunk_id()
		counts[id] = (counts.get(id, 0) as int) + 1
	assert_eq(RunIds.RUN_IDS.size(), 500)
	var expected: float = 62.5
	var chi: float = 0.0
	for i: int in range(1, 9):
		var observed: float = float(counts.get(StringName(str(i)), 0) as int)
		chi += (observed - expected) * (observed - expected) / expected
	assert_lt(chi, CHI_SQUARE_CRITICAL, "chi-square %s over counts %s" % [chi, counts])
