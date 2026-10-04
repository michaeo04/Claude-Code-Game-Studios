## Pure Scoring math (design/gdd/scoring-personal-best.md F1, F2).
##
## Static and engine-free. `score` assumes a valid `s` (the guards live in `ScoreCore.step`).
class_name ScoreMath
extends RefCounted


## F1: the integer score for a travelled distance `s` (`floori`, never `round`).
## Example: `score(9.999)` is 9 and `score(10.5)` is 10.
static func score(s: float) -> int:
	return floori(s)


## F2: true only when `final_score` is strictly greater than `personal_best` (a tie is false).
## Example: `is_new_best(342, 342)` is false and `is_new_best(343, 342)` is true.
static func is_new_best(final_score: int, personal_best: int) -> bool:
	return final_score > personal_best
