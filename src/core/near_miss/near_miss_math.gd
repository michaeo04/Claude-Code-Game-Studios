## Pure Near-Miss Detection math (GDD F1-NM, F2 reused). Static and engine-free; all values are float64.
##
## Footprints are flat `PackedFloat64Array`s, 4 values per piece: `theta_min, theta_max, s_start, s_end`.
class_name NearMissMath
extends RefCounted

## Bit set by `zones` when the swept path overlaps the hit zone.
const HIT_BIT: int = 1
## Bit set by `zones` when the swept path overlaps the near zone.
const NEAR_BIT: int = 2
## F3-NM preflight code: two angularly adjacent pieces active at one critical `s0` whose NEAR zones overlap in theta.
const NEAR_ZONE_OVERLAP: StringName = &"NEAR_ZONE_OVERLAP"


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


## F3-NM validator. At each of F3's critical `s0` points (every finite piece's `s_start - d/2` and `s_end + d/2`,
## ascending, unique) the pieces active there are sorted by theta centre and each angularly adjacent pair, including the
## wraparound pair, is tested: the near zones overlap (closed bounds) when the open arc between the two hit zones is
## `<= 2 * NEAR_MISS_ANGLE_MARGIN`. The check keys off that gap width, never off co-presence at `s0`.
## Returns one `PreflightRecord` per offending pair (at the first `s0` where it is seen, `pieces` ascending), in
## ascending `s0` order. A lone active piece has no pair and is skipped (its own wraparound is proven safe by F3-NM).
## Non-finite pieces are skipped (reported by `ObstacleMath.validate_footprints`). Example: three pieces with eff theta
## spans `[0, 2]`, `[2.01, 4]`, `[4.3, 6]` give exactly one record, for the first two.
static func validate_near_zone_overlap(
	hazards: Array[PreflightHazard], r: float, d: float, cfg: NearMissConfig
) -> Array[PreflightRecord]:
	var out: Array[PreflightRecord] = []
	var half: float = ObstacleMath.ball_half_angle(r, d)
	var reach: float = 2.0 * cfg.angle_margin(half)
	var ids: PackedInt64Array = PackedInt64Array()
	var idx: PackedInt64Array = PackedInt64Array()
	var centre: PackedFloat64Array = PackedFloat64Array()
	var width: PackedFloat64Array = PackedFloat64Array()
	var s_lo: PackedFloat64Array = PackedFloat64Array()
	var s_hi: PackedFloat64Array = PackedFloat64Array()
	var crit: PackedFloat64Array = PackedFloat64Array()
	for hz: PreflightHazard in hazards:
		for k: int in range(hz.piece_count()):
			var b: int = k * 4
			if not (
				is_finite(hz.pieces[b])
				and is_finite(hz.pieces[b + 1])
				and is_finite(hz.pieces[b + 2])
				and is_finite(hz.pieces[b + 3])
			):
				continue
			ids.append(hz.hazard_id)
			idx.append(k)
			centre.append(fposmod((hz.pieces[b] + hz.pieces[b + 1]) / 2.0, TAU))
			width.append(hz.pieces[b + 1] - hz.pieces[b] + 2.0 * half)
			s_lo.append(hz.pieces[b + 2] - d / 2.0)
			s_hi.append(hz.pieces[b + 3] + d / 2.0)
			crit.append(s_lo[s_lo.size() - 1])
			crit.append(s_hi[s_hi.size() - 1])
	crit.sort()
	var seen: Dictionary = {}
	var last: float = NAN
	for s0: float in crit:
		if not is_nan(last) and s0 == last:
			continue
		last = s0
		var order: Array[int] = []
		for i: int in range(ids.size()):
			if s_lo[i] <= s0 and s0 <= s_hi[i]:
				order.append(i)
		var n: int = order.size()
		if n < 2:
			continue
		order.sort_custom(
			func(a: int, b: int) -> bool:
				if centre[a] != centre[b]:
					return centre[a] < centre[b]
				if ids[a] != ids[b]:
					return ids[a] < ids[b]
				return idx[a] < idx[b]
		)
		for k: int in range(n):
			var a: int = order[k]
			var b: int = order[(k + 1) % n]
			var diff: float = centre[b] - centre[a]
			if k == n - 1:
				diff += TAU
			var gap: float = diff - (width[a] + width[b]) / 2.0
			if gap > reach:
				continue
			var lo: Vector2i = Vector2i(ids[a], idx[a])
			var hi: Vector2i = Vector2i(ids[b], idx[b])
			if lo.x > hi.x or (lo.x == hi.x and lo.y > hi.y):
				var swap: Vector2i = lo
				lo = hi
				hi = swap
			var key: Vector4i = Vector4i(lo.x, lo.y, hi.x, hi.y)
			if seen.has(key):
				continue
			seen[key] = true
			var rec: PreflightRecord = PreflightRecord.new(NEAR_ZONE_OVERLAP, -1, s0)
			rec.pieces = [lo, hi]
			out.append(rec)
	return out
