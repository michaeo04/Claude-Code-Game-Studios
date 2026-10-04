## Settings & Accessibility core (GDD `design/gdd/settings-accessibility.md`, ADR-0002, ADR-0007).
##
## A `RefCounted` with no engine call. It reads its five settings once at construction through the injected
## `get_value_seam(section, key, default) -> Variant` (exactly one call per key, each with its own default,
## never batched) and afterwards serves them from memory. `set_value_seam(section, key, value) -> bool` and
## `log_sink(level, code, key, message)` are injected too. Tilt sensitivity is stored raw here; boot
## validation arrives with story 003.
class_name SettingsCore
extends RefCounted

## Settings section used for every seam call.
const SECTION: String = "settings"
const KEY_HAPTICS_ENABLED: String = "haptics_enabled"
const KEY_HAPTICS_INTENSITY: String = "haptics_intensity"
const KEY_TILT_SENSITIVITY: String = "tilt_sensitivity"
const KEY_REDUCED_MOTION: String = "reduced_motion_enabled"
const KEY_COLORBLIND_SAFE: String = "colorblind_safe_enabled"
## Log level of a corrected setting (same scale as `RunStateMath.LogLevel.WARNING`).
const LEVEL_WARNING: int = 1
## Log code emitted once at boot when the stored tilt sensitivity had to be corrected.
const CODE_SETTING_CLAMPED: StringName = &"SETTING_CLAMPED"

var _get_value_seam: Callable
var _set_value_seam: Callable
var _log_sink: Callable
var _sensitivity_min: float
var _sensitivity_max: float
var _default_sensitivity: float

var _haptics_enabled: bool = true
var _haptics_intensity: float = 1.0
var _tilt_sensitivity: float = 1.0
var _reduced_motion_enabled: bool = false
var _colorblind_safe_enabled: bool = false


## Builds the core and performs the boot read (five seam reads). Float defaults are floats on purpose:
## ADR-0007 `type_matches` compares `typeof(stored) == typeof(default)`.
func _init(
	get_value_seam: Callable,
	set_value_seam: Callable,
	log_sink: Callable,
	sensitivity_min: float = 0.5,
	sensitivity_max: float = 2.0,
	default_sensitivity: float = 1.0
) -> void:
	_get_value_seam = get_value_seam
	_set_value_seam = set_value_seam
	_log_sink = log_sink
	_sensitivity_min = sensitivity_min
	_sensitivity_max = sensitivity_max
	_default_sensitivity = default_sensitivity
	_haptics_enabled = _get_value_seam.call(SECTION, KEY_HAPTICS_ENABLED, true) as bool
	_haptics_intensity = _get_value_seam.call(SECTION, KEY_HAPTICS_INTENSITY, 1.0) as float
	var raw_tilt: float = _get_value_seam.call(SECTION, KEY_TILT_SENSITIVITY, _default_sensitivity) as float
	var checked: Dictionary = SettingsMath.tilt_sensitivity_validate(raw_tilt, _sensitivity_min, _sensitivity_max, _default_sensitivity)
	_tilt_sensitivity = checked["value"] as float
	if checked["was_corrected"] as bool:
		_log_sink.call(
			LEVEL_WARNING,
			CODE_SETTING_CLAMPED,
			KEY_TILT_SENSITIVITY,
			"stored tilt_sensitivity %s corrected to %s" % [str(raw_tilt), str(_tilt_sensitivity)]
		)
	_reduced_motion_enabled = _get_value_seam.call(SECTION, KEY_REDUCED_MOTION, false) as bool
	_colorblind_safe_enabled = _get_value_seam.call(SECTION, KEY_COLORBLIND_SAFE, false) as bool


## Whether haptic feedback is on.
func get_haptics_enabled() -> bool:
	return _haptics_enabled


## Haptic intensity.
func get_haptics_intensity() -> float:
	return _haptics_intensity


## Tilt sensitivity multiplier.
func get_tilt_sensitivity() -> float:
	return _tilt_sensitivity


## Whether reduced motion is on.
func get_reduced_motion_enabled() -> bool:
	return _reduced_motion_enabled


## Whether the colorblind-safe palette is on.
func get_colorblind_safe_enabled() -> bool:
	return _colorblind_safe_enabled


## Seam contrast scale (F1), derived from reduced motion on each call: 0.0 when on, 1.0 when off.
## A plain computation: it never touches the get/set seams.
func get_seam_contrast_scale() -> float:
	return SettingsMath.seam_contrast_scale(_reduced_motion_enabled)
