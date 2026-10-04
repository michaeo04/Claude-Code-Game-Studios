## Pure Near-Miss Detection math (GDD F1-NM, F2 reused). Static and engine-free; all values are float64.
##
## Footprints are flat `PackedFloat64Array`s, 4 values per piece: `theta_min, theta_max, s_start, s_end`.
class_name NearMissMath
extends RefCounted

## Bit set by `zones` when the swept path overlaps the hit zone.
const HIT_BIT: int = 1
## Bit set by `zones` when the swept path overlaps the near zone.
const NEAR_BIT: int = 2


## F1-NM near footprint of a whole raw flat footprint: the F1 hit zone (`ObstacleMath`, never re-derived) widened by
## `angle_margin` on both theta sides and `s_margin` on both s sides. Same layout and length as the input.
## Example (Graze 701, R 3, D 0.8, margins 0.1179 / 0.4): raw `(-0.3, 0.3, 100, 101.5)` gives
## `[-0.5358, 0.5358, 99.2, 102.3]`. A width reaching 2*PI is the F3-NM validator's concern, not this formula's.
static func near_footprint(
	raw: PackedFloat64Array, half_angle: float, d: float, angle_margin: float, s_margin: float
) -> PackedFloat64Array:
	var out: PackedFloat64Array = ObstacleMath.effective_footprint_array(raw, half_angle, d)
	var i: int = 0
	while i + 3 < out.size():
		out[i] -= angle_margin
		out[i + 1] += angle_margin
		out[i + 2] -= s_margin
		out[i + 3] += s_margin
		i += 4
	return out


## F2 reused twice for piece `piece`: returns a bitmask of `HIT_BIT` (against `eff`) and `NEAR_BIT` (against `near`).
## `ObstacleMath.swept_hit` is called per zone, so `dtheta`/`swept_start` are computed twice (the wrapper takes whole
## footprints and a second `arc_overlap` is forbidden); the cost is one `fposmod` extra per piece.
static func zones(
	theta_prev: float,
	theta: float,
	s_prev: float,
	s: float,
	eff: PackedFloat64Array,
	near: PackedFloat64Array,
	piece: int = 0
) -> int:
	var mask: int = 0
	if ObstacleMath.swept_hit(theta_prev, theta, s_prev, s, eff, piece):
		mask |= HIT_BIT
	if ObstacleMath.swept_hit(theta_prev, theta, s_prev, s, near, piece):
		mask |= NEAR_BIT
	return mask


## `NEAR_MISS_CANDIDATE = NEAR_ZONE and not HIT_ZONE` for a `zones` mask.
static func is_candidate(mask: int) -> bool:
	return (mask & NEAR_BIT) != 0 and (mask & HIT_BIT) == 0
