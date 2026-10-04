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
## Log code emitted when a tilt sensitivity (stored at boot, or passed to `set_value`) had to be corrected.
const CODE_SETTING_CLAMPED: StringName = &"SETTING_CLAMPED"
## Log code emitted when `set_value` receives a key that is not one of the five settings.
const CODE_UNKNOWN_SETTING_KEY: StringName = &"UNKNOWN_SETTING_KEY"
## The closed list of recognised setting keys.
const KEYS: Array[String] = [
	KEY_HAPTICS_ENABLED, KEY_HAPTICS_INTENSITY, KEY_TILT_SENSITIVITY, KEY_REDUCED_MOTION, KEY_COLORBLIND_SAFE
]

## Emitted once per actual change, after memory is updated and the write seam was called.
signal setting_changed(key: String, value: Variant)

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
			LogLevel.WARNING,
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


## Changes one setting. Returns `false` only for an unknown key (logged `UNKNOWN_SETTING_KEY`, no state change);
## returns `true` for every recognised key, including a no-op (value equal to the current one: no write, no event).
## On an actual change: memory is updated, `set_value_seam` is called immediately (its result is ignored: no
## rollback, no retry; Save logs a failed write), then `setting_changed(key, value)` is emitted once.
## `tilt_sensitivity` is corrected through F2 first and the corrected value is stored, written and emitted.
## Menus owns the slider rule: commit on `drag_ended`, never per `value_changed`; there is no coalescing here.
func set_value(key: String, value: Variant) -> bool:
	if not KEYS.has(key):
		_log_sink.call(LogLevel.WARNING, CODE_UNKNOWN_SETTING_KEY, key, "unknown setting key '%s'" % key)
		return false
	var new_value: Variant
	match key:
		KEY_TILT_SENSITIVITY:
			var checked: Dictionary = SettingsMath.tilt_sensitivity_validate(
				value as float, _sensitivity_min, _sensitivity_max, _default_sensitivity
			)
			new_value = checked["value"] as float
			if checked["was_corrected"] as bool:
				_log_sink.call(
					LogLevel.WARNING,
					CODE_SETTING_CLAMPED,
					key,
					"tilt_sensitivity %s corrected to %s" % [str(value), str(new_value)]
				)
		KEY_HAPTICS_INTENSITY:
			new_value = value as float
		_:
			new_value = value as bool
	if new_value == _current(key):
		return true
	_store(key, new_value)
	_set_value_seam.call(SECTION, key, new_value)
	setting_changed.emit(key, new_value)
	return true


func _current(key: String) -> Variant:
	match key:
		KEY_HAPTICS_ENABLED:
			return _haptics_enabled
		KEY_HAPTICS_INTENSITY:
			return _haptics_intensity
		KEY_TILT_SENSITIVITY:
			return _tilt_sensitivity
		KEY_REDUCED_MOTION:
			return _reduced_motion_enabled
		_:
			return _colorblind_safe_enabled


func _store(key: String, value: Variant) -> void:
	match key:
		KEY_HAPTICS_ENABLED:
			_haptics_enabled = value as bool
		KEY_HAPTICS_INTENSITY:
			_haptics_intensity = value as float
		KEY_TILT_SENSITIVITY:
			_tilt_sensitivity = value as float
		KEY_REDUCED_MOTION:
			_reduced_motion_enabled = value as bool
		_:
			_colorblind_safe_enabled = value as bool
