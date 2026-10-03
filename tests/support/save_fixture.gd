## Fixture for Save & Persistence tests (GDD Fixture). Deliberately uses 3 / 0.05 / 3 so that no AC can
## pass against a shipped default. Framework-free (ADR-0009): no GUT call.
extends RefCounted

const REAL_PATH: String = "user://save.cfg"
const TMP_PATH: String = "user://save.cfg.tmp"
const CURRENT_SCHEMA_VERSION_TEST: int = 3
const SAVE_LOG_RATE_LIMIT_TEST: float = 0.05
const CORRUPT_BACKUP_RETENTION_TEST: int = 3


## A `SaveConfig` with the fixture knobs (the shipped file size limit is kept).
static func make_save_fixture() -> SaveConfig:
	var config: SaveConfig = SaveConfig.new()
	config.save_log_rate_limit = SAVE_LOG_RATE_LIMIT_TEST
	config.corrupt_backup_retention = CORRUPT_BACKUP_RETENTION_TEST
	return config


## A populated, compatible file: personal_best 500, haptics true, tilt 1.0; `reduced_motion_enabled` is
## deliberately absent (the "new key, no migration" case).
static func make_loaded_sections() -> Dictionary:
	return {
		"_meta": {"schema_version": CURRENT_SCHEMA_VERSION_TEST},
		"scoring": {"personal_best": 500},
		"settings": {"haptics_enabled": true, "tilt_sensitivity": 1.0},
	}
