## Obstacle System runtime core (GDD Core Rules 1 to 7; ADR-0008 Decision 3): binds the hazards of each segment that
## enters Tube Track's window, releases them when it leaves or the window is re-primed, and runs the analytic swept
## test of the ball against every bound hazard once per tick. Pure RefCounted, no engine call, no physics node.
##
## Inputs (the driver or a test connects the matching signals): `on_segment_entered_window`,
## `on_segment_left_window`, `on_window_primed`, `on_run_reset`, and `step(ball)` once per tick.
## Example: `core.on_window_primed(-2, 6)` then `core.step(ball)`.
class_name ObstacleCore
extends RefCounted

## A second `hazards_for_segment` query for an index that is already bound.
const DUPLICATE_SEGMENT_QUERY: StringName = &"DUPLICATE_SEGMENT_QUERY"

## A hazard was stored. `footprint` is 4 floats per piece in world `s`: `theta_min, theta_max, s_start, s_end` (raw).
## State is recorded before the emission, so the read accessors are valid inside the handler.
signal hazard_bound(hazard_id: int, footprint: PackedFloat64Array)
## A hazard was dropped. `released_by_reset` is true for every `window_primed` release, false for a recycle.
signal hazard_released(hazard_id: int, released_by_reset: bool)
## The ball overlaps the hazard on this tick (level-triggered, one per hazard per tick, ascending `hazard_id`).
signal hit_reported(hazard_id: int, run_id: int)

var _cfg: ObstacleConfig
var _provider: HazardContentProvider
var _seg_len: float
var _half_angle: float
var _d: float
var _log_sink: Callable
var _run_id: int = 0
var _next_id: int = 0
var _hazards: Dictionary = {}
var _queried: Dictionary = {}


class _Hazard:
	extends RefCounted
	var hazard_id: int = 0
	var home_segment: int = 0
	var hazard_type: int = 0
	var footprint: PackedFloat64Array = PackedFloat64Array()
	var eff: PackedFloat64Array = PackedFloat64Array()
	var s_lo: float = 0.0
	var s_hi: float = 0.0
	var spec: HazardSpec = null
	var s_offset: float = 0.0


## `seg_len` is `L`, `half_angle` is `BALL_HALF_ANGLE`, `d` the ball diameter `D`.
func _init(
	cfg: ObstacleConfig,
	provider: HazardContentProvider,
	seg_len: float,
	half_angle: float,
	d: float,
	log_sink: Callable = Callable()
) -> void:
	_cfg = cfg
	_provider = provider
	_seg_len = seg_len
	_half_angle = half_angle
	_d = d
	_log_sink = log_sink


## `segment_entered_window(index)`: queries the provider once for `index` and binds every returned spec.
func on_segment_entered_window(index: int) -> void:
	if _queried.has(index):
		_log(DUPLICATE_SEGMENT_QUERY, "segment_index", "segment %d was already queried" % index)
		return
	_queried[index] = true
	_bind_segment(index)


## `segment_left_window(index)`: releases the hazards bound to `index` with `released_by_reset` false.
func on_segment_left_window(index: int) -> void:
	_queried.erase(index)
	var ids: Array[int] = []
	for key: int in _hazards.keys():
		if (_hazards[key] as _Hazard).home_segment == index:
			ids.append(key)
	for id: int in ids:
		_hazards.erase(id)
		hazard_released.emit(id, false)


## `window_primed(first, last)`: releases everything (flag true), restarts ids at 0, then populates `first..last`.
func on_window_primed(first_index: int, last_index: int) -> void:
	var ids: Array[int] = []
	for key: int in _hazards.keys():
		ids.append(key)
	_hazards.clear()
	_queried.clear()
	_next_id = 0
	for id: int in ids:
		hazard_released.emit(id, true)
	for index: int in range(first_index, last_index + 1):
		_queried[index] = true
		_bind_segment(index)


## `run_reset(run_id)`: only stores the id carried by later `hit_reported`; clears and reseeds nothing.
func on_run_reset(run_id: int) -> void:
	_run_id = run_id


## One tick: swept test of the ball (`theta_prev, theta, s_prev, s`) against every bound hazard.
func step(ball: RefCounted) -> void:
	var theta: float = ball.get(&"theta") as float
	var theta_prev: float = ball.get(&"theta_prev") as float
	var s: float = ball.get(&"s") as float
	var s_prev: float = ball.get(&"s_prev") as float
	var ids: Array[int] = []
	for key: int in _hazards.keys():
		ids.append(key)
	for id: int in ids:
		var hz: _Hazard = _hazards.get(id) as _Hazard
		if hz == null or not (s_prev <= hz.s_hi and s >= hz.s_lo):
			continue
		for piece: int in range(hz.eff.size() / 4):
			if ObstacleMath.swept_hit(theta_prev, theta, s_prev, s, hz.eff, piece):
				hit_reported.emit(id, _run_id)
				break


## Number of hazards currently bound.
func bound_count() -> int:
	return _hazards.size()


## True while `hazard_id` is bound.
func is_bound(hazard_id: int) -> bool:
	return _hazards.has(hazard_id)


## Run id carried by `hit_reported` (last `run_reset` seen, 0 before any).
func get_run_id() -> int:
	return _run_id


## The raw world footprint of `hazard_id` (4 floats per piece); empty when unbound.
func footprint_of(hazard_id: int) -> PackedFloat64Array:
	var hz: _Hazard = _hazards.get(hazard_id) as _Hazard
	return hz.footprint if hz != null else PackedFloat64Array()


## `HazardPlacement.HazardType` of `hazard_id`, or -1 when unbound.
func hazard_type_of(hazard_id: int) -> int:
	var hz: _Hazard = _hazards.get(hazard_id) as _Hazard
	return hz.hazard_type if hz != null else -1


## The shared spec the hazard was bound from (valid inside the `hazard_bound` emission), or null when unbound.
func spec_of(hazard_id: int) -> HazardSpec:
	var hz: _Hazard = _hazards.get(hazard_id) as _Hazard
	return hz.spec if hz != null else null


## `(i - spec.local_segment_index) * L` of `hazard_id` (valid inside the `hazard_bound` emission), 0.0 when unbound.
func s_offset_of(hazard_id: int) -> float:
	var hz: _Hazard = _hazards.get(hazard_id) as _Hazard
	return hz.s_offset if hz != null else 0.0


func _bind_segment(index: int) -> void:
	var specs: Array[HazardSpec] = _provider.hazards_for_segment(index)
	for spec: HazardSpec in specs:
		var hz: _Hazard = _Hazard.new()
		hz.hazard_id = _next_id
		_next_id += 1
		hz.home_segment = index
		hz.hazard_type = spec.hazard_type
		hz.spec = spec
		hz.s_offset = (index - spec.local_segment_index) * _seg_len
		var local: PackedFloat64Array = spec.pieces
		var fp: PackedFloat64Array = PackedFloat64Array()
		fp.resize(local.size())
		var k: int = 0
		while k + 3 < local.size():
			fp[k] = local[k]
			fp[k + 1] = local[k + 1]
			fp[k + 2] = local[k + 2] + hz.s_offset
			fp[k + 3] = local[k + 3] + hz.s_offset
			k += 4
		hz.footprint = fp
		hz.eff = ObstacleMath.effective_footprint_array(fp, _half_angle, _d)
		hz.s_lo = INF
		hz.s_hi = -INF
		k = 0
		while k + 3 < hz.eff.size():
			hz.s_lo = minf(hz.s_lo, hz.eff[k + 2])
			hz.s_hi = maxf(hz.s_hi, hz.eff[k + 3])
			k += 4
		_hazards[hz.hazard_id] = hz
		hazard_bound.emit(hz.hazard_id, fp)


func _log(code: StringName, key: String, message: String) -> void:
	if _log_sink.is_valid():
		_log_sink.call(LogLevel.ERROR, code, key, message)
