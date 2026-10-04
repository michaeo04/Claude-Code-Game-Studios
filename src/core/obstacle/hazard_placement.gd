## One authored hazard of a chunk (ADR-0008 Decision 1): its type, owning segment, pieces and dodge angles.
##
## Data only (no methods tooling must call), not `@tool`.
class_name HazardPlacement
extends Resource

## Explicit integers: they are stored in `.tres` files, never reorder.
enum HazardType { WALL = 0, SPIKE = 1, DOUBLE_GATE = 2, NEAR_RING = 3 }

@export var hazard_type: HazardType = HazardType.WALL
## The segment of the chunk that owns the hazard, `0 .. segment_count - 1`.
@export var local_segment_index: int = 0
@export var pieces: Array[HazardPiece] = []
## The correct dodge angle(s): one for Wall and Near-Ring, two for Double Gate, none for Spike.
@export var solution_angles: PackedFloat64Array = PackedFloat64Array()
