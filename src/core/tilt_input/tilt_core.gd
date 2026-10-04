## Tilt Input core (design/gdd/tilt-input.md rules 4, 6, 8, 12): poll, clock stamps and the sample ring buffer.
##
## Engine-free `RefCounted`: no `Input`, no `Time`, no node. The gravity vector comes from the injected
## `sample_source`, time from the injected microsecond `clock`. Covers the poll path, neutral capture
## (rules 7, 8), the pipeline and the published output (rules 2, 5), the availability states, the start timeout,
## the sensor-loss hold (F6) and the app lifecycle (rule 9). Fallback steering arrives in a later story.
class_name TiltCore
extends RefCounted

## Emitted whenever `valid` changes value (not at construction).
signal availability_changed(available: bool)

enum State { ACQUIRING, LIVE, UNAVAILABLE }
## Control source (rule 2). Only SENSOR is produced until the fallback story.
enum InputSource { SENSOR, FALLBACK }
## Phase before a `run_reset`, supplied by the adapter (Story 012).
enum PreviousPhase { UNKNOWN, BOOT, MENU, HIT, PAUSED }

## Log code of an invalid injected Callable at construction (error level).
const LOG_SEAM_INVALID: StringName = &"SEAM_INVALID"
## Ring buffer capacity (fixed constant, GDD rule 8).
const BUFFER_CAPACITY: int = 256
## Samples older than this (microseconds) are dropped at every append (`BUFFER_AGE` 1.0 s).
const BUFFER_AGE_US: int = 1000000
## Log code of a non-finite published value (error level).
const LOG_BAD_OUTPUT: StringName = &"BAD_OUTPUT"
## Log code of a rest pose beyond `L_eff` (error level).
const LOG_POSTURE_UNSUPPORTED: StringName = &"POSTURE_UNSUPPORTED"
## Log code of a non-portrait boot (diagnostic, error level).
const LOG_NOT_PORTRAIT: StringName = &"NOT_PORTRAIT"
## Log code of a corrected live sensitivity (warning level).
const LOG_SETTING_CLAMPED: StringName = &"SETTING_CLAMPED"
## Log code of sensors disabled by project setting (error level).
const LOG_SENSORS_DISABLED: StringName = &"SENSORS_DISABLED"
## Log code of the start timeout (error level).
const LOG_SENSOR_TIMEOUT: StringName = &"SENSOR_TIMEOUT"
## Consecutive invalid polls needed before Unavailable (GDD F6 `DROPOUT_MIN_POLLS`).
const DROPOUT_MIN_POLLS: int = 3

var _config: TiltConfig
var _sample_source: Callable
var _clock: Callable
var _log_sink: Callable
var _fallback_source: Callable

var _state: State = State.ACQUIRING
var _sensor_ever_live: bool = false
var _has_previous: bool = false
var _previous_now_us: int = 0
var _last_dt: float = 0.0
## Poll step clamp in microseconds: the injected Run State `dt_max`.
var _dt_max_us: int = 0
var _g_min_sq: float = 0.0
var _sensitivity: float = 1.0
var _fs_eff: float = 25.0
var _guard_us: int = 0
var _window_us: int = 0
var _n_min: int = 5
var _input_source: InputSource = InputSource.SENSOR
var _locked: bool = false
var _in_background: bool = false
var _hold_us: int = 0
var _timeout_us: int = 0
var _settle_us: int = 0
var _settle_until_us: int = 0
var _timeout_armed: bool = false
var _timeout_start_us: int = 0
var _invalid_us: int = 0
var _invalid_polls: int = 0

var _phi0: float = 0.0
var _phi_f: float = 0.0
var _steer: float = 0.0
var _neutral_pending: bool = true
var _neutral_stale: bool = true
var _pending_samples: PackedFloat64Array = PackedFloat64Array()
var _pending_count: int = 0
var _stop_us: int = 0
var _phi_stop: float = NAN

# Ring buffer: roll angles (degrees) and their poll stamps (us); `_head` is the next write slot.
var _angles: PackedFloat64Array = PackedFloat64Array()
var _stamps: PackedInt64Array = PackedInt64Array()
var _head: int = 0
var _count: int = 0


## Builds a core. `config` should already be validated. An invalid Callable (unset or freed) logs one
## `SEAM_INVALID` error per seam through `log_sink` (when that one is valid) and leaves the core Unavailable
## for good; `poll()` then does nothing. `sensitivity` is the Settings hook (validated here); a false
## `is_portrait` logs one `NOT_PORTRAIT` diagnostic and changes nothing else. `sensors_enabled` false logs one
## `SENSORS_DISABLED` error: Live `FALLBACK` when `is_debug`, otherwise Unavailable for good (a configuration error).
## `dt_max` is Run State's `dt_max` in seconds (non-positive or non-finite falls back to the shipped default).
## Example: `TiltCore.new(cfg, src, clk, sink, fb, 1.0, true, false, false)` is Unavailable and inert.
func _init(config: TiltConfig, sample_source: Callable, clock: Callable, log_sink: Callable, fallback_source: Callable,
		sensitivity: float = 1.0, is_portrait: bool = true, sensors_enabled: bool = true, is_debug: bool = true,
		dt_max: float = TuningLimits.DT_MAX_DEFAULT) -> void:
	_config = config
	_dt_max_us = roundi((dt_max if is_finite(dt_max) and dt_max > 0.0 else TuningLimits.DT_MAX_DEFAULT) * 1e6)
	_sample_source = sample_source
	_clock = clock
	_log_sink = log_sink
	_fallback_source = fallback_source
	_g_min_sq = config.g_min * config.g_min
	_sensitivity = TiltConfig.validated_sensitivity(sensitivity, log_sink)
	_fs_eff = minf(config.tilt_full_scale / _sensitivity, TiltMath.FS_EFF_MAX)
	_guard_us = roundi(config.neutral_guard * 1e6)
	_window_us = roundi(config.neutral_window * 1e6)
	_n_min = maxi(1, config.neutral_min_samples)
	_hold_us = roundi(config.dropout_hold * 1e6)
	_timeout_us = roundi(config.sensor_start_timeout * 1e6)
	_settle_us = roundi(config.sensor_resume_settle * 1e6)
	_pending_samples.resize(_n_min)
	_angles.resize(BUFFER_CAPACITY)
	_stamps.resize(BUFFER_CAPACITY)
	var seams: Dictionary = {
		"sample_source": sample_source, "clock": clock, "log_sink": log_sink, "fallback_source": fallback_source,
	}
	var broken: bool = false
	for seam_name: String in seams:
		var seam: Callable = seams[seam_name]
		if not seam.is_valid():
			broken = true
			_log(LOG_SEAM_INVALID, "%s is not a valid Callable" % seam_name)
	if broken:
		_state = State.UNAVAILABLE
	if not is_portrait:
		_log(LOG_NOT_PORTRAIT, "the screen is not in portrait; F1 still uses the screen-relative x axis")
	if not sensors_enabled:
		_log(LOG_SENSORS_DISABLED, "the sensor project settings are disabled")
		if is_debug:
			_enter_fallback_state()
		else:
			_state = State.UNAVAILABLE
			_locked = true


## Reads one sample and stamps it with the injected clock (once per rendered frame, GDD rule 6).
## `dt` is the clamped stamp difference to the last accepted poll; an equal or backwards stamp appends
## nothing and gives `dt` 0. A valid sample (finite, `|g| >= g_min`) is appended to the ring buffer.
func poll() -> void:
	if _is_broken() or _in_background:
		return
	var now_us: int = _clock.call() as int
	if _has_previous and now_us <= _previous_now_us:
		_last_dt = 0.0
		return
	var diff_us: int = 0
	if _has_previous:
		diff_us = clampi(now_us - _previous_now_us, 0, _dt_max_us)
	_last_dt = float(diff_us) / 1e6
	_has_previous = true
	_previous_now_us = now_us
	if _input_source == InputSource.FALLBACK or now_us < _settle_until_us:
		return
	if not _timeout_armed:
		_timeout_armed = true
		_timeout_start_us = now_us

	var g: Vector3 = _sample_source.call() as Vector3
	if not g.is_finite() or g.length_squared() < _g_min_sq:
		_on_invalid_poll(now_us, diff_us)
		return
	_invalid_us = 0
	_invalid_polls = 0
	var angle: float = TiltMath.roll_deg(g, _config.sensor_sign)
	_append(angle, now_us)
	_sensor_ever_live = true
	var was_live: bool = _state == State.LIVE
	_state = State.LIVE
	_process_sample(angle, was_live)
	if not was_live:
		availability_changed.emit(true)


## App backgrounded (rule 9, from Platform Services): clears the buffer and sets `neutral_stale`. From Live or
## Unavailable (sensor lost) the state becomes Acquiring (`availability_changed(false)` when it was Live); in
## Acquiring only the buffer is cleared. Polls are ignored until `on_app_foregrounded()`. A second call equals one.
## Ignored in Live `FALLBACK` and after a release-build configuration error.
func on_app_backgrounded() -> void:
	if _is_broken() or _input_source == InputSource.FALLBACK:
		return
	_count = 0
	_head = 0
	_in_background = true
	_timeout_armed = false
	_invalid_us = 0
	_invalid_polls = 0
	_neutral_stale = true
	_steer = 0.0
	var was_live: bool = _state == State.LIVE
	_state = State.ACQUIRING
	if was_live:
		availability_changed.emit(false)


## App foregrounded (rule 9): samples are discarded for `SENSOR_RESUME_SETTLE` from now, and the start timeout
## counts from the first poll after the settle. Does nothing without a prior `on_app_backgrounded()`.
func on_app_foregrounded() -> void:
	if _is_broken() or _input_source == InputSource.FALLBACK or not _in_background:
		return
	_in_background = false
	_settle_until_us = (_clock.call() as int) + _settle_us
	_timeout_armed = false


## Capture event: `run_reset` (rule 7). From Hit or Paused it re-anchors conditionally unless `neutral_stale`;
## every other previous phase (Boot, Menu, unknown) always captures.
func on_run_reset(previous_phase: PreviousPhase) -> void:
	if _is_broken() or _input_source == InputSource.FALLBACK:
		return
	if (previous_phase == PreviousPhase.HIT or previous_phase == PreviousPhase.PAUSED) and not _neutral_stale:
		_reanchor()
	else:
		_capture_event()


## Capture event: the end of the resume countdown (rule 7). Always captures.
func on_run_resumed() -> void:
	if _is_broken() or _input_source == InputSource.FALLBACK:
		return
	_capture_event()


## `run_started` changes nothing in the core (rule 7); kept so the adapter can forward every Run State event.
func on_run_started() -> void:
	pass


## `run_ended` / `run_paused`: records `stop_us` and `phi_stop`, the median of the roll samples in
## `[stop_us - G - W, stop_us - G]` (unknown, NAN, with fewer than `N_min` samples). Nothing else changes.
func on_run_stopped() -> void:
	if _is_broken():
		return
	_stop_us = _clock.call() as int
	var vals: PackedFloat64Array = _window_samples(_stop_us - _guard_us - _window_us, _stop_us - _guard_us)
	_phi_stop = TiltMath.median(vals) if vals.size() >= _n_min else NAN


## Settings hook, live: replaces the sensitivity (validated against the `TiltConfig` bounds, one `SETTING_CLAMPED`
## warning when corrected) and recomputes `FS_eff`. The ring buffer, the neutral and the filter are untouched; the
## next `poll()` publishes a `steer` scaled by the new value.
func set_sensitivity(value: float) -> void:
	var quiet: Callable = func(_level: int, _code: StringName, _key: String, _message: String) -> void: pass
	var checked: float = TiltConfig.validated_sensitivity(value, quiet)
	if checked != value and _log_sink.is_valid():
		_log_sink.call(LogLevel.WARNING, LOG_SETTING_CLAMPED, "tilt_sensitivity", "sensitivity %s corrected to %s" % [value, checked])
	_sensitivity = checked
	_fs_eff = minf(_config.tilt_full_scale / _sensitivity, TiltMath.FS_EFF_MAX)


## Current availability state.
func get_state() -> State:
	return _state


## Number of samples currently held in the ring buffer.
func get_sample_count() -> int:
	return _count


## Clamped `dt` in seconds of the last poll (0 for the first, an equal or a backwards stamp).
func get_last_dt() -> float:
	return _last_dt


## Accumulated clamped poll time (microseconds) of the consecutive invalid polls (F6).
func get_invalid_us() -> int:
	return _invalid_us


## Number of consecutive invalid polls (F6).
func get_invalid_polls() -> int:
	return _invalid_polls


## True once a valid sample was accepted.
func get_sensor_ever_live() -> bool:
	return _sensor_ever_live


## Published steer in `[-1, 1]`, never NaN or infinite. Reading it twice without a poll gives the same value.
func get_steer() -> float:
	return _steer


## True while the state is Live (rule 2).
func get_valid() -> bool:
	return _state == State.LIVE


## Control source (rule 2): SENSOR, or FALLBACK after the start timeout or with sensors disabled in a debug build.
func get_input_source() -> InputSource:
	return _input_source


## Captured neutral in degrees (within +-PHI_MAX).
func get_phi0() -> float:
	return _phi0


## Filtered relative angle in degrees.
func get_phi_f() -> float:
	return _phi_f


## Median roll of the window before the last stop, or NAN when unknown.
func get_phi_stop() -> float:
	return _phi_stop


## Clock stamp (us) of the last `on_run_stopped`.
func get_stop_us() -> int:
	return _stop_us


## True while a capture waits for its first `N_min` valid samples.
func get_neutral_pending() -> bool:
	return _neutral_pending


## True from construction until any capture.
func get_neutral_stale() -> bool:
	return _neutral_stale


func _is_broken() -> bool:
	return _locked or not (_sample_source.is_valid() and _clock.is_valid() and _log_sink.is_valid() and _fallback_source.is_valid())


func _append(angle_deg: float, now_us: int) -> void:
	# Drop samples older than BUFFER_AGE (true time), oldest first.
	while _count > 0:
		var tail: int = posmod(_head - _count, BUFFER_CAPACITY)
		if now_us - _stamps[tail] > BUFFER_AGE_US:
			_count -= 1
		else:
			break
	_angles[_head] = angle_deg
	_stamps[_head] = now_us
	_head = (_head + 1) % BUFFER_CAPACITY
	_count = mini(_count + 1, BUFFER_CAPACITY)


func _log(code: StringName, detail: String) -> void:
	if _log_sink.is_valid():
		_log_sink.call(LogLevel.ERROR, code, "", detail)


func _process_sample(angle: float, was_live: bool) -> void:
	if _neutral_pending:
		_pending_samples[_pending_count] = angle
		_pending_count += 1
		if _pending_count >= _n_min:
			_apply_capture(TiltMath.median(_pending_samples))
		return
	var phi_r: float = angle - _phi0
	if was_live:
		_phi_f = TiltMath.filter_step(_phi_f, phi_r, _last_dt, _config.filter_tau)
	else:
		_phi_f = phi_r
	_update_steer()


func _update_steer() -> void:
	var s: float = TiltMath.steer(_phi_f, _config.tilt_full_scale, _config.dead_zone, _config.curve_exp, _sensitivity)
	if not is_finite(s) or not is_finite(_phi_f):
		_log(LOG_BAD_OUTPUT, "steer is not finite (phi_f=%s); using 0" % _phi_f)
		_phi_f = 0.0
		s = 0.0
	_steer = s


func _capture_event() -> void:
	if _state != State.LIVE:
		_begin_pending()
		return
	var t: int = _clock.call() as int
	var vals: PackedFloat64Array = _window_samples(t - _guard_us - _window_us, t - _guard_us)
	if vals.size() >= _n_min:
		_apply_capture(TiltMath.median(vals))
	else:
		_begin_pending()


func _reanchor() -> void:
	var t: int = _clock.call() as int
	var vals: PackedFloat64Array = _window_samples(maxi(t - _guard_us - _window_us, _stop_us), t - _guard_us)
	if vals.is_empty():
		return
	var m: float = TiltMath.median(vals)
	var lo: float = vals[0]
	var hi: float = vals[0]
	for v: float in vals:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	if TiltMath.should_reanchor(vals.size(), hi - lo, m, _phi0, _phi_stop, _n_min, _config.reanchor_spread,
			_config.reanchor_offset, _fs_eff):
		_apply_capture(m)


func _begin_pending() -> void:
	_neutral_pending = true
	_pending_count = 0
	_steer = 0.0


## Sets the neutral from median `m` (F2): clamp, posture diagnostic, filter to 0, flags cleared.
func _apply_capture(m: float) -> void:
	_phi0 = clampf(m, -TiltMath.PHI_MAX, TiltMath.PHI_MAX)
	if absf(m) > maxf(0.0, TiltMath.PHI_MAX - _fs_eff):
		_log(LOG_POSTURE_UNSUPPORTED, "rest pose %s deg is beyond the supported range" % m)
	_phi_f = 0.0
	_steer = 0.0
	_neutral_pending = false
	_neutral_stale = false
	_pending_count = 0


## Roll samples whose stamp lies in the closed interval `[lo_us, hi_us]`, oldest first.
func _window_samples(lo_us: int, hi_us: int) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var first: int = _head - _count
	for i: int in _count:
		var idx: int = posmod(first + i, BUFFER_CAPACITY)
		var stamp: int = _stamps[idx]
		if stamp >= lo_us and stamp <= hi_us:
			out.append(_angles[idx])
	return out


## One invalid poll: Acquiring checks the start timeout, Live (`SENSOR`) runs the F6 hold.
func _on_invalid_poll(now_us: int, diff_us: int) -> void:
	if _state == State.ACQUIRING:
		if now_us - _timeout_start_us < _timeout_us:
			return
		if _sensor_ever_live:
			_state = State.UNAVAILABLE
			_log(LOG_SENSOR_TIMEOUT, "no valid sample after the app returned; Unavailable")
		else:
			_enter_fallback_state()
			_log(LOG_SENSOR_TIMEOUT, "no valid sample within the start timeout; using the fallback input")
			availability_changed.emit(true)
	elif _state == State.LIVE:
		_invalid_us += diff_us
		_invalid_polls += 1
		if _invalid_us <= _hold_us or _invalid_polls < DROPOUT_MIN_POLLS:
			return
		_state = State.UNAVAILABLE
		_steer = 0.0
		_neutral_stale = true
		availability_changed.emit(false)


func _enter_fallback_state() -> void:
	_state = State.LIVE
	_input_source = InputSource.FALLBACK
	_neutral_pending = false
	_neutral_stale = false
	_steer = 0.0
