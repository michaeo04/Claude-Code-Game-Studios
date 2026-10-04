## Loader knobs (ADR-0004). Data-driven; no gameplay value.
class_name MapLoaderConfig
extends Resource

## Window of the rate-limited log (`RateLimitedLog`), microseconds.
@export var log_window_us: int = RateLimitedLog.RATE_LIMIT_US
