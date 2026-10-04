## Pure Ball Movement math (design/gdd/ball-movement.md F1, F2, F5a; Core Rule 13).
##
## Static and engine-free: every function takes scalars, none reads a config or a clock. `wrap_angle` is the one
## canonical copy shared verbatim with Tube Track (do not reimplement it over the built-in angle wrapper: that
## one collapses `PI - 1e-9` to `-PI`). Oracles come from `tools/reference-sim/ball_movement.js`.
class_name BallMath
extends RefCounted

## Below this `BALL_LAG_TAU` (seconds) the lag is treated as zero and `alpha` is 1 (F1; a fixed constant, not a knob).
const ALPHA_GUARD_TAU: float = 1e-4
## A remaining error under this many radians snaps onto the target (F1; a fixed constant, not a knob).
const SNAP_EPSILON: float = 1e-6


## Wraps an angle to the shortest signed representative in `[-PI, PI)`.
## Example: `wrap_angle(3.0 * PI / 2.0)` is `-PI / 2.0`.
static func wrap_angle(x: float) -> float:
	var r: float = x - TAU * floor((x + PI) / TAU)
	# For x one ulp below -PI, `x + PI` rounds so that the quotient lands on the wrong side and r can reach +PI.
	if r >= PI:
		r -= TAU
	return r


## The smoothing factor of F1: `1 - exp(-dt / tau)`, or 1 when `tau < ALPHA_GUARD_TAU`.
static func alpha(dt: float, tau: float) -> float:
	if tau < ALPHA_GUARD_TAU:
		return 1.0
	return 1.0 - exp(-dt / tau)


## F1 angular tracking step for a wrapped shortest-arc error `e`: `clamp(e * alpha, -omega_max * dt, omega_max * dt)`.
## When the remaining error `|e - step|` is under `SNAP_EPSILON` the whole error `e` is returned, so that applying
## the result lands exactly on the target. The caller owns the `dt <= 0` or non-finite no-op.
## Example: `step(1.0, 1.0 / 60.0, 0.06, 3.0)` is `0.05` (the cap).
static func step(e: float, dt: float, tau: float, omega_max: float) -> float:
	var cap: float = omega_max * dt
	var applied: float = clampf(e * alpha(dt, tau), -cap, cap)
	if absf(e - applied) < SNAP_EPSILON:
		return e
	return applied


## F2 forward speed at run time `t`. `t_ramp <= 0` is the sentinel "V_MAX from the start", checked first.
static func speed(t: float, v_start: float, v_max: float, t_ramp: float) -> float:
	if t_ramp <= 0.0:
		return v_max
	return v_start + (v_max - v_start) * minf(t / t_ramp, 1.0)


## F2 distance travelled `S(t)`, the exact integral of `speed`. `t_ramp <= 0` gives `v_max * t` (no division).
static func S(t: float, v_start: float, v_max: float, t_ramp: float) -> float:
	if t_ramp <= 0.0:
		return v_max * t
	if t <= t_ramp:
		return v_start * t + (v_max - v_start) * t * t / (2.0 * t_ramp)
	return t_ramp * (v_start + v_max) / 2.0 + v_max * (t - t_ramp)


## F5a time in seconds to cover an angle `x` down to a residual `eps` under the rate cap and the lag.
## Zero when `x <= eps`. With `K = omega_max * tau`: `(x - K) / omega_max + tau * ln(K / eps)` if `eps < K`,
## else `(x - eps) / omega_max`. `T(PI, 0.05, ...)` is `T_DODGE_180`.
static func T(x: float, eps: float, omega_max: float, tau: float) -> float:
	if x <= eps:
		return 0.0
	var k: float = omega_max * tau
	if eps < k:
		return (x - k) / omega_max + tau * log(k / eps)
	return (x - eps) / omega_max
