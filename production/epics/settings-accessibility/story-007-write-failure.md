# Story 007: Failed write keeps the in-memory value

> **Epic**: Settings & Accessibility
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 1 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/settings-accessibility.md`
**Requirement**: `TR-settings-accessibility-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0007: Persistence implementation (primary); ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: `Save.set_value` returns `false` on a failed write or rename (`WRITE_FAILED`) and keeps its own in-memory value; Settings does not retry or roll back.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: The false return is the only signal; the real failure path is exercised in story 011.
**Control Manifest Rules (this layer)**:
- Required: the seam's `false` result never reverts memory or suppresses the event.
- Forbidden: retrying the write; rolling back.
- Guardrail: exact `==` for call counts.

## Acceptance Criteria
- [ ] **AC-14** With `make_set_value_stub(succeeds := false)`, `set_value("reduced_motion_enabled", true)` from `false`: `set_value_seam` is called once and returns `false`; `get_reduced_motion_enabled()` returns `true` in the same session; `setting_changed` fires once.

## Implementation Notes
Ignore the boolean returned by `set_value_seam` for state purposes; do not branch on it for the in-memory update or the signal. Do not log it either: Save already logs `WRITE_FAILED`, rate limited (ADR-0007 Decision 4). `set_value` itself still returns `true` for a recognised key.

## Out of Scope
- Story 005: successful write path.
- Story 011: real Save failure.

## QA Test Cases
- **AC-14**: no rollback
  - Given: failing set stub, `reduced_motion_enabled` false
  - When: `set_value("reduced_motion_enabled", true)`
  - Then: one seam call returning false; getter true; one emission
  - Edge cases: a rollback mutation fails; a second call with the same value is a no-op (zero further seam calls, no retry).

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/settings_accessibility/settings_accessibility_write_failure_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 005
- Unlocks: Story 008
