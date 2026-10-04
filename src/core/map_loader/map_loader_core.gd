## The loader core (ADR-0004 Decisions 2 and 3): validate first (Phase A), apply second (Phase B), report failure
## once per attempt. A RefCounted with NO engine calls: the file read, every apply step and the log are injected
## through `MapLoaderSeams`.
##
## Failure code set (stable strings, exact `==`): `MAP_RESOURCE_MISSING`, `MAP_RESOURCE_TYPE`, `MAP_ENV_INVALID`,
## `HAZARD_STYLE_INVALID`, `MAP_LIBRARY_MISSING`, `MAP_CAMERA_INVALID`, the Tube Track codes of
## `TubeConfig.validate` unchanged, `MAP_APPLY_FAILED`, `TUBE_LOAD_REJECTED`.
## `MAP_APPLY_FAILED` stays one stable string in `last_codes`; the failing system's name (`env`, `obstacle`,
## `pattern`, `hazard_view`) is the `key` argument of the log line for that code.
class_name MapLoaderCore
extends RefCounted

enum Status { NOT_LOADED, READY, FAILED }

const MAP_RESOURCE_MISSING: StringName = &"MAP_RESOURCE_MISSING"
const MAP_RESOURCE_TYPE: StringName = &"MAP_RESOURCE_TYPE"
const MAP_ENV_INVALID: StringName = &"MAP_ENV_INVALID"
const HAZARD_STYLE_INVALID: StringName = &"HAZARD_STYLE_INVALID"
const MAP_LIBRARY_MISSING: StringName = &"MAP_LIBRARY_MISSING"
const MAP_CAMERA_INVALID: StringName = &"MAP_CAMERA_INVALID"
const MAP_APPLY_FAILED: StringName = &"MAP_APPLY_FAILED"
const TUBE_LOAD_REJECTED: StringName = &"TUBE_LOAD_REJECTED"
## INFO line of a `retry()` in `READY`.
const RETRY_IGNORED_READY: StringName = &"RETRY_IGNORED_READY"
## WARNING line of an `attempt()` / `retry()` made while one is running.
const REENTRANT_CALL_REJECTED: StringName = &"REENTRANT_CALL_REJECTED"

## Emitted once per failed attempt with the whole code set (codes only, no prose).
signal map_load_failed(codes: PackedStringArray)

var status: Status = Status.NOT_LOADED
var last_codes: PackedStringArray = PackedStringArray()

var _seams: MapLoaderSeams
var _config: MapLoaderConfig
var _path: String = ""
var _attempting: bool = false


func _init(seams: MapLoaderSeams, config: MapLoaderConfig) -> void:
	_seams = seams
	_config = config


## Runs the whole sequence for `path` (remembered for `retry()`). Returns true when the map is `READY`.
## Rejected (false, nothing run) while another attempt is running.
func attempt(path: String) -> bool:
	if _attempting:
		_seams.log_sink(LogLevel.WARNING, REENTRANT_CALL_REJECTED, "attempt", "attempt while attempting")
		return false
	_attempting = true
	_path = path
	var ok: bool = _run()
	_attempting = false
	return ok


## Re-runs everything, including a fresh `load_definition`, with the last path. Valid in `FAILED`; in
## `NOT_LOADED` it acts as the first attempt; in `READY` it logs one INFO line and does nothing. No cap, no debounce.
func retry() -> bool:
	if _attempting:
		_seams.log_sink(LogLevel.WARNING, REENTRANT_CALL_REJECTED, "retry", "retry while attempting")
		return false
	if status == Status.READY:
		_seams.log_sink(LogLevel.INFO, RETRY_IGNORED_READY, "retry", "map already ready")
		return false
	return attempt(_path)


func _run() -> bool:
	var a: Dictionary = _phase_a(_path)
	if not (a["ok"] as bool):
		_fail(a["codes"] as Array[StringName], "")
		return false
	var map: MapConfig = a["map"] as MapConfig
	var tube_cfg: TubeConfig = a["tube_cfg"] as TubeConfig
	var steps: Array[Array] = [
		["env", _seams.apply_env.bind(map)],
		["obstacle", _seams.apply_obstacle.bind(map)],
		["pattern", _seams.apply_pattern.bind(map)],
		["hazard_view", _seams.apply_hazard_view.bind(map)],
	]
	for step: Array in steps:
		if not ((step[1] as Callable).call() as bool):
			_fail([MAP_APPLY_FAILED] as Array[StringName], step[0] as String)
			return false
	if not _seams.tube_load(tube_cfg):
		_fail([TUBE_LOAD_REJECTED] as Array[StringName], "tube_load")
		return false
	status = Status.READY
	last_codes = PackedStringArray()
	_seams.send_map_ready()
	return true


## Phase A (ADR-0004 A1..A6): pure, no Phase B seam is called. Returns `ok`, `codes` (Array[StringName]), `map`,
## `tube_cfg`. Skip rule: A2, A3b and A4 are independent and all run once A1 gave a `MapDefinition`; A5 (camera,
## `MapConfig.build`, `TubeConfig.from_map`) needs the results of A2 to A4 and runs only if they all passed; A6 needs A5.
## Code order is fixed: A1, A2, A3b, A4, A5 (camera), A6.
func _phase_a(path: String) -> Dictionary:
	var codes: Array[StringName] = []
	var out: Dictionary = {"ok": false, "codes": codes, "map": null, "tube_cfg": null}
	var raw: Variant = _seams.load_definition(path)
	if raw == null:
		codes.append(MAP_RESOURCE_MISSING)
		return out
	if not (raw is MapDefinition):
		codes.append(MAP_RESOURCE_TYPE)
		return out
	var def: MapDefinition = raw as MapDefinition
	var sink: Callable = Callable(_seams, "log_sink")
	var env: EnvConfig = null
	if def.env != null:
		env = def.env.validated(sink)
	if env == null:
		codes.append(MAP_ENV_INVALID)
	var style: HazardStyle = null
	if def.hazard_style is HazardStyle:
		style = (def.hazard_style as HazardStyle).validated(sink)
	if style == null:
		codes.append(HAZARD_STYLE_INVALID)
	if def.chunk_library == null:
		codes.append(MAP_LIBRARY_MISSING)
	if not codes.is_empty():
		return out
	var map: MapConfig = MapConfig.build(def.map_id, env, def.chunk_library, style, _seams.camera_geometry(), codes)
	if map == null:
		return out
	var tube_cfg: TubeConfig = TubeConfig.from_map(_seams.base_tube_config(), map)
	for record: Dictionary in tube_cfg.validate(_config.v_max, _config.ball_diameter):
		codes.append(StringName(record.get("code", &"")))
	if not codes.is_empty():
		return out
	out["ok"] = true
	out["map"] = map
	out["tube_cfg"] = tube_cfg
	return out


## Writes the failure state, logs each code, then emits once (state first, so a subscriber sees final values).
func _fail(codes: Array[StringName], detail: String) -> void:
	status = Status.FAILED
	var packed: PackedStringArray = PackedStringArray()
	for code: StringName in codes:
		packed.append(String(code))
		_seams.log_sink(LogLevel.ERROR, code, detail, "map load failed: %s" % [code])
	last_codes = packed
	map_load_failed.emit(packed)
