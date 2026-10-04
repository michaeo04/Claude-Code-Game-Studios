## The injected seams of the map loader (ADR-0004). A plain base class, not `@abstract`: every default is a
## failure or neutral value, so a core built on the bare base fails safely. Fakes and the real driver extend it.
class_name MapLoaderSeams
extends RefCounted


## Loads the `MapDefinition` at `_path`; the default returns `null` (missing).
func load_definition(_path: String) -> Variant:
	return null


## Camera geometry: `rear_extent`, `camera_distance`, `visible_arc_half_width`, `L`. Default: empty (invalid).
func camera_geometry() -> Dictionary:
	return {}


func apply_env(_map: MapConfig) -> bool:
	return false


func apply_obstacle(_map: MapConfig) -> bool:
	return false


func apply_pattern(_map: MapConfig) -> bool:
	return false


func apply_hazard_view(_map: MapConfig) -> bool:
	return false


func tube_load(_cfg: TubeConfig) -> bool:
	return false


func send_map_ready() -> void:
	pass


## The base `TubeConfig`; the default is a fresh default config.
func base_tube_config() -> TubeConfig:
	return TubeConfig.new()


## Log sink `(level, code, key, message)` (see `LogLevel`); the default discards.
func log_sink(_level: int, _code: StringName, _key: String, _message: String) -> void:
	pass
