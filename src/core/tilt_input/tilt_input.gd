## Thin Tilt Input node (ADR-0005, design/gdd/tilt-input.md rule 12): the only file that reads the motion sensor.
##
## Holds a `TiltCore`, hands it the raw gravity vector once per `poll()` and exposes read-only `steer`, `valid` and
## `input_source`. No filtering, no `_process`: `GameRoot` calls `poll()` once per rendered frame (ADR-0002).
## Time comes from the injected `clock_us`; the log sink is wrapped in a `RateLimitedLog` (one message per code
## per 1.0 s of that clock). The synthetic arrow-key source exists only when `setup()` is told it runs in the editor.
class_name TiltInput
extends Node

## ProjectSettings key of the gravity sensor flag (ADR-0005 Decision 2).
const SETTING_GRAVITY: String = "input_devices/sensors/enable_gravity"
## ProjectSettings key of the screen orientation (1 is portrait).
const SETTING_ORIENTATION: String = "display/window/handheld/orientation"
## Orientation value that means portrait.
const ORIENTATION_PORTRAIT: int = 1
## Roll (degrees) of the editor-only synthetic gravity while an arrow key is held (a development aid, not gameplay).
const EDITOR_ROLL_DEG: float = 20.0
## Input actions read by the editor-only source.
const ACTION_LEFT: StringName = &"steer_left"
const ACTION_RIGHT: StringName = &"steer_right"

## Published steer in `[-1, 1]` (the core's value).
var steer: float:
	get:
		return _core.get_steer() if _core != null else 0.0
## True while the core is Live.
var valid: bool:
	get:
		return _core != null and _core.get_valid()
## Control source (`TiltCore.InputSource`).
var input_source: TiltCore.InputSource:
	get:
		return _core.get_input_source() if _core != null else TiltCore.InputSource.SENSOR

var _core: TiltCore
var _rate_limited: RateLimitedLog
var _sample_source: Callable
var _config: TiltConfig


## Builds the core. `config` should already be validated. `clock_us` returns microseconds. `log_sink` is the
## 4-argument sink; it is wrapped in a rate limiter. `is_debug` is supplied by the composition root (never read
## here). `is_editor` is `OS.has_feature("editor")`; only then is the synthetic arrow-key source attached.
## `sample_source` replaces the gravity read (tests); an invalid Callable keeps `Input.get_gravity()`.
## The sensors-enabled flag and the portrait check come from `ProjectSettings` (a missing flag reads false).
func setup(config: TiltConfig, clock_us: Callable, log_sink: Callable, sensitivity: float = 1.0, is_debug: bool = false,
		is_editor: bool = OS.has_feature("editor"), sample_source: Callable = Callable()) -> void:
	_config = config
	_rate_limited = RateLimitedLog.new(log_sink, clock_us)
	_sample_source = sample_source if sample_source.is_valid() else _read_gravity
	if is_editor:
		_sample_source = _editor_gravity
	var sensors_enabled: bool = bool(ProjectSettings.get_setting(SETTING_GRAVITY, false))
	var is_portrait: bool = int(ProjectSettings.get_setting(SETTING_ORIENTATION, 0)) == ORIENTATION_PORTRAIT
	_core = TiltCore.new(config, _sample_source, clock_us, _rate_limited.emit, _no_fallback, sensitivity, is_portrait,
			sensors_enabled, is_debug)


## Reads the sensor once and advances the core (once per rendered frame, GDD rule 6).
func poll() -> void:
	if _core != null:
		_core.poll()


## The core, for the composition root's `TiltRunAdapter` and lifecycle wiring.
func get_core() -> TiltCore:
	return _core


## Gravity vector for a held direction (`-1`, `0` or `+1`) so that F1 gives a roll of `direction * roll_deg`.
## Pure helper of the editor-only source. Example: `synthetic_gravity(0, 20.0, 1)` is `(0, -9.81, 0)`.
static func synthetic_gravity(direction: int, roll_deg: float, sensor_sign: int) -> Vector3:
	var angle: float = deg_to_rad(float(clampi(direction, -1, 1)) * roll_deg * float(sensor_sign))
	return Vector3(9.81 * sin(angle), -9.81 * cos(angle), 0.0)


func _read_gravity() -> Vector3:
	return Input.get_gravity()


func _no_fallback() -> int:
	return 0


## Editor-only: the left and right arrow keys (`steer_left` / `steer_right`) as a fixed-roll gravity vector.
func _editor_gravity() -> Vector3:
	var direction: int = 0
	if InputMap.has_action(ACTION_LEFT) and Input.is_action_pressed(ACTION_LEFT):
		direction -= 1
	if InputMap.has_action(ACTION_RIGHT) and Input.is_action_pressed(ACTION_RIGHT):
		direction += 1
	return synthetic_gravity(direction, EDITOR_ROLL_DEG, _config.sensor_sign)
