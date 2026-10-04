## The scripted 500-tick Near-Miss input of the determinism tests (story 009): binds, hits, ordinary and reset
## releases, a non-finite frame, no-op frames and run resets, all from integer arithmetic (no randomness).
## One `Driver` per core; `advance()` plays the next tick. Framework-free: no GUT call.
extends RefCounted

const Fixture = preload("res://tests/support/near_miss_fixture.gd")

const TICKS: int = 500
const CYCLE: int = 50
const NEAR_THETA: float = -0.5
const OUT_THETA: float = 2.5
const GRAZE_S: float = 100.5
const RESET_EVERY: int = 100


## Plays the script on one core and records the stream as `[tick, hazard_id - id_base, run_id]`.
class Driver:
	extends RefCounted
	var core: NearMissCore
	var ball: RefCounted
	var id_base: int
	var stream: Array[Array] = []
	var tick: int = 0
	var _theta: float = OUT_THETA

	## `ball` must have `set_pose(theta_prev, theta, s_prev, s)`; `id_base` offsets every hazard id.
	func _init(p_core: NearMissCore, p_ball: RefCounted, p_id_base: int = 0) -> void:
		core = p_core
		ball = p_ball
		id_base = p_id_base
		core.near_miss_detected.connect(_on_detected)

	func _on_detected(hazard_id: int, run_id: int) -> void:
		stream.append([tick, hazard_id - id_base, run_id])

	## Plays one tick of the script.
	func advance() -> void:
		var cycle: int = tick / CYCLE
		var local: int = tick % CYCLE
		var kind: int = cycle % 4
		var hid: int = id_base + 1000 + cycle
		if local == 0:
			core.on_hazard_bound(hid, Fixture.worked_raw(701))
		var theta: float = OUT_THETA
		if local >= 10 and local < 30:
			theta = NEAR_THETA
		if local == 5 and cycle % 7 == 0:
			theta = NAN
		if local == 20 and kind == 1:
			core.on_hit_reported(hid, 1)
		if local == 25 and kind == 2:
			core.on_hazard_released(hid, false)
		if local == 25 and kind == 3:
			core.on_hazard_released(hid, true)
		if local == 48 and kind <= 1:
			core.on_hazard_released(hid, false)
		ball.call(&"set_pose", _theta, theta, GRAZE_S, GRAZE_S)
		core.step(ball)
		if is_finite(theta):
			_theta = theta
		if tick % RESET_EVERY == RESET_EVERY - 1:
			core.on_run_reset(tick / RESET_EVERY + 2)
		tick += 1


## Spy ball: reads of the four pose names go through `_get` and are recorded; any write is recorded.
class SpyBall:
	extends RefCounted
	var reads: Array[StringName] = []
	var writes: Array[StringName] = []
	var _pose: Dictionary = {&"theta_prev": 0.0, &"theta": 0.0, &"s_prev": 0.0, &"s": 0.0}

	func set_pose(theta_prev: float, theta: float, s_prev: float, s: float) -> SpyBall:
		_pose = {&"theta_prev": theta_prev, &"theta": theta, &"s_prev": s_prev, &"s": s}
		return self

	func _get(property: StringName) -> Variant:
		if _pose.has(property):
			reads.append(property)
			return _pose[property]
		return null

	func _set(property: StringName, _value: Variant) -> bool:
		writes.append(property)
		return false
