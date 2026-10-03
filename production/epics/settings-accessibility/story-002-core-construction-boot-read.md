# Story 002: SettingsCore construction, fixture factories and boot read

> **Epic**: Settings & Accessibility
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: 2026-10-04

## Context
**GDD**: `design/gdd/settings-accessibility.md`
**Requirement**: `TR-settings-accessibility-001`, `TR-settings-accessibility-002`, `TR-settings-accessibility-003`, `TR-settings-accessibility-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0002: Game loop, Composition Root and tick order (primary); ADR-0007: Persistence implementation; ADR-0009: Test framework and CI
**ADR Decision Summary**: `SettingsCore` is constructed third (after `PlatformServices` and `SaveService`) and reads Save once at boot, which ADR-0007 completes synchronously before Settings exists. Test factories live in `tests/support/` as plain `RefCounted` with no GUT calls.
**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: ADR-0007 `type_matches` compares `typeof(stored) == typeof(default)`; every float setting must therefore be requested with a float default (`1.0`, not `1`).
**Control Manifest Rules (this layer)**:
- Required: `SettingsCore` built after `SaveService`; tests reference support code by `const X = preload("res://tests/support/x.gd")`.
- Forbidden: `tests/support/` depending on GUT or naming fakes `Double`/`Spy`; a batched section read; an autoload.
- Guardrail: exact `==` for counts and defaults; `1e-6` for floats.

## Acceptance Criteria
- [ ] **AC-4** Construction calls `get_value_seam` exactly five times, once each for `("settings","haptics_enabled",true)`, `("settings","haptics_intensity",1.0)`, `("settings","tilt_sensitivity",<default_sensitivity>)`, `("settings","reduced_motion_enabled",false)`, `("settings","colorblind_safe_enabled",false)`, verified by spy args.
- [ ] **AC-5** Against a fully populated stub every getter returns the fixture's stored value, never a default.
- [ ] **AC-6** With `get_value_seam` returning the caller's default for `haptics_enabled` only, `get_haptics_enabled()` reads `true` and the other four getters keep their stored values; a companion row with all five keys defaulted reads Core Rule 1 defaults with no error.

## Implementation Notes
`SettingsCore extends RefCounted`; `_init(get_value_seam, set_value_seam, log_sink, sensitivity_min := 0.5, sensitivity_max := 2.0, default_sensitivity := 1.0)`. Exactly five reads, one per key, each with its own default, in the order above. Tilt sensitivity passes through `SettingsMath` validation in story 003; this story reads the raw value. Create `tests/support/settings_fixtures.gd` with `make_settings_fixture()` (0.4 / 2.6 / 1.3; stored `false`, 0.6, 1.75, `true`, `true`), `make_get_value_stub(stored)` (returns Callable plus a spy of `(section,key,default)`), `make_set_value_stub(succeeds := true)`, `make_log_spy()` (records `(level,code,key,message)`), `make_settings_core(...)`. A fresh core per test.

## Out of Scope
- Story 003: clamping a stored out-of-range `tilt_sensitivity`.
- Story 004: getter surface and `seam_contrast_scale` getter.
- Story 012: constructing it in `GameRoot`.

## QA Test Cases
- **AC-4**: five exact reads
  - Given: fixture stub and spy
  - When: construct the core
  - Then: five spy entries equal to the listed tuples, in any order but each exactly once
  - Edge cases: wrong default for a key, a missing key, or one batched call fails.
- **AC-5**: stored values
  - Given: stub with fixture values
  - When: call the five typed getters
  - Then: false, 0.6, 1.75, true, true
  - Edge cases: a getter returning the shipped default fails.
- **AC-6**: per-key isolation
  - Given: stub returning default for `haptics_enabled` only
  - When: construct
  - Then: `get_haptics_enabled()` is true, other four unchanged; all-default row reads defaults, no thrown error
  - Edge cases: cross-contamination between keys.

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/settings_accessibility/settings_accessibility_boot_read_test.gd`
**Evidence**: tests/unit/settings_accessibility/settings_accessibility_boot_read_test.gd (6 tests), passing in run_ci.py --only all.
**Status**: [x] Created and passing

## Dependencies
- Depends on: Story 001; test-harness-ci epic (GUT)
- Unlocks: Story 003 to Story 009, Story 012
