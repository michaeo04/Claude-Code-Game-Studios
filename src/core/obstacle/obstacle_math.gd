## Pure Obstacle System math (GDD F1, F2). Static and engine-free; all values are float64.
##
## Footprints are flat `PackedFloat64Array`s, 4 values per piece: `theta_min, theta_max, s_start, s_end`.
## The F3 gap sweep-line and F4/F5 are added by later stories to THIS file.
class_name ObstacleMath
extends RefCounted

## Raw piece span reaches `2*PI` (checked before expansion).
const FOOTPRINT_TOO_WIDE: StringName = &"FOOTPRINT_TOO_WIDE"
## Expanded (effective) span reaches `2*PI` although the raw span passed.
const FOOTPRINT_EFF_TOO_WIDE: StringName = &"FOOTPRINT_EFF_TOO_WIDE"


## `BALL_HALF_ANGLE = asin(D / (2 * (R + D/2)))` (Tube Track F6).
static func ball_half_angle(r: float, d: float) -> float:
	return TubeMath.lane_half_angle(r, d)


## F1 effective footprint of one raw piece: `[theta_min - h, theta_max + h, s_start - d/2, s_end + d/2]`
## with `h = half_angle`. Example: Picket `(-0.05, 0.05, 200, 200.3)` at R 3, D 0.8 gives
## `[-0.1679, 0.1679, 199.6, 200.7]`.
static func effective_footprint(
	theta_min: float, theta_max: float, s_start: float, s_end: float, half_angle: float, d: float
) -> PackedFloat64Array:
	return PackedFloat64Array([theta_min - half_angle, theta_max + half_angle, s_start - d / 2.0, s_end + d / 2.0])


## Expands a whole flat footprint (4 per piece) with F1; the result has the same length.
static func effective_footprint_array(raw: PackedFloat64Array, half_angle: float, d: float) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize(raw.size())
	var i: int = 0
	while i + 3 < raw.size():
		out[i] = raw[i] - half_angle
		out[i + 1] = raw[i + 1] + half_angle
		out[i + 2] = raw[i + 2] - d / 2.0
		out[i + 3] = raw[i + 3] + d / 2.0
		i += 4
	return out


## Width check of a raw theta span: `FOOTPRINT_TOO_WIDE` when `theta_max - theta_min >= 2*PI` (reported alone),
## else `FOOTPRINT_EFF_TOO_WIDE` when the span plus `2 * half_angle` reaches `2*PI`, else `&""`.
static func width_code(theta_min: float, theta_max: float, half_angle: float) -> StringName:
	var span: float = theta_max - theta_min
	if span >= TAU:
		return FOOTPRINT_TOO_WIDE
	if span + 2.0 * half_angle >= TAU:
		return FOOTPRINT_EFF_TOO_WIDE
	return &""


## Closed arc vs closed arc on the circle with a single `fposmod` (no seam branch). Widths are in `[0, 2*PI]`.
static func arc_overlap(a_start: float, a_width: float, b_start: float, b_width: float) -> bool:
	var d: float = fposmod(b_start - a_start, TAU)
	return d <= a_width or (TAU - d) <= b_width


## F2 theta axis against one effective piece `[eff_theta_min, eff_theta_max]` for the step `theta_prev -> theta`.
static func theta_hit(theta_prev: float, theta: float, eff_theta_min: float, eff_theta_max: float) -> bool:
	var dtheta: float = TubeMath.delta_theta(theta, theta_prev)
	var swept_start: float = theta_prev if dtheta >= 0.0 else theta
	return arc_overlap(swept_start, absf(dtheta), eff_theta_min, eff_theta_max - eff_theta_min)


## F2 s axis: `s_prev <= s_eff_end and s >= s_eff_start`.
static func s_hit(s_prev: float, s: float, eff_s_start: float, eff_s_end: float) -> bool:
	return s_prev <= eff_s_end and s >= eff_s_start


## F2 `HIT` against the effective piece starting at index `piece * 4` of `eff_footprint`.
static func swept_hit(
	theta_prev: float, theta: float, s_prev: float, s: float, eff_footprint: PackedFloat64Array, piece: int = 0
) -> bool:
	var i: int = piece * 4
	return (
		theta_hit(theta_prev, theta, eff_footprint[i], eff_footprint[i + 1])
		and s_hit(s_prev, s, eff_footprint[i + 2], eff_footprint[i + 3])
	)
