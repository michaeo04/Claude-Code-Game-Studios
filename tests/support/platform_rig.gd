## Test rig for PlatformCore: stub clock, recording sink, recording vibrate, signal recorder.
##
## Framework-free: no GUT call.
extends RefCounted

const ClockStub = preload("res://tests/support/clock_stub.gd")
const LogSink = preload("res://tests/support/platform_log_sink.gd")

var clock: ClockStub = ClockStub.new(0)
var sink: LogSink = LogSink.new()
var core: PlatformCore
## `[duration_ms, amplitude]` per `vibrate` call.
var vibrations: Array[Array] = []
## Signal names recorded since the last `take()`.
var signals: Array[String] = []


func _init(fis: bool, config: HapticsConfig = null) -> void:
	var cfg: HapticsConfig = config if config != null else haptics_config()
	core = PlatformCore.new(fis, clock.as_callable(), sink.sink, vibrate, display, cfg)
	core.app_interrupted.connect(_on_interrupted)
	core.app_backgrounded.connect(_on_backgrounded)
	core.app_foregrounded.connect(_on_foregrounded)
	core.app_returned.connect(_on_returned)


## Fixture haptics: 0.05 s (not the shipped 0.08), NEAR_MISS 30/0.5/1, HIT 80/1.0/2, UI_TAP 15/0.3/0.
static func haptics_config() -> HapticsConfig:
	var c: HapticsConfig = HapticsConfig.new()
	c.haptic_min_interval = 0.05
	c.haptic_max_ms = 200.0
	c.near_miss_duration_ms = 30.0
	c.near_miss_amplitude = 0.5
	c.near_miss_priority = 1
	c.hit_duration_ms = 80.0
	c.hit_amplitude = 1.0
	c.hit_priority = 2
	c.ui_tap_duration_ms = 15.0
	c.ui_tap_amplitude = 0.3
	c.ui_tap_priority = 0
	return c


func vibrate(duration_ms: int, amplitude: float) -> void:
	vibrations.append([duration_ms, amplitude])


func display() -> Dictionary:
	return {}


## Recorded signals since the last call as `"INT,BG"`, or `"-"` when none; clears the record.
func take() -> String:
	var text: String = "-" if signals.is_empty() else ",".join(signals)
	signals.clear()
	return text


func _on_interrupted() -> void:
	signals.append("INT")


func _on_backgrounded() -> void:
	signals.append("BG")


func _on_foregrounded() -> void:
	signals.append("FG")


func _on_returned() -> void:
	signals.append("RET")
