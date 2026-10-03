# Story 006: Runtime tilt sensitivity validation and unknown-key rejection

> **Epic**: Settings & Accessibility
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/settings-accessibility.md`
**Requirement**: `TR-settings-accessibility-004`, `TR-settings-accessibility-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0007: Persistence implementation (secondary)
**ADR Decision Summary**: The core is a closed, injected-seam state holder; ADR-0007 rejects non-serializable values (NaN/INF floats) at `Save.set_value`, so Settings must hand it only corrected values.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Passing `NAN` to the seam would be `UNSERIALIZABLE_VALUE` in Save; the F2 correction here prevents that.
**Control Manifest Rules (this layer)**:
- Required: the corrected value, not the raw one, is stored, written and emitted.
- Forbidden: creating any new in-memory slot for an unrecognised key.
- Guardrail: exact `==` for log counts and codes.

## Acceptance Criteria
- [ ] **AC-12** `set_value("tilt_sensitivity", 5.0)` from an in-range current value (fixture MAX 2.6): memory becomes 2.6; `set_value_seam` is called once with 2.6; exactly one `SETTING_CLAMPED` log; `setting_changed` fires once with 2.6.
- [ ] **AC-13** `set_value("haptics_enable", true)` and `set_value("brightness", 0.5)` each return failure, log exactly one `UNKNOWN_SETTING_KEY` warning naming the key, call zero `set_value_seam`, emit zero `setting_changed`, and leave all six getters unchanged; the getter surface is still exactly the six named methods.

## Implementation Notes
In `set_value`, for `tilt_sensitivity` run `SettingsMath.tilt_sensitivity_validate` before the equality check, then continue as story 005 with the corrected value; log `SETTING_CLAMPED` (WARNING, key `tilt_sensitivity`) once when `was_corrected`. Unknown key: `log_sink("WARNING","UNKNOWN_SETTING_KEY", key, ...)` then return `false`. Keep the key set a closed constant list of the five names. The "getter surface" check can inspect `get_method_list()` filtered to `get_*` script methods.

## Out of Scope
- Story 005: ordinary write and event behaviour.
- Story 007: failed seam write.

## QA Test Cases
- **AC-12**: corrected value everywhere
  - Given: fixture core, current in range, spies
  - When: `set_value("tilt_sensitivity", 5.0)`
  - Then: getter 2.6; seam entry value 2.6; one `SETTING_CLAMPED`; one emission with 2.6
  - Edge cases: a mutation writing raw 5.0 fails; NAN input also resolves to default 1.3 and is never written as NaN.
- **AC-13**: unknown keys
  - Given: fixture core and snapshot of the six getters
  - When: both bad-key calls
  - Then: both return false, one `UNKNOWN_SETTING_KEY` log each, zero seam calls, zero emissions, getters equal snapshot
  - Edge cases: silent no-op without logging fails; a new slot fails the getter-surface row.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/settings_accessibility/settings_accessibility_runtime_validation_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001, Story 003, Story 005
- Unlocks: Story 008
