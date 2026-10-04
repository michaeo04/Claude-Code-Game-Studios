## The thin map loader driver (ADR-0004). The only file that may name `ResourceLoader`: it builds the real
## `load_definition` seam and delegates every other seam (the four Phase B applies, `tube_load`, `send_map_ready`,
## camera geometry, base tube config, log sink) to an injected `MapLoaderSeams`, then runs `MapLoaderCore`.
##
## Loading is synchronous. MS-1 pre-commitment: if the boot-time spike shows it is too slow, only the
## `load_definition` seam of `_ReadSeams` switches to the threaded API; nothing else changes.
class_name MapLoader
extends RefCounted

## Forwarded from the core: emitted once per failed attempt with the whole code set.
signal map_load_failed(codes: PackedStringArray)

## The core, public for state reads (`status`, `last_codes`).
var core: MapLoaderCore

var _config: MapLoaderConfig


## `delegate` supplies every seam except the file read. `config.map_path` is the boot path.
func _init(config: MapLoaderConfig, delegate: MapLoaderSeams) -> void:
	_config = config
	core = MapLoaderCore.new(_ReadSeams.new(delegate), config)
	core.map_load_failed.connect(_on_core_failed)


## Called by `GameRoot` after `_wire()`: runs the first attempt on the boot map path.
func start() -> bool:
	return attempt(_config.map_path)


## Runs the whole sequence for `path`. Returns true when the map is ready.
func attempt(path: String) -> bool:
	return core.attempt(path)


## Re-runs the sequence with the last path and a fresh read. Menus' Retry is bound to this method.
func retry() -> bool:
	return core.retry()


func _on_core_failed(codes: PackedStringArray) -> void:
	map_load_failed.emit(codes)


## The real file read plus forwarding of every other seam.
class _ReadSeams extends MapLoaderSeams:
	var _delegate: MapLoaderSeams

	func _init(delegate: MapLoaderSeams) -> void:
		_delegate = delegate

	## Returns null for a missing or unreadable path; any non-`MapDefinition` load is handed over as-is so the core
	## reports `MAP_RESOURCE_TYPE`. `CACHE_MODE_IGNORE_DEEP` makes a Retry read the file and its sub-resources again.
	func load_definition(path: String) -> Variant:
		if not ResourceLoader.exists(path):
			return null
		return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)

	func camera_geometry() -> Dictionary:
		return _delegate.camera_geometry()

	func apply_env(map: MapConfig) -> bool:
		return _delegate.apply_env(map)

	func apply_obstacle(map: MapConfig) -> bool:
		return _delegate.apply_obstacle(map)

	func apply_pattern(map: MapConfig) -> bool:
		return _delegate.apply_pattern(map)

	func apply_hazard_view(map: MapConfig) -> bool:
		return _delegate.apply_hazard_view(map)

	func tube_load(cfg: TubeConfig) -> bool:
		return _delegate.tube_load(cfg)

	func send_map_ready() -> void:
		_delegate.send_map_ready()

	func base_tube_config() -> TubeConfig:
		return _delegate.base_tube_config()

	func log_sink(level: int, code: StringName, key: String, message: String) -> void:
		_delegate.log_sink(level, code, key, message)
