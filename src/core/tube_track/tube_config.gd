## Tuning and map data of Tube Track (GDD Tuning Knobs, Edge Cases "Map validation").
##
## Scalars, enums only: no Resource, Array or Dictionary field (ADR-0004), and no copy of the ball diameter `D`
## (Ball Movement owns it; `validate` takes it). `validate(v_max, d)` returns a set of failure records
## `{code: StringName, ...}`; an empty array means the config loads. Tests compare the code set, not an order.
class_name TubeConfig
extends Resource

## Fog mode; only DEPTH is accepted by the validator.
enum FogMode { DEPTH = 0, EXPONENTIAL = 1 }

## Stable failure codes (GDD Edge Cases, "Map validation").
const NOT_FINITE: StringName = &"NOT_FINITE"
const NOT_POSITIVE: StringName = &"NOT_POSITIVE"
const VISIBILITY: StringName = &"VISIBILITY"
const FOG_BEFORE_READ: StringName = &"FOG_BEFORE_READ"
const FOG_DENSITY: StringName = &"FOG_DENSITY"
const FOG_MODE: StringName = &"FOG_MODE"
const FOG_RANGE: StringName = &"FOG_RANGE"
const A_TOO_LARGE: StringName = &"A_TOO_LARGE"
const A_TOO_SMALL: StringName = &"A_TOO_SMALL"
const A_OUT_OF_RANGE: StringName = &"A_OUT_OF_RANGE"
const B_OUT_OF_RANGE: StringName = &"B_OUT_OF_RANGE"
const L_INVALID: StringName = &"L_INVALID"
const SEAM_HZ: StringName = &"SEAM_HZ"
const R_RANGE: StringName = &"R_RANGE"
const NO_VALID_F: StringName = &"NO_VALID_F"

const R_MIN: float = 2.5
const R_MAX: float = 3.3
const L_RANGE_MIN: int = 6
const L_RANGE_MAX: int = 24
## `gap(R) <= GAP_MAX_FRACTION * D` (F7).
const GAP_MAX_FRACTION: float = 0.02

@export_group("Geometry")
## Tube radius `R` (2.5 to 3.3).
@export var tube_radius: float = 3.0
## Segment length `L`, integer-valued 6 to 24.
@export var segment_length: float = 12.0
## Segments ahead `A` (1 to 12).
@export var segments_ahead: int = 9
## Segments behind `B` (at least ceil((C_b + M_cam) / L), at most 3).
@export var segments_behind: int = 2
## Seams per segment (at least 1).
@export var n_seams: int = 1
## Seam flash frequency cap in Hz (2.1 to 3.0).
@export var seam_hz_max: float = 3.0
## Idle scroll speed in u/s (F8).
@export var idle_scroll_speed: float = 1.5

@export_group("Window")
## Step margin `t_lat` in seconds (the shared `DT_MAX`).
@export var t_lat: float = TuningLimits.DT_MAX_DEFAULT
## Camera rear extent `C_b`.
@export var rear_extent: float = 6.0
## Camera slack `M_cam`.
@export var camera_slack: float = 2.0
## Camera distance `d_cam` (published by Camera).
@export var camera_distance: float = 8.0
## Minimum hazard visibility time `T_VIS_MIN` in seconds.
@export var t_vis_min: float = 1.5

@export_group("Fog")
@export var fog_mode: FogMode = FogMode.DEPTH
## Where depth fog starts (radial from the camera).
@export var fog_depth_begin: float = 44.0
## Fog end distance `F` (100 percent opaque).
@export var fog_end_distance: float = 84.0
@export var fog_depth_curve: float = 1.0
## Must be 1.0 (needed by the F3 horizon reasoning).
@export var fog_density: float = 1.0
## Readable distance `F_read` at v_max.
@export var readable_distance: float = 46.0


## Copy of this config whose `t_lat` is the injected Run State `dt_max` (the single source); `self` is not mutated.
func with_dt_max(dt_max: float) -> TubeConfig:
	var out: TubeConfig = duplicate() as TubeConfig
	out.t_lat = dt_max
	return out


## Validates the config for `v_max` (Ball Movement) and the ball diameter `d`. `raw` optionally replaces the integer
## fields `segment_length`, `segments_ahead`, `segments_behind`, `n_seams` with Variants (a typed int export cannot hold
## 2.5). Returns failure records; `[]` means valid. Reporting rules follow the GDD: a non-finite or non-positive input
## reports `NOT_FINITE` / `NOT_POSITIVE` and skips every check that uses it; `A_TOO_SMALL` only when required A <=
## `A_MAX`; an empty F range reports only `NO_VALID_F` (with `f_min` and `f_max`); below `L_min` only `L_INVALID`.
## A non-integer or non-positive `n_seams` is reported as `NOT_POSITIVE` (field `n_seams`).
## Example: `TubeConfig.new().validate(25.0, 0.8)` is `[]`.
func validate(v_max: float, d: float, raw: Dictionary = {}) -> Array[Dictionary]:
	var out := _records()
	var l_var: Variant = raw.get("segment_length", segment_length)
	var a_var: Variant = raw.get("segments_ahead", segments_ahead)
	var b_var: Variant = raw.get("segments_behind", segments_behind)
	var n_var: Variant = raw.get("n_seams", n_seams)

	var f_ok: bool = _positive(out, "fog_end_distance", fog_end_distance)
	var fr_ok: bool = _positive(out, "readable_distance", readable_distance)
	var dcam_ok: bool = _positive(out, "camera_distance", camera_distance)
	var curve_ok: bool = _positive(out, "fog_depth_curve", fog_depth_curve)
	var v_ok: bool = _positive(out, "v_max", v_max)
	var lat_ok: bool = _positive(out, "t_lat", t_lat)
	var cb_ok: bool = _positive(out, "rear_extent", rear_extent)
	var mcam_ok: bool = _positive(out, "camera_slack", camera_slack)
	var tv_ok: bool = _positive(out, "t_vis_min", t_vis_min)
	var hz_ok: bool = _positive(out, "seam_hz_max", seam_hz_max)
	var d_ok: bool = _positive(out, "ball_diameter", d)
	var r_ok: bool = _positive(out, "tube_radius", tube_radius)
	var begin_ok: bool = is_finite(fog_depth_begin)
	if not begin_ok:
		out.append({"code": NOT_FINITE, "field": "fog_depth_begin"})
	var dens_ok: bool = is_finite(fog_density)
	if not dens_ok:
		out.append({"code": NOT_FINITE, "field": "fog_density"})
	elif absf(fog_density - 1.0) > 1e-9:
		out.append({"code": FOG_DENSITY})
	if fog_mode != FogMode.DEPTH:
		out.append({"code": FOG_MODE})

	# Radius and facet gap.
	if r_ok:
		var bad_r: bool = not (tube_radius >= R_MIN and tube_radius <= R_MAX)
		if d_ok and TubeMath.facet_gap(tube_radius) > GAP_MAX_FRACTION * d:
			bad_r = true
		if bad_r:
			out.append({"code": R_RANGE})

	# Segment length L: integer in [6, 24] and at least L_min.
	var l_ok: bool = false
	var l: float = 0.0
	if _is_number(l_var):
		l = float(l_var)
		if not is_finite(l):
			out.append({"code": NOT_FINITE, "field": "segment_length"})
		elif l <= 0.0:
			out.append({"code": NOT_POSITIVE, "field": "segment_length"})
		else:
			var l_min: int = -1
			if v_ok and hz_ok:
				l_min = TubeMath.l_min(v_max, seam_hz_max)
			var bad_l: bool = not (l == floorf(l) and l >= float(L_RANGE_MIN) and l <= float(L_RANGE_MAX))
			if l_min >= 0 and l < float(l_min):
				bad_l = true
			if bad_l:
				out.append({"code": L_INVALID, "l_min": l_min})
			else:
				l_ok = true

	# Seams.
	var n_ok: bool = false
	var n: int = 0
	if _is_number(n_var) and is_finite(float(n_var)) and float(n_var) >= 1.0 and float(n_var) == floorf(float(n_var)):
		n_ok = true
		n = int(n_var)
	elif _is_number(n_var) and not is_finite(float(n_var)):
		out.append({"code": NOT_FINITE, "field": "n_seams"})
	else:
		out.append({"code": NOT_POSITIVE, "field": "n_seams"})
	if n_ok and l_ok and v_ok and hz_ok and TubeMath.f_seam(v_max, l, n) > seam_hz_max + 1e-9:
		out.append({"code": SEAM_HZ, "max_n_seams": TubeMath.max_n_seams(seam_hz_max, l, v_max)})

	# Fog ordering.
	if f_ok and fr_ok and readable_distance > fog_end_distance:
		out.append({"code": FOG_BEFORE_READ})
	if f_ok and begin_ok and fog_depth_begin >= fog_end_distance:
		out.append({"code": FOG_RANGE})

	# F9 range of F and the window.
	var range_known: bool = l_ok and v_ok and lat_ok and dcam_ok and tv_ok
	var range_empty: bool = false
	if range_known:
		var f_min: float = t_vis_min * v_max + camera_distance
		var f_max: float = float(TubeMath.A_MAX - 1) * l - v_max * t_lat
		if f_min > f_max:
			range_empty = true
			out.append({"code": NO_VALID_F, "f_min": f_min, "f_max": f_max})
	if not range_empty and v_ok and dcam_ok and tv_ok and fr_ok:
		if readable_distance - camera_distance < t_vis_min * v_max:
			out.append({"code": VISIBILITY})

	# Window A and B.
	var a_ok: bool = _is_number(a_var) and is_finite(float(a_var)) and float(a_var) == floorf(float(a_var)) \
			and float(a_var) >= 1.0 and float(a_var) <= float(TubeMath.A_MAX)
	if not a_ok:
		out.append({"code": A_OUT_OF_RANGE})
	if l_ok and v_ok and lat_ok and f_ok:
		var req_a: int = TubeMath.required_a(fog_end_distance, v_max, t_lat, l)
		if req_a > TubeMath.A_MAX:
			if not range_empty:
				out.append({"code": A_TOO_LARGE, "required": req_a})
		elif a_ok and int(a_var) < req_a:
			out.append({"code": A_TOO_SMALL, "required": req_a, "configured": int(a_var)})
	if l_ok and cb_ok and mcam_ok:
		var req_b: int = TubeMath.required_b(rear_extent, camera_slack, l)
		var b_bad: bool = not (_is_number(b_var) and float(b_var) == floorf(float(b_var)) and float(b_var) >= float(req_b) and float(b_var) <= float(TubeMath.B_MAX))
		if b_bad:
			out.append({"code": B_OUT_OF_RANGE, "required": req_b})
	elif not _is_number(b_var) or float(b_var) > float(TubeMath.B_MAX) or float(b_var) < 0.0:
		out.append({"code": B_OUT_OF_RANGE})
	return out


static func _records() -> Array[Dictionary]:
	return []


static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## True when `value` is finite and positive; otherwise appends `NOT_FINITE` or `NOT_POSITIVE` and returns false.
static func _positive(out: Array[Dictionary], field: String, value: float) -> bool:
	if not is_finite(value):
		out.append({"code": NOT_FINITE, "field": field})
		return false
	if value <= 0.0:
		out.append({"code": NOT_POSITIVE, "field": field})
		return false
	return true
