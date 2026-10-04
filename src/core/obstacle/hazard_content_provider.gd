## The content seam of Obstacle System (ADR-0008 Decision 2): Pattern & Difficulty implements it, tests fake it.
##
## A plain `RefCounted`, not `@abstract`. The base returns no hazards.
class_name HazardContentProvider
extends RefCounted


## The shared (never copied) specs of the chunk placed at `_segment_index`; called once per entering segment.
func hazards_for_segment(_segment_index: int) -> Array[HazardSpec]:
	return []
