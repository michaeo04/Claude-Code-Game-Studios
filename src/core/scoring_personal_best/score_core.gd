## Scoring and Personal Best core (design/gdd/scoring-personal-best.md).
##
## Pure RefCounted, no engine calls. Collaborators arrive as injected Callable seams:
## `s_seam() -> float`, `get_value_seam(section, key, default) -> Variant`,
## `set_value_seam(section, key, value) -> bool`.
class_name ScoreCore
extends RefCounted

## Emitted once, synchronously, when a run ending sets a strictly higher best (in-memory best already updated).
signal personal_best_updated(final_score: int)
## Emitted once per run when the live score first exceeds a non-zero personal best.
signal personal_best_passed(personal_best: int)

## Largest `s` accepted by `step()` (crash-safety bound just under int64 max).
const S_MAX: float = 9.2e18

## Live score of the current run (floor of `s`).
var current_score: int = 0
## Best final score, read once at construction through `get_value_seam`.
var personal_best: int = 0
## Score captured by the last run ending.
var final_score: int = 0
## Verdict of the last run ending (F2).
var is_new_best: bool = false
## True once the live score has passed the personal best this run (used by story 006).
var has_passed_this_run: bool = false
## Index of the next milestone to fire (used by story 007).
var next_milestone_index: int = 0

var _s_seam: Callable
var _get_value_seam: Callable
var _set_value_seam: Callable
var _milestone_distances: Array[int] = []


func _init(s_seam: Callable, get_value_seam: Callable, set_value_seam: Callable, milestone_distances: Array[int]) -> void:
	assert(validate_seams(s_seam, get_value_seam, set_value_seam), "ScoreCore: an injected seam is not valid")
	_s_seam = s_seam
	_get_value_seam = get_value_seam
	_set_value_seam = set_value_seam
	_milestone_distances = milestone_distances.duplicate()
	# Rule 7: read once, clamp the low side only (an oversized value is deliberately kept).
	personal_best = maxi(0, int(_get_value_seam.call("scoring", "personal_best", 0)))


## True when all three seams are valid callables. Example: `validate_seams(Callable(), g, s2)` is false.
static func validate_seams(s: Callable, g: Callable, s2: Callable) -> bool:
	return s.is_valid() and g.is_valid() and s2.is_valid()


## The live score. Example: after `step()` at `s = 10.5` this is 10.
func get_current_score() -> int:
	return current_score


## The in-memory personal best.
func get_personal_best() -> int:
	return personal_best


## Per-tick update: one `s_seam` read, `current_score = floor(s)`. No phase argument: a frozen `s` freezes the score.
## A non-finite, negative, over-range (> 9.2e18) or decreasing `s` holds the score and fires nothing.
## Example: `s` of 500.0 then 490.0 leaves the score at 500.
func step() -> void:
	var s: float = _s_seam.call()
	# Guard before converting: floori of a non-finite or huge float is undefined.
	if not (is_finite(s) and s >= 0.0 and s <= S_MAX):
		return
	var new_score: int = ScoreMath.score(s)
	if new_score < current_score:
		return
	current_score = new_score
	if not has_passed_this_run and personal_best > 0 and current_score > personal_best:
		has_passed_this_run = true
		personal_best_passed.emit(personal_best)


## Run ended by a hit. `hazard_id` and `run_time_ms` are accepted for the signal shape and never read.
func on_run_ended(_run_id: int, _hazard_id: int, _run_time_ms: int) -> void:
	_finalize()


## Run abandoned. Identical outcome to `on_run_ended`.
func on_run_abandoned(_run_id: int, _run_time_ms: int) -> void:
	_finalize()


## Synchronous run reset (before `run_started`; the optional run id lets it connect to `run_reset(run_id)` directly): zeroes score, latch and milestone index; makes no seam call.
func on_run_reset(_run_id: int = 0) -> void:
	current_score = 0
	has_passed_this_run = false
	next_milestone_index = 0


# Finalize from the stored score (never re-reads s_seam). A failed write keeps the in-memory best (ADR-0007).
func _finalize() -> void:
	final_score = current_score
	is_new_best = ScoreMath.is_new_best(final_score, personal_best)
	if not is_new_best:
		return
	personal_best = final_score
	_set_value_seam.call("scoring", "personal_best", final_score)
	personal_best_updated.emit(final_score)
