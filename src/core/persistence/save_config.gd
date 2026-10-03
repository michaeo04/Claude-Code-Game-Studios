## Tuning knobs of Save & Persistence (GDD Tuning Knobs, ADR-0007). Shipped values live in
## `assets/data/save_config.tres`; `validated(log_sink)` returns a clamped copy and never mutates the source.
class_name SaveConfig
extends Resource

## Save schema version of this build. A constant, not a knob: it changes only with a format change.
const CURRENT_SCHEMA_VERSION: int = 1
## Log code of a clamped knob.
const KNOB_CLAMPED: String = "KNOB_CLAMPED"
const LEVEL_ERROR: int = 2

const RATE_LIMIT_MIN: float = 0.5
const RATE_LIMIT_MAX: float = 5.0
const RETENTION_MIN: int = 1
const RETENTION_MAX: int = 20
const FILE_SIZE_MIN: int = 16384
const FILE_SIZE_MAX: int = 1048576

## Seconds between two identical log lines (`SAVE_LOG_RATE_LIMIT`).
@export var save_log_rate_limit: float = 1.0
## Corrupt-file backups kept (`CORRUPT_BACKUP_RETENTION`).
@export var corrupt_backup_retention: int = 5
## Largest save file read, in bytes (`SAVE_FILE_SIZE_MAX`, 64 KB).
@export var save_file_size_max: int = 65536


## A clamped copy; each knob outside its safe range (or NaN/INF) is clamped with one `KNOB_CLAMPED` error
## through `log_sink(level, code, key, message)`.
func validated(log_sink: Callable) -> SaveConfig:
	var out: SaveConfig = duplicate() as SaveConfig
	var defaults: SaveConfig = SaveConfig.new()
	var rate: float = save_log_rate_limit
	if not is_finite(rate):
		rate = defaults.save_log_rate_limit
	out.save_log_rate_limit = clampf(rate, RATE_LIMIT_MIN, RATE_LIMIT_MAX)
	if out.save_log_rate_limit != save_log_rate_limit:
		_log_clamped(log_sink, "save_log_rate_limit", str(save_log_rate_limit), str(out.save_log_rate_limit))
	out.corrupt_backup_retention = clampi(corrupt_backup_retention, RETENTION_MIN, RETENTION_MAX)
	if out.corrupt_backup_retention != corrupt_backup_retention:
		_log_clamped(
			log_sink, "corrupt_backup_retention", str(corrupt_backup_retention), str(out.corrupt_backup_retention)
		)
	out.save_file_size_max = clampi(save_file_size_max, FILE_SIZE_MIN, FILE_SIZE_MAX)
	if out.save_file_size_max != save_file_size_max:
		_log_clamped(log_sink, "save_file_size_max", str(save_file_size_max), str(out.save_file_size_max))
	return out


static func _log_clamped(log_sink: Callable, key: String, raw: String, used: String) -> void:
	if log_sink.is_valid():
		log_sink.call(LEVEL_ERROR, KNOB_CLAMPED, key, "%s=%s is outside its safe range; using %s" % [key, raw, used])
