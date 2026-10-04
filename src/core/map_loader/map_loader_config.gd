## Loader knobs (ADR-0004). Data-driven; no gameplay value.
class_name MapLoaderConfig
extends Resource

## Window of the rate-limited log (`RateLimitedLog`), microseconds.
@export var log_window_us: int = RateLimitedLog.RATE_LIMIT_US
## Ball Movement `V_MAX` handed to `TubeConfig.validate` (Phase A step A6). The composition root overrides it from
## the real Ball Movement config; the default is the ADR-0004 example value.
@export var v_max: float = 25.0
## Ball diameter `D` handed to `TubeConfig.validate` (Phase A step A6). Same ownership note as `v_max`.
@export var ball_diameter: float = 0.8
