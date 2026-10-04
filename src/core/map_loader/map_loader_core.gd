## Skeleton of the loader core (ADR-0004 Decision 2/3): status, last codes and the failure signal only.
## Later stories add `attempt` and `retry`. No engine calls.
class_name MapLoaderCore
extends RefCounted

enum Status { NOT_LOADED, READY, FAILED }

## Emitted once per failed attempt with the whole code set.
signal map_load_failed(codes: PackedStringArray)

var status: Status = Status.NOT_LOADED
var last_codes: PackedStringArray = PackedStringArray()

var _seams: MapLoaderSeams
var _config: MapLoaderConfig


func _init(seams: MapLoaderSeams, config: MapLoaderConfig) -> void:
	_seams = seams
	_config = config
