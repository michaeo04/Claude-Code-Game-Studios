# Story 001: SettingsMath (seam contrast derivation and tilt sensitivity validation)

> **Epic**: Settings & Accessibility
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/settings-accessibility.md`
**Requirement**: `TR-settings-accessibility-008`, `TR-settings-accessibility-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: Settings is a pure `RefCounted` core with no Node and no per-frame callback; ADR-0009 fixes GUT 9.x and the `[system]_[feature]_test.gd` layout.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure static GDScript, no post-cutoff API. `NAN`/`INF` constants and `is_finite()` are stable across 4.x; no verification required.
**Control Manifest Rules (this layer)**:
- Required: tests are `extends GutTest`, functions `test_[scenario]_[expected]`, file `settings_accessibility_[feature]_test.gd` under `tests/unit/settings_accessibility/`.
- Forbidden: `ConfigFile`, `FileAccess`, `DirAccess`, `Input.`, `DisplayServer.`, `Engine.`, `Time.`, `OS.`, `get_tree` in `SettingsMath`; any autoload entry.
- Guardrail: exact `==` for bools/codes/counts; `1e-6` for floats.

## Acceptance Criteria
- [x] **AC-1** `seam_contrast_scale(false)` == `1.0` exactly and `seam_contrast_scale(true)` == `0.0` exactly; each output asserted a member of `{0.0, 1.0}`; a lerp or any other scale factor fails.
- [x] **AC-2** `tilt_sensitivity_validate(raw, min, max, default)` table against 0.4/2.6/1.3: 1.5 -> 1.5 not corrected; 0.4 -> 0.4 not corrected; 2.6 -> 2.6 not corrected; 5.0 -> 2.6 corrected; 0.1 -> 0.4 corrected (clamped to MIN, not DEFAULT); 0.0 -> 1.3 corrected; -2.0 -> 1.3 corrected; NAN -> 1.3 corrected; INF -> 1.3 corrected.

## Implementation Notes
`SettingsMath` is a static class (`class_name SettingsMath`, `RefCounted`), no state. F1: `0.0 if reduced_motion_enabled else 1.0`. F2: `is_valid = is_finite(raw) and raw > 0`; value is `clamp(raw, min, max)` when valid, else `default`; return `{value, was_corrected}` where `was_corrected` is true when the output differs because of clamping or fallback. The function logs nothing (logging belongs to `SettingsCore`, story 003). Typed signatures throughout. Min, max and default are parameters, never read from constants, so the 0.4/2.6/1.3 fixture is exercisable.

## Out of Scope
- Story 003: logging `SETTING_CLAMPED` and applying F2 at boot.
- Story 006: applying F2 on runtime `set_value`.

## QA Test Cases
- **AC-1**: binary derivation
  - Given: no state
  - When: call `seam_contrast_scale(false)` and `(true)`
  - Then: results are exactly 1.0 and 0.0, both in `{0.0, 1.0}`
  - Edge cases: a mutation returning 0.5 or lerping fails.
- **AC-2**: validate table
  - Given: min 0.4, max 2.6, default 1.3
  - When: call with each of the nine rows
  - Then: value and `was_corrected` match the table to 1e-6
  - Edge cases: 0.1 must give 0.4 not 1.3; NAN/INF/0/negative must give 1.3 not 0.4.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/settings_accessibility/settings_accessibility_math_test.gd`
**Status**: [x] Created and passing (`python tools/ci/run_ci.py --only all`)
**Evidence**: `tests/unit/settings_accessibility/settings_accessibility_math_test.gd` (13 tests: AC-1 three tests, AC-2 nine table rows plus -INF, one test each)

## Dependencies
- Depends on: None (test harness: test-harness-ci epic, GUT installed)
- Unlocks: Story 002, Story 003, Story 004, Story 006
