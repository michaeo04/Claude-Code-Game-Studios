## One authored rectangle of a hazard (ADR-0008 Decision 1): data only, never mutated or copied at run time.
##
## Bounds are unwrapped reals: a seam-crossing piece has `theta_max > PI` or `theta_min < -PI`. `s_start` and
## `s_end` are chunk-local, inside `[k*L, (k+1)*L)` for the owning segment `k`.
class_name HazardPiece
extends Resource

@export var theta_min: float = 0.0
@export var theta_max: float = 0.0
@export var s_start: float = 0.0
@export var s_end: float = 0.0
