## Platform Services pure functions (design/gdd/platform-services.md F2, F3, F4; ADR-0006).
##
## Static and engine-free: no Input, DisplayServer, ProjectSettings, Engine, Time or OS. Every tunable value
## (minimum interval, maximum duration, frame cap) arrives as a parameter. `fis_for_platform` is added by Story 008.
class_name PlatformMath
extends RefCounted

## `last_played_us` value meaning "no pulse played yet" (the GDD's `none`).
const NO_LAST_US: int = -1
## Amplitude sentinel: the OS default level (applied before any intensity scale).
const AMP_OS_DEFAULT: float = -1.0


## F2 haptic gate. True when the pulse should play. `last` is `NO_LAST_US` when nothing played yet.
## Both comparisons are inclusive; a strictly higher `prio` bypasses the gate; the other drop causes
## (`enabled`, `attentive`, `dur_eff <= 0`) cannot be bypassed.
static func haptic_gate(
	enabled: bool,
	attentive: bool,
	dur_eff: int,
	prio: int,
	now: int,
	last: int,
	last_end: int,
	last_prio: int,
	min_us: int
) -> bool:
	if not enabled or not attentive or dur_eff <= 0:
		return false
	var gate_open: bool = last == NO_LAST_US or now < last or (now - last >= min_us and now >= last_end)
	return gate_open or prio > last_prio


## F3 effective duration and amplitude as `Vector2(dur_eff, amp_eff)`.
## `dur_eff = clamp(dur, 0, max_ms)`; `amp_eff = -1` for a negative amplitude (sentinel), else `clamp(amp, 0, 1)`.
static func effective(dur: int, amp: float, max_ms: int) -> Vector2:
	var dur_eff: int = clampi(dur, 0, maxi(max_ms, 0))
	var amp_eff: float = AMP_OS_DEFAULT if amp < 0.0 else clampf(amp, 0.0, 1.0)
	return Vector2(float(dur_eff), amp_eff)


## Seconds to integer microseconds: `roundi(seconds * 1e6)`, once.
static func interval_us(seconds: float) -> int:
	return roundi(seconds * 1.0e6)


## F4 effective frame rate. 0 means unknown. `max_fps` <= 0 is the engine's "unlimited".
static func fps_eff(max_fps: float, refresh: float) -> float:
	var max_known: bool = is_finite(max_fps) and max_fps > 0.0
	var refresh_known: bool = is_finite(refresh) and refresh > 0.0
	if max_known and refresh_known:
		return minf(max_fps, refresh)
	if max_known:
		return max_fps
	if refresh_known:
		return refresh
	return 0.0


## Frame time in milliseconds, `1000 / fps`; 0 when `fps` is not positive (no division).
static func frame_time(fps: float) -> float:
	if not (is_finite(fps) and fps > 0.0):
		return 0.0
	return 1000.0 / fps
