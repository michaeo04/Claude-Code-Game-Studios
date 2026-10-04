## Tuning values shared by more than one core, defined once (code review finding 8).
##
## Neutral on purpose: Settings files may not name Tilt, Platform or Tube Track classes (lint
## `settings_core_coupling`), so the shared numbers live here and every consumer reads them.
class_name TuningLimits
extends RefCounted

## Shipped default of the run clock step clamp in seconds: Run State `dt_max`, which Tilt Input
## and Tube Track `t_lat` receive by injection (they default to this value).
const DT_MAX_DEFAULT: float = 0.1
## Lowest accepted `tilt_sensitivity` (Settings hook, clamped by Settings and Tilt Input).
const SENSITIVITY_MIN: float = 0.5
## Highest accepted `tilt_sensitivity`.
const SENSITIVITY_MAX: float = 2.0
