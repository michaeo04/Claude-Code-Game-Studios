# Epic: Save & Persistence

> **Layer**: Foundation
> **GDD**: design/gdd/save-persistence.md
> **Architecture Module**: Save & Persistence
> **Status**: Ready
> **Control Manifest Version**: 2026-10-03
> **Stories**: 15 stories (see table)

## Overview

Save & Persistence is the only code that does file I/O: `user://save.cfg` through a `SaveFs` seam, schema versioning, an atomic temp-then-rename write, a synchronous load before Scoring and Settings are built, and the synchronous personal-best write inside Scoring's run-end handler (ADR-0007). It exposes `get_value` and `set_value` and nothing else.

## Governing ADRs

| ADR | Decision Summary | Status | Engine Risk |
|-----|-----------------|--------|-------------|
| ADR-0007: Persistence implementation | This ADR keeps the GDD's format and write protocol, replaces the eight loose seams with **one `SaveFs` facade plus three Callables**, adds the file-size and backup-listing operations the GDD already requires, keeps th... | Accepted | MEDIUM |
| ADR-0009: Test framework and CI | Eight ADRs have also registered lints that nothing runs. This ADR settles it: **GUT 9.x**, vendored and pinned, confirmed on 4.7.2 by a first spike (T-1) with gdUnit4 as the pre-committed fallback; **GitHub Actions on... | Accepted | MEDIUM |

**Engine risk of the epic: MEDIUM** (highest among its governing ADRs). Spikes named in those ADRs gate the first dependent story (P-1).

## GDD Requirements

22 requirements registered for this system: 21 covered by an ADR, 1 partial, 0 gap, 0 GDD-owned (specified fully by the GDD, no ADR needed).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-save-persistence-001 | Single file user://save.cfg, ConfigFile format, sections [scoring] (personal_best int only), [settings], reserved [cosmetics] (not created early), and [_meta].schema_version int | ADR-0007 ✅ Covered |
| TR-save-persistence-002 | SaveCore (RefCounted) with 8 injected seams: config_reader(path)->{status:"OK"/"MISSING"/"PARSE_ERROR", sections}, config_writer(path,sections)->bool, path_exists, path_rename, path_delete, clock(), wall_clock()->int, log_sink(... | ADR-0007 ✅ Covered |
| TR-save-persistence-003 | PersistMath static functions: schema_compatible (F1), read_valid and read_error_code (F2), is_serializable_type | ADR-0007 ✅ Covered |
| TR-save-persistence-004 | API get_value(section, key, default) and set_value(section, key, value)->bool; getters return exactly stored value or the caller's own default, never a SaveCore-invented one | ADR-0007 ✅ Covered |
| TR-save-persistence-005 | Boot read is synchronous and complete before Scoring, Settings, Cosmetics are constructed; no "loaded" signal | ADR-0007 ✅ Covered |
| TR-save-persistence-006 | set_value writes immediately: in-memory update, then config_writer(TMP_PATH, complete sections map), then path_rename(TMP, REAL), both before return; no batching | ADR-0007 ✅ Covered |
| TR-save-persistence-007 | Every write serializes the complete in-memory section map (including untouched sections, [_meta], and still-wrong-typed keys carried forward byte-for-byte) | ADR-0007 ✅ Covered |
| TR-save-persistence-008 | Real seams: rename via DirAccess.rename_absolute(), delete via DirAccess.remove_absolute(), save via ConfigFile.save() with Error return checked; failure of writer or rename logs one WRITE_FAILED, returns false to caller, in-me... | ADR-0007 ✅ Covered |
| TR-save-persistence-009 | Orphaned user://save.cfg.tmp is deleted (path_exists then path_delete) before the next temp write | ADR-0007 ✅ Covered |
| TR-save-persistence-010 | Crash guarantee scoped to app-termination (kill) only, not power loss (no fsync available from GDScript); SP-1 device kill test: 3 kill points x >= 20 reps, zero corrupted save.cfg | ADR-0007 ✅ Covered |
| TR-save-persistence-011 | F1 schema_compatible: is_int type guard first; non-int treated as 0; compatible iff 0 < v <= CURRENT_SCHEMA_VERSION (past versions compatible with no migration; newer = incompatible) | ADR-0007 ✅ Covered |
| TR-save-persistence-012 | F2 per-key validity: parsed_ok and compatible and has_key and type_matches; error precedence FILE_UNREADABLE > SCHEMA_INCOMPATIBLE > TYPE_MISMATCH; absent key logs nothing; file-level errors logged once per requested key per AC-10 | ADR-0007 ⚠️ Partial |
| TR-save-persistence-013 | Corrupt or schema-incompatible file: whole file invalid (all defaults), old file renamed to save.cfg.corrupt-<wall_clock()>-<n> (n increments on same-second collision); CORRUPT_BACKUP_RETENTION caps backups, oldest deleted | ADR-0007 ✅ Covered |
| TR-save-persistence-014 | Oversized file guard: files over SAVE_FILE_SIZE_MAX are rejected before config_reader, handled like PARSE_ERROR (backed up, never parsed) | ADR-0007 ✅ Covered |
| TR-save-persistence-015 | First launch (status MISSING): all defaults, one INFO log (not error), first set_value creates the file | ADR-0007 ✅ Covered |
| TR-save-persistence-016 | set_value rejects non-serializable values (raw Object/RefCounted) before any seam call: no memory update, one UNSERIALIZABLE_VALUE error, returns failure | ADR-0007 ✅ Covered |
| TR-save-persistence-017 | Write-failure logging rate limited per section+key via reused PlatformServices RateLimitedLog on injected real-time clock | ADR-0007 ✅ Covered |
| TR-save-persistence-018 | SaveService node listens to PlatformServices app_backgrounded and calls the persist path once (redundant safety flush, no-op when nothing pending); app_foregrounded/interrupted/returned never call it | ADR-0007 ✅ Covered |
| TR-save-persistence-019 | SaveCore and PersistMath contain no ConfigFile, FileAccess, DirAccess, Input., DisplayServer., Engine., Time., OS., get_tree and no Run State symbols; SaveService is the sole file using ConfigFile/FileAccess/DirAccess; no autoload | ADR-0009 ✅ Covered |
| TR-save-persistence-020 | SP-2 real-parser sweep on device or editor: hand-crafted files (non-int schema_version, typed-constructor value, at/over SAVE_FILE_SIZE_MAX, truncated/garbage) must not crash/hang; pre-parse content sniff pre-committed if Varia... | ADR-0007 ✅ Covered |
| TR-save-persistence-021 | No mid-run persistence and no interface to Run State; no signing/encryption (deliberate: single-player, no server truth); revisit only with leaderboard/cloud | ADR-0007 ✅ Covered |
| TR-save-persistence-022 | Fixture uses distinct non-shipped values (schema 3, rate limit 0.05, retention 3) with a shipped-defaults smoke check AC-23; tests in tests/unit/save_persistence/ named save_persistence_[feature]_test.gd | ADR-0009 ✅ Covered |

**Partial or gap requirements:** stories for these carry the open point named in `docs/architecture/architecture-traceability.md` (Partial Coverage) and are marked Blocked until it is closed.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/save-persistence.md` are verified
- All Logic and Integration stories have passing test files in `tests/` (`python tools/ci/run_ci.py`)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Every spike its ADRs name for this module has a recorded result in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [PersistMath pure functions](story-001-persist-math.md) | Logic | Ready | ADR-0007 |
| 002 | [SaveFs facade, SaveConfig and test fixture](story-002-save-fs-config-fixture.md) | Config/Data | Ready | ADR-0007 |
| 003 | [SaveCore boot load, get_value and first launch](story-003-boot-load-and-get-value.md) | Logic | Ready | ADR-0007 |
| 004 | [set_value write path (temp, complete map, rename)](story-004-write-path.md) | Logic | Ready | ADR-0007 |
| 005 | [Write failure handling and rate-limited logging](story-005-write-failure-and-rate-limit.md) | Logic | Ready | ADR-0007 |
| 006 | [Read validity, per-key fallback and error logging](story-006-read-validity-and-error-logging.md) | Logic | Ready (GDD F2 and AC-10 amended 2026-10-03) | ADR-0007 |
| 007 | [Corrupt-file backup, rotation and oversize guard](story-007-corrupt-backup-and-oversize-guard.md) | Logic | Ready | ADR-0007 |
| 008 | [Flush no-op and SaveService node wiring](story-008-flush-and-save-service-node.md) | Logic | Ready | ADR-0007 |
| 009 | [Real SaveFs implementation and file round trip](story-009-real-save-fs.md) | Integration | Ready | ADR-0007 |
| 010 | [Architecture and coupling lints](story-010-architecture-lints.md) | Logic | Ready | ADR-0009 |
| 011 | [SP-2 real-parser sweep against hostile files](story-011-sp2-real-parser-sweep.md) | Integration | Ready | ADR-0007 |
| 012 | [SP-1 write survives a kill (device)](story-012-sp1-write-survives-kill.md) | Integration | Ready | ADR-0007 |
| 013 | [SP-3 death-frame write latency (device)](story-013-sp3-write-latency.md) | Integration | Ready | ADR-0007 |
| 014 | [Android allowBackup disabled and manifest lint](story-014-android-allow-backup-off.md) | Integration | Ready | ADR-0007 |
| 015 | [Real Platform Services wiring integration](story-015-platform-services-wiring.md) | Integration | Ready | ADR-0007 |

## Next Step

Run `/story-readiness production/epics/save-persistence/story-001-persist-math.md`, then `/dev-story`.
