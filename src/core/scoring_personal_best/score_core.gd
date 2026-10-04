## Scoring and Personal Best core (design/gdd/scoring-personal-best.md).
##
## Pure RefCounted, no engine calls. Collaborators arrive as injected Callable seams:
## `s_seam() -> float`, `get_value_seam(section, key, default) -> Variant`,
## `set_value_seam(section, key, value) -> bool`.
class_name ScoreCore
extends RefCounted

## Live score of the current run (floor of `s`).
var current_score: int = 0
## Best final score, read once at construction through `get_value_seam`.
var personal_best: int = 0
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
## A non-finite `s` holds the score (the full guard set is story 004).
func step() -> void:
	var s: float = _s_seam.call()
	if not is_finite(s):
		return
	current_score = ScoreMath.score(s)


## Synchronous run reset (before `run_started`): zeroes score, latch and milestone index; makes no seam call.
func on_run_reset() -> void:
	current_score = 0
	has_passed_this_run = false
	next_milestone_index = 0
