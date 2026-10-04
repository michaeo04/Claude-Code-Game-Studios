## Haptic values of Platform Services (design/gdd/platform-services.md Tuning Knobs, F2, F3; ADR-0006).
##
## Scalar fields only (data-driven). Defaults are the shipped values; every default is a guess until a device
## test. `validated(log_sink)` returns a clamped copy and never mutates this Resource.
class_name HapticsConfig
extends Resource

## Haptic kinds (provisional). A kind outside this enum is not in the config (`UNKNOWN_KIND`).
enum Kind { NEAR_MISS, HIT, UI_TAP }

const KEY_MAX_MS: String = "HAPTIC_MAX_MS"
const KEY_MIN_INTERVAL: String = "HAPTIC_MIN_INTERVAL"
const MIN_INTERVAL_RANGE: Vector2 = Vector2(0.0, 0.5)
const MAX_MS_RANGE: Vector2 = Vector2(50.0, 500.0)
const AMPLITUDE_RANGE: Vector2 = Vector2(0.0, 1.0)
## Range of the global `haptics_intensity` scalar supplied by Settings (single source for Platform and Settings).
const INTENSITY_RANGE: Vector2 = Vector2(0.0, 1.0)
## Shipped default of `haptics_intensity`.
const INTENSITY_DEFAULT: float = 1.0
const PRIORITY_MIN: int = 0
const PRIORITY_MAX: int = 9
## Lower duration bound of NEAR_MISS and HIT (UI_TAP may be 0 = disabled).
const KIND_MIN_DURATION_MS: float = 10.0

@export_group("Global")
## Minimum time between two same-priority pulses, seconds (0-0.5).
@export var haptic_min_interval: float = 0.08
## Cap on any pulse duration, ms (50-500).
@export var haptic_max_ms: float = 200.0
@export_group("NEAR_MISS")
@export var near_miss_duration_ms: float = 30.0
@export var near_miss_amplitude: float = 0.5
@export var near_miss_priority: int = 1
@export_group("HIT")
@export var hit_duration_ms: float = 80.0
@export var hit_amplitude: float = 1.0
@export var hit_priority: int = 2
@export_group("UI_TAP")
@export var ui_tap_duration_ms: float = 15.0
@export var ui_tap_amplitude: float = 0.3
@export var ui_tap_priority: int = 0


## Kind name (`NEAR_MISS`, `HIT`, `UI_TAP`); `str(kind)` for an unknown kind. Used as log key.
static func kind_name(kind: int) -> String:
	if kind >= 0 and kind < Kind.size():
		return String(Kind.keys()[kind])
	return str(kind)


## True when `kind` is configured.
func has_kind(kind: int) -> bool:
	return kind >= 0 and kind < Kind.size()


## Duration of `kind` in whole milliseconds (`roundi`); 0 for an unknown kind.
func duration_ms(kind: int) -> int:
	match kind:
		Kind.NEAR_MISS:
			return roundi(near_miss_duration_ms)
		Kind.HIT:
			return roundi(hit_duration_ms)
		Kind.UI_TAP:
			return roundi(ui_tap_duration_ms)
	return 0


## Amplitude of `kind`; 0 for an unknown kind.
func amplitude(kind: int) -> float:
	match kind:
		Kind.NEAR_MISS:
			return near_miss_amplitude
		Kind.HIT:
			return hit_amplitude
		Kind.UI_TAP:
			return ui_tap_amplitude
	return 0.0


## Priority of `kind`; 0 for an unknown kind.
func priority(kind: int) -> int:
	match kind:
		Kind.NEAR_MISS:
			return near_miss_priority
		Kind.HIT:
			return hit_priority
		Kind.UI_TAP:
			return ui_tap_priority
	return 0


## `HAPTIC_MAX_MS` in whole milliseconds.
func max_ms() -> int:
	return roundi(haptic_max_ms)


## `HAPTIC_MIN_INTERVAL` converted once to integer microseconds.
func min_interval_us() -> int:
	return PlatformMath.interval_us(haptic_min_interval)


## A clamped copy. Order: `HAPTIC_MAX_MS`, `HAPTIC_MIN_INTERVAL`, then per kind (duration, amplitude, priority).
## One `KNOB_CLAMPED` error per value changed (key `<kind>.<field>` or the knob name); a NaN or infinite
## value takes the shipped default. `log_sink` is `Callable(level, code, key, message)`.
func validated(log_sink: Callable) -> HapticsConfig:
	var out: HapticsConfig = duplicate() as HapticsConfig
	var def: HapticsConfig = HapticsConfig.new()
	out.haptic_max_ms = _fix(log_sink, KEY_MAX_MS, haptic_max_ms, def.haptic_max_ms, MAX_MS_RANGE.x, MAX_MS_RANGE.y, true)
	out.haptic_min_interval = _fix(
		log_sink, KEY_MIN_INTERVAL, haptic_min_interval, def.haptic_min_interval, MIN_INTERVAL_RANGE.x, MIN_INTERVAL_RANGE.y, false
	)
	var cap: float = out.haptic_max_ms
	out.near_miss_duration_ms = _fix(
		log_sink, "NEAR_MISS.duration_ms", near_miss_duration_ms, def.near_miss_duration_ms, KIND_MIN_DURATION_MS, cap, true
	)
	out.near_miss_amplitude = _fix(
		log_sink, "NEAR_MISS.amplitude", near_miss_amplitude, def.near_miss_amplitude, AMPLITUDE_RANGE.x, AMPLITUDE_RANGE.y, false
	)
	out.near_miss_priority = _fix_priority(log_sink, "NEAR_MISS.priority", near_miss_priority)
	out.hit_duration_ms = _fix(log_sink, "HIT.duration_ms", hit_duration_ms, def.hit_duration_ms, KIND_MIN_DURATION_MS, cap, true)
	out.hit_amplitude = _fix(
		log_sink, "HIT.amplitude", hit_amplitude, def.hit_amplitude, AMPLITUDE_RANGE.x, AMPLITUDE_RANGE.y, false
	)
	out.hit_priority = _fix_priority(log_sink, "HIT.priority", hit_priority)
	out.ui_tap_duration_ms = _fix(log_sink, "UI_TAP.duration_ms", ui_tap_duration_ms, def.ui_tap_duration_ms, 0.0, cap, true)
	out.ui_tap_amplitude = _fix(
		log_sink, "UI_TAP.amplitude", ui_tap_amplitude, def.ui_tap_amplitude, AMPLITUDE_RANGE.x, AMPLITUDE_RANGE.y, false
	)
	out.ui_tap_priority = _fix_priority(log_sink, "UI_TAP.priority", ui_tap_priority)
	return out


static func _fix(log_sink: Callable, key: String, raw: float, default: float, lo: float, hi: float, round_whole: bool) -> float:
	var finite: bool = is_finite(raw)
	var used: float = raw if finite else default
	if round_whole:
		used = float(roundi(used))
	var clamped: float = clampf(used, lo, hi)
	if not finite or clamped != used:
		_log(log_sink, key, str(raw), str(clamped))
	return clamped


static func _fix_priority(log_sink: Callable, key: String, raw: int) -> int:
	var clamped: int = clampi(raw, PRIORITY_MIN, PRIORITY_MAX)
	if clamped != raw:
		_log(log_sink, key, str(raw), str(clamped))
	return clamped


static func _log(log_sink: Callable, key: String, raw: String, used: String) -> void:
	log_sink.call(
		LogLevel.ERROR,
		RateLimitedLog.KNOB_CLAMPED,
		key,
		"%s=%s is outside its safe range; using %s" % [key, raw, used]
	)
