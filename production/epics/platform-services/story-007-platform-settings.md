# Story 007: PlatformSettings manifest data and mismatches()

> **Epic**: Platform Services
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: `design/gdd/platform-services.md`
**Requirement**: `TR-platform-services-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0006: Android platform integration (Decision 9); ADR-0005: Sensor source and input pipeline (required_input_settings manifest)
**ADR Decision Summary**: `PlatformSettings` is a data manifest (section, key, expected value, owner tag) covering `project.godot` keys and the export preset keys; the pure function `mismatches(manifest, read)` reports wrong or missing runtime-readable keys.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Runtime reads go through the injected `read_setting` Callable (the node uses `ProjectSettings.get_setting`); the function itself is engine-free. The boot check must confirm `enable_gravity` first, so a missing flag reads as a settings error, not a missing sensor.
**Control Manifest Rules (this layer)**:
- Required: runtime-readable entries `display/window/handheld/orientation` = 1, `application/config/quit_on_go_back` = false, `application/run/max_fps` = 60, `input_devices/sensors/enable_gravity` = true, `input_devices/pointing/emulate_mouse_from_touch` = true, `input_devices/pointing/emulate_touch_from_mouse` = true; check `enable_gravity` first.
- Forbidden: never set `enable_accelerometer` (or other sensor flags) true; the node never repairs a value except `quit_on_go_back`.
- Guardrail: `max_fps` manifest holds one expected value; changing the knob means editing the manifest entry in the same commit.

## Acceptance Criteria
- [ ] **AC-11 [M]** (R8) `PlatformSettings.mismatches(manifest, read)` with a fake `read`: N wrong runtime-readable keys (orientation, `max_fps`, `quit_on_go_back`, a sensor setting) give N `SETTINGS_MISMATCH` entries, one per key with the key as detail; all correct gives none; a missing key (the `read` default) gives a mismatch; export-preset entries (`VIBRATE`, immersive, Picture-in-Picture) are not runtime-readable and are excluded.

## Implementation Notes
The manifest is data (an array of entries with `section`, `key`, `expected`, `owner` tag, and a flag for runtime-readable vs export-preset), not code, so Story 010's lint can read the same entries. Entries tagged `tilt` are shared with Tilt Input AC-37d. Manifest entries from ADR-0006 Decision 9 and ADR-0005 Decision 2; do not add `enable_accelerometer`. Preset entries (VIBRATE true, immersive on, PiP off, key names UNVERIFIED until Story 011) are stored but excluded from `mismatches`. Output goes to the rate-limited sink with the setting key as the log key.

## Out of Scope
- Story 008: the boot call that passes the injected `read_setting` once
- Story 010: CI lint of `project.godot` and `export_presets.cfg`
- Story 011: confirming the export preset key names

## QA Test Cases
- **AC-11**: mismatches
  - Given: a manifest and a fake `read` returning controlled values
  - When: 0, 1, N wrong keys, and a missing key are supplied
  - Then: N entries (one per wrong key, key as detail); none when all correct; missing key produces a mismatch; preset entries never appear
  - Edge cases: `enable_gravity` checked first in report order; orientation 0 (the default) and `quit_on_go_back` true both flagged

## Test Evidence
**Story Type**: Logic
**Required evidence**: `tests/unit/platform_services/platform_services_settings_test.gd` (must pass)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 002
- Unlocks: Story 008, Story 010
