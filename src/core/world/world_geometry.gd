## The immutable `WorldGeometry` value (ADR-0004 Decision 1, ADR-0013): `R`, `D`, `N_F`, `L`, `A`.
##
## Built once at composition from the base `TubeConfig` and `BallConfig` (`from_configs`) and validated together
## with the `WorldFrameConfig` (`validate`) before the first map load. Read-only by convention after construction.
## `a_segments` is the `A` of ADR-0013 Decision 4 (segments ahead of the ball that stay visible).
class_name WorldGeometry
extends RefCounted

## Code returned by `validate` for a non-finite or non-positive field.
const CODE_INVALID: String = "WORLD_GEOMETRY_INVALID"

## Tube radius `R` (world units).
var r: float
## Ball diameter `D` (world units, owned by Ball Movement).
var d: float
## Number of tube slots `N_F`.
var n_f: int
## Segment length `L` (world units).
var l: float
## `A`: segments ahead of the ball that stay visible (ADR-0013).
var a_segments: int


func _init(
	radius: float = 3.0, distance: float = 0.8, slots: int = 20, segment_length: float = 12.0, ahead: int = 9
) -> void:
	r = radius
	d = distance
	n_f = slots
	l = segment_length
	a_segments = ahead


## Builds the value from the base tube config, the validated ball config and the slot count `N_F`.
## Example: `WorldGeometry.from_configs(TubeConfig.new(), BallConfig.new(), 20).d == 0.8`.
static func from_configs(tube: TubeConfig, ball: BallConfig, slots: int) -> WorldGeometry:
	return WorldGeometry.new(tube.tube_radius, ball.ball_diameter, slots, tube.segment_length, tube.segments_ahead)


## Validates the geometry together with the render-origin config; returns error codes (empty when valid).
static func validate(geometry: WorldGeometry, frame_config: WorldFrameConfig) -> Array[String]:
	var codes: Array[String] = []
	var fields: Array[float] = [geometry.r, geometry.d, geometry.l]
	for value: float in fields:
		if not is_finite(value) or value <= 0.0:
			codes.append(CODE_INVALID)
			return codes
	if geometry.n_f <= 0 or geometry.a_segments <= 0:
		codes.append(CODE_INVALID)
		return codes
	return WorldFrame.validate(frame_config, geometry)
