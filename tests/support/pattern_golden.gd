## Golden-sequence driver (PD-013, ADR-0008 Decision 8): the library is reloaded from disk, compiled, and drawn for a
## hardcoded seed with a scripted run time. Framework-free: no GUT call.
extends RefCounted

const LIBRARY_PATH: String = "res://tests/support/data/pattern_golden_library.tres"
const SEGMENTS: int = 30
## Run time (s) per segment: INTRO for the first 10, RAMP for the next 10, FULL after.
const INTRO_UNTIL: int = 10
const RAMP_UNTIL: int = 20
const RAMP_TIME: float = 20.0
const FULL_TIME: float = 120.0
const SEGMENT_LENGTH: float = 12.0


class TimeStub:
	extends RefCounted
	var value: float = 0.0

	func get_value() -> float:
		return value


## `chunk_id@base` of every chunk placed over `SEGMENTS` segments, in order, for `run_id`.
static func sequence_for(run_id: int) -> Array[String]:
	var library: ChunkLibrary = load(LIBRARY_PATH) as ChunkLibrary
	var stub: TimeStub = TimeStub.new()
	var core: PatternCore = PatternCore.new(PatternConfig.new(), SEGMENT_LENGTH, Callable(stub, "get_value"))
	core.apply_map(_map_with(library))
	core.on_run_reset(run_id)
	var out: Array[String] = []
	var last: String = ""
	for i: int in SEGMENTS:
		stub.value = 0.0 if i < INTRO_UNTIL else (RAMP_TIME if i < RAMP_UNTIL else FULL_TIME)
		core.hazards_for_segment(i)
		var entry: String = "%s@%d" % [core.last_chunk_id(), core.last_chunk_base()]
		if entry != last:
			out.append(entry)
			last = entry
	return out


static func _map_with(library: ChunkLibrary) -> MapConfig:
	var map: MapConfig = MapConfig.new()
	map.chunk_library = library
	return map
