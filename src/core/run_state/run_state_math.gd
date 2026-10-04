## Pure helpers for Run State & Restart: shared enums, stable log codes and the F1/F3/F4/F5 arithmetic.
##
## No state and no engine call (ADR-0002 Decision 4, ADR-0009): every function is a pure function of its
## arguments, so the formulas of `design/gdd/run-state-restart.md` are unit-testable without a core.
class_name RunStateMath
extends RefCounted

## Microseconds per second, as a float for the `round(seconds * 1e6)` conversions of the GDD.
const US_PER_S: float = 1_000_000.0
## Milliseconds per second.
const MS_PER_S: float = 1000.0

## Stable log codes. A log message always starts with its code, so tests and telemetry can match on it.
const LOG_REQUEST_REJECTED: StringName = &"RS_REQUEST_REJECTED"
const LOG_REQUEST_LOCKED: StringName = &"RS_REQUEST_LOCKED"
const LOG_REQUEST_NESTED: StringName = &"RS_REQUEST_NESTED"
const LOG_HIT_STALE: StringName = &"RS_HIT_STALE"
const LOG_HIT_SETTLING: StringName = &"RS_HIT_SETTLING"
const LOG_HIT_IGNORED: StringName = &"RS_HIT_IGNORED"
const LOG_HIT_BAD_ID: StringName = &"RS_HIT_BAD_ID"
const LOG_PRESS_US_INVALID: StringName = &"RS_PRESS_US_INVALID"
const LOG_DT_INVALID: StringName = &"RS_DT_INVALID"
const LOG_CONFIG_CLAMPED: StringName = &"RS_CONFIG_CLAMPED"
const LOG_CONFIG_LOCK_BOUNDS: StringName = &"RS_CONFIG_LOCK_BOUNDS"
const LOG_CONFIG_LOCK_READ: StringName = &"RS_CONFIG_LOCK_READ"


## `round(seconds * 1e6)`: the microsecond form of a configured duration (GDD Open Question 15: `round`, not `int`).
static func seconds_to_us(seconds: float) -> int:
	return roundi(seconds * US_PER_S)


## `round(seconds * 1000)`: the integer millisecond form carried in events (`run_time_ms`, `duration_ms`).
static func seconds_to_ms(seconds: float) -> int:
	return roundi(seconds * MS_PER_S)


## F1 step candidate: `min(dt, dt_max)` when `dt` is finite and positive, else 0.
static func clamp_step(dt: float, dt_max: float) -> float:
	if not is_finite(dt) or dt <= 0.0:
		return 0.0
	return minf(dt, dt_max)


## True when `dt` is a legitimate world step: finite and not negative (0 is legitimate in Paused and hitstop).
static func is_valid_dt(dt: float) -> bool:
	return is_finite(dt) and dt >= 0.0


## Elapsed microseconds since an anchor, never negative (GDD Edge Cases: a backwards clock never finishes a timer early).
static func elapsed_us(now_us: int, anchor_us: int) -> int:
	return maxi(0, now_us - anchor_us)


## F5 countdown progress in [0, 1]: `1 - remaining / duration`. A duration of 0 or less returns 1
## (unreachable in the game because the config clamps the countdown; kept testable on the helper).
static func progress_for(duration: float, elapsed: float) -> float:
	if duration <= 0.0:
		return 1.0
	var remaining: float = maxf(0.0, duration - elapsed)
	return clampf(1.0 - remaining / duration, 0.0, 1.0)


## F4 `LOCK_MIN = max(HITSTOP_MAX + T_READ, T_REACT + T_STOP)`.
static func lock_min(hitstop_max: float, t_read: float, t_react: float, t_stop: float) -> float:
	return maxf(hitstop_max + t_read, t_react + t_stop)


## F4 `LOCK_MAX = min(FRICTION_MAX, RESTART_BUDGET - T_restart@30fps)`.
static func lock_max(friction_max: float, restart_budget: float, t_restart_30fps: float) -> float:
	return minf(friction_max, restart_budget - t_restart_30fps)
