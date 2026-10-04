## Platform Services settings manifest and boot check (design/gdd/platform-services.md rule 8; ADR-0006 Decision 9,
## ADR-0005 `required_input_settings`). Engine-free: runtime values arrive through an injected `read` Callable.
##
## The manifest is data (entries of `section`, `key`, `expected`, `owner`, `runtime`) so the CI lint can read the same
## entries. `enable_accelerometer` and other sensor flags are deliberately absent (forbidden to set true).
class_name PlatformSettings
extends RefCounted

## Owner tag of the entries shared with Tilt Input (its AC-37d).
const OWNER_TILT: String = "tilt"
## Owner tag of the entries Platform Services owns.
const OWNER_PLATFORM: String = "platform"


## The manifest. `runtime` entries are `project.godot` keys readable at run time (checked in this order,
## `enable_gravity` first so a missing flag reads as a settings error, not a missing sensor). Preset entries
## (`runtime` false) are export-preset keys, stored for the lint; key names are UNVERIFIED until story 011.
static func manifest() -> Array[Dictionary]:
	return [
		_entry("input_devices", "input_devices/sensors/enable_gravity", true, OWNER_TILT, true),
		_entry("display", "display/window/handheld/orientation", 1, OWNER_TILT, true),
		_entry("application", "application/run/max_fps", 60, OWNER_PLATFORM, true),
		_entry("application", "application/config/quit_on_go_back", false, OWNER_PLATFORM, true),
		_entry("input_devices", "input_devices/pointing/emulate_mouse_from_touch", true, OWNER_PLATFORM, true),
		_entry("input_devices", "input_devices/pointing/emulate_touch_from_mouse", true, OWNER_PLATFORM, true),
		_entry("preset", "permissions/vibrate", true, OWNER_PLATFORM, false),
		_entry("preset", "screen/immersive_mode", true, OWNER_PLATFORM, false),
		_entry("preset", "graphics/picture_in_picture", false, OWNER_PLATFORM, false),
	]


## Keys (in manifest order) whose runtime value differs from the expected one or is missing.
## `read` is `Callable(key: String, default: Variant) -> Variant`; a missing key returns the `null` default,
## which never equals an expected value. Preset entries are skipped.
static func mismatches(entries: Array[Dictionary], read: Callable) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in entries:
		if not e["runtime"]:
			continue
		var key: String = e["key"]
		var value: Variant = read.call(key, null)
		if value == null or typeof(value) != typeof(e["expected"]) or value != e["expected"]:
			out.append(key)
	return out


## Runs `mismatches` and logs one `SETTINGS_MISMATCH` error per key (key as log key) through `log`.
## Returns the mismatching keys.
static func report(entries: Array[Dictionary], read: Callable, log: RateLimitedLog) -> Array[String]:
	var bad: Array[String] = mismatches(entries, read)
	for key: String in bad:
		log.emit(LogLevel.ERROR, RateLimitedLog.SETTINGS_MISMATCH, key, "project setting %s differs from the manifest" % key)
	return bad


static func _entry(section: String, key: String, expected: Variant, owner: String, runtime: bool) -> Dictionary:
	return {"section": section, "key": key, "expected": expected, "owner": owner, "runtime": runtime}
