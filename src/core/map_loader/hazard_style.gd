## Scalar-only style data of the hazards (ADR-0014 Decision 3), carried by `MapDefinition.hazard_style`.
##
## `validated(log_sink)` returns a clamped copy, or `null` for a fatal problem (equal colours, non-finite
## height). The loaded instance is never written. Floats and Colors only: no nested Resource, Array or Dictionary.
class_name HazardStyle
extends Resource

## Log code of a clamped height.
const KNOB_CLAMPED: StringName = &"KNOB_CLAMPED"
## Safe range shared by wall, double gate and near ring heights (in ball diameters).
const HEIGHT_MIN: float = 1.0
const HEIGHT_MAX: float = 3.0
## Safe range of the spike height (taper inside the top third).
const SPIKE_MIN: float = 1.5
const SPIKE_MAX: float = 3.0

@export_range(1.0, 3.0) var height_d_wall: float = 1.0
@export_range(1.0, 3.0) var height_d_double_gate: float = 1.0
@export_range(1.0, 3.0) var height_d_near_ring: float = 1.0
@export_range(1.5, 3.0) var height_d_spike: float = 1.6
@export var face_color: Color = Color(0.9, 0.3, 0.3)
@export var shade_color: Color = Color(0.4, 0.1, 0.1)


## Clamped copy or `null` (fatal). Example: `HazardStyle.new().validated(Callable())` is a valid copy.
func validated(log_sink: Callable) -> HazardStyle:
	if face_color == shade_color:
		return null
	var specs: Dictionary = {
		"height_d_wall": [height_d_wall, HEIGHT_MIN, HEIGHT_MAX],
		"height_d_double_gate": [height_d_double_gate, HEIGHT_MIN, HEIGHT_MAX],
		"height_d_near_ring": [height_d_near_ring, HEIGHT_MIN, HEIGHT_MAX],
		"height_d_spike": [height_d_spike, SPIKE_MIN, SPIKE_MAX],
	}
	for key: String in specs:
		if not is_finite((specs[key] as Array)[0] as float):
			return null
	var copy: HazardStyle = duplicate() as HazardStyle
	for key: String in specs:
		var spec: Array = specs[key] as Array
		var value: float = spec[0] as float
		var clamped: float = clampf(value, spec[1] as float, spec[2] as float)
		if clamped != value:
			copy.set(key, clamped)
			if log_sink.is_valid():
				log_sink.call(LogLevel.WARNING, KNOB_CLAMPED, key, "%f -> %f" % [value, clamped])
	return copy
