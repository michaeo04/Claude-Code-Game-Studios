## Platform Services logic (design/gdd/platform-services.md rules 1-6, 11; ADR-0006). No engine calls.
##
## OS notifications arrive as method calls (`on_focus_out` ...); vibration leaves through the injected `vibrate`
## Callable; time comes from the injected `clock_us`. Signals are emitted synchronously inside the handler,
## are never replayed and nothing is emitted at construction: late consumers read `attentive` / `suspended`.
## Use method Callables for the seams, not lambdas capturing `self`.
class_name PlatformCore
extends RefCounted

## The app lost attention (focus lost or paused).
signal app_interrupted
## The app is suspended: the only flush signal.
signal app_backgrounded
## The app is no longer suspended.
signal app_foregrounded
## The app regained attention.
signal app_returned
## The Back request arrived (one emission per `on_back_requested` call). Decides nothing; consumers are idempotent.
signal back_pressed

## Reasons a `haptic` call is dropped, in evaluation order.
enum DropCause { UNKNOWN_KIND, DISABLED, NOT_ATTENTIVE, ZERO_DURATION, THROTTLED }

const EVENT_FOCUS_OUT: String = "FOCUS_OUT"
const EVENT_FOCUS_IN: String = "FOCUS_IN"
const EVENT_PAUSED: String = "PAUSED"
const EVENT_RESUMED: String = "RESUMED"

## Stamp (us) of the last played pulse, `PlatformMath.NO_LAST_US` when none.
var last_played_us: int = PlatformMath.NO_LAST_US
## End (us) of the last played pulse.
var last_end_us: int = 0
## Priority of the last played pulse.
var last_prio: int = 0

var _fis: bool
var _clock_us: Callable
## Repeating diagnostics (unknown haptic kind, redundant lifecycle calls) go through this: one line per window.
var _limiter: RateLimitedLog
var _vibrate: Callable
var _display_source: Callable
var _config: HapticsConfig
var _focused: bool = true
var _paused: bool = false
var _haptics_enabled: bool = true
var _haptics_intensity: float = 1.0
var _drops: Array[int] = [0, 0, 0, 0, 0]
var _safe_area: Rect2i = Rect2i()
var _screen_size: Vector2i = Vector2i.ZERO
var _viewport_size: Vector2i = Vector2i.ZERO
var _refresh_rate: float = 0.0
var _screen_dpi: int = 0

## True when the app has focus and is not paused.
var attentive: bool:
	get:
		return _is_attentive()

## Safe area in pixels; the full screen rectangle when the source reports an empty one.
var safe_area: Rect2i:
	get:
		return _safe_area

## Screen size in pixels.
var screen_size: Vector2i:
	get:
		return _screen_size

## Viewport size in pixels, exposed unconverted.
var viewport_size: Vector2i:
	get:
		return _viewport_size

## Display refresh rate in Hz, raw (0 or negative means unknown; `PlatformMath.fps_eff` handles it).
var refresh_rate: float:
	get:
		return _refresh_rate

## Screen DPI (extra key for ADR-0011), 0 when unknown.
var screen_dpi: int:
	get:
		return _screen_dpi

## True when the app is suspended (paused, or unfocused when focus implies suspend).
var suspended: bool:
	get:
		return _is_suspended()


## `focus_implies_suspend` is true on Android. `log_sink` is `Callable(level, code, key, message)`,
## `vibrate` is `Callable(duration_ms: int, amplitude: float)`, `config` a validated `HapticsConfig`.
func _init(
	focus_implies_suspend: bool,
	clock_us: Callable,
	log_sink: Callable,
	vibrate: Callable,
	display_source: Callable,
	config: HapticsConfig
) -> void:
	_fis = focus_implies_suspend
	_clock_us = clock_us
	_limiter = RateLimitedLog.new(log_sink, clock_us)
	_vibrate = vibrate
	_display_source = display_source
	_config = config
	_read_display()


## Window focus lost.
func on_focus_out() -> void:
	if not _focused:
		_noop(EVENT_FOCUS_OUT)
		return
	_apply(false, _paused)


## Window focus regained.
func on_focus_in() -> void:
	if _focused:
		_noop(EVENT_FOCUS_IN)
		return
	_apply(true, _paused)


## OS pause. A no-op when focus implies suspend (Android).
func on_paused() -> void:
	if _fis or _paused:
		_noop(EVENT_PAUSED)
		return
	_apply(_focused, true)


## OS resume. A no-op when focus implies suspend (Android).
func on_resumed() -> void:
	if _fis or not _paused:
		_noop(EVENT_RESUMED)
		return
	_apply(_focused, false)


## Back request (the node forwards `NOTIFICATION_WM_GO_BACK_REQUEST`). Emits `back_pressed` in every lifecycle state.
func on_back_requested() -> void:
	back_pressed.emit()


## Master haptics switch (fed by Settings). Disabling mid-pulse makes no extra `vibrate` call.
func set_haptics_enabled(enabled: bool) -> void:
	_haptics_enabled = enabled


## Global amplitude scalar, clamped to 0-1; a non-finite value is ignored.
func set_haptics_intensity(intensity: float) -> void:
	if is_finite(intensity):
		_haptics_intensity = clampf(intensity, HapticsConfig.INTENSITY_RANGE.x, HapticsConfig.INTENSITY_RANGE.y)


## Plays the pulse of `kind` if the gate allows it; returns true when `vibrate` was called.
## Drop causes are evaluated in `DropCause` order; the first match is counted and drops the call.
func haptic(kind: int) -> bool:
	if not _config.has_kind(kind):
		_drop(DropCause.UNKNOWN_KIND)
		_limiter.emit(
			LogLevel.ERROR, RateLimitedLog.UNKNOWN_HAPTIC_KIND, str(kind), "haptic kind %d is not configured" % kind
		)
		return false
	if not _haptics_enabled:
		_drop(DropCause.DISABLED)
		return false
	if not _is_attentive():
		_drop(DropCause.NOT_ATTENTIVE)
		return false
	var eff: Vector2 = PlatformMath.effective(_config.duration_ms(kind), _config.amplitude(kind), _config.max_ms())
	var dur_eff: int = roundi(eff.x)
	if dur_eff <= 0:
		_drop(DropCause.ZERO_DURATION)
		return false
	var now: int = _clock_us.call()
	var prio: int = _config.priority(kind)
	if not PlatformMath.haptic_gate(true, true, dur_eff, prio, now, last_played_us, last_end_us, last_prio, _config.min_interval_us()):
		_drop(DropCause.THROTTLED)
		return false
	var amp_eff: float = eff.y if eff.y < 0.0 else eff.y * _haptics_intensity
	last_played_us = now
	last_end_us = now + dur_eff * 1000
	last_prio = prio
	_vibrate.call(dur_eff, amp_eff)
	return true


## Number of calls dropped for `cause` (a `DropCause`).
func haptic_drops(cause: int) -> int:
	if cause < 0 or cause >= _drops.size():
		return 0
	return _drops[cause]


func _drop(cause: int) -> void:
	_drops[cause] += 1


func _is_attentive() -> bool:
	return _focused and not _paused


func _is_suspended() -> bool:
	return _paused or (_fis and not _focused)


func _noop(event_name: String) -> void:
	_limiter.emit(LogLevel.DEBUG, RateLimitedLog.LIFECYCLE_NOOP, event_name, "%s ignored: no state change" % event_name)


## Applies the new flags, then emits the edges in order INT, BG, FG, RET.
func _apply(focused: bool, paused: bool) -> void:
	var a0: bool = _is_attentive()
	var s0: bool = _is_suspended()
	_focused = focused
	_paused = paused
	var a1: bool = _is_attentive()
	var s1: bool = _is_suspended()
	if (s0 and not s1) or (not a0 and a1):
		_read_display()
	if a0 and not a1:
		app_interrupted.emit()
	if not s0 and s1:
		app_backgrounded.emit()
	if s0 and not s1:
		app_foregrounded.emit()
	if not a0 and a1:
		app_returned.emit()


## Reads `display_source` (Dictionary with `safe_area`, `screen_size`, `viewport_size`, `refresh_rate`, `screen_dpi`).
## Missing keys keep their previous value. An empty safe area becomes the full screen rectangle.
func _read_display() -> void:
	if not _display_source.is_valid():
		return
	var facts: Dictionary = _display_source.call()
	if facts.has("screen_size"):
		_screen_size = facts["screen_size"]
	if facts.has("viewport_size"):
		_viewport_size = facts["viewport_size"]
	if facts.has("refresh_rate"):
		_refresh_rate = facts["refresh_rate"]
	if facts.has("screen_dpi"):
		_screen_dpi = facts["screen_dpi"]
	if facts.has("safe_area"):
		var area: Rect2i = facts["safe_area"]
		_safe_area = area if area.has_area() else Rect2i(Vector2i.ZERO, _screen_size)
