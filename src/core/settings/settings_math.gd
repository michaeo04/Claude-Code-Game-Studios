## Pure helpers for Settings & Accessibility: seam contrast derivation (F1) and tilt sensitivity validation (F2).
##
## No state, no engine call and no logging: logging `SETTING_CLAMPED` belongs to `SettingsCore`.
## Every limit is a parameter, so a fixture-distinct range can be exercised without touching shipped values.
class_name SettingsMath
extends RefCounted


## F1: the seam contrast scale derived from the reduced-motion setting.
## Returns exactly `0.0` when `reduced_motion_enabled` is true and exactly `1.0` otherwise (never a blend).
static func seam_contrast_scale(reduced_motion_enabled: bool) -> float:
	return 0.0 if reduced_motion_enabled else 1.0


## F2: validates a raw tilt sensitivity against `[min_value, max_value]`.
## A finite, strictly positive `raw` is clamped to the range; anything else (NaN, INF, zero, negative)
## falls back to `default_value`. Returns `{ "value": float, "was_corrected": bool }`, where
## `was_corrected` is true when the output differs from `raw` because of a clamp or a fallback.
static func tilt_sensitivity_validate(raw: float, min_value: float, max_value: float, default_value: float) -> Dictionary:
	if not is_finite(raw) or raw <= 0.0:
		return {"value": default_value, "was_corrected": true}
	var clamped: float = clampf(raw, min_value, max_value)
	return {"value": clamped, "was_corrected": clamped != raw}


## Validates a raw haptics intensity against `[min_value, max_value]` (zero is valid). A non-finite `raw` falls
## back to `default_value`; a finite one is clamped to the nearest bound. Same result shape as F2.
static func haptics_intensity_validate(raw: float, min_value: float, max_value: float, default_value: float) -> Dictionary:
	if not is_finite(raw):
		return {"value": default_value, "was_corrected": true}
	var clamped: float = clampf(raw, min_value, max_value)
	return {"value": clamped, "was_corrected": clamped != raw}
