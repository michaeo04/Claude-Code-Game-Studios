## Tuning data of Scoring (GDD Tuning Knobs): the milestone distances. Every gameplay value lives here, never in code.
##
## `validate_milestones` is a pure check; the composition root refuses to build `ScoreCore` when it reports a problem.
class_name ScoringConfig
extends Resource

## Distances (score units) at which `milestone_crossed` fires, strictly ascending and positive.
## Placeholder values pending GDD Open Question 9; an empty array disables milestones.
@export var milestone_distances: Array[int] = [100, 250, 500, 1000, 2000]


## One message per violating element: non-integer, non-positive, or not strictly greater than the previous accepted value.
## A valid or empty array returns `[]`. Example: `validate_milestones([250, 100])` has one message (index 1).
static func validate_milestones(values: Array) -> Array[String]:
	var problems: Array[String] = []
	var previous: int = 0
	for i: int in values.size():
		var v: Variant = values[i]
		if typeof(v) != TYPE_INT:
			problems.append("milestone[%d] = %s is not an integer" % [i, str(v)])
			continue
		var n: int = v
		if n <= 0:
			problems.append("milestone[%d] = %d is not positive" % [i, n])
			continue
		if n <= previous:
			problems.append("milestone[%d] = %d is not strictly greater than the previous milestone %d" % [i, n, previous])
			continue
		previous = n
	return problems
