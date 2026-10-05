## One chunk after compile: immutable, holds shared `HazardSpec` objects (never copied).
class_name CompiledChunk
extends RefCounted

var chunk_id: StringName = &""
var tier: ChunkDef.Tier = ChunkDef.Tier.INTRO
var segment_count: int = 1
var hazards: Array[HazardSpec] = []


func _init(
	p_chunk_id: StringName = &"",
	p_tier: ChunkDef.Tier = ChunkDef.Tier.INTRO,
	p_segment_count: int = 1,
	p_hazards: Array[HazardSpec] = []
) -> void:
	chunk_id = p_chunk_id
	tier = p_tier
	segment_count = p_segment_count
	hazards = p_hazards
