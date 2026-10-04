## The thin node driver of Save & Persistence (ADR-0007). It owns no rules: it runs the core's boot load once at
## construction (before the node can be observed in a scene tree) and calls `flush()` once per `app_backgrounded`.
##
## `GameRoot` builds it second, right after Platform Services. It is never an autoload and has no interface to
## Run State. `app_foregrounded`, `app_interrupted` and `app_returned` are deliberately not connected.
class_name SaveService
extends Node

var _core: SaveCore


## `source` is the Platform-Services-shaped signal source (anything with an `app_backgrounded` signal).
## Runs `core.boot_load()` synchronously, exactly once, then connects `app_backgrounded`.
## Example: `SaveService.new(core, platform_services)`.
func _init(core: SaveCore, source: Object) -> void:
	_core = core
	_core.boot_load()
	if source != null and source.has_signal(&"app_backgrounded"):
		source.connect(&"app_backgrounded", _on_app_backgrounded)


## The core this node drives (read-only for dependents).
func get_core() -> SaveCore:
	return _core


## Converts the platform's `clock_us` (integer microseconds) to the float seconds the core's clock uses.
## Example: `SaveService.us_to_seconds(1_500_000)` is `1.5`.
static func us_to_seconds(clock_us: int) -> float:
	return float(clock_us) / 1_000_000.0


func _on_app_backgrounded() -> void:
	_core.flush()
