## The authored per-map data (ADR-0004 Decision 1), a `.tres` file. No Camera values live here.
class_name MapDefinition
extends Resource

@export var map_id: StringName
## Environment values (graph `MapDefinition -> EnvConfig`, no back-edge).
@export var env: EnvConfig
## Typed `ChunkLibrary` once ADR-0008 exists (Pattern epic); `Resource` until then.
@export var chunk_library: Resource
## A `HazardStyle` (ADR-0014), validated in Phase A step A3b.
@export var hazard_style: Resource
