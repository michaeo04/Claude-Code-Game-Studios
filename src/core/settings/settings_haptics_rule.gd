## Binds the haptics intensity validation to the Platform Services range (single source: `HapticsConfig`).
##
## Kept apart from `SettingsCore`/`SettingsMath`, which the coupling lint keeps free of Platform symbols.
class_name SettingsHapticsRule
extends RefCounted

## Shipped default of `haptics_intensity` (from `HapticsConfig`).
const DEFAULT_INTENSITY: float = HapticsConfig.INTENSITY_DEFAULT


## Result of `SettingsMath.haptics_intensity_validate` over `HapticsConfig.INTENSITY_RANGE`:
## `{ "value": float, "was_corrected": bool }`.
static func validate(raw: float) -> Dictionary:
	return SettingsMath.haptics_intensity_validate(
		raw, HapticsConfig.INTENSITY_RANGE.x, HapticsConfig.INTENSITY_RANGE.y, HapticsConfig.INTENSITY_DEFAULT
	)
