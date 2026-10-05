## Pure Pattern & Difficulty math (GDD F1 to F3). Static and engine-free; all values are float64.
class_name PatternMath
extends RefCounted

## Residual angle (rad) of Ball Movement's F5a time function used by the cost ratio.
const EPSILON_RAD: float = 0.05


## F1 tier of `run_time`: INTRO below `intro`, RAMP below `ramp`, FULL from `ramp` on (upper boundary inclusive).
## Example: `tier_for(15.0, 15.0, 90.0)` is `ChunkDef.Tier.RAMP`.
static func tier_for(run_time: float, intro: float, ramp: float) -> ChunkDef.Tier:
	if run_time < intro:
		return ChunkDef.Tier.INTRO
	if run_time < ramp:
		return ChunkDef.Tier.RAMP
	return ChunkDef.Tier.FULL


## F2 opposing test: true when any angle pair `(p, q)` has `abs(wrap_angle(p - q)) > threshold` (strict).
## False when either set is empty. Uses the wrapped difference, never a raw `abs`.
static func opposing(angles_a: PackedFloat64Array, angles_b: PackedFloat64Array, threshold: float) -> bool:
	for p: float in angles_a:
		for q: float in angles_b:
			if absf(BallMath.wrap_angle(p - q)) > threshold:
				return true
	return false


## F2 `DODGE_RECOVERY_S = T_DODGE_180 * v_max` in world units.
static func dodge_recovery_s(t_dodge_180: float, v_max: float) -> float:
	return t_dodge_180 * v_max


## F3 cost ratio of a dodge of `x` rad against a half turn: `T(x) / T(PI)`, delegating to `BallMath.T`.
static func cost_ratio(x: float, eps: float, omega_max: float, tau: float) -> float:
	return BallMath.T(x, eps, omega_max, tau) / BallMath.T(PI, eps, omega_max, tau)
