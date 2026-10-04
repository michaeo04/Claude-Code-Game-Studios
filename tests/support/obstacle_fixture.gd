## Factories of the Obstacle System tests (GDD AC preamble): `make_obstacle_fixture`, `make_ball_state_stub`,
## `make_content_provider` and the six worked hazards. `make_core` is added with `ObstacleCore` (Story 007).
## Framework-free: no GUT call.
extends RefCounted

const R: float = 3.0
const D: float = 0.8
const L: float = 12.0
const V_MAX: float = 25.0
const OMEGA_MAX: float = 3.0
const DT_MAX: float = 0.1
## Deliberately different from Camera's shipped 1.0472.
const VISIBLE_ARC_HALF_WIDTH_TEST: float = PI / 2.0

## The fixture config (equals the shipped defaults) plus the derived values of the GDD.
var cfg: ObstacleConfig = ObstacleConfig.new()
var ball_half_angle: float = 0.0
var w: float = 0.0
var gap_min: float = 0.0
var hidden_span_min_s: float = 0.0


## `R` 3.0, `D` 0.8, `L` 12 and the Obstacle knobs; derived values computed from them.
static func make_obstacle_fixture() -> RefCounted:
	var fx: RefCounted = (load("res://tests/support/obstacle_fixture.gd") as GDScript).new() as RefCounted
	fx.set("cfg", make_config())
	var half: float = ObstacleMath.ball_half_angle(R, D)
	fx.set("ball_half_angle", half)
	fx.set("w", 2.0 * half)
	fx.set("gap_min", 2.5 * 2.0 * half)
	fx.set("hidden_span_min_s", 1.44 * V_MAX)
	return fx


## An `ObstacleConfig` at the Tuning Knobs table values.
static func make_config() -> ObstacleConfig:
	var cfg_out: ObstacleConfig = ObstacleConfig.new()
	cfg_out.gap_margin = 2.5
	cfg_out.t_reveal_min = 1.5
	cfg_out.hidden_span_min_time = 1.44
	cfg_out.max_pieces_per_segment = 12
	return cfg_out


## A scripted published ball pair `(theta_prev, theta, s_prev, s)`.
class BallStateStub:
	extends RefCounted
	var theta_prev: float = 0.0
	var theta: float = 0.0
	var s_prev: float = 0.0
	var s: float = 0.0


static func make_ball_state_stub(theta_prev: float, theta: float, s_prev: float, s: float) -> BallStateStub:
	var stub: BallStateStub = BallStateStub.new()
	stub.theta_prev = theta_prev
	stub.theta = theta
	stub.s_prev = s_prev
	stub.s = s
	return stub


## A provider that returns `table[segment_index]` (an `Array[HazardSpec]`, the same shared instances every call).
class FakeProvider:
	extends HazardContentProvider
	var table: Dictionary = {}
	var calls: int = 0

	func hazards_for_segment(segment_index: int) -> Array[HazardSpec]:
		calls += 1
		var out: Array[HazardSpec] = []
		if table.has(segment_index):
			out.assign(table[segment_index] as Array)
		return out


static func make_content_provider(table: Dictionary) -> FakeProvider:
	var p: FakeProvider = FakeProvider.new()
	p.table = table
	return p


## The worked hazard `hazard_id` of the GDD fixture table as a `HazardSpec`: 101, 301, 202, 401, 501, 502, 601.
static func worked_hazard(hazard_id: int) -> HazardSpec:
	var wall: int = HazardPlacement.HazardType.WALL
	var spike: int = HazardPlacement.HazardType.SPIKE
	var gate: int = HazardPlacement.HazardType.DOUBLE_GATE
	var ring: int = HazardPlacement.HazardType.NEAR_RING
	match hazard_id:
		101:
			return HazardSpec.new(spike, 0, PackedFloat64Array([
				-0.05, 0.05, 50.0, 50.3, 0.30, 0.40, 50.05, 50.35, 0.65, 0.75, 50.0, 50.3
			]), PackedFloat64Array())
		301:
			return HazardSpec.new(wall, 0, PackedFloat64Array([0.4127, 5.8705, 200.0, 201.0]), PackedFloat64Array([0.0]))
		202:
			return HazardSpec.new(gate, 0, PackedFloat64Array([
				-1.2, -0.4, 100.0, 101.2, 0.4, 1.2, 100.0, 101.2
			]), PackedFloat64Array([0.0, PI]))
		401:
			return HazardSpec.new(ring, 0, PackedFloat64Array([-2.7053, 2.7053, 300.0, 301.2]), PackedFloat64Array([PI]))
		501:
			return HazardSpec.new(spike, 0, PackedFloat64Array([-0.05, 0.05, 400.0, 401.0]), PackedFloat64Array())
		502:
			return HazardSpec.new(spike, 0, PackedFloat64Array([-0.03, 0.07, 400.5, 401.5]), PackedFloat64Array())
		601:
			return HazardSpec.new(spike, 0, PackedFloat64Array([-0.05, 0.05, 200.0, 200.3]), PackedFloat64Array())
	return null
