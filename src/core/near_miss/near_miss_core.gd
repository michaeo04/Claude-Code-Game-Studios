## Near-Miss Detection runtime core (GDD Core Rules 4 and 5): one small state machine per bound hazard and one
## edge-triggered output. Pure RefCounted, no engine call; built and wired by `GameRoot`.
##
## Expected inputs (the producers are Obstacle System stories 006 to 008 and Run State; until they exist the driver or
## a test spy calls these methods from the matching signals):
## - `hazard_bound(hazard_id: int, footprint_pieces: PackedFloat64Array)` -> `on_hazard_bound`
## - `hazard_released(hazard_id: int, released_by_reset: bool)` -> `on_hazard_released`
## - `hit_reported(hazard_id: int, run_id: int)` -> `on_hit_reported`
## - `run_reset(run_id: int)` -> `on_run_reset`
## Tick contract (ADR-0002 Decision 6): `Obstacle.test` first (its hits and releases arrive), then one `step(ball)`.
## Hits and releases are queued and applied inside `step`: pending hits first, then pending releases, then movement,
## so the result does not depend on the order in which hits and releases were delivered within a tick.
class_name NearMissCore
extends RefCounted

## Emitted once per hazard on the exit edge of its near zone (or on a normal release) when it was never hit.
## The payload is exactly these two fields.
signal near_miss_detected(hazard_id: int, run_id: int)

var _log_sink: Callable
var _angle_margin: float
var _s_margin: float
var _half_angle: float
var _d: float
var _run_id: int = 0
var _states: Dictionary = {}
var _order: Array[int] = []
var _pending_hits: Array[int] = []
var _pending_releases: Array[Vector2i] = []


## `cfg` is validated into a copy; `half_angle` is `BALL_HALF_ANGLE`, `d` the ball diameter `D`.
func _init(cfg: NearMissConfig, half_angle: float, d: float, log_sink: Callable = Callable()) -> void:
	_log_sink = log_sink
	var checked: NearMissConfig = cfg.validated(log_sink)
	_half_angle = half_angle
	_d = d
	_angle_margin = checked.angle_margin(half_angle)
	_s_margin = checked.s_margin(d)


## Last `run_reset` run id seen (0 before any).
func get_run_id() -> int:
	return _run_id


## Records the new run id carried by later `near_miss_detected` emissions.
func on_run_reset(run_id: int) -> void:
	_run_id = run_id


## Creates the state of `hazard_id` and builds its hit and near footprints once from the raw flat footprint
## (4 floats per piece). A release of the same id still pending is applied first (release before repopulate).
func on_hazard_bound(hazard_id: int, footprint_pieces: PackedFloat64Array) -> void:
	_apply_releases_of(hazard_id)
	if _states.has(hazard_id):
		_discard(hazard_id)
	var st: _HazardState = _HazardState.new()
	st.eff = ObstacleMath.effective_footprint_array(footprint_pieces, _half_angle, _d)
	st.near = NearMissMath.near_footprint(footprint_pieces, _half_angle, _d, _angle_margin, _s_margin)
	st.pieces = footprint_pieces.size() / 4
	_states[hazard_id] = st
	_order.insert(_order.bsearch(hazard_id), hazard_id)


## Queues the release of `hazard_id`; applied by the next `step`. `released_by_reset` true discards silently.
func on_hazard_released(hazard_id: int, released_by_reset: bool) -> void:
	_pending_releases.append(Vector2i(hazard_id, 1 if released_by_reset else 0))


## Queues a hit on `hazard_id` (any piece); applied by the next `step`. Unknown ids are ignored. `hit_run_id` is
## accepted for the signal shape and not read.
func on_hit_reported(hazard_id: int, _hit_run_id: int = 0) -> void:
	_pending_hits.append(hazard_id)


## One tick. `ball` exposes float `theta`, `theta_prev`, `s`, `s_prev` (`BallCore` does).
func step(ball: RefCounted) -> void:
	_apply_pending_hits()
	var releases: Array[Vector2i] = _pending_releases
	_pending_releases = []
	for rel: Vector2i in releases:
		_release(rel.x, rel.y == 1)
	var theta: float = ball.get(&"theta") as float
	var theta_prev: float = ball.get(&"theta_prev") as float
	var s: float = ball.get(&"s") as float
	var s_prev: float = ball.get(&"s_prev") as float
	var ids: Array[int] = []
	ids.append_array(_order)
	for hazard_id: int in ids:
		var st: _HazardState = _states[hazard_id] as _HazardState
		if st.hit_ever_true:
			continue
		var candidate: bool = false
		for piece: int in range(st.pieces):
			if NearMissMath.is_candidate(NearMissMath.zones(theta_prev, theta, s_prev, s, st.eff, st.near, piece)):
				candidate = true
				break
		if candidate:
			st.was_in_near_zone = true
		elif st.was_in_near_zone:
			st.was_in_near_zone = false
			near_miss_detected.emit(hazard_id, _run_id)


## True while `hazard_id` has live state.
func is_bound(hazard_id: int) -> bool:
	return _states.has(hazard_id)


## Near-zone latch of `hazard_id` (false when unbound).
func was_in_near_zone(hazard_id: int) -> bool:
	var st: _HazardState = _states.get(hazard_id) as _HazardState
	return st != null and st.was_in_near_zone


## Hit latch of `hazard_id`, including hits still queued (false when unbound).
func hit_ever_true(hazard_id: int) -> bool:
	var st: _HazardState = _states.get(hazard_id) as _HazardState
	return st != null and st.hit_ever_true


## Number of bound hazards.
func bound_count() -> int:
	return _order.size()


func _apply_pending_hits() -> void:
	for hazard_id: int in _pending_hits:
		var st: _HazardState = _states.get(hazard_id) as _HazardState
		if st != null:
			st.hit_ever_true = true
	_pending_hits.clear()


func _apply_releases_of(hazard_id: int) -> void:
	var keep: Array[Vector2i] = []
	var mine: Array[Vector2i] = []
	for rel: Vector2i in _pending_releases:
		if rel.x == hazard_id:
			mine.append(rel)
		else:
			keep.append(rel)
	if mine.is_empty():
		return
	_pending_releases = keep
	_apply_pending_hits()
	for rel: Vector2i in mine:
		_release(rel.x, rel.y == 1)


func _release(hazard_id: int, by_reset: bool) -> void:
	var st: _HazardState = _states.get(hazard_id) as _HazardState
	if st == null:
		return
	_discard(hazard_id)
	if not by_reset and st.was_in_near_zone and not st.hit_ever_true:
		near_miss_detected.emit(hazard_id, _run_id)


func _discard(hazard_id: int) -> void:
	_states.erase(hazard_id)
	var at: int = _order.find(hazard_id)
	if at >= 0:
		_order.remove_at(at)


class _HazardState:
	extends RefCounted
	var eff: PackedFloat64Array = PackedFloat64Array()
	var near: PackedFloat64Array = PackedFloat64Array()
	var pieces: int = 0
	var hit_ever_true: bool = false
	var was_in_near_zone: bool = false
