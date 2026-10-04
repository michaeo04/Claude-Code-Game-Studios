## Tuning data of Near-Miss Detection (GDD Tuning Knobs, TR-near-miss-detection-018). Gameplay values live here.
##
## Only the two dimensionless coefficients are knobs; the margins are derived from them and the ball geometry
## (`angle_margin`, `s_margin`) and never stored. `log_sink(level, code, key, message)` follows `LogLevel`.
class_name NearMissConfig
extends Resource

## Logged once per coefficient that is 0 or negative at validation (key names the knob).
const NEAR_MISS_MARGIN_NONPOSITIVE: StringName = &"NEAR_MISS_MARGIN_NONPOSITIVE"

## Multiplier on `BALL_HALF_ANGLE` (documented safe range 0.5 to 1.5; not enforced, no code exists for it).
@export var near_miss_angle_coeff: float = 1.0
## Multiplier on `D / 2` (documented safe range 0.5 to 1.5; not enforced).
@export var near_miss_s_coeff: float = 1.0


## Returns a copy. A coefficient that is 0 or negative is logged (`NEAR_MISS_MARGIN_NONPOSITIVE`, one line per
## offending knob) and replaced by the default; a non-finite one is replaced silently. The loaded resource is untouched.
func validated(log_sink: Callable = Callable()) -> NearMissConfig:
	var out: NearMissConfig = duplicate() as NearMissConfig
	var defaults: NearMissConfig = NearMissConfig.new()
	out.near_miss_angle_coeff = _checked(
		out.near_miss_angle_coeff, defaults.near_miss_angle_coeff, "near_miss_angle_coeff", log_sink
	)
	out.near_miss_s_coeff = _checked(out.near_miss_s_coeff, defaults.near_miss_s_coeff, "near_miss_s_coeff", log_sink)
	return out


## `NEAR_MISS_ANGLE_MARGIN = ANGLE_COEFF * BALL_HALF_ANGLE`. Example: 1.0 * 0.1179 = 0.1179.
func angle_margin(ball_half_angle: float) -> float:
	return near_miss_angle_coeff * ball_half_angle


## `NEAR_MISS_S_MARGIN = S_COEFF * (D / 2)`. Example: 1.0 * 0.4 = 0.4.
func s_margin(d: float) -> float:
	return near_miss_s_coeff * (d / 2.0)


static func _checked(value: float, fallback: float, key: String, log_sink: Callable) -> float:
	if not is_finite(value):
		return fallback
	if value <= 0.0:
		if log_sink.is_valid():
			log_sink.call(
				LogLevel.ERROR, NEAR_MISS_MARGIN_NONPOSITIVE, key, "%s must be above 0 (got %s)" % [key, value]
			)
		return fallback
	return value
