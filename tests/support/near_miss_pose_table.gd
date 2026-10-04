## Shared pose table of the Near-Miss hit/near geometry on the worked Graze hazard 701 (raw footprint
## theta -0.3..0.3, s 100..101.5): rows `[theta_prev, theta, s_prev, s]`. Framework-free: no GUT call.
extends RefCounted

## Rows: dead-centre hit, angular graze, along-track graze, far miss, angular edge hits, s-only hits, a
## fast tunnelling sweep, and a seam-wrapped sweep.
static func rows() -> Array[PackedFloat64Array]:
	return [
		PackedFloat64Array([-0.1, 0.1, 100.4, 100.6]),
		PackedFloat64Array([-0.5, -0.45, 100.5, 100.6]),
		PackedFloat64Array([0.0, 0.05, 99.3, 99.5]),
		PackedFloat64Array([2.0, 2.1, 50.0, 50.1]),
		PackedFloat64Array([0.4, 0.4, 100.5, 100.5]),
		PackedFloat64Array([0.5, 0.5, 100.5, 100.5]),
		PackedFloat64Array([0.0, 0.0, 99.0, 102.5]),
		PackedFloat64Array([-1.0, 1.0, 100.5, 100.5]),
		PackedFloat64Array([3.0, -3.0, 100.5, 100.5]),
		PackedFloat64Array([0.0, 0.0, 98.0, 99.0]),
		PackedFloat64Array([0.0, 0.0, 101.4, 102.0]),
	]
