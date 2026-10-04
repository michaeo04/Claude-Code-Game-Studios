# Story 006: Read validity, per-key fallback and error logging

> **Epic**: Save & Persistence
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

> **Unblocked 2026-10-03**: the GDD F2 and AC-10 now say a file-level failure is logged once per load (ADR-0007 Decision 3), so `TR-save-persistence-012` is closed.

## Context
**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-save-persistence-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: `PARSE_ERROR` gives `FILE_UNREADABLE`, an incompatible `[_meta].schema_version` gives `SCHEMA_INCOMPATIBLE`; each invalidates the whole file and is logged once per load at ERROR. `TYPE_MISMATCH` is per key, logged when the key is first read; an absent key logs nothing.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `type_matches` compares `typeof(stored) == typeof(default)` using the caller's own default; a stored `int` where a `float` default is declared is a `TYPE_MISMATCH` (verification item 8 covers real int/float round trip in Story 009).
**Control Manifest Rules (this layer)**:
- Required: whole-file failure returns every default; wrong-typed keys are kept in memory and carried forward; file-level errors logged once per load (ERROR).
- Forbidden: logging an absent key; `SaveCore` supplying its own default.
- Guardrail: error precedence `FILE_UNREADABLE` > `SCHEMA_INCOMPATIBLE` > `TYPE_MISMATCH`.

## Acceptance Criteria
- [ ] **AC-10 [C]** (reworded to ADR-0007, one log per load for rows 1-2): (1) `PARSE_ERROR` -> every requested key returns its default, one `FILE_UNREADABLE` at ERROR for the load; (2) `OK` with `schema_version` 4 vs 3 -> every key returns its default, one `SCHEMA_INCOMPATIBLE` for the load; (3) compatible schema, `haptics_enabled` stored as String -> that key returns its default with one `TYPE_MISMATCH`, while `tilt_sensitivity` returns its stored value with no error.
- [ ] **AC-11 [C]** `get_value("settings","reduced_motion_enabled",false)` on a never-written key returns false and logs nothing; `get_value("settings","haptics_enabled",true)` with a wrong-typed stored value returns true and logs exactly one `TYPE_MISMATCH`.

## Implementation Notes
Use `PersistMath.read_valid`/`read_error_code` (Story 001). Compute `file_parsed_ok` and `compatible` once in `boot_load`; cache the file-level code and log it there. Per-key `has_key` and `type_matches` are evaluated in `get_value`; log `TYPE_MISMATCH` the first time that key is read (a second read of the same key does not log again). Backing the bad file aside is Story 007.

## Out of Scope
- Story 007: oversize guard and moving the file aside.
- Story 003: the happy path.

## QA Test Cases
- **AC-10**: Given the three fixture rows; When `boot_load` and `get_value` for every fixture key; Then row 1 and 2 give defaults and exactly one file-level log each (count `==` 1, not per key); row 3 gives default for `haptics_enabled` plus one `TYPE_MISMATCH` and the real value for `tilt_sensitivity`; Edge: log level of row 1 is ERROR.
- **AC-11**: Given an otherwise valid file; When the missing key and the wrong-typed key are read; Then false/zero logs and true/one `TYPE_MISMATCH`; Edge: reading the wrong-typed key twice logs once.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/save_persistence/save_persistence_read_validity_test.gd`
**Status**: [x] Created and passing
**Evidence**: `save_persistence_read_validity_test.gd` (6 tests: AC-10 rows 1-3, AC-11, double read, int/float mismatch)

## Dependencies
- Depends on: Story 001, Story 003; GDD revision of F2/AC-10 (TR-012 open point)
- Unlocks: Story 007
