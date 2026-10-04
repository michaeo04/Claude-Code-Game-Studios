## Recording fake of `MapLoaderSeams` for the loader tests. Framework-free: no GUT call.
extends MapLoaderSeams

## Call log: seam names in call order (`load`, `camera`, `env`, `obstacle`, `pattern`, `hazard_view`, `tube_load`,
## `map_ready`).
var calls: Array[String] = []
## Definitions returned by successive reads (the last one repeats).
var definitions: Array = []
var reads: int = 0
var camera: Dictionary = {"rear_extent": 4.0, "camera_distance": 6.0, "visible_arc_half_width": 1.0, "L": 12.0}
## Seam name -> true to make that step fail.
var fail: Dictionary = {}
var last_map: MapConfig
var last_tube_cfg: TubeConfig
## Optional hook run inside the `env` step.
var on_env: Callable = Callable()
var log_lines: Array[Array] = []


func load_definition(_path: String) -> Variant:
	calls.append("load")
	reads += 1
	if definitions.is_empty():
		return null
	return definitions[mini(reads, definitions.size()) - 1]


func camera_geometry() -> Dictionary:
	calls.append("camera")
	return camera


func apply_env(map: MapConfig) -> bool:
	calls.append("env")
	last_map = map
	if on_env.is_valid():
		on_env.call()
	return not fail.has("env")


func apply_obstacle(_map: MapConfig) -> bool:
	calls.append("obstacle")
	return not fail.has("obstacle")


func apply_pattern(_map: MapConfig) -> bool:
	calls.append("pattern")
	return not fail.has("pattern")


func apply_hazard_view(_map: MapConfig) -> bool:
	calls.append("hazard_view")
	return not fail.has("hazard_view")


func tube_load(cfg: TubeConfig) -> bool:
	calls.append("tube_load")
	last_tube_cfg = cfg
	return not fail.has("tube_load")


func send_map_ready() -> void:
	calls.append("map_ready")


func log_sink(level: int, code: StringName, key: String, message: String) -> void:
	log_lines.append([level, code, key, message])


## Number of `name` entries in `calls`.
func count(name: String) -> int:
	return calls.count(name)


## Calls other than the Phase A reads (`load`, `camera`).
func seam_calls() -> Array[String]:
	var out: Array[String] = []
	for name: String in calls:
		if name != "load" and name != "camera":
			out.append(name)
	return out


## A valid definition (fresh each call).
static func valid_definition() -> MapDefinition:
	var def: MapDefinition = MapDefinition.new()
	def.map_id = &"test"
	def.env = EnvConfig.new()
	def.hazard_style = HazardStyle.new()
	def.chunk_library = Resource.new()
	return def
