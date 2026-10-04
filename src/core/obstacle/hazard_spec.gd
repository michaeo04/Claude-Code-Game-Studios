## Compiled, immutable hazard (ADR-0008 Decision 2): built once at compile, shared by every reader, never copied.
##
## Fields are read-only properties (getters only). `pieces` holds 4 floats per piece, chunk-local:
## `theta_min, theta_max, s_start, s_end`. `solution_angles` is empty for a Spike.
## Example: `HazardSpec.new(HazardPlacement.HazardType.SPIKE, 0, PackedFloat64Array([-0.05, 0.05, 50.0, 50.3]), PackedFloat64Array())`.
class_name HazardSpec
extends RefCounted

## `HazardPlacement.HazardType` as an int.
var hazard_type: int:
	get:
		return _hazard_type
## The segment of the chunk that owns the hazard.
var local_segment_index: int:
	get:
		return _local_segment_index
## A copy: GDScript packed arrays are shared by reference, so the getter keeps the stored array unreachable.
var pieces: PackedFloat64Array:
	get:
		return PackedFloat64Array(_pieces)
## A copy, as `pieces`.
var solution_angles: PackedFloat64Array:
	get:
		return PackedFloat64Array(_solution_angles)

var _hazard_type: int = 0
var _local_segment_index: int = 0
var _pieces: PackedFloat64Array = PackedFloat64Array()
var _solution_angles: PackedFloat64Array = PackedFloat64Array()


func _init(
	p_hazard_type: int = 0,
	p_local_segment_index: int = 0,
	p_pieces: PackedFloat64Array = PackedFloat64Array(),
	p_solution_angles: PackedFloat64Array = PackedFloat64Array()
) -> void:
	_hazard_type = p_hazard_type
	_local_segment_index = p_local_segment_index
	_pieces = PackedFloat64Array(p_pieces)
	_solution_angles = PackedFloat64Array(p_solution_angles)


## Number of footprint pieces (`pieces.size() / 4`).
func piece_count() -> int:
	return _pieces.size() / 4
