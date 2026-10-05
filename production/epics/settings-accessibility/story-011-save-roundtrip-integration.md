# Story 011: Real Save and Persistence round trip

> **Epic**: Settings & Accessibility
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-05

> **Note**: GDD AC-19 is deferred (no owner/date). The test is BLOCKING only once an owner and date are named; until then it is written and run but does not gate the epic.

## Context
**GDD**: `design/gdd/settings-accessibility.md`
**Requirement**: `TR-settings-accessibility-003`, `TR-settings-accessibility-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0002: Game loop, Composition Root and tick order; ADR-0009: Test framework and CI
**ADR Decision Summary**: `SaveCore.boot_load()` runs once before Settings exists; `set_value` is synchronous; type check compares `typeof` with the caller's default; integration tests write only under a unique per-test temp directory deleted in `after_each`.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Use a test `SaveFs` pointed at a per-test directory under `user://` (the real `ConfigFile` implementation, not a recording fake). `tilt_sensitivity` and `haptics_intensity` must round-trip as floats or they hit `TYPE_MISMATCH`.
**Control Manifest Rules (this layer)**:
- Required: real `SaveCore` plus real `ConfigFile` fs; per-test temp dir removed in `after_each`.
- Forbidden: touching `user://save.cfg` itself; reusing a `ConfigFile` across reads.
- Guardrail: Save file stays a few hundred bytes (`SAVE_FILE_SIZE_MAX` 64 KB).

## Acceptance Criteria
- [ ] **AC-19 (deferred)** A real `SaveCore` receiving `SettingsCore`'s `get_value`/`set_value` through the real seams round-trips a changed setting through a real save/load cycle.

## Implementation Notes
Build `SaveCore` with the real fs facade over a temp path, `boot_load()`, build `SettingsCore` with `save.get_value`/`save.set_value` bound as the seams, change all five settings (including `tilt_sensitivity` 1.5 and `haptics_intensity` 0.5 as floats), drop both objects, build a new `SaveCore` over the same temp path, `boot_load()`, build a new `SettingsCore`, assert the five getters equal the changed values. Add a row where the file is deleted between sessions and defaults return. Add a row for a `WRITE_FAILED` (unwritable temp path): in-memory value kept for the session.

## Out of Scope
- Story 012: consumers and `GameRoot` order.
- Device-level kill-point tests (SP-1), owned by save-persistence.

## QA Test Cases
- **AC-19**: round trip
  - Given: temp directory, real Save, settings changed
  - When: restart both objects over the same path
  - Then: all five getters equal the changed values; deleted file gives the five defaults
  - Edge cases: float-vs-int default mismatch yields `TYPE_MISMATCH` and fails the test; failed write keeps the in-memory value this session.

## Test Evidence
**Story Type**: Integration
**Required evidence**: `tests/integration/settings_accessibility/settings_accessibility_save_roundtrip_test.gd`
**Status**: [x] Created and passing
**Evidence**: `test_all_five_settings_round_trip_a_cold_restart`, `test_deleted_file_between_sessions_returns_the_five_defaults`, `test_failed_write_keeps_value_this_session_and_loses_it_on_restart` (3 tests, real `ConfigFile` fs in a per-test `user://` directory). AC-19 stays deferred (no owner/date), so the test does not gate the epic.

## Dependencies
- Depends on: Story 002, Story 005; cross-epic: save-persistence (`SaveCore`, real `SaveFs`)
- Unlocks: Story 012
