# Story 010: Shipped defaults and sensitivity range smoke check (ADVISORY)

> **Epic**: Settings & Accessibility
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: 1 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/settings-accessibility.md`
**Requirement**: `TR-settings-accessibility-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0009: Test framework and CI (primary); ADR-0002: Game loop, Composition Root and tick order
**ADR Decision Summary**: `tests/advisory/<system>/` holds shipped-default smoke tests; a failure there is a warning, not a CI failure.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: None.
**Control Manifest Rules (this layer)**:
- Required: advisory tests under `tests/advisory/settings_accessibility/`.
- Forbidden: skipping or disabling a failing test to get green.
- Guardrail: exact `==` for bools; `1e-6` for floats.

## Acceptance Criteria
- [ ] **AC-21 (ADVISORY)** Shipped defaults match Core Rule 1: `haptics_enabled` true; `haptics_intensity` 1.0; `tilt_sensitivity` 1.0 (== `DEFAULT_SENSITIVITY`); `reduced_motion_enabled` false; `colorblind_safe_enabled` false; `SENSITIVITY_MIN`/`SENSITIVITY_MAX` referenced as 0.5/2.0.

## Implementation Notes
Construct the core with the production default constructor arguments (no overrides) over a `get_value_seam` stub returning the caller's default for every key, and read the five getters. Read the min/max through the constructor defaults or the exposed constants; assert 0.5 and 2.0. This is the only place the real shipped numbers are asserted, since unit fixtures use 0.4/2.6/1.3.

## Out of Scope
- Stories 002 to 008: all fixture-substituted checks.

## QA Test Cases
- **AC-21**: shipped defaults
  - Given: default-argument core, defaulting stub
  - When: read the five getters and the range constants
  - Then: true, 1.0, 1.0, false, false; 0.5 and 2.0
  - Edge cases: an edit to a shipped default must be flagged here.

## Test Evidence
**Story Type**: Config/Data
**Required evidence**: `tests/advisory/settings_accessibility/settings_accessibility_defaults_test.gd`; smoke check pass note in `production/qa/smoke-[date].md`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 002
- Unlocks: None
