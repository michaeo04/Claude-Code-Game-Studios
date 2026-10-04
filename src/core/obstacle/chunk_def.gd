## One authored chunk (ADR-0008 Decision 1): 1 to 3 segments of hazard placements. Data only, not `@tool`.
class_name ChunkDef
extends Resource

## First tier that may draw the chunk (pools are supersets). Explicit integers: stored in `.tres` files.
enum Tier { INTRO = 0, RAMP = 1, FULL = 2 }

@export var chunk_id: StringName = &""
@export var tier: Tier = Tier.INTRO
## Segments the chunk spans, 1 to 3.
@export_range(1, 3) var segment_count: int = 1
@export var placements: Array[HazardPlacement] = []
