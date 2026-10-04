## Tuning data of Obstacle System (GDD Tuning Knobs, TR-024). Every gameplay value lives here, never in code.
##
## `validated(log_sink, omega_max, dt_max)` returns a clamped copy and checks the sweep invariant with the two
## external inputs injected (Ball Movement's `OMEGA_MAX`, Run State's `DT_MAX`); this class never owns them.
## `log_sink(level, code, key, message)` follows `LogLevel`.
class_name ObstacleConfig
extends Resource

## Logged once when `OMEGA_MAX * DT_MAX >= PI` (or either input is not finite).
const SWEEP_INVARIANT_VIOLATED: StringName = &"SWEEP_INVARIANT_VIOLATED"

const _GAP_MARGIN_RANGE: Vector2 = Vector2(2.0, 3.5)
const _MAX_PIECES_RANGE: Vector2i = Vector2i(6, 20)

## Safety margin above bare geometric fit of a gap, in ball widths (safe range 2.0 to 3.5).
@export var gap_margin: float = 2.5
## Seconds a hazard must be visible before the ball reaches it.
@export var t_reveal_min: float = 1.5
## Shortest allowed hidden span in seconds.
@export var hidden_span_min_time: float = 1.44
## Most footprint pieces per segment (safe range 6 to 20).
@export var max_pieces_per_segment: int = 12


## Returns a copy with every knob inside its safe range (non-finite replaced by the default; the GDD names no
## code for knob clamping, so it is silent) and logs `SWEEP_INVARIANT_VIOLATED` when the invariant fails.
## The loaded resource is left untouched.
func validated(log_sink: Callable = Callable(), omega_max: float = 3.0, dt_max: float = 0.1) -> ObstacleConfig:
	var out: ObstacleConfig = duplicate() as ObstacleConfig
	var defaults: ObstacleConfig = ObstacleConfig.new()
	out.gap_margin = _finite_or(out.gap_margin, defaults.gap_margin)
	out.gap_margin = clampf(out.gap_margin, _GAP_MARGIN_RANGE.x, _GAP_MARGIN_RANGE.y)
	out.t_reveal_min = _finite_or(out.t_reveal_min, defaults.t_reveal_min)
	out.hidden_span_min_time = _finite_or(out.hidden_span_min_time, defaults.hidden_span_min_time)
	out.max_pieces_per_segment = clampi(out.max_pieces_per_segment, _MAX_PIECES_RANGE.x, _MAX_PIECES_RANGE.y)
	sweep_invariant_holds(omega_max, dt_max, log_sink)
	return out


## True when `omega_max * dt_max < PI` (strict; both finite). Otherwise logs one `SWEEP_INVARIANT_VIOLATED` ERROR.
static func sweep_invariant_holds(omega_max: float, dt_max: float, log_sink: Callable = Callable()) -> bool:
	if is_finite(omega_max) and is_finite(dt_max) and omega_max * dt_max < PI:
		return true
	if log_sink.is_valid():
		log_sink.call(
			LogLevel.ERROR,
			SWEEP_INVARIANT_VIOLATED,
			"omega_max*dt_max",
			"OMEGA_MAX %s * DT_MAX %s must be below PI" % [omega_max, dt_max]
		)
	return false


static func _finite_or(value: float, fallback: float) -> float:
	return value if is_finite(value) else fallback
