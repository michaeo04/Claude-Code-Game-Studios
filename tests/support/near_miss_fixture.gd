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
