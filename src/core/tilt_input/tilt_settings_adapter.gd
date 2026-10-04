## Glue between `SettingsCore.setting_changed` and `TiltCore` (GDD settings-accessibility rule 6).
##
## Pure and engine-free. The composition root connects `setting_changed` to `on_setting_changed` (immediate
## connection). A `tilt_sensitivity` change reaches `TiltCore.set_sensitivity` before the next `poll`.
class_name TiltSettingsAdapter
extends RefCounted

## Settings key this adapter forwards (equals `SettingsCore.KEY_TILT_SENSITIVITY`).
const KEY_TILT_SENSITIVITY: String = "tilt_sensitivity"

var _tilt: TiltCore


func _init(tilt: TiltCore) -> void:
	_tilt = tilt


## `setting_changed(key, value)`: forwards `tilt_sensitivity`; every other key is ignored.
func on_setting_changed(key: String, value: Variant) -> void:
	if key == KEY_TILT_SENSITIVITY and typeof(value) == TYPE_FLOAT:
		_tilt.set_sensitivity(value as float)
