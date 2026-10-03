## Tuning data of the render origin (ADR-0013). `validated(log_sink)` returns a clamped copy and
## never mutates the loaded resource.
class_name WorldFrameConfig
extends Resource

## Largest render z the float32 error model allows (a constant, not a knob).
const Z_RENDER_MAX: float = 2048.0
## Lower clamp of `rebase_segments`.
const REBASE_SEGMENTS_MIN: int = 24
## Upper clamp of `rebase_segments`.
const REBASE_SEGMENTS_MAX: int = 128
## Log level used for clamp warnings (matches `RunStateMath.LogLevel.WARNING`).
const LOG_WARNING: int = 1

## Segments between rebases (safe range 24 to 128). The rebase fires at `rebase_segments * L`.
@export var rebase_segments: int = 84


## A clamped copy of this config. `log_sink` is `Callable(level: int, message: String)` or invalid.
func validated(log_sink: Callable) -> WorldFrameConfig:
	var copy: WorldFrameConfig = duplicate() as WorldFrameConfig
	var clamped: int = clampi(rebase_segments, REBASE_SEGMENTS_MIN, REBASE_SEGMENTS_MAX)
	if clamped != rebase_segments:
		copy.rebase_segments = clamped
		if log_sink.is_valid():
			log_sink.call(LOG_WARNING, "REBASE_SEGMENTS_CLAMPED %d -> %d" % [rebase_segments, clamped])
	return copy
