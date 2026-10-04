## One structured preflight failure (GDD Edge Cases: "a structured record, not message text").
##
## `code` is a stable `StringName` from `ObstacleMath`; `segment_index` is the offending home segment (-1 when the
## record is not tied to one); `s0` is the offending sweep position (0.0 when not applicable); `pieces` lists the
## involved pieces as `Vector2i(hazard_id, piece_index)` in ascending order (piece_index -1 means the whole hazard).
class_name PreflightRecord
extends RefCounted

var code: StringName = &""
var segment_index: int = -1
var s0: float = 0.0
var pieces: Array[Vector2i] = []
## Piece total for `TOO_MANY_PIECES` (0 for other codes).
var count: int = 0
## Offending solution angle for `EXIT_BEYOND_VISIBLE_ARC` (NAN for other codes).
var angle: float = NAN


func _init(p_code: StringName = &"", p_segment_index: int = -1, p_s0: float = 0.0) -> void:
	code = p_code
	segment_index = p_segment_index
	s0 = p_s0
