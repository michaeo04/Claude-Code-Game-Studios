## Test-only reference for the GDD's logical frame `P(theta, s, h) = ((R + h) sin(theta), (R + h) cos(theta), -s)`.
##
## ADR-0013: the logical `P` with z = -s exists only here, never in `src/`. Framework-free: no GUT call.
extends RefCounted


## Logical world position of the GDD (Tube Track Rule 1), float64.
static func logical_p(theta: float, s: float, h: float, r: float) -> Vector3:
	return Vector3((r + h) * sin(theta), (r + h) * cos(theta), -s)
