## One hazard as the offline preflight sees it (ADR-0008 Decision 5): a stable id, its declared home segment and its
## raw pieces in WORLD `s` (chunk-local pieces already translated by `base * L`). Data only, never used at run time.
##
## `pieces` holds 4 floats per piece: `theta_min, theta_max, s_start, s_end`.
## Example: `PreflightHazard.new(501, 33, PackedFloat64Array([-0.05, 0.05, 400.0, 401.0]))`.
class_name PreflightHazard
extends RefCounted

var hazard_id: int = 0
var home_segment: int = 0
var pieces: PackedFloat64Array = PackedFloat64Array()


func _init(
	p_hazard_id: int = 0, p_home_segment: int = 0, p_pieces: PackedFloat64Array = PackedFloat64Array()
) -> void:
	hazard_id = p_hazard_id
	home_segment = p_home_segment
	pieces = PackedFloat64Array(p_pieces)


## Number of pieces (`pieces.size() / 4`).
func piece_count() -> int:
	return pieces.size() / 4
