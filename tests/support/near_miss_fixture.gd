## Factories of the Near-Miss Detection tests (GDD AC preamble): the fixture and the three worked hazards.
## Framework-free: no GUT call.
extends RefCounted

const R: float = 3.0
const D: float = 0.8
const V_MAX: float = 25.0
const GAP_MARGIN: float = 2.5

var cfg: NearMissConfig = NearMissConfig.new()
var ball_half_angle: float = 0.0
var w: float = 0.0
var gap_min: float = 0.0
var angle_margin: float = 0.0
var s_margin: float = 0.0


## Pose source stub with the four `BallCore` properties `NearMissCore.step` reads.
class BallStub:
	extends RefCounted
	var theta: float = 0.0
	var theta_prev: float = 0.0
	var s: float = 0.0
	var s_prev: float = 0.0

	## Sets the whole pose of the tick.
	func set_pose(p_theta_prev: float, p_theta: float, p_s_prev: float, p_s: float) -> BallStub:
		theta_prev = p_theta_prev
		theta = p_theta
		s_prev = p_s_prev
		s = p_s
		return self


## Core at the fixture geometry (R 3, D 0.8).
static func make_core(config: NearMissConfig, log_sink: Callable = Callable()) -> NearMissCore:
	return NearMissCore.new(config, ObstacleMath.ball_half_angle(R, D), D, log_sink)


## A ball stub at a pose.
static func make_ball_state_stub(theta_prev: float, theta: float, s_prev: float, s: float) -> BallStub:
	return BallStub.new().set_pose(theta_prev, theta, s_prev, s)


## Delivers `hazard_bound(hazard_id, worked_raw(hazard_id))` to `core`.
static func make_hazard_bound_stub(core: NearMissCore, hazard_id: int) -> void:
	core.on_hazard_bound(hazard_id, worked_raw(hazard_id))


## Registry defaults plus both coefficients 1.0; derived margins 0.1179 and 0.4.
static func make_near_miss_fixture() -> RefCounted:
	var fx: RefCounted = (load("res://tests/support/near_miss_fixture.gd") as GDScript).new() as RefCounted
	var config: NearMissConfig = NearMissConfig.new()
	var half: float = ObstacleMath.ball_half_angle(R, D)
	fx.set("cfg", config)
	fx.set("ball_half_angle", half)
	fx.set("w", 2.0 * half)
	fx.set("gap_min", GAP_MARGIN * 2.0 * half)
	fx.set("angle_margin", config.angle_margin(half))
	fx.set("s_margin", config.s_margin(D))
	return fx


## Raw flat footprint of a worked hazard: 701 Graze (1 piece), 101 Spike cluster (3), 202 Double Gate (2).
static func worked_raw(hazard_id: int) -> PackedFloat64Array:
	match hazard_id:
		701:
			return PackedFloat64Array([-0.3, 0.3, 100.0, 101.5])
		101:
			return PackedFloat64Array([-0.05, 0.05, 50.0, 50.3, 0.30, 0.40, 50.05, 50.35, 0.65, 0.75, 50.0, 50.3])
		202:
			return PackedFloat64Array([-1.2, -0.4, 100.0, 101.2, 0.4, 1.2, 100.0, 101.2])
	return PackedFloat64Array()
