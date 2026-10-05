## Recording wrapper around a real `HazardContentProvider` (PD-013, AC-26): logs every queried segment index and every
## returned spec in call order, then answers with the wrapped provider's own result. Framework-free: no GUT call.
extends HazardContentProvider

## The provider every call is forwarded to.
var inner: HazardContentProvider = null
## Every queried segment index, in call order.
var queried: Array[int] = []
## Every returned spec (the shared instances), flattened in call order.
var returned: Array[HazardSpec] = []


func _init(wrapped: HazardContentProvider = null) -> void:
	inner = wrapped


func hazards_for_segment(segment_index: int) -> Array[HazardSpec]:
	queried.append(segment_index)
	var specs: Array[HazardSpec] = inner.hazards_for_segment(segment_index)
	returned.append_array(specs)
	return specs
