## The render origin (ADR-0013): maps float64 gameplay distance `s` to a render z that stays small.
##
## Pure and engine-free. `s` is never reduced; `origin_s` is a whole number of segments and moves
## forward in `maybe_rebase`. This is the only place a world distance becomes a render z.
class_name WorldFrame
extends RefCounted

## Code returned by `validate` when the rebase window does not fit the render budget.
const CODE_BUDGET: String = "REBASE_Z_EXCEEDS_BUDGET"

## Start of the render window in `s` units; always an exact multiple of `L`.
var origin_s: float = 0.0
## Count of `render_z` results outside `2 * Z_RENDER_MAX` (the debug assertion of ADR-0013).
var budget_violations: int = 0
## When true a violation also calls `push_error` (never `assert`, which would abort the test run).
var report_violations: bool = true

var _config: WorldFrameConfig
var _l: float
var _threshold: float


func _init(config: WorldFrameConfig, geometry: WorldGeometry) -> void:
	_config = config
	_l = geometry.l
	_threshold = float(config.rebase_segments) * _l


## Budget check `(REBASE_SEGMENTS + A + 1) * L <= Z_RENDER_MAX`; returns error codes (empty when valid).
static func validate(config: WorldFrameConfig, geometry: WorldGeometry) -> Array[String]:
	var codes: Array[String] = []
	var reach: float = float(config.rebase_segments + geometry.a_segments + 1) * geometry.l
	if reach > WorldFrameConfig.Z_RENDER_MAX:
		codes.append(CODE_BUDGET)
	return codes


## True when `z` is inside the debug bound `2 * Z_RENDER_MAX`.
static func z_within_bound(z: float) -> bool:
	return absf(z) <= 2.0 * WorldFrameConfig.Z_RENDER_MAX


## `-(s - origin_s)` in float64. A result beyond the bound counts a violation (stale origin or raw `s`).
func render_z(s: float) -> float:
	var z: float = -(s - origin_s)
	if not z_within_bound(z):
		budget_violations += 1
		if report_violations:
			push_error("WorldFrame.render_z out of budget: z=%f (stale origin or raw s?)" % z)
	return z


## Rebases when `s - origin_s >= REBASE_SEGMENTS * L`; true once per rebase, else false.
func maybe_rebase(s: float) -> bool:
	var rel: float = s - origin_s
	if rel < _threshold:
		return false
	origin_s += floorf(rel / _l) * _l
	if s - origin_s < 0.0: # the division rounded up to the next whole segment
		origin_s -= _l
	return true


## Run reset (`_wire()` row, rank 1): origin back to 0.
func on_run_reset(_run_id: int) -> void:
	origin_s = 0.0


## Origin back to 0 (Tube Track adapter, immediately before `to_idle()`).
func reset() -> void:
	origin_s = 0.0
