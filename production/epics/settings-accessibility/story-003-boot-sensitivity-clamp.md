# Story 003: Boot-time tilt sensitivity validation and logging

> **Epic**: Settings & Accessibility
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/settings-accessibility.md`
**Requirement**: `TR-settings-accessibility-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0009: Test framework and CI
**ADR Decision Summary**: Settings is a pure core driven through injected Callables, here `log_sink`; correction happens once at boot, never per getter call.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: None beyond stable GDScript; `NAN`/`INF` literals used in the test.
**Control Manifest Rules (this layer)**:
- Required: log through the injected `log_sink(level, code, key, message)`; tests use a fresh core per case.
- Forbidden: `Engine.`, `Time.`, `OS.` calls in `SettingsCore`.
- Guardrail: exact `==` for log counts and codes; `1e-6` for floats.

## Acceptance Criteria
- [ ] **AC-3** The three no-correction rows (1.5, 0.4, 2.6) produce zero `log_sink` calls; each of the six corrected rows produces exactly one `SETTING_CLAMPED` (level `WARNING`) naming key `"tilt_sensitivity"`, verified by call count and args.
- [ ] **AC-7** Constructed with stored `tilt_sensitivity` 5.0 (fixture MAX 2.6): `get_tilt_sensitivity()` returns 2.6 on every one of several repeated calls and `log_sink` records exactly one `SETTING_CLAMPED` in total.

## Implementation Notes
At construction, pass the raw `tilt_sensitivity` through `SettingsMath.tilt_sensitivity_validate(raw, sensitivity_min, sensitivity_max, default_sensitivity)`; store the corrected value in memory; when `was_corrected`, call `log_sink("WARNING", "SETTING_CLAMPED", "tilt_sensitivity", <message>)` once. Getters return the stored value and never re-validate. The AC-3 table is driven through the core constructor (one construction per row) so the log call is observed end to end.

## Out of Scope
- Story 001: the pure validation function itself.
- Story 006: validation on runtime `set_value`.

## QA Test Cases
- **AC-3**: log counts per row
  - Given: nine stored values with 0.4/2.6/1.3 fixture
  - When: construct one core per row
  - Then: 0 logs for 1.5, 0.4, 2.6; exactly 1 `SETTING_CLAMPED` WARNING key `tilt_sensitivity` for the other six
  - Edge cases: logging that depends only on the returned value is not enough; assert the spy.
- **AC-7**: clamp once
  - Given: stored 5.0
  - When: construct, call `get_tilt_sensitivity()` ten times
  - Then: always 2.6; one total log entry
  - Edge cases: re-validating per getter call would re-log and fails.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/settings_accessibility/settings_accessibility_boot_clamp_test.gd`
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 001, Story 002
- Unlocks: Story 006
