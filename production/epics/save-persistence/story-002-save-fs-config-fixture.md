# Story 002: SaveFs facade, SaveConfig and test fixture

> **Epic**: Save & Persistence
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/save-persistence.md`
**Requirement**: `TR-save-persistence-002`, `TR-save-persistence-019` (SaveFs has no engine calls), `TR-save-persistence-022`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: The GDD's eight seams become one `SaveFs` facade (plain base class with failing defaults) plus three Callables (`clock`, `wall_clock`, `log_sink`). `SaveConfig` is a `Resource` with `validated(log_sink)` holding the three knobs; `CURRENT_SCHEMA_VERSION` is a constant.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `@abstract` (4.5) is not used. A `Resource` with only scalar `@export` fields; `validated` returns a clamped `duplicate()` and never mutates the loaded instance.
**Control Manifest Rules (this layer)**:
- Required: `SaveFs` methods return failure values (`false`, `-1`, status `"PARSE_ERROR"` with empty sections); test fakes extend `SaveFs`, record calls in order, script returns; factories live in `tests/support/` with no GUT call.
- Forbidden: `@abstract` for `SaveFs`; engine file calls in `SaveFs`; hardcoded knob values outside `SaveConfig`.
- Guardrail: gameplay values data-driven; knob defaults 1.0 s / 5 / 64 KB, safe ranges 0.5-5.0 / 1-20 / 16 KB-1 MB.

## Acceptance Criteria
- [ ] **AC-23 [K, ADVISORY]** Shipped defaults match Tuning Knobs: `SAVE_LOG_RATE_LIMIT` = 1.0 s, `CORRUPT_BACKUP_RETENTION` = 5, `CURRENT_SCHEMA_VERSION` = 1 (and `SAVE_FILE_SIZE_MAX` = 64 KB), asserted from the shipped `SaveConfig` resource.
- [ ] Support code for later stories exists: `make_save_fixture()` (schema 3, rate limit 0.05, retention 3, keys per GDD Fixture, paths `REAL_PATH`/`TMP_PATH`) and a recording `FakeSaveFs` extending `SaveFs` (records ordered calls, scripted returns). These carry no AC of their own; they are verified by use in Stories 003-008 plus one smoke test here that the fake records order.

## Implementation Notes
Files: `src/core/persistence/save_fs.gd` (ADR-0007 Key Interfaces, verbatim signatures), `src/core/persistence/save_config.gd` (`class_name SaveConfig extends Resource`, `validated(log_sink)` clamps to the safe ranges and logs `KNOB_CLAMPED`), `assets/data/save_config.tres`, `tests/support/save_fixture.gd`, `tests/support/fake_save_fs.gd`. The fixture deliberately uses 3 / 0.05 / 3 so no AC can pass against a shipped default. AC-23 lives in `tests/advisory/save_persistence/`.

## Out of Scope
- Story 003-005, 007: `SaveCore` behaviour.
- Story 009: the real `SaveFs` implementation.

## QA Test Cases
- **AC-23**: shipped defaults
  - Given: `load("res://assets/data/save_config.tres")`
  - When: fields and constant are read
  - Then: 1.0, 5, 65536 (64 KB), schema 1, exact `==` for ints, 1e-6 for floats
  - Edge cases: `validated` with out-of-range values (0.1 s, 0, 5 MB) returns clamped copies and leaves the source unchanged
- **Fake order smoke**: Given a `FakeSaveFs`; When `exists`, `write_config`, `rename` are called; Then the call log equals that order and scripted returns are honoured.

## Test Evidence
**Story Type**: Config/Data
**Required evidence**: `tests/advisory/save_persistence/save_persistence_shipped_defaults_test.gd` (smoke check pass, ADVISORY) plus `tests/unit/save_persistence/save_persistence_fake_fs_test.gd`
**Evidence**: tests/unit/save_persistence/save_persistence_fake_fs_test.gd (6 tests) and tests/advisory/save_persistence/save_persistence_shipped_defaults_test.gd (1 test), passing.
**Status**: [x] Created and passing

## Dependencies
- Depends on: None (cross-epic: test-harness-ci T-1)
- Unlocks: Stories 003, 004, 005, 006, 007, 008, 009
