## Glue between `SettingsCore` and Platform Services haptics (GDD settings-accessibility rule 6; ADR-0002).
##
## Engine-free. `GameRoot` calls `push_initial` once at construction (after Settings, before Run State) and connects
## `setting_changed` to `on_setting_changed` (immediate connection). Settings never calls Platform after that push.
class_name HapticsSettingsAdapter
extends RefCounted

## Settings keys this adapter forwards (equal `SettingsCore.KEY_HAPTICS_*`).
const KEY_HAPTICS_ENABLED: String = "haptics_enabled"
const KEY_HAPTICS_INTENSITY: String = "haptics_intensity"

var _set_enabled: Callable
var _set_intensity: Callable


## `set_enabled(enabled: bool)` and `set_intensity(intensity: float)` are the Platform Services setters.
func _init(set_enabled: Callable, set_intensity: Callable) -> void:
	_set_enabled = set_enabled
	_set_intensity = set_intensity


## Pushes the boot values once.
func push_initial(enabled: bool, intensity: float) -> void:
	_set_enabled.call(enabled)
	_set_intensity.call(intensity)


## `setting_changed(key, value)`: forwards the two haptics keys; every other key is ignored.
func on_setting_changed(key: String, value: Variant) -> void:
	if key == KEY_HAPTICS_ENABLED and typeof(value) == TYPE_BOOL:
		_set_enabled.call(value as bool)
	elif key == KEY_HAPTICS_INTENSITY and typeof(value) == TYPE_FLOAT:
		_set_intensity.call(value as float)
