## Pure tube geometry math (ADR-0013, frame `P` of design/gdd/tube-track.md Rule 1).
##
## Static and engine-free. The tube-track epic extends THIS file with the other functions (wrap_angle,
## delta_theta, F2-F9, idle_step); do not create a second TubeMath file. No function here returns a
## `Vector3` built from the distance `s`: a view builds `Vector3(p.x, p.y, world_frame.render_z(s))`.
class_name TubeMath
extends RefCounted

## Log code for a non-finite `theta` or `h` (TR-tube-track-002); the key is the function name.
const NON_FINITE_INPUT: StringName = &"TUBE_NON_FINITE_INPUT"


## The x and y of the GDD's `P`: `((r + h) * sin(theta), (r + h) * cos(theta))`; the z is `WorldFrame.render_z(s)`.
## `r` is the tube radius `R` (from WorldGeometry). A non-finite `theta`, `h` or `r` returns `Vector2.ZERO` and
## sends one ERROR record to `log_sink(level, code, key, message)` when that callable is valid.
static func local_point(theta: float, h: float, r: float, log_sink: Callable = Callable()) -> Vector2:
	if not (is_finite(theta) and is_finite(h) and is_finite(r)):
		if log_sink.is_valid():
			log_sink.call(
				RateLimitedLog.Level.ERROR,
				NON_FINITE_INPUT,
				"local_point",
				"local_point got a non-finite input (theta=%s, h=%s, r=%s)" % [theta, h, r]
			)
		return Vector2.ZERO
	var radius: float = r + h
	return Vector2(radius * sin(theta), radius * cos(theta))
