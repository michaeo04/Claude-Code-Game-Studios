## Fakes for the WorldFrame rebase contract (ADR-0013): views that store `s` and place through `render_z`.
##
## Framework-free: no GUT call. `Stub` stands in for every system `GameRoot._tick()` calls; `View` for TubeView
## and HazardView (stored gameplay `s`, `rebase()`, `reset_physics_interpolation` count); `Effect` for a future
## effect node that stores `s` and converts it each tick; `Renderer` records a "draw" after the whole tick.
extends RefCounted


## Permissive no-op system; as run state it returns `dt_eff = world_dt` while `phase` is RUNNING, as ball it moves `s`.
class Stub extends RefCounted:
	var phase: int = RunStateCore.Phase.RUNNING
	var s: float = 0.0
	var speed: float = 25.0
	var rebases: int = 0

	func poll() -> void:
		pass

	func flush() -> void:
		pass

	func tick(world_dt: float = 0.0, _real_dt: float = 0.0) -> float:
		return world_dt if phase == RunStateCore.Phase.RUNNING else 0.0

	func step(dt_eff: float = 0.0, _steer: float = 0.0, _valid: bool = true, _source: int = 0) -> void:
		s += speed * dt_eff

	func advance(_ball_s: float) -> void:
		pass

	func test() -> void:
		pass

	func get_steer() -> float:
		return 0.0

	func get_valid() -> bool:
		return true

	func get_input_source() -> int:
		return 0


## A view holding placed nodes: stored gameplay `s` per node, z derived only through `WorldFrame.render_z`.
class View extends RefCounted:
	var frame: WorldFrame
	var node_s: Array[float] = []
	var node_z: Array[float] = []
	var rebase_calls: int = 0
	var interpolation_resets: int = 0
	var segment_length: float = 12.0
	var _name: String
	var _log: Array[String]

	func _init(owner_frame: WorldFrame, view_name: String, shared_log: Array[String]) -> void:
		frame = owner_frame
		_name = view_name
		_log = shared_log

	func bind(stored_s: float) -> void:
		node_s.append(stored_s)
		node_z.append(frame.render_z(stored_s))

	func rebase() -> void:
		rebase_calls += 1
		_log.append(_name + ".rebase")
		for i: int in node_s.size():
			node_z[i] = frame.render_z(node_s[i])
		interpolation_resets += 1

	func idle_step(_dt: float = 0.0) -> void:
		pass

	## Idle re-prime: node i goes back to `i * L`.
	func to_idle() -> void:
		_log.append(_name + ".to_idle@" + str(frame.origin_s))
		for i: int in node_s.size():
			node_s[i] = float(i) * segment_length
			node_z[i] = frame.render_z(node_s[i])

	func tick() -> void:
		pass


## An effect that stores `s` (float64) and converts it every tick.
class Effect extends RefCounted:
	var frame: WorldFrame
	var stored_s: float = 0.0
	var z: float = 0.0

	func _init(owner_frame: WorldFrame) -> void:
		frame = owner_frame

	func tick() -> void:
		z = frame.render_z(stored_s)


## Records a draw after the tick: counts nodes whose z disagrees with a fresh placement at the current origin.
class Renderer extends RefCounted:
	var frame: WorldFrame
	var views: Array[View] = []
	var effects: Array[Effect] = []
	var draws: int = 0
	var inconsistent_nodes: int = 0

	func _init(owner_frame: WorldFrame) -> void:
		frame = owner_frame

	func tick() -> void:
		draws += 1
		for view: View in views:
			for i: int in view.node_s.size():
				if absf(view.node_z[i] - (-(view.node_s[i] - frame.origin_s))) > 1e-9:
					inconsistent_nodes += 1
		for effect: Effect in effects:
			if absf(effect.z - (-(effect.stored_s - frame.origin_s))) > 1e-9:
				inconsistent_nodes += 1


## Mimics the Tube Track adapter call site: `reset()` strictly before `to_idle()` on return to Menu.
class FakeTubeAdapter extends RefCounted:
	var frame: WorldFrame
	var view: View
	var _log: Array[String]

	func _init(owner_frame: WorldFrame, tube_view: View, shared_log: Array[String]) -> void:
		frame = owner_frame
		view = tube_view
		_log = shared_log

	func on_run_reset(_run_id: int) -> void:
		_log.append("tube_adapter.run_reset@" + str(frame.origin_s))
		view.to_idle()

	func on_phase_changed(new_phase: int, old_phase: int) -> void:
		if new_phase != RunStateCore.Phase.MENU or old_phase == RunStateCore.Phase.BOOT:
			return
		_log.append("frame.reset")
		frame.reset()
		view.to_idle()


## Builds the 17-key systems dictionary for `GameRoot.inject_systems`; unlisted systems are `Stub`s.
static func systems(run_state: Object, ball: Object, frame: WorldFrame, tube_view: Object, hazard_view: Object,
		overrides: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for key: StringName in GameRoot.SYSTEM_KEYS:
		out[key] = Stub.new()
	out[&"run_state"] = run_state
	out[&"ball"] = ball
	out[&"world_frame"] = frame
	out[&"tube_view"] = tube_view
	out[&"hazard_view"] = hazard_view
	out.merge(overrides, true)
	return out
