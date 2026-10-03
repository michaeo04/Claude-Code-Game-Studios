## Composition Root and the only game-logic `_process` (ADR-0002).
##
## Ignores the engine delta, reads the injected `clock_us`, and hands `(real_dt, world_dt)` to the
## single `_tick()` that writes the per-frame order. Ticks in every phase; never pauses the tree
## and never touches the engine time scale.
class_name GameRoot
extends Node

## Systems that `_tick()` calls, by key (all required). Values are duck-typed so tests inject spies.
const SYSTEM_KEYS: Array[StringName] = [
	&"tilt_input", &"tilt_adapter", &"run_state", &"ball", &"tube_track", &"world_frame", &"tube_view",
	&"hazard_view", &"obstacle", &"near_miss", &"scoring", &"camera", &"ball_view", &"environment",
	&"juice", &"hud", &"menus",
]

## Microsecond clock (ADR-0002 Decision 4). Production: `Time.get_ticks_usec`.
var clock_us: Callable

var _prev_us: int = 0
var _has_prev: bool = false

var _tilt_input: Object
var _tilt_adapter: Object
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


## Injects the systems listed in `SYSTEM_KEYS`. Returns false (and injects nothing) when a key is missing.
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
	return true


## Registers a view Node: its own processing is switched off, `GameRoot` drives it.
func register_view(view: Node) -> void:
	view.set_process(false)
	view.set_physics_process(false)


## The ONE place the per-frame order is written (ADR-0002 Decision 6, ADR-0013 Decision 2).
func _tick(real_dt: float, world_dt: float) -> void:
	_tilt_input.call(&"poll")
	_tilt_adapter.call(&"flush")
	_run_state.call(&"tick", world_dt, real_dt)
	var phase: int = _run_state.get(&"phase") as int
	_ball.call(&"step", world_dt)
	if phase == RunStateCore.Phase.RUNNING:
		_tube_track.call(&"advance", world_dt)
		# WorldFrame step: rebase, then re-place the views that hold placed nodes.
		if _world_frame.call(&"maybe_rebase", _ball.get(&"s") as float) as bool:
			_tube_view.call(&"rebase")
			_hazard_view.call(&"rebase")
	_obstacle.call(&"test")
	_near_miss.call(&"step")
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
