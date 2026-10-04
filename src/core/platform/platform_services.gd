## The thin Platform Services node (ADR-0006 Decisions 1, 3, 4, 7): the only owner of OS calls.
##
## Maps `NOTIFICATION_*` to `PlatformCore` calls through `_marshal` (synchronous on the main thread,
## `call_deferred` on any other thread), applies the boot settings and exposes `quit()`. Not an autoload: the
## composition root creates it first. Tests inject every seam with `configure` before the node enters the tree.
class_name PlatformServices
extends Node

## Re-emitted from the core (late consumers read `core.attentive` / `core.suspended`).
signal app_interrupted
signal app_backgrounded
signal app_foregrounded
signal app_returned
signal back_pressed

## The logic core; built from the real engine seams in `_ready` when `configure` was not called.
var core: PlatformCore = null

var _keep_on: Callable = Callable()
var _read_setting: Callable = Callable()
var _caller_id: Callable = Callable()
var _main_id: Callable = Callable()
var _log_sink: Callable = Callable()
var _configured: bool = false
var _boot_mismatches: Array[String] = []


## Injects the seams (tests): the core, `keep_on(enabled: bool)`, `read_setting(key, default) -> Variant`, the
## calling and main thread id providers and the log sink. Call before adding the node to the tree.
func configure(
	p_core: PlatformCore,
	keep_on: Callable,
	read_setting: Callable,
	caller_id: Callable,
	main_id: Callable,
	log_sink: Callable
) -> void:
	core = p_core
	_keep_on = keep_on
	_read_setting = read_setting
	_caller_id = caller_id
	_main_id = main_id
	_log_sink = log_sink
	_configured = true


func _ready() -> void:
	if not _configured:
		_configure_real()
	core.app_interrupted.connect(_on_core_interrupted)
	core.app_backgrounded.connect(_on_core_backgrounded)
	core.app_foregrounded.connect(_on_core_foregrounded)
	core.app_returned.connect(_on_core_returned)
	core.back_pressed.connect(_on_core_back_pressed)
	_boot()


func _notification(what: int) -> void:
	if core == null:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_marshal(core.on_focus_out)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_marshal(core.on_focus_in)
		NOTIFICATION_APPLICATION_PAUSED:
			_marshal(core.on_paused)
		NOTIFICATION_APPLICATION_RESUMED:
			_marshal(core.on_resumed)
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_marshal(core.on_back_requested)


## Keys of the runtime manifest that differed at boot (empty when all matched).
func boot_mismatches() -> Array[String]:
	return _boot_mismatches


## Plays the haptic `kind` (see `PlatformCore.haptic`).
func haptic(kind: int) -> bool:
	return core.haptic(kind)


## Master haptics switch.
func set_haptics_enabled(enabled: bool) -> void:
	core.set_haptics_enabled(enabled)


## Haptics amplitude scalar.
func set_haptics_intensity(intensity: float) -> void:
	core.set_haptics_intensity(intensity)


## Quits the app; called only when Menus asks.
func quit() -> void:
	get_tree().quit()


func _configure_real() -> void:
	var sink: Callable = _real_log
	var cfg: HapticsConfig = HapticsConfig.new().validated(sink)
	core = PlatformCore.new(
		PlatformMath.fis_for_platform(OS.get_name()), _real_clock_us, sink, _real_vibrate, _real_display, cfg
	)
	_keep_on = _real_keep_on
	_read_setting = _real_read_setting
	_caller_id = _real_caller_id
	_main_id = _real_main_id
	_log_sink = sink
	_configured = true


## Boot: the back button is ours, the screen stays on, the manifest is checked (log only).
func _boot() -> void:
	get_tree().quit_on_go_back = false
	_keep_on.call(true)
	var limiter: RateLimitedLog = RateLimitedLog.new(_log_sink, _real_clock_us)
	_boot_mismatches = PlatformSettings.report(PlatformSettings.manifest(), _read_setting, limiter)


## The thread rule: synchronous on the main thread, deferred from any other thread.
func _marshal(fn: Callable) -> void:
	if int(_caller_id.call()) == int(_main_id.call()):
		fn.call()
	else:
		fn.call_deferred()


func _real_log(level: int, code: StringName, key: String, message: String) -> void:
	if level >= LogLevel.WARNING:
		push_warning("%s [%s] %s" % [code, key, message])


func _real_clock_us() -> int:
	return Time.get_ticks_usec()


func _real_vibrate(duration_ms: int, amplitude: float) -> void:
	Input.vibrate_handheld(duration_ms, amplitude)


func _real_display() -> Dictionary:
	return {
		"safe_area": Rect2i(DisplayServer.get_display_safe_area()),
		"screen_size": DisplayServer.screen_get_size(),
		"viewport_size": Vector2i(get_viewport().get_visible_rect().size),
		"refresh_rate": DisplayServer.screen_get_refresh_rate(),
		"screen_dpi": DisplayServer.screen_get_dpi(),
	}


func _real_keep_on(enabled: bool) -> void:
	DisplayServer.screen_set_keep_on(enabled)


func _real_read_setting(key: String, default: Variant) -> Variant:
	return ProjectSettings.get_setting(key, default)


func _real_caller_id() -> int:
	return OS.get_thread_caller_id()


func _real_main_id() -> int:
	return OS.get_main_thread_id()


func _on_core_interrupted() -> void:
	app_interrupted.emit()


func _on_core_backgrounded() -> void:
	app_backgrounded.emit()


func _on_core_foregrounded() -> void:
	app_foregrounded.emit()


func _on_core_returned() -> void:
	app_returned.emit()


func _on_core_back_pressed() -> void:
	back_pressed.emit()
