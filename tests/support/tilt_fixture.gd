## Shared Tilt Input test fixture: a `TiltCore` wired to a clock stub, a log recorder and a settable pose.
##
## Framework-free: no GUT call. Fixtures use sensor sign +1 unless a config is given. A pose is the roll in
## degrees; the gravity vector is `(9.81 sin(pose), -9.81 cos(pose), 0)`.
extends RefCounted

const ClockStub = preload("res://tests/support/clock_stub.gd")
const TiltSink = preload("res://tests/support/tilt_log_sink.gd")
const TiltCoreClass = preload("res://src/core/tilt_input/tilt_core.gd")

## Default poll step in microseconds (60 Hz).
const STEP_US: int = 16667

var clock: ClockStub = ClockStub.new(0)
var sink: TiltSink = TiltSink.new()
var core: TiltCore
var gravity: Vector3 = Vector3(0.0, -9.81, 0.0)
var fallback_value: int = 0
var step_us: int = STEP_US
## Every `availability_changed` value in emission order.
var availability: Array[bool] = []
var _polled: bool = false


func _init(config: TiltConfig = null, sensitivity: float = 1.0, is_portrait: bool = true, sensors_enabled: bool = true,
		is_debug: bool = true) -> void:
	var cfg: TiltConfig = config
	if cfg == null:
		cfg = TiltConfig.new()
		cfg.sensor_sign = 1
	core = TiltCoreClass.new(cfg, _source, clock.as_callable(), sink.sink, _fallback, sensitivity, is_portrait,
			sensors_enabled, is_debug)
	core.availability_changed.connect(_on_availability)


func _on_availability(available: bool) -> void:
	availability.append(available)


func _source() -> Vector3:
	return gravity


func _fallback() -> int:
	return fallback_value


## Sets the gravity vector for a roll of `pose_deg` degrees.
func set_pose(pose_deg: float) -> void:
	var r: float = deg_to_rad(pose_deg)
	gravity = Vector3(9.81 * sin(r), -9.81 * cos(r), 0.0)


## `count` polls at `pose_deg`; the first poll of the fixture is stamped at the current clock, every later
## one `step_us` after the previous.
func tick(pose_deg: float, count: int = 1) -> void:
	set_pose(pose_deg)
	for i: int in count:
		if _polled:
			clock.advance_us(step_us)
		core.poll()
		_polled = true


## `count` polls with an invalid sample (zero vector), stamped like `tick`.
func tick_invalid(count: int = 1) -> void:
	gravity = Vector3.ZERO
	for i: int in count:
		if _polled:
			clock.advance_us(step_us)
		core.poll()
		_polled = true


## A core that is Live with `phi0 = pose`, `phi_f = 0`: 60 polls at `pose` from stamp 0, then `run_reset`
## from Menu at the last stamp. The log is cleared afterwards, so the first (pending) capture of the fresh
## core does not count against the single capture under test.
func live_core(pose_deg: float) -> TiltCore:
	tick(pose_deg, 60)
	sink.entries.clear()
	core.on_run_reset(TiltCore.PreviousPhase.MENU)
	return core


## Number of recorded log lines with `code`.
func count_code(code: StringName) -> int:
	var n: int = 0
	for entry: Array in sink.entries:
		if entry[1] == code:
			n += 1
	return n
