# Story 010: Android export smoke test (load and corrupted copy)

> **Epic**: Map Loader & MapConfig
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4 h
> **Manifest Version**: 2026-10-03
> **Last Updated**: (set by /dev-story when implementation begins)

## Context
**GDD**: none, defined by ADR-0004
**Requirement**: `TR-map-loader-???`
*(Requirement text lives in `docs/architecture/tr-registry.yaml`, read fresh at review time)*
**ADR Governing Implementation**: ADR-0004: Map Loader and MapConfig (primary); ADR-0008 (library loads and compiles from the package); ADR-0006 (export preset)
**ADR Decision Summary**: Load only through `ResourceLoader`; verify on a device export that `map_01.tres` and its typed sub-resources load, and that a corrupted copy gives the failure screen and not a crash.
**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: NEEDS VERIFICATION on device: (1) `ResourceLoader.load` of a remapped, binary-converted `.tres`; (3) null on missing/corrupt, `as MapDefinition` null for wrong type; (4) typed exported properties round-trip in an export (class cache); (5) int into float coercion; ADR-0008 items 1, 2, 3 (typed arrays of Resources, `PackedFloat64Array` precision, enums as int).
**Control Manifest Rules (this layer)**:
- Required: a test that needs a real device is device evidence in `production/qa/evidence/`, blocking at its named gate (not a GUT test)
- Required: `exclude_filter` covers `tests/*`, `addons/gut/*`, `tools/*`, `build/*` when the preset exists
- Forbidden: opening the map path with `FileAccess` or listing with `DirAccess`; committing a keystore
- Guardrail: engine version exactly 4.7.2

## Acceptance Criteria
- [ ] On an Android export, `map_01.tres` loads and Phase A passes: `env`, `hazard_style` and `chunk_library` non-null, typed (ADR-0004 Validation)
- [ ] The library inside the package loads and compiles (structural checks) per ADR-0008 Validation (export smoke test); typed arrays round-trip
- [ ] A corrupted copy of the map (replaced file or pointed path) yields the map-load-failure screen and no crash; the engine error line is tolerated and recorded
- [ ] A missing path yields `MAP_RESOURCE_MISSING` on device and the screen shows; Retry on the corrupted copy fails again with the same screen, no crash
- [ ] The result sheet records verification items 1, 3, 4, 5 of ADR-0004 (and ADR-0008 items 1 to 3) as confirmed, refuted or untested, with device model and Android version

## Implementation Notes
Needs the first export preset (remove `export_presets.cfg` from `.gitignore` in the same commit, see git-workflow). Use a debug-only boot flag to point the loader at a corrupted copy shipped under a debug path, or swap the file in a test export; do not ship the corrupt file in release. Include a screenshot of the failure screen. If the Menus failure screen does not exist yet, record the result via the debug label and mark the screen row "not yet testable".

## Out of Scope
- Story 011: timing (MS-1)
- Menus epic: failure screen design
- Threaded loading

## QA Test Cases
- **AC-1/2**: shipped map on device
  - Setup: debug APK exported from `dev`, launch on a mid-tier phone, `adb logcat` captured
  - Verify: boot reaches Menu; log shows Phase A pass and library compile
  - Pass condition: no error codes, `map_ready` sent
- **AC-3/4**: corrupted and missing
  - Setup: build with the corrupted copy path / missing path
  - Verify: failure screen shown, Retry repeats the failure, process alive after 30 s
  - Pass condition: no crash, no ANR, codes in log match
- **AC-5**: verification sheet filled in

## Test Evidence
**Story Type**: Integration
**Required evidence**: `production/qa/evidence/map-loader-android-export-smoke.md` (device sheet, logcat excerpt, screenshot)
**Status**: [ ] Not yet created

## Dependencies
- Depends on: Story 007, Story 008, Story 009; platform-services epic (export preset)
- Unlocks: first-playable gate evidence for the loader
