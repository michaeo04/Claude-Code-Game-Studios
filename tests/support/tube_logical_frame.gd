## Test-only reference for the GDD's logical frame `P(theta, s, h) = ((R + h) sin(theta), (R + h) cos(theta), -s)`.
##
## ADR-0013: the logical `P` with z = -s exists only here, never in `src/`. Framework-free: no GUT call.
extends RefCounted


## Logical world position of the GDD (Tube Track Rule 1), float64.
static func logical_p(theta: float, s: float, h: float, r: float) -> Vector3:
	return Vector3((r + h) * sin(theta), (r + h) * cos(theta), -s)


## Sanitised reference `P(theta, s, h)` for the AC-6 cases: x and y from `TubeMath.frame_xy`, z = -s; a non-finite
## `s` becomes 0 with one ERROR record to `log_sink(level, code, key, message)`.
static func p_reference(theta: float, s: float, h: float, r: float, log_sink: Callable = Callable()) -> Vector3:
	var xy: Vector2 = TubeMath.frame_xy(theta, h, r, log_sink)
	var z: float = s
	if not is_finite(z):
		if log_sink.is_valid():
			log_sink.call(RateLimitedLog.Level.ERROR, TubeMath.NON_FINITE_INPUT, "p_reference", "non-finite s")
		z = 0.0
	return Vector3(xy.x, xy.y, -z)
