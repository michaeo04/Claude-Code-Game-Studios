## Recording subscriber of `ObstacleCore` signals, in arrival order. Framework-free: no GUT call.
##
## `bound`: `[hazard_id, footprint]`; `released`: `[hazard_id, released_by_reset]`; `hits`: `[hazard_id, run_id]`.
## `probe_log`: one entry per `hazard_bound` with the four accessor values read inside the handler.
extends RefCounted

var bound: Array[Array] = []
var released: Array[Array] = []
var hits: Array[Array] = []
## Per `hazard_bound`: `[footprint_of, hazard_type_of, spec_of, s_offset_of]`.
var probe_log: Array[Array] = []
## All three kinds in order: `["bound"|"released"|"hit", id]`.
var order: Array[Array] = []

var _core: ObstacleCore = null


## Connects to the core signals (bound methods, no lambda).
func attach(core: ObstacleCore) -> void:
	_core = core
	core.hazard_bound.connect(_on_bound)
	core.hazard_released.connect(_on_released)
	core.hit_reported.connect(_on_hit)


## Forgets everything recorded so far.
func clear() -> void:
	bound.clear()
	released.clear()
	hits.clear()
	probe_log.clear()
	order.clear()


## Ids of the hits recorded since the last `clear`.
func hit_ids() -> Array[int]:
	var out: Array[int] = []
	for h: Array in hits:
		out.append(h[0] as int)
	return out


func _on_bound(hazard_id: int, footprint: PackedFloat64Array) -> void:
	bound.append([hazard_id, footprint])
	order.append(["bound", hazard_id])
	probe_log.append([
		_core.footprint_of(hazard_id),
		_core.hazard_type_of(hazard_id),
		_core.spec_of(hazard_id),
		_core.s_offset_of(hazard_id),
	])


func _on_released(hazard_id: int, released_by_reset: bool) -> void:
	released.append([hazard_id, released_by_reset])
	order.append(["released", hazard_id])


func _on_hit(hazard_id: int, run_id: int) -> void:
	hits.append([hazard_id, run_id])
	order.append(["hit", hazard_id])
