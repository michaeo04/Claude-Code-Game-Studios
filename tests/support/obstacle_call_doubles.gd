## Recording doubles of Ball Movement and Tube Track for Obstacle System AC-39. Framework-free: no GUT call.
##
## `RecordingBall` answers only property reads (`_get`) and records every name; it defines no method, so any
## call the core made on it would raise an error. `RecordingProvider` records `hazards_for_segment` calls.
extends RefCounted


class RecordingBall:
	extends RefCounted
	var values: Dictionary = {&"theta": 0.0, &"theta_prev": 0.0, &"s": 0.0, &"s_prev": 0.0}
	var reads: Array[StringName] = []

	func _get(property: StringName) -> Variant:
		if values.has(property):
			reads.append(property)
			return values[property]
		reads.append(StringName("UNKNOWN:" + String(property)))
		return null
