## STUB of the per-map environment values (ADR-0004 Decision 1). Scalars, enums and Colors only.
##
## The environment-theming epic owns the real class and will extend this file in place (ranges, more fields).
## The map-loader epic only needs the fields below and the `validated(log_sink)` contract: a clamped COPY, the
## loaded instance is never written, and `null` for a fatal problem. It holds no reference to `MapDefinition`
## or `MapConfig` (no back-edge).
class_name EnvConfig
extends Resource

## Stable log code for a clamped value.
const KNOB_CLAMPED: StringName = &"KNOB_CLAMPED"
## Safe range of `fog_depth_curve` (stub range; Environment owns the final one).
const FOG_CURVE_MIN: float = 0.1
const FOG_CURVE_MAX: float = 4.0

## Seam pattern id (`TubeConfig` has no seam-pattern field yet; kept for Environment).
@export var seam_pattern_id: StringName = &"default"
## 0 is DEPTH (see `TubeConfig.FogMode`).
@export var fog_mode: int = 0
## Where depth fog starts.
@export var fog_depth_begin: float = 44.0
## Fog end distance `F` (resting value `F_rest` for Camera).
@export var fog_end_distance: float = 84.0
@export var fog_depth_curve: float = 1.0
@export var fog_density: float = 1.0
@export var fog_color: Color = Color(0.1, 0.1, 0.15)
## Readable distance `F_read`.
@export var readable_distance: float = 46.0
@export var tube_color: Color = Color(0.2, 0.2, 0.3)
@export var sky_top_color: Color = Color(0.05, 0.05, 0.1)
@export var sky_bottom_color: Color = Color(0.1, 0.1, 0.2)
@export var prop_set_id: StringName = &"none"


## A clamped copy, or `null` when a distance is non-finite or not positive. `self` is never modified.
## `log_sink` is `(level, code, key, message)` (see `LogLevel`) or invalid.
func validated(log_sink: Callable) -> EnvConfig:
	for value: float in [fog_depth_begin, fog_end_distance, fog_depth_curve, fog_density, readable_distance]:
		if not is_finite(value):
			return null
	if fog_end_distance <= 0.0 or readable_distance <= 0.0:
		return null
	var copy: EnvConfig = duplicate() as EnvConfig
	var curve: float = clampf(fog_depth_curve, FOG_CURVE_MIN, FOG_CURVE_MAX)
	if curve != fog_depth_curve:
		copy.fog_depth_curve = curve
		if log_sink.is_valid():
			log_sink.call(LogLevel.WARNING, KNOB_CLAMPED, "fog_depth_curve", "%f -> %f" % [fog_depth_curve, curve])
	return copy
