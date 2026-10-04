## Composition Root and the only game-logic `_process` (ADR-0002).
##
## Ignores the engine delta, reads the injected `clock_us`, and hands `(real_dt, world_dt)` to the
## single `_tick()` that writes the per-frame order. Ticks in every phase; never pauses the tree
## and never touches the engine time scale. Builds the cores in one fixed order (`_construct`), connects the
## Run State subscribers from one sorted table (`_wire`) and then starts the map load.
class_name GameRoot
extends Node

## Systems that `_tick()` calls, by key (all required). Values are duck-typed so tests inject spies.
const SYSTEM_KEYS: Array[StringName] = [
	&"tilt_input", &"tilt_adapter", &"run_state", &"ball", &"tube_track", &"world_frame", &"tube_view",
	&"hazard_view", &"obstacle", &"near_miss", &"scoring", &"camera", &"ball_view", &"environment",
	&"juice", &"hud", &"menus",
]

## Construction steps in the ADR-0002 Decision 5 order. `preflight` is run by `GameRoot` itself (it validates the
## immutable `WorldGeometry` together with the `WorldFrameConfig` and builds the `WorldFrame`); every other step is
## built by a Callable of the factory dictionary under the same key and must return an `Object`
## (`core_systems` returns a `Dictionary` of the systems listed in `CORE_SYSTEM_KEYS`).
const CONSTRUCTION_ORDER: Array[StringName] = [
	&"platform", &"save", &"settings", &"run_state", &"scoring", &"preflight", &"core_systems",
	&"environment_view", &"world_chroma", &"ball_view", &"hazard_view", &"environment", &"juice", &"hud", &"menus",
]
## Views: none of them may be built before `preflight` has finished.
const VIEW_STEPS: Array[StringName] = [
	&"environment_view", &"world_chroma", &"ball_view", &"hazard_view", &"environment", &"juice", &"hud", &"menus",
]

## Subscriber ranks (ADR-0002 Decision 7); lower runs first, ties go by row index.
const RANK_PATTERN_FRAME: int = 1
const RANK_TUBE_OBSTACLE: int = 2
const RANK_BALL: int = 3
const RANK_CAMERA: int = 4
const RANK_REST: int = 5
const RANK_JUICE: int = 1
const RANK_SCORING: int = 2
const RANK_HUD: int = 3
const RANK_ENDED_REST: int = 4

## Codes of `validate_rows` and `_wire`.
const CODE_ROW_INVALID: String = "WIRE_ROW_INVALID"
const CODE_HANDLER_UNTYPED: String = "WIRE_HANDLER_UNTYPED"
const CODE_JUICE_AFTER_SCORING: String = "WIRE_JUICE_AFTER_SCORING"
const CODE_NO_RUN_STATE: String = "WIRE_NO_RUN_STATE"

## Steps finished so far, in order (`CONSTRUCTION_ORDER` names, then `wire`, `map_loader`, `map_loader.start`).
var construction_trace: Array[StringName] = []
## True once `WorldGeometry` and `WorldFrame` passed `validate` together.
var geometry_validated: bool = false
## `MapLoaderConfig` with `v_max` and `ball_diameter` taken from the real Ball Movement config.
var map_loader_config: MapLoaderConfig
## When true a fatal boot error quits the tree with code 1 (tests switch it off).
var quit_on_fatal: bool = true
## Microsecond clock (ADR-0002 Decision 4). Production: `Time.get_ticks_usec`.
var clock_us: Callable

var _prev_us: int = 0
var _has_prev: bool = false

var _factory: Dictionary = {}
var _cores: Dictionary = {}
var _geometry: WorldGeometry
var _map_loader: Object
var _extra_rows: Array = []
var _rows: Array = []
var _connected: Array = []

var _tilt_input: Object
var _tilt_adapter: Object
var _tube_adapter: Object
var _run_state: Object
var _ball: Object
var _tube_track: Object
var _world_frame: Object
var _tube_view: Object
var _hazard_view: Object
var _obstacle: Object
var _near_miss: Object
var _scoring: Object
var _camera: Object
var _ball_view: Object
var _environment: Object
var _juice: Object
var _hud: Object
var _menus: Object


## `clock` defaults to the production binding. `process_mode` is set here until the root scene
## file (which will carry it) exists.
func _init(clock: Callable = Callable()) -> void:
	clock_us = clock if clock.is_valid() else _engine_clock_us
	process_mode = Node.PROCESS_MODE_ALWAYS


## Hands `_ready` the factory of Callables (see `CONSTRUCTION_ORDER`). It also needs `tube_config`, `ball_config`,
## `world_frame_config`, `slot_count`, an optional `log_sink`, and `map_loader` (a Callable taking the
## `MapLoaderConfig`, returning an object with `start()`). Without a factory `_ready` does nothing; the production
## factory arrives with the system stories.
func configure(factory: Dictionary) -> void:
	_factory = factory


## `_construct()`, `_wire()`, then `_map_loader.start()` in that order; a fatal error stops boot.
func _ready() -> void:
	if _factory.is_empty():
		return
	if _construct() != OK or _wire() != OK or _start_map_loader() != OK:
		if quit_on_fatal and is_inside_tree():
			get_tree().quit(1)


## The engine delta is ignored on purpose: `real_dt` comes from `clock_us`, raw and unclamped.
func _process(_engine_delta: float) -> void:
	var now_us: int = clock_us.call() as int
	# The first tick yields 0 (not a boot-time gap); Run State's stall guard needs raw values afterwards.
	var real_dt: float = 0.0
	if _has_prev:
		real_dt = float(now_us - _prev_us) / 1e6
	_prev_us = now_us
	_has_prev = true
	_tick(real_dt, real_dt)


## Injects the systems listed in `SYSTEM_KEYS` (and the optional `tube_adapter`). Returns false (and injects
## nothing) when a key is missing.
func inject_systems(systems: Dictionary) -> bool:
	for key: StringName in SYSTEM_KEYS:
		if not systems.has(key) or not (systems[key] is Object):
			push_error("GameRoot.inject_systems: missing system %s" % key)
			return false
	_tilt_input = systems[&"tilt_input"] as Object
	_tilt_adapter = systems[&"tilt_adapter"] as Object
	_run_state = systems[&"run_state"] as Object
	_ball = systems[&"ball"] as Object
	_tube_track = systems[&"tube_track"] as Object
	_world_frame = systems[&"world_frame"] as Object
	_tube_view = systems[&"tube_view"] as Object
	_hazard_view = systems[&"hazard_view"] as Object
	_obstacle = systems[&"obstacle"] as Object
	_near_miss = systems[&"near_miss"] as Object
	_scoring = systems[&"scoring"] as Object
	_camera = systems[&"camera"] as Object
	_ball_view = systems[&"ball_view"] as Object
	_environment = systems[&"environment"] as Object
	_juice = systems[&"juice"] as Object
	_hud = systems[&"hud"] as Object
	_menus = systems[&"menus"] as Object
	_tube_adapter = systems.get(&"tube_adapter") as Object
	return true


## Registers a view Node: its own processing is switched off, `GameRoot` drives it.
func register_view(view: Node) -> void:
	view.set_process(false)
	view.set_physics_process(false)


## Appends a `[signal, handler, rank]` row for a system whose epic has not landed yet; `_wire()` includes it.
func add_wire_row(sig: Signal, handler: Callable, rank: int) -> void:
	_extra_rows.append([sig, handler, rank])


## Builds the cores in `CONSTRUCTION_ORDER`, each step finishing before the next, and keeps a strong reference to
## each in `_cores`. Returns `OK`, `ERR_UNCONFIGURED` (missing factory entry) or `ERR_INVALID_DATA` (fatal preflight
## failure, or a step that built nothing); after a preflight failure no view has been built.
func _construct() -> Error:
	construction_trace.clear()
	_cores.clear()
	geometry_validated = false
	var systems: Dictionary = {}
	for step: StringName in CONSTRUCTION_ORDER:
		if step == &"preflight":
			if not _preflight():
				return ERR_INVALID_DATA
			systems[&"world_frame"] = _cores[&"world_frame"]
		else:
			if not _factory.has(step) or not (_factory[step] is Callable):
				push_error("GameRoot._construct: missing factory step %s" % step)
				return ERR_UNCONFIGURED
			var built: Variant = (_factory[step] as Callable).call()
			if step == &"core_systems":
				if not (built is Dictionary):
					push_error("GameRoot._construct: core_systems must return a Dictionary")
					return ERR_INVALID_DATA
				systems.merge(built as Dictionary)
			elif not (built is Object):
				push_error("GameRoot._construct: step %s built no Object" % step)
				return ERR_INVALID_DATA
			else:
				systems[step] = built
			_cores[step] = built
		construction_trace.append(step)
	return OK if inject_systems(systems) else ERR_INVALID_DATA


func _preflight() -> bool:
	var sink: Callable = _factory.get(&"log_sink", Callable()) as Callable
	var tube: TubeConfig = _factory.get(&"tube_config") as TubeConfig
	var ball_raw: BallConfig = _factory.get(&"ball_config") as BallConfig
	var frame_raw: WorldFrameConfig = _factory.get(&"world_frame_config") as WorldFrameConfig
	if tube == null or ball_raw == null or frame_raw == null:
		push_error("GameRoot._preflight: tube_config, ball_config and world_frame_config are required")
		return false
	var ball: BallConfig = ball_raw.validated(sink)
	var frame_cfg: WorldFrameConfig = frame_raw.validated(sink)
	_geometry = WorldGeometry.from_configs(tube, ball, _factory.get(&"slot_count", 20) as int)
	var codes: Array[String] = WorldGeometry.validate(_geometry, frame_cfg)
	if not codes.is_empty():
		push_error("GameRoot._preflight: fatal %s" % [codes])
		return false
	geometry_validated = true
	_cores[&"world_frame"] = WorldFrame.new(frame_cfg, _geometry)
	map_loader_config = MapLoaderConfig.new()
	map_loader_config.v_max = ball.v_max
	map_loader_config.ball_diameter = ball.ball_diameter
	return true


func _start_map_loader() -> Error:
	if not _factory.has(&"map_loader"):
		push_error("GameRoot: missing factory step map_loader")
		return ERR_UNCONFIGURED
	_map_loader = (_factory[&"map_loader"] as Callable).call(map_loader_config) as Object
	construction_trace.append(&"map_loader")
	_bind_menus_to_map_loader()
	_map_loader.call(&"start")
	construction_trace.append(&"map_loader.start")
	return OK


## Hands Menus the `map_load_failed` signal and the typed Retry Callable (`request_map_retry`, bound to
## `MapLoader.retry`) before the first attempt, so a failure in `start()` reaches Menus in the same call. Menus connects
## the signal immediately. Skipped for a loader that is not a `MapLoader` or a Menus without `bind_map_loader`.
func _bind_menus_to_map_loader() -> void:
	if not (_map_loader is MapLoader) or _menus == null or not _menus.has_method(&"bind_map_loader"):
		return
	var loader: MapLoader = _map_loader as MapLoader
	var request_map_retry: Callable = loader.retry
	_menus.call(&"bind_map_loader", loader.map_load_failed, request_map_retry)


## Builds the row table, validates it (a failure connects nothing), sorts by `(rank, row index)` and connects every
## row immediately in that order. Calling it again first removes the previous connections.
func _wire() -> Error:
	unwire()
	_rows = _build_rows()
	var codes: Array[String] = validate_rows(_rows)
	if _run_state as RunStateCore == null:
		codes.append(CODE_NO_RUN_STATE)
	codes.append_array(_juice_scoring_codes(_rows))
	if not codes.is_empty():
		push_error("GameRoot._wire: %s" % [codes])
		return ERR_INVALID_DATA
	for row: Array in order_rows(_rows):
		(row[0] as Signal).connect(row[1] as Callable)
		_connected.append(row)
	construction_trace.append(&"wire")
	return OK


## Disconnects every row that `_wire()` connected.
func unwire() -> void:
	for row: Array in _connected:
		var sig: Signal = row[0] as Signal
		if sig.is_connected(row[1] as Callable):
			sig.disconnect(row[1] as Callable)
	_connected.clear()


## Rows sorted by rank, the row index breaking ties (the engine sort is not stable). Returns a new array.
static func order_rows(rows: Array) -> Array:
	var keyed: Array = []
	for i: int in rows.size():
		keyed.append([(rows[i] as Array)[2] as int, i])
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return (a[0] as int) < (b[0] as int)
		return (a[1] as int) < (b[1] as int))
	var out: Array = []
	for key: Array in keyed:
		out.append(rows[key[1] as int])
	return out


## Codes for rows that are malformed, hold an invalid Callable, or whose handler has an untyped parameter.
static func validate_rows(rows: Array) -> Array[String]:
	var codes: Array[String] = []
	for row: Variant in rows:
		var items: Array = row as Array
		if items == null or items.size() != 3 or not (items[0] is Signal) or not (items[1] is Callable) \
				or not (items[2] is int) or not (items[1] as Callable).is_valid():
			codes.append(CODE_ROW_INVALID)
		elif not handler_is_typed(items[1] as Callable):
			codes.append(CODE_HANDLER_UNTYPED)
	return codes


## True when `handler` names a method of its object and every parameter carries a static type.
static func handler_is_typed(handler: Callable) -> bool:
	var target: Object = handler.get_object()
	var method: StringName = handler.get_method()
	if target == null or method == &"":
		return false
	for entry: Dictionary in target.get_method_list():
		if entry["name"] != method:
			continue
		for arg: Dictionary in (entry["args"] as Array):
			if (arg["type"] as int) == TYPE_NIL and ((arg["usage"] as int) & PROPERTY_USAGE_NIL_IS_VARIANT) != 0:
				return false
		return true
	return false


func _juice_scoring_codes(rows: Array) -> Array[String]:
	var codes: Array[String] = []
	if _juice == null or _scoring == null:
		return codes
	for signal_name: StringName in [&"run_ended", &"run_abandoned"]:
		var juice_rank: int = -1
		var scoring_rank: int = -1
		for row: Array in rows:
			if (row[0] as Signal).get_name() != signal_name:
				continue
			var owner_obj: Object = (row[1] as Callable).get_object()
			if owner_obj == _juice:
				juice_rank = row[2] as int
			elif owner_obj == _scoring:
				scoring_rank = row[2] as int
		if juice_rank >= 0 and scoring_rank >= 0 and juice_rank >= scoring_rank:
			codes.append(CODE_JUICE_AFTER_SCORING)
	return codes


## The rows of the systems that exist, then the rows added with `add_wire_row`. A new system adds one row here.
func _build_rows() -> Array:
	var rows: Array = []
	var rs: RunStateCore = _run_state as RunStateCore
	if rs == null:
		return rows
	var frame: WorldFrame = _world_frame as WorldFrame
	if frame != null:
		rows.append([rs.run_reset, frame.on_run_reset, RANK_PATTERN_FRAME])
	var tube: TubeRunAdapter = _tube_adapter as TubeRunAdapter
	if tube != null:
		rows.append([rs.run_reset, tube.on_run_reset, RANK_TUBE_OBSTACLE])
		rows.append([rs.run_paused, tube.on_run_paused, RANK_REST])
		rows.append([rs.run_resumed, tube.on_run_resumed, RANK_REST])
		rows.append([rs.run_ended, tube.on_run_ended, RANK_ENDED_REST])
		rows.append([rs.phase_changed, tube.on_phase_changed, RANK_REST])
	var tilt: TiltRunAdapter = _tilt_adapter as TiltRunAdapter
	if tilt != null:
		rows.append([rs.run_reset, tilt.on_run_reset, RANK_REST])
		rows.append([rs.run_started, tilt.on_run_started, RANK_REST])
		rows.append([rs.run_resumed, tilt.on_run_resumed, RANK_REST])
		rows.append([rs.run_ended, tilt.on_run_ended, RANK_ENDED_REST])
		rows.append([rs.run_paused, tilt.on_run_paused, RANK_REST])
		rows.append([rs.phase_changed, tilt.on_phase_changed, RANK_REST])
	rows.append_array(_real_core_rows(rs))
	rows.append_array(_extra_rows)
	return rows


## Rows of the real Obstacle, Near-Miss, Ball and Scoring cores (present only when the injected system is the real
## class; a spy or stub adds nothing). Still strict spies (no class yet, so no row here): Pattern provider, Camera,
## Juice, HUD, Menus; their rows arrive with their stories through `add_wire_row`.
## `run_reset`: Obstacle rank 2 (after the Tube Track adapter by row index), Ball 3, Near-Miss and Scoring rank 5.
## `run_ended` / `run_abandoned`: Scoring rank 2. Window and hit signals go in the rest rank.
func _real_core_rows(rs: RunStateCore) -> Array:
	var rows: Array = []
	var obstacle: ObstacleCore = _obstacle as ObstacleCore
	var near_miss: NearMissCore = _near_miss as NearMissCore
	var ball: BallCore = _ball as BallCore
	var scoring: ScoreCore = _scoring as ScoreCore
	var window: TubeWindow = _tube_track as TubeWindow
	if obstacle != null:
		rows.append([rs.run_reset, obstacle.on_run_reset, RANK_TUBE_OBSTACLE])
		if window != null:
			rows.append([window.segment_entered_window, obstacle.on_segment_entered_window, RANK_REST])
			rows.append([window.segment_left_window, obstacle.on_segment_left_window, RANK_REST])
			rows.append([window.window_primed, obstacle.on_window_primed, RANK_REST])
		if near_miss != null:
			rows.append([obstacle.hazard_bound, near_miss.on_hazard_bound, RANK_REST])
			rows.append([obstacle.hazard_released, near_miss.on_hazard_released, RANK_REST])
			rows.append([obstacle.hit_reported, near_miss.on_hit_reported, RANK_REST])
		rows.append([obstacle.hit_reported, rs.request_hit, RANK_REST])
	if ball != null:
		rows.append([rs.run_reset, ball.on_run_reset, RANK_BALL])
		rows.append([rs.run_resumed, ball.on_run_resumed, RANK_REST])
	if near_miss != null:
		rows.append([rs.run_reset, near_miss.on_run_reset, RANK_REST])
	if scoring != null:
		rows.append([rs.run_reset, scoring.on_run_reset, RANK_REST])
		rows.append([rs.run_ended, scoring.on_run_ended, RANK_SCORING])
		rows.append([rs.run_abandoned, scoring.on_run_abandoned, RANK_SCORING])
	return rows


## The ONE place the per-frame order is written (ADR-0002 Decision 6, ADR-0013 Decision 2), against the real APIs:
## `TiltCore.poll()`, `TiltRunAdapter.flush()`, `dt_eff = RunStateCore.tick(world_dt, real_dt)`,
## `BallCore.step(dt_eff, steer, valid, input_source)` with the Tilt outputs, then (Running only)
## `TubeWindow.advance(ball.s)` and `WorldFrame.maybe_rebase(ball.s)`. Ball Movement only ever sees `dt_eff`.
func _tick(real_dt: float, world_dt: float) -> void:
	_tilt_input.call(&"poll")
	_tilt_adapter.call(&"flush")
	var dt_eff: float = _run_state.call(&"tick", world_dt, real_dt) as float
	var phase: int = _run_state.get(&"phase") as int
	var steer: float = _tilt_input.call(&"get_steer") as float
	var valid: bool = _tilt_input.call(&"get_valid") as bool
	var input_source: int = _tilt_input.call(&"get_input_source") as int
	_ball.call(&"step", dt_eff, steer, valid, input_source)
	if phase == RunStateCore.Phase.RUNNING:
		var ball_s: float = _ball.get(&"s") as float
		_tube_track.call(&"advance", ball_s)
		# WorldFrame step: rebase, then re-place the views that hold placed nodes.
		if _world_frame.call(&"maybe_rebase", ball_s) as bool:
			_tube_view.call(&"rebase")
			_hazard_view.call(&"rebase")
	_obstacle.call(&"step", _ball)
	_near_miss.call(&"step", _ball)
	_scoring.call(&"step")
	if phase == RunStateCore.Phase.MENU:
		_tube_view.call(&"idle_step", real_dt)
	_camera.call(&"step")
	_ball_view.call(&"tick")
	_environment.call(&"tick")
	_juice.call(&"tick")
	_hud.call(&"tick")
	_menus.call(&"tick")


static func _engine_clock_us() -> int:
	return Time.get_ticks_usec()
