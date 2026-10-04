## Pure tube geometry math (ADR-0013, frame `P` of design/gdd/tube-track.md Rule 1).
##
## Static and engine-free. The tube-track epic extends THIS file with the other functions (wrap_angle,
## delta_theta, F2-F9, idle_step); do not create a second TubeMath file. No function here returns a
## `Vector3` built from the distance `s`: a view builds `Vector3(p.x, p.y, world_frame.render_z(s))`.
class_name TubeMath
extends RefCounted

## Log code for a non-finite `theta` or `h` (TR-tube-track-002); the key is the function name.
const NON_FINITE_INPUT: StringName = &"TUBE_NON_FINITE_INPUT"
## Log code for a negative `h` clamped to 0 (logged at `RateLimitedLog.Level.DEBUG`: the log has no warning level).
const H_NEGATIVE: StringName = &"TUBE_H_NEGATIVE"

## Fixed caps (GDD F3): segments ahead, segments behind, and pool size.
const A_MAX: int = 12
const B_MAX: int = 3
const N_MAX: int = 16
## Facet count factor of F7: the tube is a polygon with 64 facets, half-angle `PI / 32`.
const _FACET_HALF_ANGLE: float = PI / 32.0


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


## F1 angle wrap to `[-PI, PI)`: `fposmod(a + PI, TAU) - PI`, minus `TAU` if the result is at least `PI` (the guard
## matters for the double just below `-PI`). A non-finite input returns 0 and sends one ERROR to `log_sink`.
## This is the canonical copy; `BallMath.wrap_angle` duplicates it and should be repointed here.
## Example: `wrap_angle(3.0 * PI / 2.0)` is `-PI / 2.0`.
static func wrap_angle(a: float, log_sink: Callable = Callable()) -> float:
	if not is_finite(a):
		_log(log_sink, RateLimitedLog.Level.ERROR, NON_FINITE_INPUT, "wrap_angle", "wrap_angle got a non-finite angle (%s)" % [a])
		return 0.0
	var r: float = fposmod(a + PI, TAU) - PI
	if r >= PI:
		r -= TAU
	return r


## F1 shortest signed difference `wrap_angle(a - b)`; a non-finite result returns 0 with one ERROR.
## Opposite angles give magnitude PI with an arbitrary sign: never rely on that sign.
static func delta_theta(a: float, b: float, log_sink: Callable = Callable()) -> float:
	return wrap_angle(a - b, log_sink)


## The x and y of the GDD frame `P` with input sanitising (Rule 1): a negative `h` becomes 0 with one DEBUG record;
## a non-finite `h` becomes 0 and a non-finite `theta` becomes 0, each with one ERROR record. Then `local_point`.
## Example: `frame_xy(PI, 0.5, 3.0)` is `(0, -3.5)` up to rounding.
static func frame_xy(theta: float, h: float, r: float, log_sink: Callable = Callable()) -> Vector2:
	var t: float = theta
	var height: float = h
	if not is_finite(t):
		_log(log_sink, RateLimitedLog.Level.ERROR, NON_FINITE_INPUT, "frame_xy", "frame_xy got a non-finite theta (%s)" % [theta])
		t = 0.0
	if not is_finite(height):
		_log(log_sink, RateLimitedLog.Level.ERROR, NON_FINITE_INPUT, "frame_xy", "frame_xy got a non-finite h (%s)" % [h])
		height = 0.0
	elif height < 0.0:
		_log(log_sink, RateLimitedLog.Level.DEBUG, H_NEGATIVE, "frame_xy", "frame_xy clamped h=%s to 0" % [h])
		height = 0.0
	return local_point(t, height, r)


## F6 half of the angular width of one ball in radians: `asin(D / (2 * (R + D / 2)))`. Defined for `R > 0`.
static func lane_half_angle(r: float, d: float) -> float:
	return asin(d / (2.0 * (r + d / 2.0)))


## F6 angular width of one lane in degrees: `2 * asin(D / (2 * (R + D / 2)))`. Example: R 3, D 0.8 gives 13.5.
static func lane_width_deg(r: float, d: float) -> float:
	return rad_to_deg(2.0 * lane_half_angle(r, d))


## F6 lane count `floor(PI / asin(D / (2 * (R + D / 2))))`. Example: R 3, D 0.8 gives 26; R 2.5 gives 22.
static func lane_count(r: float, d: float) -> int:
	return floori(PI / lane_half_angle(r, d))


## F7 facet gap `R * (1 - cos(PI / 32))`; the requirement is `gap(R) <= 0.02 * D`. Example: R 3 gives 0.0144.
static func facet_gap(r: float) -> float:
	return r * (1.0 - cos(_FACET_HALF_ANGLE))


## F2 segment index `floori(s / L)` (never `int()`, which is off by one for s < 0). Example: `-1` at L 12 is `-1`.
static func segment_index(s: float, l: float) -> int:
	return floori(s / l)


## F2 pool slot `posmod(i, N)`. Example: `slot_of(-1, 12)` is `11`.
static func slot_of(i: int, n: int) -> int:
	return posmod(i, n)


## F3 minimum segments ahead `ceil((F + v_max * t_lat) / L) + 1`. Example: F 84, L 12 gives 9.
static func required_a(f: float, v_max: float, t_lat: float, l: float) -> int:
	return ceili((f + v_max * t_lat) / l) + 1


## F3 minimum segments behind `ceil((C_b + M_cam) / L)`. Example: C_b 6, M_cam 2, L 12 gives 1.
static func required_b(c_b: float, m_cam: float, l: float) -> int:
	return ceili((c_b + m_cam) / l)


## F5 seam spacing `SP = L / n_seams`.
static func seam_spacing(l: float, n_seams: int) -> float:
	return l / float(n_seams)


## F5 position of seam `j` of segment `i`: `i * L + (j + 0.5) * (L / n_seams)`. Example: i 0, j 0, L 12, n 1 is 6.
static func seam_s(i: int, j: int, l: float, n_seams: int) -> float:
	return float(i) * l + (float(j) + 0.5) * seam_spacing(l, n_seams)


## F5 seam frequency `v / SP` in Hz. Example: v 25, L 12, n 1 gives 2.0833.
static func f_seam(v: float, l: float, n_seams: int) -> float:
	return v / seam_spacing(l, n_seams)


## F5 largest allowed `n_seams`, `floor(SEAM_HZ_MAX * L / v_max)`.
static func max_n_seams(seam_hz_max: float, l: float, v_max: float) -> int:
	return floori(seam_hz_max * l / v_max)


## F5 shortest loadable segment `ceil(v_max / SEAM_HZ_MAX)`. Example: v_max 25 at 3 Hz gives 9.
static func l_min(v_max: float, seam_hz_max: float) -> int:
	return ceili(v_max / seam_hz_max)


## F5/AC-17 idle scroll: `fposmod(s_idle + v_idle * step, L)` with `step = clamp(dt, 0, t_lat)`; a non-finite or negative
## `dt` adds 0. The result is always in `[0, L)` (guards `fposmod(-tiny, L)` returning exactly `L`).
## Example: `idle_step(0.0, 1.5, 1.0 / 60.0, 0.1, 12.0)` is 0.025.
static func idle_step(s_idle: float, v_idle: float, dt: float, t_lat: float, l: float) -> float:
	var step: float = 0.0
	if is_finite(dt) and dt > 0.0:
		step = minf(dt, t_lat)
	var r: float = fposmod(s_idle + v_idle * step, l)
	if r >= l or r < 0.0:
		r = 0.0
	return r


## AC-18 pure content of segment `index`: `{"index": int, "seam_s": Array[float]}` (seam positions along the track,
## F5, one per seam). A function of `(cfg, index)` only: no randomness, no engine objects.
static func segment_content(cfg: TubeConfig, index: int) -> Dictionary:
	var seams: Array[float] = []
	for j: int in range(cfg.n_seams):
		seams.append(seam_s(index, j, cfg.segment_length, cfg.n_seams))
	return {"index": index, "seam_s": seams}


static func _log(log_sink: Callable, level: int, code: StringName, key: String, message: String) -> void:
	if log_sink.is_valid():
		log_sink.call(level, code, key, message)
