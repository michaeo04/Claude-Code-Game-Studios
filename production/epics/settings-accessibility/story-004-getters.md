# Story 004: Typed getters and seam_contrast_scale, no seam access after construction

> **Epic**: Settings & Accessibility
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 1-2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/settings-accessibility.md`
**Requirement**: `TR-settings-accessibility-007`, `TR-settings-accessibility-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0003: Renderer choice and tube render route (secondary)
**ADR Decision Summary**: Settings has no per-frame work; consumers pull getters. ADR-0003 has Tube Track pull the Settings getter every frame in every state and write its material only on change, so the getter must be cheap and seam-free.
**Engine**: Godot 4.7.2 | **Risk**: LOW (ADR-0003 is HIGH for the renderer, but this story touches no rendering API)
**Engine Notes**: Getters are plain member reads; no engine call.
**Control Manifest Rules (this layer)**:
- Required: six typed getters; `seam_contrast_scale` derived through `SettingsMath`, not stored.
- Forbidden: `_process` in the core; re-reading a seam from any getter.
- Guardrail: exact `==` for call counts.

## Acceptance Criteria
- [ ] **AC-8** After construction (five `get_value_seam` calls), calling each of the six getters, `get_seam_contrast_scale()` included, at least 10 calls in total, leaves the `get_value_seam` call count at exactly 5.

## Implementation Notes
Getters: `get_haptics_enabled() -> bool`, `get_haptics_intensity() -> float`, `get_tilt_sensitivity() -> float`, `get_reduced_motion_enabled() -> bool`, `get_colorblind_safe_enabled() -> bool`, `get_seam_contrast_scale() -> float` (calls `SettingsMath.seam_contrast_scale(_reduced_motion)`; derived, never a stored field). Doc comments on every public method. Also assert in the same test file that `get_seam_contrast_scale()` is `1.0` for the default and `0.0` after reduced motion is stored `true` (covers the getter wiring of F1; the F1 maths is story 001).

## Out of Scope
- Story 005: `set_value` and `setting_changed`.
- Story 012: Tube Track and Environment actually reading the getter.

## QA Test Cases
- **AC-8**: getters never touch the seam
  - Given: core built from the fixture stub; spy count is 5
  - When: call all six getters, at least ten calls in total
  - Then: spy count still exactly 5
  - Edge cases: a getter that re-reads the seam fails by count alone.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/settings_accessibility/settings_accessibility_getters_test.gd`
**Status**: [x] Created and passing
**Evidence**: `settings_accessibility_getters_test.gd` (3 tests: AC-8, F1 wiring)

## Dependencies
- Depends on: Story 001, Story 002
- Unlocks: Story 012
