## The immutable per-map value the loader builds (ADR-0004 Decision 1). Read-only by convention after `build`.
##
## Never an `@export` type. `env` and `hazard_style` are validated copies; `chunk_library` is the shared
## resource, never copied.
class_name MapConfig
extends RefCounted

## Failure code for non-finite or out-of-range camera geometry, `L <= 0` or a non-finite `camera_far`.
const MAP_CAMERA_INVALID: StringName = &"MAP_CAMERA_INVALID"
## Largest accepted `visible_arc_half_width` (a half turn, radians).
const ARC_HALF_WIDTH_MAX: float = PI

var map_id: StringName
var env: EnvConfig
var chunk_library: Resource
var rear_extent: float
var camera_distance: float
var visible_arc_half_width: float
var hazard_style: Resource
## `F_rest + L`, constant (ADR-0014 Decision 6).
var camera_far: float


## Builds a `MapConfig`. `camera` is the `camera_geometry()` seam result: keys `rear_extent`, `camera_distance`,
## `visible_arc_half_width` and `L`. On failure returns `null` and appends `MAP_CAMERA_INVALID` to `codes`.
## Example: fog end 84 and `L` 12 give `camera_far == 96.0`.
static func build(
	id: StringName, validated_env: EnvConfig, library: Resource, validated_style: Resource,
	camera: Dictionary, codes: Array[StringName]
) -> MapConfig:
	var values: Dictionary = {}
	for key: String in ["rear_extent", "camera_distance", "visible_arc_half_width", "L"]:
		var raw: Variant = camera.get(key)
		if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
			codes.append(MAP_CAMERA_INVALID)
			return null
		var value: float = float(raw)
		if not is_finite(value) or value <= 0.0:
			codes.append(MAP_CAMERA_INVALID)
			return null
		values[key] = value
	if (values["visible_arc_half_width"] as float) > ARC_HALF_WIDTH_MAX:
		codes.append(MAP_CAMERA_INVALID)
		return null
	var far: float = validated_env.fog_end_distance + (values["L"] as float)
	if not is_finite(far):
		codes.append(MAP_CAMERA_INVALID)
		return null
	var map: MapConfig = MapConfig.new()
	map.map_id = id
	map.env = validated_env
	map.chunk_library = library
	map.hazard_style = validated_style
	map.rear_extent = values["rear_extent"] as float
	map.camera_distance = values["camera_distance"] as float
	map.visible_arc_half_width = values["visible_arc_half_width"] as float
	map.camera_far = far
	return map
