# Story 004: set_value write path (temp, complete map, rename)

> **Epic**: Save & Persistence
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-save-persistence-006`, `TR-save-persistence-007`, `TR-save-persistence-009`, `TR-save-persistence-016` (the `set_value` rejection part)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: `set_value` is synchronous: reject unserializable values (no memory update, no seam call), update memory, delete an existing TMP, `write_config(TMP, complete_sections)` then `size(TMP) > 0`, `rename(TMP, REAL)`, return true. The map written is always complete.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Real `ConfigFile.save` and `rename_absolute` semantics are unverified and are covered by Stories 009 and 012; here only the call sequence against `FakeSaveFs` is tested. If SP-3 (Story 013) fails, AC-6 is reworded to "writes before the tick returns" and `set_value` only marks dirty.
**Control Manifest Rules (this layer)**:
- Required: `complete_sections` is the whole map including `[_meta].schema_version` and wrong-typed keys carried byte for byte; personal-best write stays inside `set_value`.
- Forbidden: write-behind to `app_backgrounded`; writing a raw `Object` or NaN/infinite `float`; batching or timers.
- Guardrail: a file of a few hundred bytes; one write per `set_value`.

## Acceptance Criteria
- [x] **AC-6 [C]** One `set_value` synchronously calls `write_config(TMP_PATH, sections)` then `rename(TMP_PATH, REAL_PATH)` before returning; `sections` equals the complete in-memory map (every section and key, including `[_meta].schema_version`); no timer or frame mechanism. A mutation passing only the changed section must fail.
- [x] **AC-6b [C]** After loading `personal_best` 500 and `haptics_enabled` true, `set_value("settings","haptics_enabled",false)` then `get_value("scoring","personal_best",-1)` returns 500; the second `write_config` call's `sections` still contains `[scoring].personal_best` = 500.
- [x] **AC-9 [C]** If `exists(TMP_PATH)` is true the next `set_value` calls `delete(TMP_PATH)` before `write_config`; if false, `delete` is never called.
- [x] **AC-13 [C]** `set_value` with an unserializable value calls no seam, leaves the in-memory value unchanged, logs exactly one `UNSERIALIZABLE_VALUE` naming section/key, returns false. (The `PersistMath` half is Story 001.)

## Implementation Notes
Add `set_value` to `save_core.gd` per ADR-0007 Decision 4 steps 1-6; keep the call order exact (`exists`, `delete`, `write_config`, `size`, `rename`) so the fake's log can assert it. The `size(TMP) > 0` check guards a short write on a full disk; its failure takes the same path as a failed write (Story 005). Write `[_meta].schema_version = CURRENT_SCHEMA_VERSION` into the map on the first write of a fresh core. Never drop a key that failed `type_matches` at load: carry it into the map.

## Out of Scope
- Story 005: failure returns, logging and rate limit.
- Story 008: `flush()` and the node.
- Story 013: the latency measurement.

## QA Test Cases
- **AC-6**: Given a loaded fixture and recording fake; When `set_value("scoring","personal_best",900)`; Then the call log is exactly `[exists(TMP), write_config(TMP, full), size(TMP), rename(TMP, REAL)]` and `full` has `[scoring]`, `[settings]` keys, `[_meta]`; Edge: a changed-section-only map fails.
- **AC-6b**: Given the 500/true fixture; When the settings write happens; Then `get_value` returns 500 and the second writer argument holds 500 verbatim; Edge: a wrong-typed `tilt_sensitivity` String is still in the map.
- **AC-9**: Given `exists(TMP)` scripted true, then false; When two `set_value` calls; Then `delete(TMP)` appears before `write_config` once only.
- **AC-13**: Given `Object.new()` value; When `set_value`; Then zero seam calls, one log, false, `get_value` unchanged; Edge: NaN float also rejected.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/save_persistence/save_persistence_write_path_test.gd`
**Status**: Passing
**Evidence**: save_persistence_write_path_test.gd (8 tests): call order, complete map, settings write keeps personal_best, tmp delete once, unserializable and NaN rejected

## Dependencies
- Depends on: Story 001, Story 003
- Unlocks: Stories 005, 007, 008, 013
