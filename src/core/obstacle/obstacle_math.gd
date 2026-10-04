## Pure Obstacle System math (GDD F1, F2). Static and engine-free; all values are float64.
##
## Footprints are flat `PackedFloat64Array`s, 4 values per piece: `theta_min, theta_max, s_start, s_end`.
## The F3 sweep-line and the preflight validators (Stories 004, 005) live at the bottom; F4 is added by later stories.
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


# ---------------------------------------------------------------------------------------------------------------
# Offline preflight validators (Stories 004 and 005). Pure, exhaustive and deterministic: hazards are visited in
# ascending `hazard_id` order, results come back as `PreflightRecord`s and nothing stops at the first failure.
# ---------------------------------------------------------------------------------------------------------------

## F3: a gap must hold a ball width times `GAP_MARGIN` (`NO_SAFE_GAP`).
const NO_SAFE_GAP: StringName = &"NO_SAFE_GAP"
## Two different hazards whose footprints touch (`HAZARD_OVERLAP`).
const HAZARD_OVERLAP: StringName = &"HAZARD_OVERLAP"
const FOOTPRINT_NOT_FINITE: StringName = &"FOOTPRINT_NOT_FINITE"
const FOOTPRINT_INVALID_ORDER: StringName = &"FOOTPRINT_INVALID_ORDER"
const HOME_SEGMENT_MISMATCH: StringName = &"HOME_SEGMENT_MISMATCH"
const GRACE_ZONE_VIOLATION: StringName = &"GRACE_ZONE_VIOLATION"
const TOO_MANY_PIECES: StringName = &"TOO_MANY_PIECES"
const TOO_DENSE: StringName = &"TOO_DENSE"
## A piece whose whole arc lies beyond the visible arc (the ban is active until OQ2 and OQ15 resolve).
const HIDDEN_CONTENT_FORBIDDEN: StringName = &"HIDDEN_CONTENT_FORBIDDEN"
## Hidden pieces too close together (F4b frequency floor).
const HIDDEN_UNFAIR: StringName = &"HIDDEN_UNFAIR"
## An escape gap beyond the visible arc on a type that is not PI-symmetric.
const EXIT_BEYOND_VISIBLE_ARC: StringName = &"EXIT_BEYOND_VISIBLE_ARC"
## Fixed reference angle of the static hidden classification: the tube's top.
const THETA_REF: float = 0.0
## Tolerance of the PI-symmetry test of the exit rule.
const PI_SYMMETRY_TOLERANCE: float = 1e-6

## Numeric slack of the F3 `>=` check (GDD AC-6: "to within 1e-4"); authored gaps are given to four decimals.
const GAP_TOLERANCE: float = 1e-4
## Float-noise slack of the F5 spacing check.
const SPACING_EPSILON: float = 1e-9


## `w = 2 * BALL_HALF_ANGLE`, the angular width of one ball (Tube Track F6).
static func ball_width(r: float, d: float) -> float:
	return 2.0 * ball_half_angle(r, d)


## `GAP_MIN = GAP_MARGIN * w`, computed from the injected `R`, `D`, `GAP_MARGIN` (never from constants).
static func gap_min(r: float, d: float, gap_margin: float) -> float:
	return gap_margin * ball_width(r, d)


## F5 `S_MIN_SPACING = T_REACT * v_max`.
static func min_spacing(t_react: float, v_max: float) -> float:
	return t_react * v_max


## F3 sweep-line over every critical `s0` (each piece's `s_eff_start` and `s_eff_end`, ascending, unique):
## `open(s0) = 2*PI - sum(theta_eff widths of the active pieces of any hazard)` must be `>= GAP_MIN`.
## One `NO_SAFE_GAP` record per failing `s0`, holding `s0` and the active `(hazard_id, piece_index)` set.
## Pieces with a non-finite field are skipped (reported by `validate_footprints`).
static func validate_gaps(
	hazards: Array[PreflightHazard], r: float, d: float, gap_margin: float
) -> Array[PreflightRecord]:
	var out: Array[PreflightRecord] = []
	var half: float = ball_half_angle(r, d)
	var floor_open: float = gap_min(r, d, gap_margin) - GAP_TOLERANCE
	var ids: PackedInt64Array = PackedInt64Array()
	var idx: PackedInt64Array = PackedInt64Array()
	var widths: PackedFloat64Array = PackedFloat64Array()
	var s_lo: PackedFloat64Array = PackedFloat64Array()
	var s_hi: PackedFloat64Array = PackedFloat64Array()
	var crit: PackedFloat64Array = PackedFloat64Array()
	for hz: PreflightHazard in _sorted_hazards(hazards):
		for k: int in range(hz.piece_count()):
			if not _piece_finite(hz.pieces, k * 4):
				continue
			ids.append(hz.hazard_id)
			idx.append(k)
			widths.append(hz.pieces[k * 4 + 1] - hz.pieces[k * 4] + 2.0 * half)
			s_lo.append(hz.pieces[k * 4 + 2] - d / 2.0)
			s_hi.append(hz.pieces[k * 4 + 3] + d / 2.0)
			crit.append(s_lo[s_lo.size() - 1])
			crit.append(s_hi[s_hi.size() - 1])
	crit.sort()
	var last: float = NAN
	for s0: float in crit:
		if not is_nan(last) and s0 == last:
			continue
		last = s0
		var occupied: float = 0.0
		var active: Array[Vector2i] = []
		for i: int in range(ids.size()):
			if s_lo[i] <= s0 and s0 <= s_hi[i]:
				occupied += widths[i]
				active.append(Vector2i(ids[i], idx[i]))
		if TAU - occupied < floor_open:
			var rec: PreflightRecord = PreflightRecord.new(NO_SAFE_GAP, -1, s0)
			rec.pieces = active
			out.append(rec)
	return out


## `HAZARD_OVERLAP`, pairwise over the whole library (distinct hazards only), one record per offending pair.
## Two pieces collide when one piece's raw footprint reaches into the other's effective (F1 expanded) footprint in
## both `theta` and `s`, i.e. their raw gaps are within `BALL_HALF_ANGLE` and `D/2` (the ball is expanded once, not
## twice; this reproduces the GDD AC-11 rows). Closed bounds.
static func validate_overlaps(hazards: Array[PreflightHazard], r: float, d: float) -> Array[PreflightRecord]:
	var out: Array[PreflightRecord] = []
	var half: float = ball_half_angle(r, d)
	var sorted: Array[PreflightHazard] = _sorted_hazards(hazards)
	for i: int in range(sorted.size()):
		for j: int in range(i + 1, sorted.size()):
			var a: PreflightHazard = sorted[i]
			var b: PreflightHazard = sorted[j]
			if a.hazard_id == b.hazard_id:
				continue
			var hit: Vector2i = _first_piece_overlap(a, b, half, d)
			if hit.x >= 0:
				var s_first: float = maxf(a.pieces[hit.x * 4 + 2], b.pieces[hit.y * 4 + 2])
				var rec: PreflightRecord = PreflightRecord.new(HAZARD_OVERLAP, -1, s_first)
				rec.pieces = [Vector2i(a.hazard_id, hit.x), Vector2i(b.hazard_id, hit.y)]
				out.append(rec)
	return out


## `FOOTPRINT_NOT_FINITE` (any NaN or infinite field, one record per piece, the piece is then not order-checked) and
## `FOOTPRINT_INVALID_ORDER` (`theta_max < theta_min` or `s_end < s_start`, one record per piece; equal bounds pass).
static func validate_footprints(hazards: Array[PreflightHazard]) -> Array[PreflightRecord]:
	var out: Array[PreflightRecord] = []
	for hz: PreflightHazard in _sorted_hazards(hazards):
		for k: int in range(hz.piece_count()):
			var b: int = k * 4
			var code: StringName = &""
			if not _piece_finite(hz.pieces, b):
				code = FOOTPRINT_NOT_FINITE
			elif hz.pieces[b + 1] < hz.pieces[b] or hz.pieces[b + 3] < hz.pieces[b + 2]:
				code = FOOTPRINT_INVALID_ORDER
			if code != &"":
				var s_at: float = hz.pieces[b + 2] if is_finite(hz.pieces[b + 2]) else 0.0
				var rec: PreflightRecord = PreflightRecord.new(code, hz.home_segment, s_at)
				rec.pieces = [Vector2i(hz.hazard_id, k)]
				out.append(rec)
	return out


## `HOME_SEGMENT_MISMATCH`: a piece's raw `s` range must lie fully inside `[k*L, (k+1)*L)` of its declared segment `k`
## (Edge Cases text; a piece straddling the boundary is rejected). One record per piece. Non-finite pieces are skipped.
static func validate_home_segments(hazards: Array[PreflightHazard], seg_len: float) -> Array[PreflightRecord]:
	var out: Array[PreflightRecord] = []
	for hz: PreflightHazard in _sorted_hazards(hazards):
		var lo: float = hz.home_segment * seg_len
		var hi: float = (hz.home_segment + 1) * seg_len
		for k: int in range(hz.piece_count()):
			if not _piece_finite(hz.pieces, k * 4):
				continue
			if hz.pieces[k * 4 + 2] < lo or hz.pieces[k * 4 + 3] >= hi:
				var rec: PreflightRecord = PreflightRecord.new(HOME_SEGMENT_MISMATCH, hz.home_segment, hz.pieces[k * 4 + 2])
				rec.pieces = [Vector2i(hz.hazard_id, k)]
				out.append(rec)
	return out


## `GRACE_ZONE_VIOLATION`: a piece of segment 0 with raw `s_start < grace_length` (strict, so exactly equal passes).
static func validate_grace_zone(hazards: Array[PreflightHazard], grace_length: float) -> Array[PreflightRecord]:
	var out: Array[PreflightRecord] = []
	for hz: PreflightHazard in _sorted_hazards(hazards):
		if hz.home_segment != 0:
			continue
		for k: int in range(hz.piece_count()):
			if _piece_finite(hz.pieces, k * 4) and hz.pieces[k * 4 + 2] < grace_length:
				var rec: PreflightRecord = PreflightRecord.new(GRACE_ZONE_VIOLATION, 0, hz.pieces[k * 4 + 2])
				rec.pieces = [Vector2i(hz.hazard_id, k)]
				out.append(rec)
	return out


## `TOO_MANY_PIECES`: pieces summed over every hazard bound to one segment must be `<= max_pieces`.
## One record per offending segment, ascending, with `count` set.
static func validate_piece_counts(hazards: Array[PreflightHazard], max_pieces: int) -> Array[PreflightRecord]:
	var out: Array[PreflightRecord] = []
	var totals: Dictionary = {}
	for hz: PreflightHazard in hazards:
		totals[hz.home_segment] = (totals.get(hz.home_segment, 0) as int) + hz.piece_count()
	var segments: Array = totals.keys()
	segments.sort()
	for seg: int in segments:
		var total: int = totals[seg] as int
		if total > max_pieces:
			var rec: PreflightRecord = PreflightRecord.new(TOO_MANY_PIECES, seg, 0.0)
			rec.count = total
			out.append(rec)
	return out


## F5 `TOO_DENSE`: each hazard is one read positioned at its earliest finite raw `s_start`; reads sorted by position
## (ties by `hazard_id`) across the whole library must be consecutively `>= S_MIN_SPACING` apart. One record per
## offending consecutive pair (`s0` = the later read).
static func validate_spacing(hazards: Array[PreflightHazard], s_min_spacing: float) -> Array[PreflightRecord]:
	var out: Array[PreflightRecord] = []
	var pos: PackedFloat64Array = PackedFloat64Array()
	var ids: PackedInt64Array = PackedInt64Array()
	for hz: PreflightHazard in hazards:
		var earliest: float = INF
		for k: int in range(hz.piece_count()):
			if _piece_finite(hz.pieces, k * 4):
				earliest = minf(earliest, hz.pieces[k * 4 + 2])
		if is_finite(earliest):
			pos.append(earliest)
			ids.append(hz.hazard_id)
	var order: Array[int] = []
	for i: int in range(pos.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return pos[a] < pos[b] or (pos[a] == pos[b] and ids[a] < ids[b]))
	for n: int in range(1, order.size()):
		var prev: int = order[n - 1]
		var cur: int = order[n]
		if pos[cur] - pos[prev] < s_min_spacing - SPACING_EPSILON:
			var rec: PreflightRecord = PreflightRecord.new(TOO_DENSE, -1, pos[cur])
			rec.pieces = [Vector2i(ids[prev], -1), Vector2i(ids[cur], -1)]
			out.append(rec)
	return out


static func _piece_finite(p: PackedFloat64Array, base: int) -> bool:
	return is_finite(p[base]) and is_finite(p[base + 1]) and is_finite(p[base + 2]) and is_finite(p[base + 3])


static func _sorted_hazards(hazards: Array[PreflightHazard]) -> Array[PreflightHazard]:
	var copy: Array[PreflightHazard] = []
	copy.append_array(hazards)
	copy.sort_custom(func(a: PreflightHazard, b: PreflightHazard) -> bool: return a.hazard_id < b.hazard_id)
	return copy


## First `(piece_a, piece_b)` pair of two hazards that overlap, else `Vector2i(-1, -1)`.
static func _first_piece_overlap(a: PreflightHazard, b: PreflightHazard, half: float, d: float) -> Vector2i:
	for i: int in range(a.piece_count()):
		if not _piece_finite(a.pieces, i * 4):
			continue
		for j: int in range(b.piece_count()):
			if not _piece_finite(b.pieces, j * 4):
				continue
			var a0: float = a.pieces[i * 4]
			var a1: float = a.pieces[i * 4 + 1]
			var b0: float = b.pieces[j * 4]
			var b1: float = b.pieces[j * 4 + 1]
			var theta_ok: bool = arc_overlap(a0 - half, a1 - a0 + 2.0 * half, b0, b1 - b0)
			var s_ok: bool = (
				b.pieces[j * 4 + 2] <= a.pieces[i * 4 + 3] + d / 2.0
				and a.pieces[i * 4 + 2] <= b.pieces[j * 4 + 3] + d / 2.0
			)
			if theta_ok and s_ok:
				return Vector2i(i, j)
	return Vector2i(-1, -1)


## F4 `hidden()` of one raw piece: the whole arc `[theta_min, theta_max]` lies farther than `visible_half` from
## `theta_ref`. `W = theta_max - theta_min`, `o = fposmod(theta_ref - theta_min, 2*PI)`,
## `d_min = 0 if o <= W else min(o - W, 2*PI - o)`, `hidden := d_min > visible_half` (strict).
static func hidden(theta_min: float, theta_max: float, visible_half: float, theta_ref: float = THETA_REF) -> bool:
	var width: float = theta_max - theta_min
	var o: float = fposmod(theta_ref - theta_min, TAU)
	var d_min: float = 0.0 if o <= width else minf(o - width, TAU - o)
	return d_min > visible_half


## `HIDDEN_CONTENT_FORBIDDEN`: one record per hidden piece (a hazard with one hidden piece is rejected).
static func validate_hidden_content(hazards: Array[PreflightHazard], visible_half: float) -> Array[PreflightRecord]:
	var out: Array[PreflightRecord] = []
	for hz: PreflightHazard in _sorted_hazards(hazards):
		for k: int in range(hz.piece_count()):
			if _piece_finite(hz.pieces, k * 4) and hidden(hz.pieces[k * 4], hz.pieces[k * 4 + 1], visible_half):
				var rec: PreflightRecord = PreflightRecord.new(
					HIDDEN_CONTENT_FORBIDDEN, hz.home_segment, hz.pieces[k * 4 + 2]
				)
				rec.pieces = [Vector2i(hz.hazard_id, k)]
				out.append(rec)
	return out


## F4b `HIDDEN_UNFAIR`: hidden pieces of different hazards sorted by `s_start` must be at least
## `hidden_span_min_s` apart (`>=`) and never in the same or an adjacent home segment. One record per offending
## consecutive pair (`s0` = the later `s_start`). The pieces of one hazard count as one read.
static func validate_hidden_frequency(
	hazards: Array[PreflightHazard], visible_half: float, hidden_span_min_s: float
) -> Array[PreflightRecord]:
	var out: Array[PreflightRecord] = []
	var reads: Array[Dictionary] = []
	for hz: PreflightHazard in _sorted_hazards(hazards):
		var first: Dictionary = {}
		for k: int in range(hz.piece_count()):
			if _piece_finite(hz.pieces, k * 4) and hidden(hz.pieces[k * 4], hz.pieces[k * 4 + 1], visible_half):
				if first.is_empty() or hz.pieces[k * 4 + 2] < (first["s"] as float):
					first = {"id": hz.hazard_id, "piece": k, "s": hz.pieces[k * 4 + 2], "seg": hz.home_segment}
		if not first.is_empty():
			reads.append(first)
	reads.sort_custom(_read_before)
	for n: int in range(1, reads.size()):
		var prev: Dictionary = reads[n - 1]
		var cur: Dictionary = reads[n]
		var gap: float = (cur["s"] as float) - (prev["s"] as float)
		var adjacent: bool = absi((cur["seg"] as int) - (prev["seg"] as int)) <= 1
		if adjacent or gap < hidden_span_min_s - SPACING_EPSILON:
			var rec: PreflightRecord = PreflightRecord.new(HIDDEN_UNFAIR, cur["seg"] as int, cur["s"] as float)
			rec.pieces = [
				Vector2i(prev["id"] as int, prev["piece"] as int), Vector2i(cur["id"] as int, cur["piece"] as int)
			]
			out.append(rec)
	return out


## `EXIT_BEYOND_VISIBLE_ARC`: per solution angle, `e = fposmod(angle - theta_ref, 2*PI)`, `d_exit = min(e, 2*PI - e)`;
## `d_exit > visible_half` is only allowed when `d_exit` is PI within 1e-6. One record per failing angle (`angle`
## set). A hazard without solution angles (Spike) is exempt.
static func validate_exit_rule(
	hazards: Array[PreflightHazard], visible_half: float, theta_ref: float = THETA_REF
) -> Array[PreflightRecord]:
	var out: Array[PreflightRecord] = []
	for hz: PreflightHazard in _sorted_hazards(hazards):
		for angle: float in hz.solution_angles:
			if not is_finite(angle):
				continue
			var e: float = fposmod(angle - theta_ref, TAU)
			var d_exit: float = minf(e, TAU - e)
			if d_exit > visible_half and absf(d_exit - PI) > PI_SYMMETRY_TOLERANCE:
				var rec: PreflightRecord = PreflightRecord.new(EXIT_BEYOND_VISIBLE_ARC, hz.home_segment, 0.0)
				rec.pieces = [Vector2i(hz.hazard_id, -1)]
				rec.angle = angle
				out.append(rec)
	return out


static func _read_before(a: Dictionary, b: Dictionary) -> bool:
	var sa: float = a["s"] as float
	var sb: float = b["s"] as float
	return sa < sb or (sa == sb and (a["id"] as int) < (b["id"] as int))
